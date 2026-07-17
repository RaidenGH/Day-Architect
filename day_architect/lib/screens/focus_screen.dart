import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/focus_provider.dart';
import '../services/app_block_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/page_transitions.dart';
import 'today_screen.dart';
import 'winddown_screen.dart';
import 'progress_screen.dart';

class FocusScreen extends StatefulWidget {
  final String? initialSubject;
  const FocusScreen({super.key, this.initialSubject});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final int _navIndex = 1;
  late final TextEditingController _subjectCtrl;
  final TextEditingController _durationCtrl = TextEditingController(text: '25');

  // Cached provider values — updated by _syncFromProvider.
  bool _isActive = false;
  bool _isPaused = false;
  bool _isRunning = false;
  int _remainingSeconds = 0;
  int _plannedSeconds = 0;
  String _sessionSubject = '';
  int _sessionCountToday = 0;
  int _totalInterruptions = 0;
  String _formattedTotal = '0 min';
  bool _appBlockingActive = false;
  bool _usageStatsGranted = false;
  bool _overlayGranted = false;
  List<String> _blockedAppNames = [];
  String _blockedAppsSummary = 'No apps selected — tap to choose';

  FocusProvider? _provider;
  bool _providerOk = false;

  // ======================== Lifecycle ========================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subjectCtrl = TextEditingController(text: widget.initialSubject ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final p = context.read<FocusProvider>();
        _provider = p;
        _providerOk = true;
        p.addListener(_onProviderChanged);
        await p.init();
        _syncFromProvider(p);
        p.loadToday().catchError((_) {});
      } catch (e) {
        debugPrint('FocusScreen: Provider not available – $e');
        _providerOk = false;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider?.removeListener(_onProviderChanged);
    _subjectCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _providerOk) {
      // When the app comes back to foreground, check if a blocked app
      // was detected during the session and show the redirect dialog.
      _checkPendingBlockedApp();
    }
  }

  void _checkPendingBlockedApp() {
    if (_provider == null || !_providerOk) return;
    if (!_provider!.isActive) return;
    if (!_provider!.hasPendingBlockedApp) return;

    final appName = _provider!.pendingBlockedAppName ?? 'a blocked app';
    _showBlockedAppDialog(appName);
  }

  void _showBlockedAppDialog(String appName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF26464).withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 28,
                  color: Color(0xFFF26464),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '🚫 $appName',
                style: AppTextStyles.body(
                  size: 16,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You tried to open a blocked app during your focus session.\nTap below to get back on track.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  size: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child:                GestureDetector(
                  onTap: () {
                    _provider?.clearPendingBlockedApp();
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppGradients.accentButton,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Return to Focus',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2142),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    _provider?.endSession();
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'End Session',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onProviderChanged() {
    if (!mounted || _provider == null) return;
    _syncFromProvider(_provider!);
  }

  void _syncFromProvider(FocusProvider p) {
    setState(() {
      _isActive = p.isActive;
      _isPaused = p.isPaused;
      _isRunning = p.isRunning;
      _remainingSeconds = p.remainingSeconds;
      _plannedSeconds = p.plannedSeconds;
      _sessionSubject = p.sessionSubject;
      _sessionCountToday = p.sessionCountToday;
      _totalInterruptions = p.totalInterruptionsToday;
      _formattedTotal = p.formattedTotalToday;
      _appBlockingActive = p.appBlockingActive;
      _usageStatsGranted = p.usageStatsGranted;
      _overlayGranted = p.overlayGranted;
      _blockedAppNames = p.blockedAppNames;
      _blockedAppsSummary = p.blockedAppsSummary;
    });
  }

  // ======================== Actions ========================

  void _startSession() {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('What are you focusing on?')),
      );
      return;
    }
    if (!_providerOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Focus provider not ready. Try again.')),
      );
      return;
    }
    // Don't start a session if no apps are selected to block
    if (!_provider!.hasBlockedAppsSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one app to block first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 25;
    _provider!.startSession(subject: subject, durationMinutes: duration);
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        pushReplacementPage(context, const TodayScreen());
        break;
      case 2:
        pushReplacementPage(context, const WindDownScreen());
        break;
      case 3:
        pushReplacementPage(context, const ProgressScreen());
        break;
    }
  }

  // ======================== Build ========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isActive ? _buildTimerView() : _buildIdleView(),
              ),
              AppBottomNav(activeIndex: _navIndex, onTap: _onNavTap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          Text('Focus Mode', style: AppTextStyles.eyebrow()),
          if (_isActive)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isPaused ? '● PAUSED' : '● LIVE',
                style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: _isPaused ? AppColors.textMuted : AppColors.accent),
              ),
            ),
        ],
      ),
    );
  }

  // ======================== Idle (setup form) ========================

  void _openAppPicker() async {
    await _provider?.openAppPicker(context);
  }

  Widget _buildIdleView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubjectField(),
          const SizedBox(height: 20),
          _buildDurationRow(),
          const SizedBox(height: 12),
          _buildBlockedAppsRow(),
          // Permission warnings for Android
          if (_sessionCountToday > 0 && !_usageStatsGranted) ...[
            const SizedBox(height: 12),
            _buildPermissionBanner(),
          ],
          if (_sessionCountToday > 0 && !_overlayGranted) ...[
            const SizedBox(height: 8),
            _buildOverlayBanner(),
          ],
          const SizedBox(height: 32),
          if (_sessionCountToday > 0) ..._buildStatsSection(),
          if (_sessionCountToday == 0) _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildBlockedAppsRow() {
    final hasSelection = _blockedAppNames.isNotEmpty;
    return GestureDetector(
      onTap: _openAppPicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasSelection
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  hasSelection
                      ? Icons.shield_rounded
                      : Icons.shield_outlined,
                  size: 16,
                  color: hasSelection
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _blockedAppsSummary,
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w500,
                  color: hasSelection
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: hasSelection
                  ? AppColors.textSecondary
                  : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _requestUsageAccess() async {
    // Open system settings so the user can grant Usage Access
    await AppBlockService.instance.openUsageStatsSettings();
    // Then refresh the permission check
    await _provider?.refreshUsageStatsPermission();
  }

  void _requestOverlayAccess() async {
    // Open system settings so the user can grant overlay permission
    await AppBlockService.instance.openOverlaySettings();
    // Then refresh the permission check
    await _provider?.refreshOverlayPermission();
  }

  Widget _buildPermissionBanner() {
    return GestureDetector(
      onTap: _requestUsageAccess,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usage Access needed',
                    style: AppTextStyles.body(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.accent),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to open settings →',
                    style: AppTextStyles.body(
                        size: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayBanner() {
    return GestureDetector(
      onTap: _requestOverlayAccess,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.plum.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.plum.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.layers_outlined, color: AppColors.plum, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App freeze needs overlay permission',
                    style: AppTextStyles.body(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.plum),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to grant in Settings →',
                    style: AppTextStyles.body(
                        size: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'What are you studying?',
          child: Text('What are you studying?',
              style: AppTextStyles.body(
                  size: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 6),
        Semantics(
          textField: true,
          label: 'Focus subject',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: TextField(
              controller: _subjectCtrl,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'e.g. Software Design Lecture',
                hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A87B0)),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Minutes',
                hintStyle: TextStyle(fontSize: 14, color: Color(0xFF8A87B0)),
                suffixText: 'min',
                suffixStyle: TextStyle(fontSize: 13, color: Color(0xFF8A87B0)),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _startSession,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppGradients.accentButton,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Start',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2142))),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStatsSection() {
    return [
      Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(200, 200),
                painter: _RingPainter(progress: 0),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formattedTotal,
                      style: AppTextStyles.heading(size: 34)),
                  const SizedBox(height: 2),
                  Text('focused today',
                      style: AppTextStyles.body(
                          size: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          _pill(_formattedTotal, 'Focused today'),
          const SizedBox(width: 10),
          _pill('$_sessionCountToday', 'Sessions'),
          const SizedBox(width: 10),
          _pill('$_totalInterruptions', 'Interruptions'),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.sage.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '🏆 $_sessionCountToday session${_sessionCountToday == 1 ? '' : 's'} today',
          style: AppTextStyles.body(
              size: 12, weight: FontWeight.w600, color: AppColors.sage),
        ),
      ),
    ];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Semantics(
        label: 'No focus sessions yet',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textMuted.withValues(alpha: 0.1),
              ),
              child: Icon(Icons.track_changes_rounded,
                  size: 36,
                  color: AppColors.textMuted.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 12),
            Text('No sessions yet',
                style: AppTextStyles.body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text('Set a subject and tap Start above',
                style: AppTextStyles.body(
                    size: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  // ======================== Timer View ========================

  Widget _buildTimerView() {
    final minStr = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secStr = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          Text('Studying: $_sessionSubject',
              style: AppTextStyles.body(
                  size: 15,
                  weight: FontWeight.w600,
                  color: AppColors.textLavender)),
          const SizedBox(height: 40),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0.0,
                end: _plannedSeconds > 0
                    ? 1.0 - (_remainingSeconds / _plannedSeconds)
                    : 0.0,
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              builder: (context, progress, _) => SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(220, 220),
                      painter: _RingPainter(progress: progress.clamp(0.0, 1.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label:
                              '$minStr minutes $secStr seconds remaining',
                          child: Text('$minStr:$secStr',
                              style: AppTextStyles.heading(size: 44)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isPaused ? 'paused' : 'remaining',
                          style: AppTextStyles.body(
                              size: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Blocking right now card
          if (_blockedAppNames.isNotEmpty)
            _buildBlockingCard(),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRunning)
                _controlBtn(Icons.pause_rounded, 'Pause', AppColors.accent,
                    () => _provider?.pauseSession()),
              if (_isPaused)
                _controlBtn(Icons.play_arrow_rounded, 'Resume', AppColors.accent,
                    () => _provider?.resumeSession()),
              const SizedBox(width: 14),
              _controlBtn(Icons.stop_rounded, 'End', const Color(0xFFF26464),
                  () => _provider?.endSession()),
            ],
          ),

          // Permission warnings
          if (!_usageStatsGranted) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _requestUsageAccess,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'App blocking needs Usage Access — tap to enable',
                        style: AppTextStyles.body(
                            size: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!_overlayGranted) ...[
            const SizedBox(height: 8),
            _buildOverlayBanner(),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockingCard() {
    final provider = _provider;
    final apps = provider?.blockedAppsWithIcons ?? [];
    if (apps.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BLOCKING RIGHT NOW',
              style: AppTextStyles.label(size: 10.5)),
          const SizedBox(height: 8),
          if (_appBlockingActive)
            Text(
              'These apps are blocked during your session',
              style: AppTextStyles.body(
                  size: 11, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 12),
          ...apps.take(5).map((app) => _blockRow(
                app['name'] ?? app['package'] ?? '',
                app['icon'] ?? '🚫',
                _colorForPackage(app['package'] ?? ''),
              )),
        ],
      ),
    );
  }

  Widget _blockRow(String name, String emoji, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: AppTextStyles.body(
                    size: 13, weight: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF26464).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Blocked',
                style: AppTextStyles.body(
                    size: 9.5,
                    weight: FontWeight.w700,
                    color: const Color(0xFFF26464))),
          ),
        ],
      ),
    );
  }

  // ======================== Shared Widgets ========================

  Widget _controlBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.body(size: 15, weight: FontWeight.w700)),
            Text(label,
                style: AppTextStyles.body(
                    size: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Color _colorForPackage(String pkg) {
    switch (pkg) {
      case 'com.instagram.android':
        return const Color(0xFFDC2743);
      case 'com.facebook.katana':
      case 'com.facebook.orca':
        return const Color(0xFF1877F2);
      case 'com.twitter.android':
        return const Color(0xFF1DA1F2);
      case 'com.snapchat.android':
        return const Color(0xFFFFFC00);
      case 'com.zhiliaoapp.musically':
      case 'com.ss.android.ugc.trill':
        return Colors.black;
      case 'com.spotify.music':
        return const Color(0xFF1DB954);
      case 'com.netflix.mediaclient':
        return const Color(0xFFE50914);
      case 'com.google.android.youtube':
        return const Color(0xFFFF0000);
      default:
        return AppColors.textMuted;
    }
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..shader = const LinearGradient(
              colors: [AppColors.accent, AppColors.accentSoft])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2;
    final sweepAngle = 2 * 3.14159 * (progress.clamp(0.0, 1.0));
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
