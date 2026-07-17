import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/page_transitions.dart';
import '../widgets/add_edit_task_sheet.dart';
import 'focus_screen.dart';
import 'winddown_screen.dart';
import 'progress_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _navIndex = 0;
  late String _greeting;
  late String _dateDisplay;

  @override
  void initState() {
    super.initState();
    _greeting = _computeGreeting();
    _dateDisplay = _formatDisplayDate(DateTime.now());
    // Load data after the first frame so the Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadToday();
    });
  }

  String _computeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDisplayDate(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    setState(() => _navIndex = index);
    switch (index) {
      case 1:
        pushPage(context, const FocusScreen());
        break;
      case 2:
        pushPage(context, const WindDownScreen());
        break;
      case 3:
        pushPage(context, const ProgressScreen());
        break;
    }
  }

  /// Tap a task card → toggle done state.
  Future<void> _onTaskTap(Task task) async {
    if (!mounted) return;
    final provider = context.read<TaskProvider>();
    await provider.toggleDone(task);
  }

  /// Long-press a task card → open edit sheet.
  Future<void> _onTaskLongPress(Task task) async {
    final provider = context.read<TaskProvider>();
    final result = await AddEditTaskSheet.show(
      context,
      existingTask: task,
    );
    if (result == null || !mounted) return;

    if (result.delete) {
      await provider.deleteTask(task.id!);
    } else if (result.task != null) {
      final edited = result.task!;
      // Preserve date and sortOrder from the original
      final updated = edited.copyWith(
        id: task.id,
        date: task.date,
        sortOrder: task.sortOrder,
      );
      await provider.updateTask(updated);
    }
  }

  /// FAB → open Add Task sheet.
  Future<void> _openAddTask() async {
    final provider = context.read<TaskProvider>();
    final result = await AddEditTaskSheet.show(context);
    if (result != null && result.task != null && mounted) {
      await provider.addTask(result.task!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Consumer<TaskProvider>(
                      builder: (context, provider, _) {
                        if (provider.loading) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final tasks = provider.tasks;
                        final streak = provider.streak;
                        final totalDone = provider.totalDone;

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$_greeting 👋',
                                  style: AppTextStyles.eyebrow()),
                              const SizedBox(height: 2),
                              Text(_dateDisplay,
                                  style: AppTextStyles.heading(size: 27)),
                              const SizedBox(height: 16),

                              // Streak bar
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 11),
                                decoration: BoxDecoration(
                                  color: AppColors.cardSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      const Text('🔥',
                                          style: TextStyle(fontSize: 18)),
                                      const SizedBox(width: 8),
                                      RichText(
                                        text: TextSpan(
                                          style: AppTextStyles.body(
                                              size: 13,
                                              weight: FontWeight.w600),
                                          children: [
                                            TextSpan(
                                                text: '$streak-day',
                                                style: AppTextStyles.body(
                                                    size: 13,
                                                    weight: FontWeight.w600,
                                                    color: AppColors.accent)),
                                            const TextSpan(text: ' streak'),
                                          ],
                                        ),
                                      ),
                                    ]),
                                    Text(
                                      tasks.isEmpty
                                          ? 'No blocks yet'
                                          : '$totalDone / ${tasks.length} blocks done',
                                      style: AppTextStyles.body(
                                          size: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),
                              Text("TODAY'S SCHEDULE",
                                  style: AppTextStyles.label()),
                              const SizedBox(height: 10),

                              if (tasks.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: Semantics(
                                      label:
                                          'No tasks yet. Tap the plus button to add your first block.',
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.textMuted
                                                  .withValues(alpha: 0.1),
                                            ),
                                            child: Icon(
                                                Icons.event_note_outlined,
                                                size: 32,
                                                color: AppColors.textMuted
                                                    .withValues(alpha: 0.5)),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            'Your day is wide open',
                                            style: AppTextStyles.body(
                                                size: 14,
                                                weight: FontWeight.w600,
                                                color: AppColors.textMuted),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tap + to add your first block',
                                            style: AppTextStyles.body(
                                                size: 12,
                                                color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...tasks.map((task) => TaskCard(
                                      time: task.time,
                                      title: task.title,
                                      chipLabel: task.chipLabel,
                                      accentColor: Color(task.accentColor),
                                      chipBg: Color(task.chipBg),
                                      meta: task.meta,
                                      done: task.done,
                                      onTap: () => _onTaskTap(task),
                                      onLongPress: () => _onTaskLongPress(task),
                                      onStartFocus: () {
                                        pushPage(
                                          context,
                                          FocusScreen(
                                              initialSubject: task.title),
                                        );
                                      },
                                    )),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  AppBottomNav(activeIndex: _navIndex, onTap: _onNavTap),
                ],
              ),

              // Floating action button
              Positioned(
                right: 22,
                bottom: 90,
                child: GestureDetector(
                  onTap: _openAddTask,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.accentButton,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child:
                        const Icon(Icons.add, color: AppColors.bgMid, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
