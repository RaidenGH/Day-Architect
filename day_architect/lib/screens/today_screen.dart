import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
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
  List<Task> _tasks = [];
  bool _loading = true;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final db = DatabaseHelper();
    final todayStr = _todayDateString;
    final tasks = await db.getTasks(date: todayStr);
    final streak = await db.getStreak();
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _streak = streak;
        _loading = false;
      });
    }
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    setState(() => _navIndex = index);
    switch (index) {
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WindDownScreen()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProgressScreen()));
        break;
    }
  }

  // ---------------------- Add Task ----------------------

  Future<void> _openAddTask() async {
    final result = await AddEditTaskSheet.show(context);
    if (result == null || result.task == null) return;

    final task = result.task!;
    final todayStr = _todayDateString;
    final db = DatabaseHelper();
    await db.insertTask(task.copyWith(
      date: todayStr,
      sortOrder: _tasks.length + 1,
    ));
    await _loadAll();
  }

  // ---------------------- Toggle Done ----------------------

  Future<void> _toggleDone(Task task) async {
    final updated = task.copyWith(done: !task.done);
    final db = DatabaseHelper();
    await db.updateTask(updated);
    await _loadAll();
  }

  // ---------------------- Edit / Delete ----------------------

  Future<void> _openEditTask(Task task) async {
    final result = await AddEditTaskSheet.show(context, existingTask: task);
    if (result == null) return;

    if (result.delete) {
      await DatabaseHelper().deleteTask(task.id!);
      await _loadAll();
      return;
    }

    final updated = result.task!.copyWith(
      id: task.id,
      date: task.date,
      sortOrder: task.sortOrder,
      done: task.done,
    );
    await DatabaseHelper().updateTask(updated);
    await _loadAll();
  }

  // ---------------------- Build ----------------------

  int get _doneCount => _tasks.where((t) => t.done).length;

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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good morning, Andrea 👋', style: AppTextStyles.eyebrow()),
                          const SizedBox(height: 2),
                          Text(_todayFormatted, style: AppTextStyles.heading(size: 27)),
                          const SizedBox(height: 16),

                          // Streak bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  const Text('🔥', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  RichText(
                                    text: TextSpan(
                                      style: AppTextStyles.body(size: 13, weight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                          text: '$_streak-day',
                                          style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: AppColors.accent),
                                        ),
                                        const TextSpan(text: ' streak'),
                                      ],
                                    ),
                                  ),
                                ]),
                                Text('$_doneCount / ${_tasks.length} blocks done', style: AppTextStyles.body(size: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),
                          Text("TODAY'S SCHEDULE", style: AppTextStyles.label()),
                          const SizedBox(height: 10),

                          if (_loading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(color: AppColors.accent),
                              ),
                            )
                          else if (_tasks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Text('No tasks yet. Tap + to add one!', style: AppTextStyles.body(size: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._tasks.map((task) => TaskCard(
                              time: task.time,
                              title: task.title,
                              chipLabel: task.chipLabel,
                              accentColor: Color(task.accentColor),
                              chipBg: Color(task.chipBg),
                              meta: task.meta,
                              done: task.done,
                              onTap: () => _openEditTask(task),
                              onToggleDone: () => _toggleDone(task),
                              onLongPress: () => _openEditTask(task),
                            )),
                        ],
                      ),
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
                      boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 10))],
                    ),
                    child: const Icon(Icons.add, color: AppColors.bgMid, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _todayDateString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String get _todayFormatted {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, $month ${now.day}';
  }
}
