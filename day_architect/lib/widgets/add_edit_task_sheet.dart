import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

/// Category option shown in the chip selector.
class _CategoryOption {
  final String label;
  final Color accentColor;
  final Color chipBg;

  const _CategoryOption(this.label, this.accentColor, this.chipBg);
}

const _categories = [
  _CategoryOption('Routine', AppColors.sage, AppColors.chipSageBg),
  _CategoryOption('Class', AppColors.accent, AppColors.chipAmberBg),
  _CategoryOption('Focus', AppColors.accentSoft, AppColors.chipCoralBg),
  _CategoryOption('Org', AppColors.plum, AppColors.chipPlumBg),
  _CategoryOption('Sleep', AppColors.sage, AppColors.chipSageBg),
];

/// Result from the Add/Edit task bottom sheet.
class TaskSheetResult {
  final Task? task;
  final bool delete;

  const TaskSheetResult({this.task, this.delete = false});
}

/// A modal bottom sheet for adding or editing a task.
class AddEditTaskSheet extends StatefulWidget {
  final Task? existingTask;

  const AddEditTaskSheet({super.key, this.existingTask});

  /// Show the bottom sheet, returning a [TaskSheetResult] or null if cancelled.
  static Future<TaskSheetResult?> show(BuildContext context,
      {Task? existingTask}) {
    return showModalBottomSheet<TaskSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditTaskSheet(existingTask: existingTask),
    );
  }

  @override
  State<AddEditTaskSheet> createState() => _AddEditTaskSheetState();
}

