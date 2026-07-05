import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static Future<TaskSheetResult?> show(BuildContext context, {Task? existingTask}) {
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
  late final TextEditingController _timeCtrl;
  late final TextEditingController _metaCtrl; // used as "duration / notes"
  late String _chipLabel;
  late Color _accentColor;
  late Color _chipBg;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _timeCtrl = TextEditingController(text: t?.time ?? '');
    _metaCtrl = TextEditingController(text: t?.meta ?? '');

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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _timeCtrl.dispose();
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
      time: _timeCtrl.text.trim(),
      chipLabel: _chipLabel,
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
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),

              // Time
              Text('Time', style: AppTextStyles.label(size: 10.5)),
              const SizedBox(height: 6),
              _buildField(
                controller: _timeCtrl,
                hint: 'e.g. 8:00',
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d:]'))],
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a time' : null,
              ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? cat.chipBg : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: selected ? Border.all(color: cat.accentColor, width: 1.5) : null,
                      ),
                      child: Text(
                        cat.label,
                        style: AppTextStyles.body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: selected ? cat.accentColor : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Duration / Notes
              Text('Duration / Notes (optional)', style: AppTextStyles.label(size: 10.5)),
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
                            border: Border.all(color: const Color(0xFFF26464).withValues(alpha: 0.4), width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text('Delete', style: AppTextStyles.body(size: 14, weight: FontWeight.w600, color: const Color(0xFFF26464))),
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
                            style: AppTextStyles.body(size: 14, weight: FontWeight.w700, color: AppColors.bgMid),
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

  Widget _buildField({
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      inputFormatters: inputFormatters,
      style: AppTextStyles.body(size: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body(size: 14, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFF26464).withValues(alpha: 0.7), width: 1),
        ),
      ),
    );
  }
}
