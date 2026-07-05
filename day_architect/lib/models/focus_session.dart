/// Represents a single focus session.
class FocusSession {
  final int? id;
  final String title;
  final int? taskId;
  final int durationMinutes;
  final int interruptions;
  final String date; // ISO-8601 date string (yyyy-MM-dd)

  FocusSession({
    this.id,
    required this.title,
    this.taskId,
    required this.durationMinutes,
    this.interruptions = 0,
    required this.date,
  });

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'] as int?,
      title: map['title'] as String,
      taskId: map['taskId'] as int?,
      durationMinutes: map['durationMinutes'] as int,
      interruptions: map['interruptions'] as int? ?? 0,
      date: map['date'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'taskId': taskId,
      'durationMinutes': durationMinutes,
      'interruptions': interruptions,
      'date': date,
    };
  }

  FocusSession copyWith({
    int? id,
    String? title,
    int? taskId,
    int? durationMinutes,
    int? interruptions,
    String? date,
  }) {
    return FocusSession(
      id: id ?? this.id,
      title: title ?? this.title,
      taskId: taskId ?? this.taskId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      interruptions: interruptions ?? this.interruptions,
      date: date ?? this.date,
    );
  }

  @override
  String toString() => 'FocusSession(id: $id, title: $title, duration: ${durationMinutes}min)';
}