class _AddEditTaskSheetState extends State<AddEditTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _metaCtrl;
  late String _chipLabel;
  late Color _accentColor;
  late Color _chipBg;

  // Time state
  late int _hour;
  late int _minute;
  late bool _isAm;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _metaCtrl = TextEditingController(text: t?.meta ?? '');

    // Initialize time from existing task or current time
    if (t != null && t.time.isNotEmpty) {
      _parseTime(t.time);
    } else {
      final now = DateTime.now();
      // Round to nearest 5 minutes
      _minute = (now.minute / 5).round() * 5;
      if (_minute >= 60) {
        _minute = 0;
        _hour = now.hour + 1;
      } else {
        _hour = now.hour;
      }
      _isAm = _hour < 12;
      // Convert to 12-hour format
      _hour = _hour == 0 ? 12 : (_hour > 12 ? _hour - 12 : _hour);
    }

    if (t != null) {
      _chipLabel = t.chipLabel;
      _accentColor = Color(t.accentColor);
      _chipBg = Color(t.chipBg);
    } else {
      _chipLabel = _categories[1].label; // default: Class
      _accentColor = _categories[1].accentColor;
      _chipBg = _categories[1].chipBg;
    }
  }

  /// Parse a time string like "8:00", "8:00 AM", "2:30 PM", "14:00".
  void _parseTime(String timeStr) {
    final cleaned = timeStr.trim().toUpperCase();
    final isPm = cleaned.contains('PM');
    final isAm = cleaned.contains('AM');

    // Strip AM/PM suffix
    var numeric = cleaned.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = numeric.split(':');
    if (parts.length >= 2) {
      int rawHour = int.tryParse(parts[0]) ?? 8;
      _minute = (int.tryParse(parts[1]) ?? 0).clamp(0, 59);

      if (isPm && rawHour < 12) rawHour += 12;
      if (isAm && rawHour >= 12) rawHour -= 12;

      // Convert to 12-hour format
      _hour = rawHour == 0 ? 12 : (rawHour > 12 ? rawHour - 12 : rawHour);
      _isAm = rawHour < 12;
    } else {
      _hour = 8;
      _minute = 0;
      _isAm = true;
    }
  }

  /// Format the time as "h:mm AM/PM".
  String get _formattedTime =>
      '$_hour:${_minute.toString().padLeft(2, '0')} ${_isAm ? 'AM' : 'PM'}';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _metaCtrl.dispose();
    super.dispose();
  }

  void _selectCategory(_CategoryOption cat) {
    setState(() {
      _chipLabel = cat.label;
      _accentColor = cat.accentColor;
      _chipBg = cat.chipBg;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final task = Task(
      id: widget.existingTask?.id,
      title: _titleCtrl.text.trim(),
      time: _formattedTime,
      category: TaskCategory.fromString(_chipLabel),
      accentColor: _accentColor.toARGB32(),
      chipBg: _chipBg.toARGB32(),
      meta: _metaCtrl.text.trim().isEmpty ? null : _metaCtrl.text.trim(),
      done: widget.existingTask?.done ?? false,
      date: widget.existingTask?.date ?? '',
      sortOrder: widget.existingTask?.sortOrder ?? 0,
    );
    Navigator.of(context).pop(TaskSheetResult(task: task));
  }

  void _delete() {
    if (!_isEditing) return;
    Navigator.of(context).pop(const TaskSheetResult(delete: true));
  }

  /// Open the custom time picker bottom sheet.
  Future<void> _openTimePicker() async {
    final result = await showModalBottomSheet<_TimeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimePickerSheet(
        initialHour: _hour,
        initialMinute: _minute,
        initialIsAm: _isAm,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _hour = result.hour;
        _minute = result.minute;
        _isAm = result.isAm;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                _isEditing ? 'Edit Task' : 'New Task',
                style: AppTextStyles.heading(size: 22),
              ),
              const SizedBox(height: 20),

              // Title
              Text('Title', style: AppTextStyles.label(size: 10.5)),
              const SizedBox(height: 6),
              _buildField(
                controller: _titleCtrl,
                hint: 'e.g. Software Design Lecture',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),

              // Time (custom picker)
              Text('Time', style: AppTextStyles.label(size: 10.5)),
              const SizedBox(height: 6),
              _buildTimePickerTile(),
              const SizedBox(height: 16),

              // Category
              Text('Category', style: AppTextStyles.label(size: 10.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _categories.map((cat) {
                  final selected = _chipLabel == cat.label;
                  return GestureDetector(
                    onTap: () => _selectCategory(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? cat.chipBg
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? Border.all(color: cat.accentColor, width: 1.5)
                            : null,
                      ),
                      child: Text(
                        cat.label,
                        style: AppTextStyles.body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: selected
                              ? cat.accentColor
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Duration / Notes
              Text('Duration / Notes (optional)',
                  style: AppTextStyles.label(size: 10.5)),
              const SizedBox(height: 6),
              _buildField(
                controller: _metaCtrl,
                hint: 'e.g. 30 min · Social media blocked',
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  if (_isEditing) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: _delete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFF26464)
                                    .withValues(alpha: 0.4),
                                width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text('Delete',
                                style: AppTextStyles.body(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: const Color(0xFFF26464))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: _isEditing ? 2 : 1,
                    child: GestureDetector(
                      onTap: _submit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: AppGradients.accentButton,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _isEditing ? 'Save Changes' : 'Add Task',
                            style: AppTextStyles.body(
                                size: 14,
                                weight: FontWeight.w700,
                                color: AppColors.bgMid),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the tappable time picker tile that shows the selected time.
  Widget _buildTimePickerTile() {
    return GestureDetector(
      onTap: _openTimePicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded,
                size: 18, color: AppColors.accent.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
            Text(
              _formattedTime,
              style: AppTextStyles.body(
                size: 15,
                weight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isAm ? 'AM' : 'PM',
                style: AppTextStyles.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: AppTextStyles.body(size: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body(size: 14, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: const Color(0xFFF26464).withValues(alpha: 0.7), width: 1),
        ),
      ),
    );
  }
}

// ======================== Custom Time Picker Sheet ========================

/// Result from the time picker.
class _TimeResult {
  final int hour;
  final int minute;
  final bool isAm;

  const _TimeResult({
    required this.hour,
    required this.minute,
    required this.isAm,
  });
}

/// A scroll-wheel time picker bottom sheet with AM/PM selection.
class _TimePickerSheet extends StatefulWidget {
  final int initialHour;
  final int initialMinute;
  final bool initialIsAm;

  const _TimePickerSheet({
    required this.initialHour,
    required this.initialMinute,
    required this.initialIsAm,
  });

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  // Use fixed wheel controllers so the initial position is correct
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  late int _selectedHour;
  late int _selectedMinute;
  late bool _isAm;

  // Detent snap points for the bottom sheet
  static const _snapHeight = 380.0;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour;
    _selectedMinute = widget.initialMinute;
    _isAm = widget.initialIsAm;

    _hourController = FixedExtentScrollController(initialItem: _selectedHour - 1);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(_TimeResult(
      hour: _selectedHour,
      minute: _selectedMinute,
      isAm: _isAm,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _snapHeight,
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Text('Select Time', style: AppTextStyles.heading(size: 20)),
          const SizedBox(height: 4),
          Text(
            'Scroll to set the time',
            style: AppTextStyles.body(
                size: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Time picker wheels + AM/PM
          SizedBox(
            height: 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour wheel
                SizedBox(
                  width: 72,
                  child: ListWheelScrollView.useDelegate(
                    controller: _hourController,
                    itemExtent: 44,
                    perspective: 0.006,
                    diameterRatio: 1.4,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() => _selectedHour = index + 1);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 12,
                      builder: (context, index) {
                        final hour = index + 1;
                        final isSelected = hour == _selectedHour;
                        return Center(
                          child: Text(
                            '$hour',
                            style: TextStyle(
                              fontSize: isSelected ? 28 : 18,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Colon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':',
                      style: AppTextStyles.heading(
                          size: 28, weight: FontWeight.w700)),
                ),

                // Minute wheel
                SizedBox(
                  width: 72,
                  child: ListWheelScrollView.useDelegate(
                    controller: _minuteController,
                    itemExtent: 44,
                    perspective: 0.006,
                    diameterRatio: 1.4,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() => _selectedMinute = index);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 60,
                      builder: (context, index) {
                        final minute = index;
                        final isSelected = minute == _selectedMinute;
                        return Center(
                          child: Text(
                            minute.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: isSelected ? 28 : 18,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // AM/PM vertical toggle
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ampmButton('AM', true),
                    const SizedBox(height: 4),
                    _ampmButton('PM', false),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Confirm button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _confirm,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: AppGradients.accentButton,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Done',
                    style: AppTextStyles.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: AppColors.bgMid),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build an AM or PM toggle button.
  Widget _ampmButton(String label, bool isAm) {
    final selected = _isAm == isAm;
    return GestureDetector(
      onTap: () => setState(() => _isAm = isAm),
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(
                  color: AppColors.accent.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body(
              size: 13,
              weight: FontWeight.w700,
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
