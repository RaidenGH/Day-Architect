import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/focus_session.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'today_screen.dart';
import 'winddown_screen.dart';
import 'progress_screen.dart';

/// Possible states of the focus timer.
enum _TimerStatus { idle, running, paused, completed }

/// Duration presets shown before starting a session.
const _durationPresets = [15, 25, 30, 45, 60];

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  // ── Navigation ──
  int _navIndex = 1;

  // ── Session data (from DB) ──
  List<FocusSession> _sessions = [];
  int _totalMinutes = 0;
  int _totalInterruptions = 0;
  bool _loading = true;
  String? _error;

  // ── Timer state ──
  _TimerStatus _timerStatus = _TimerStatus.idle;
  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  Timer? _timer;
  final TextEditingController _titleController =
      TextEditingController(text: 'Focus Session');


  // ── Lifecycle ──

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  // ── Data loading ──

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final today = _todayString;
      final db = DatabaseHelper();
      final sessions = await db.getFocusSessions(date: today);
      final totalMinutes = await db.getTotalFocusMinutes(date: today);
      final totalInterruptions = sessions.fold(0, (sum, s) => sum + s.interruptions);

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _totalMinutes = totalMinutes;
          _totalInterruptions = totalInterruptions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Could not load focus data.';
        _loading = false;
      });
    }
  }

  // ── Navigation ──

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    _timer?.cancel();
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, fadeSlideRoute(const TodayScreen()));
        break;
      case 2:
        Navigator.pushReplacement(
            context, fadeSlideRoute(const WindDownScreen()));
        break;
      case 3:
        Navigator.pushReplacement(
            context, fadeSlideRoute(const ProgressScreen()));
        break;
    }
  }

  // ── Timer logic ──

  void _startTimer() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    setState(() {
      _timerStatus = _TimerStatus.running;
      _remainingSeconds = _selectedMinutes * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer t) {
    if (_remainingSeconds <= 1) {
      t.cancel();
      _onSessionComplete();
      return;
    }
    setState(() => _remainingSeconds--);
  }

  void _pauseTimer() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() => _timerStatus = _TimerStatus.paused);
  }

  void _resumeTimer() {
    HapticFeedback.mediumImpact();
    setState(() => _timerStatus = _TimerStatus.running);
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timerStatus = _TimerStatus.idle;
      _remainingSeconds = _selectedMinutes * 60;
    });
  }

  /// End the session early (still logs the partial duration).
  void _endSessionEarly() {
    _timer?.cancel();
    _completeAndLog(early: true);
  }

  /// Called when the timer naturally reaches zero.
  void _onSessionComplete() {
    _timer?.cancel();
    HapticFeedback.heavyImpact();
    _completeAndLog(early: false);
  }

  /// Immediately show the completed UI and fire notification,
  /// then log the session to the DB in the background.
  void _completeAndLog({required bool early}) {
    final elapsedMinutes = _selectedMinutes -
        (_remainingSeconds / 60).ceil();
    final actualMinutes =
        early ? elapsedMinutes.clamp(1, _selectedMinutes) : _selectedMinutes;

    // Snap to completed state immediately
    setState(() => _timerStatus = _TimerStatus.completed);

    // Fire notification immediately
    NotificationService().showSessionComplete(actualMinutes);

    // Log to DB in the background
    final session = FocusSession(
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'Focus Session',
      durationMinutes: actualMinutes,
      interruptions: 0,
      date: _todayString,
    );
    DatabaseHelper().insertFocusSession(session).then((_) => _loadData());
  }



  // ── Helpers ──

  String get _todayString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String get _formattedFocus {
    final hours = _totalMinutes ~/ 60;
    final minutes = _totalMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String get _formattedRemaining {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress =>
      _selectedMinutes > 0
          ? 1.0 - (_remainingSeconds / (_selectedMinutes * 60))
          : 0.0;

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top bar ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.arrow_back,
                              color: AppColors.textSecondary),
                          if (_sessions.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${_sessions.length} TODAY',
                                  style: AppTextStyles.body(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: AppColors.accent)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Text('Focus Mode', style: AppTextStyles.eyebrow()),
                      const SizedBox(height: 4),
                      Text(
                        _sessions.isNotEmpty
                            ? 'Studying: ${_sessions.first.title}'
                            : 'No sessions yet today',
                        style: AppTextStyles.body(
                            size: 15,
                            weight: FontWeight.w600,
                            color: AppColors.textLavender),
                      ),

                      const SizedBox(height: 24),

                      // ── Timer ring + controls ──
                      _buildTimerSection(),

                      const SizedBox(height: 22),

                      // ── Stats ──
                      if (_loading)
                        const LoadingIndicator()
                      else if (_error != null)
                        ErrorBanner(message: _error!, onRetry: _loadData)
                      else
                        Row(
                          children: [
                            _infoPill(
                                _formattedFocus, 'Focused today'),
                            const SizedBox(width: 12),
                            _infoPill(
                                '${_sessions.length}', 'Sessions'),
                            const SizedBox(width: 12),
                            _infoPill(
                                '$_totalInterruptions', 'Interruptions'),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // ── Blocking card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BLOCKING RIGHT NOW',
                                style: AppTextStyles.label(size: 10.5)),
                            const SizedBox(height: 12),
                            _blockRow('Instagram', Icons.camera_alt_outlined,
                                const Color(0xFFDC2743)),
                            _blockRow('TikTok', Icons.music_note,
                                Colors.black),
                            _blockRow('Facebook', Icons.facebook,
                                const Color(0xFF1877F2)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Session count banner ──
                      if (_sessions.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '🏆 ${_sessions.length} session${_sessions.length > 1 ? 's' : ''} today — keep going!',
                                style: AppTextStyles.body(
                                    size: 12.5,
                                    weight: FontWeight.w600,
                                    color: AppColors.sage)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                    color: AppColors.sage.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text('+$_formattedFocus',
                                    style: AppTextStyles.body(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: AppColors.sage)),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // ── Ghost button only shown when idle or completed ──
                      if (_timerStatus == _TimerStatus.idle ||
                          _timerStatus == _TimerStatus.completed)
                        GhostButton(
                            label: 'Start another session',
                            onTap: _resetTimer),
                    ],
                  ),
                ),
              ),
              AppBottomNav(activeIndex: _navIndex, onTap: _onNavTap),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Timer section ─────────────────────────────────────────────

  Widget _buildTimerSection() {
    switch (_timerStatus) {
      case _TimerStatus.idle:
        return _buildIdleState();
      case _TimerStatus.running:
        return _buildRunningState();
      case _TimerStatus.paused:
        return _buildPausedState();
      case _TimerStatus.completed:
        return _buildCompletedState();
    }
  }

  /// IDLE state — pick duration, enter title, start.
  Widget _buildIdleState() {
    return Column(
      children: [
        // Duration presets
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _durationPresets.map((m) {
            final active = m == _selectedMinutes;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedMinutes = m;
                  _remainingSeconds = m * 60;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: active ? AppColors.accent : Colors.white.withValues(alpha: 0.08),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    '${m}m',
                    style: AppTextStyles.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: active ? AppColors.accent : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Timer ring (shows selected duration, not yet started)
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                    painter: _RingPainter(progress: 0.0)),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formattedRemaining,
                      style: AppTextStyles.heading(size: 42)),
                  const SizedBox(height: 4),
                  Text('ready to focus',
                      style: AppTextStyles.body(
                          size: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Session title field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: TextField(
            controller: _titleController,
            style: AppTextStyles.body(
                size: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'What are you focusing on?',
              hintStyle: AppTextStyles.body(
                  size: 13, color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Start button
        PrimaryButton(label: 'Start Focus', onTap: _startTimer),
      ],
    );
  }

  /// RUNNING state — countdown shown, pause available.
  Widget _buildRunningState() {
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                    painter: _RingPainter(progress: _progress)),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formattedRemaining,
                      style: AppTextStyles.heading(size: 42)),
                  const SizedBox(height: 4),
                  Text('remaining',
                      style: AppTextStyles.body(
                          size: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pause button
            GestureDetector(
              onTap: _pauseTimer,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.pause_rounded,
                    color: AppColors.accent, size: 26),
              ),
            ),
            const SizedBox(width: 20),
            // End early button
            GestureDetector(
              onTap: _endSessionEarly,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0x30F26464),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: const Color(0xFFF26464).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stop_rounded,
                        color: Color(0xFFF26464), size: 18),
                    const SizedBox(width: 6),
                    Text('End',
                        style: AppTextStyles.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: const Color(0xFFF26464))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// PAUSED state — countdown frozen, resume or end.
  Widget _buildPausedState() {
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                    painter: _RingPainter(progress: _progress)),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formattedRemaining,
                      style: AppTextStyles.heading(size: 42)),
                  const SizedBox(height: 4),
                  Text('paused',
                      style: AppTextStyles.body(
                          size: 12, color: AppColors.accent)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Resume button
            GestureDetector(
              onTap: _resumeTimer,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppGradients.accentButton,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 16)
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: AppColors.bgMid, size: 28),
              ),
            ),
            const SizedBox(width: 20),
            // End early
            GestureDetector(
              onTap: _endSessionEarly,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0x30F26464),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: const Color(0xFFF26464).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stop_rounded,
                        color: Color(0xFFF26464), size: 18),
                    const SizedBox(width: 6),
                    Text('End',
                        style: AppTextStyles.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: const Color(0xFFF26464))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// COMPLETED state — celebration, logged to DB.
  Widget _buildCompletedState() {
    final elapsed = _selectedMinutes;
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                    painter: _RingPainter(progress: 1.0)),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 4),
                  Text('Complete!',
                      style: AppTextStyles.heading(size: 24)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.sage.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.sage.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.sage, size: 20),
              const SizedBox(width: 8),
              Text(
                _formatMinutes(elapsed),
                style: AppTextStyles.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.sage),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // ── Shared widgets ──

  Widget _infoPill(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.body(
                    size: 15, weight: FontWeight.w700)),
            Text(label,
                style: AppTextStyles.body(
                    size: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _blockRow(String name, IconData icon, Color iconBg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(name,
                  style: AppTextStyles.body(
                      size: 13, weight: FontWeight.w500)),
            ],
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0x30F26464),
                borderRadius: BorderRadius.circular(20)),
            child: Text('Blocked',
                style: AppTextStyles.body(
                    size: 10,
                    weight: FontWeight.w700,
                    color: const Color(0xFFF26464))),
          ),
        ],
      ),
    );
  }
}

// ── Custom ring painter ──

class _RingPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0 (fraction of ring filled)

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress gradient ring
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.accent, AppColors.accentSoft],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2; // 12 o'clock
    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
