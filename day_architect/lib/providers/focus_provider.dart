import 'dart:async';
import 'package:flutter/material.dart';
import '../models/focus_session.dart';
import '../screens/app_picker_screen.dart';
import '../services/app_block_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

/// Possible states of the focus timer state machine.
enum FocusTimerState { idle, running, paused }

/// Reactive state provider for the Focus Mode screen.
/// Manages timer countdown, session persistence, notifications, and
/// Android app blocking (detects when blocked apps are opened).
class FocusProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final NotificationService _notif = NotificationService();
  final AppBlockService _blocker = AppBlockService.instance;

  // --- Timer state ---
  FocusTimerState _timerState = FocusTimerState.idle;
  Timer? _timer;
  int _remainingSeconds = 0;
  int _plannedSeconds = 0;
  String _sessionSubject = '';
  int? _activeSessionId;
  DateTime? _sessionStartTime;

  // --- Pending blocked app (for real-time redirect) ---
  String? _pendingBlockedAppName;

  // --- Today's aggregated stats ---
  List<FocusSession> _todaySessions = [];

  // --- App blocking state ---
  List<String> _blockedApps = [];
  bool _appBlockingActive = false;
  bool _usageStatsGranted = false;
  bool _overlayGranted = false;
  StreamSubscription<String>? _foregroundSub;

  // --- Getters ---
  FocusTimerState get timerState => _timerState;
  bool get isRunning => _timerState == FocusTimerState.running;
  bool get isPaused => _timerState == FocusTimerState.paused;
  bool get isIdle => _timerState == FocusTimerState.idle;
  bool get isActive => _timerState != FocusTimerState.idle;

  int get remainingSeconds => _remainingSeconds;
  int get plannedSeconds => _plannedSeconds;
  String get sessionSubject => _sessionSubject;

  int get remainingMinutes => _remainingSeconds ~/ 60;
  int get remainingSecs => _remainingSeconds % 60;

  double get progress =>
      _plannedSeconds > 0 ? 1.0 - (_remainingSeconds / _plannedSeconds) : 0.0;

  /// Whether a blocked app was detected during the current session
  /// (used by FocusScreen to show a redirect dialog when user returns).
  bool get hasPendingBlockedApp => _pendingBlockedAppName != null;

  /// The human-friendly name of the last blocked app detected.
  String? get pendingBlockedAppName => _pendingBlockedAppName;

  /// Clear the pending blocked app state (after dialog is shown).
  void clearPendingBlockedApp() {
    _pendingBlockedAppName = null;
    // Dismiss the native system overlay as well
    _blocker.dismissBlockOverlay().catchError((_) {});
    notifyListeners();
  }

  // --- App blocking getters ---
  bool get appBlockingActive => _appBlockingActive;
  bool get usageStatsGranted => _usageStatsGranted;
  bool get overlayGranted => _overlayGranted;
  List<String> get blockedApps => _blockedApps;
  bool get isAndroid => _blocker.isAndroid;

  /// Human-friendly names for the blocked apps shown in the UI.
  List<String> get blockedAppNames =>
      _blockedApps.map(AppBlockService.friendlyName).toList();

  /// The blocked app list for the "Blocking right now" card in the timer view.
  List<Map<String, String>> get blockedAppsWithIcons => _blockedApps.map((pkg) {
        final name = AppBlockService.friendlyName(pkg);
        final icon = _iconForPackage(pkg);
        return {'name': name, 'package': pkg, 'icon': icon};
      }).toList();

  // --- Today's stats ---
  List<FocusSession> get todaySessions => _todaySessions;
  int get totalMinutesToday =>
      _todaySessions.fold(0, (sum, s) => sum + s.actualMinutes);
  int get sessionCountToday => _todaySessions.length;
  int get totalInterruptionsToday =>
      _todaySessions.fold(0, (sum, s) => sum + s.interruptions);

  String get formattedTotalToday {
    final m = totalMinutesToday;
    final h = m ~/ 60;
    final r = m % 60;
    if (h > 0 && r > 0) return '${h}h ${r}m';
    if (h > 0) return '${h}h';
    return '$r min';
  }

  // ======================== Lifecycle ========================

  /// Load blocked apps from DB (read directly from is_blocked = 1 rows).
  Future<void> init() async {
    _usageStatsGranted = await _blocker.isUsageStatsGranted;
    _overlayGranted = await _blocker.canDrawOverlays;
    _blockedApps = await _db.getBlockedPackageNames();
    notifyListeners();
  }

  /// Open the app picker (instant-toggle style). It reads/writes the
  /// blocked_apps table directly, so we just refresh our state on return.
  Future<void> openAppPicker(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AppPickerScreen()),
    );
    // Refresh state from DB after the picker closes (toggles were persisted
    // instantly, so this catches any changes the user made).
    _blockedApps = await _db.getBlockedPackageNames();
    notifyListeners();
  }

  /// Load today's sessions in background.
  Future<void> loadToday() async {
    try {
      final todayStr = DatabaseHelper.formatDate(DateTime.now());
      _todaySessions = await _db.getFocusSessions(date: todayStr);
    } catch (e) {
      debugPrint('FocusProvider.loadToday error: $e');
      _todaySessions = [];
    }
    notifyListeners();
  }

  /// Check (or re-check) whether Usage Access is granted.
  Future<void> refreshUsageStatsPermission() async {
    _usageStatsGranted = await _blocker.isUsageStatsGranted;
    notifyListeners();
  }

  /// Check (or re-check) whether SYSTEM_ALERT_WINDOW overlay permission is granted.
  Future<void> refreshOverlayPermission() async {
    _overlayGranted = await _blocker.canDrawOverlays;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _foregroundSub?.cancel();
    _blocker.stopMonitoring();
    super.dispose();
  }

  // ======================== Timer Controls ========================

  /// Start a new focus session for [subject] lasting [durationMinutes].
  Future<void> startSession({
    required String subject,
    required int durationMinutes,
  }) async {
    _timer?.cancel();
    _foregroundSub?.cancel();
    _pendingBlockedAppName = null;

    _sessionSubject = subject;
    _plannedSeconds = durationMinutes * 60;
    _remainingSeconds = _plannedSeconds;

    final todayStr = DatabaseHelper.formatDate(DateTime.now());
    final session = FocusSession(
      subject: subject,
      plannedMinutes: durationMinutes,
      actualMinutes: 0,
      date: todayStr,
      startTime: DateTime.now(),
    );
    _sessionStartTime = DateTime.now();
    _activeSessionId = await _db.insertFocusSession(session);

    _timerState = FocusTimerState.running;
    _startTick();
    _startAppBlocking();
    notifyListeners();
  }

  void pauseSession() {
    if (_timerState != FocusTimerState.running) return;
    _timer?.cancel();
    _timerState = FocusTimerState.paused;
    _foregroundSub?.pause();
    notifyListeners();
  }

  void resumeSession() {
    if (_timerState != FocusTimerState.paused) return;
    _timerState = FocusTimerState.running;
    _startTick();
    _foregroundSub?.resume();
    notifyListeners();
  }

  Future<void> endSession() async {
    _timer?.cancel();
    await _saveCompletedSession();
    _stopAppBlocking();
    _timerState = FocusTimerState.idle;
    _activeSessionId = null;
    _sessionStartTime = null;
    _pendingBlockedAppName = null;
    // Dismiss the native system overlay
    await _blocker.dismissBlockOverlay();
    await loadToday();
    notifyListeners();
  }

  Future<void> _onTimerComplete() async {
    _timer?.cancel();
    _remainingSeconds = 0;
    _timerState = FocusTimerState.idle;
    await _saveCompletedSession();
    _stopAppBlocking();
    await _blocker.dismissBlockOverlay();
    await loadToday();

    final elapsed = _plannedSeconds ~/ 60;
    await _notif.showSessionComplete(elapsed);
    notifyListeners();
  }

  // ======================== App Blocking ========================

  Future<void> _startAppBlocking() async {
    if (!_blocker.isAndroid) return;

    // Re-read blocked apps from DB right before starting
    _blockedApps = await _db.getBlockedPackageNames();
    _usageStatsGranted = await _blocker.isUsageStatsGranted;

    await _blocker.startMonitoring(blocked: _blockedApps);

    _foregroundSub = _blocker.onForegroundAppChanged.listen((package) {
      if (_blocker.isBlockedPackage(package) && _timerState == FocusTimerState.running) {
        _interruptedBy(package);
      }
    });

    _appBlockingActive = true;
    notifyListeners();
  }

  Future<void> _stopAppBlocking() async {
    _foregroundSub?.cancel();
    _foregroundSub = null;
    await _blocker.stopMonitoring();
    _appBlockingActive = false;
    notifyListeners();
  }

  int _blockedAppInterruptions = 0;

  void _interruptedBy(String package) {
    _blockedAppInterruptions++;
    final name = AppBlockService.friendlyName(package);
    _pendingBlockedAppName = name;
    debugPrint('FocusProvider: Blocked app detected – $package (interruption #$_blockedAppInterruptions)');

    // Fire a notification so even if Day Architect is in the background,
    // the user gets an immediate alert and can tap to return.
    _notif.showNotification(
      id: _blockedNotificationId,
      title: '🚫 Focus Interrupted',
      body: '$name was blocked — tap to return to your session.',
    ).catchError((_) {});

    // Show a full-screen system overlay that literally freezes the blocked app
    // The overlay covers the entire screen so the user can't interact with the blocked app
    _blocker.showBlockOverlay(appName: name).catchError((_) {});

    notifyListeners();
  }

  /// Whether the user has at least one app toggled on.
  bool get hasBlockedAppsSelected => _blockedApps.isNotEmpty;

  /// Display string for the "Blocking: X apps" row on the setup screen.
  String get blockedAppsSummary {
    if (_blockedApps.isEmpty) return 'No apps blocked — tap to choose';
    final count = _blockedApps.length;
    return 'Blocking: $count app${count == 1 ? '' : 's'}';
  }

  // ======================== Internal ========================

  void _startTick() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        _onTimerComplete();
      }
    });
  }

  Future<void> _saveCompletedSession() async {
    if (_activeSessionId == null) return;

    final elapsedMinutes = (_plannedSeconds - _remainingSeconds) ~/ 60;
    final updated = FocusSession(
      id: _activeSessionId,
      subject: _sessionSubject,
      plannedMinutes: _plannedSeconds ~/ 60,
      actualMinutes: elapsedMinutes > 0 ? elapsedMinutes : 0,
      interruptions: _blockedAppInterruptions,
      date: DatabaseHelper.formatDate(DateTime.now()),
      startTime: _sessionStartTime,
      endTime: DateTime.now(),
    );
    _blockedAppInterruptions = 0;
    await _db.updateFocusSession(updated);
  }

  String _iconForPackage(String pkg) {
    switch (pkg) {
      case 'com.instagram.android':
        return '📸';
      case 'com.facebook.katana':
      case 'com.facebook.orca':
        return '👤';
      case 'com.twitter.android':
        return '🐦';
      case 'com.snapchat.android':
        return '👻';
      case 'com.zhiliaoapp.musically':
      case 'com.ss.android.ugc.trill':
        return '🎵';
      case 'com.spotify.music':
        return '🎧';
      case 'com.netflix.mediaclient':
        return '🎬';
      case 'com.google.android.youtube':
        return '▶️';
      default:
        return '🚫';
    }
  }

  // ======================== Constants ========================

  /// Notification ID for blocked app alerts (reused so it replaces previous).
  static const _blockedNotificationId = 999002;
}
