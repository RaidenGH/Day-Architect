/// Represents a scheduled task/block on a given day.
class Task {
  final int? id;
  final String title;
  final String time;
  final String chipLabel;
  final int accentColor;
  final int chipBg;
  final String? meta;
  final bool done;
  final String date; // ISO-8601 date string (yyyy-MM-dd)
  final int sortOrder;

  Task({
    this.id,
    required this.title,
    required this.time,
    required this.chipLabel,
    required this.accentColor,
    required this.chipBg,
    this.meta,
    this.done = false,
    required this.date,
    this.sortOrder = 0,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      time: map['time'] as String,
      chipLabel: map['chipLabel'] as String,
      accentColor: map['accentColor'] as int,
      chipBg: map['chipBg'] as int,
      meta: map['meta'] as String?,
      done: (map['done'] as int) == 1,
      date: map['date'] as String,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'time': time,
      'chipLabel': chipLabel,
      'accentColor': accentColor,
      'chipBg': chipBg,
      'meta': meta,
      'done': done ? 1 : 0,
      'date': date,
      'sortOrder': sortOrder,
    };
  }

  Task copyWith({
    int? id,
    String? title,
    String? time,
    String? chipLabel,
    int? accentColor,
    int? chipBg,
    String? meta,
    bool? done,
    String? date,
    int? sortOrder,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      chipLabel: chipLabel ?? this.chipLabel,
      accentColor: accentColor ?? this.accentColor,
      chipBg: chipBg ?? this.chipBg,
      meta: meta ?? this.meta,
      done: done ?? this.done,
      date: date ?? this.date,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  String toString() => 'Task(id: $id, title: $title, time: $time, done: $done)';
}
