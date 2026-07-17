/// Categories matching the five chip types in the UI.
enum TaskCategory {
  routine,
  class_,
  focus,
  org,
  sleep;

  String get label {
    switch (this) {
      case TaskCategory.routine:
        return 'Routine';
      case TaskCategory.class_:
        return 'Class';
      case TaskCategory.focus:
        return 'Focus';
      case TaskCategory.org:
        return 'Org';
      case TaskCategory.sleep:
        return 'Sleep';
    }
  }

  /// Parse from a stored DB string or a legacy chipLabel.
  static TaskCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'routine':
        return TaskCategory.routine;
      case 'class':
        return TaskCategory.class_;
      case 'focus':
        return TaskCategory.focus;
      case 'org':
        return TaskCategory.org;
      case 'sleep':
        return TaskCategory.sleep;
      default:
        return TaskCategory.class_;
    }
  }
}

/// Represents a scheduled task/block on a given day.
class Task {
  final int? id;
  final String title;
  final String time;           // Display string e.g. "8:00"
  final TaskCategory category;
  final int accentColor;       // Kept for backwards compat with DB / TaskCard
  final int chipBg;
  final String? meta;
  final bool done;
  final String date;           // ISO-8601 date string (yyyy-MM-dd)
  final int sortOrder;
  final DateTime? startTime;   // Actual start time (nullable)
  final int? durationMinutes;  // Planned duration (nullable)

  Task({
    this.id,
    required this.title,
    required this.time,
    this.category = TaskCategory.class_,
    this.accentColor = 0xFFE8935B,
    this.chipBg = 0x33E8935B,
    this.meta,
    this.done = false,
    required this.date,
    this.sortOrder = 0,
    this.startTime,
    this.durationMinutes,
  });

  /// Derive accent color from category (used when creating from category).
  static int _accentFor(TaskCategory cat) {
    switch (cat) {
      case TaskCategory.routine:
        return 0xFF9CAF94;
      case TaskCategory.class_:
        return 0xFFE8935B;
      case TaskCategory.focus:
        return 0xFFF2A488;
      case TaskCategory.org:
        return 0xFF6E6A99;
      case TaskCategory.sleep:
        return 0xFF9CAF94;
    }
  }

  static int _chipBgFor(TaskCategory cat) {
    switch (cat) {
      case TaskCategory.routine:
        return 0x339CAF94;
      case TaskCategory.class_:
        return 0x33E8935B;
      case TaskCategory.focus:
        return 0x33F2A488;
      case TaskCategory.org:
        return 0x336E6A99;
      case TaskCategory.sleep:
        return 0x339CAF94;
    }
  }

  /// Legacy: chipLabel derived from category.
  String get chipLabel => category.label;

  factory Task.fromMap(Map<String, dynamic> map) {
    // Try reading the new `category` column; fall back to legacy `chipLabel`
    final categoryStr = (map['category'] as String?) ?? (map['chipLabel'] as String? ?? 'Class');
    final startTimeStr = map['startTime'] as String?;
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      time: map['time'] as String,
      category: TaskCategory.fromString(categoryStr),
      accentColor: map['accentColor'] as int? ?? _accentFor(TaskCategory.fromString(categoryStr)),
      chipBg: map['chipBg'] as int? ?? _chipBgFor(TaskCategory.fromString(categoryStr)),
      meta: map['meta'] as String?,
      done: (map['done'] as int) == 1,
      date: map['date'] as String,
      sortOrder: map['sortOrder'] as int? ?? 0,
      startTime: startTimeStr != null ? DateTime.tryParse(startTimeStr) : null,
      durationMinutes: map['durationMinutes'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'time': time,
      'category': category.name,
      'chipLabel': category.label,
      'accentColor': accentColor,
      'chipBg': chipBg,
      'meta': meta,
      'done': done ? 1 : 0,
      'date': date,
      'sortOrder': sortOrder,
      'startTime': startTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
    };
  }

  Task copyWith({
    int? id,
    String? title,
    String? time,
    TaskCategory? category,
    int? accentColor,
    int? chipBg,
    String? meta,
    bool? done,
    String? date,
    int? sortOrder,
    DateTime? startTime,
    int? durationMinutes,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      category: category ?? this.category,
      accentColor: accentColor ?? this.accentColor,
      chipBg: chipBg ?? this.chipBg,
      meta: meta ?? this.meta,
      done: done ?? this.done,
      date: date ?? this.date,
      sortOrder: sortOrder ?? this.sortOrder,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  @override
  String toString() => 'Task(id: $id, title: $title, time: $time, done: $done)';
}
