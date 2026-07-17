/// Represents a single focus session.
class FocusSession {
  final int? id;
  final String subject;        // Renamed from 'title'
  final int? taskId;
  final int plannedMinutes;    // Renamed from 'durationMinutes'
  final int actualMinutes;     // New: actual minutes focused
  final int interruptions;
  final String date;           // ISO-8601 date string (yyyy-MM-dd)
  final DateTime? startTime;   // ISO-8601 datetime
  final DateTime? endTime;     // ISO-8601 datetime

  FocusSession({
    this.id,
    required this.subject,
    this.taskId,
    this.plannedMinutes = 25,
    this.actualMinutes = 0,
    this.interruptions = 0,
    required this.date,
    this.startTime,
    this.endTime,
  });

  /// Alias for backwards compat.
  String get title => subject;
  int get durationMinutes => plannedMinutes;

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    final stStr = map['startTime'] as String?;
    final etStr = map['endTime'] as String?;
    return FocusSession(
      id: map['id'] as int?,
      subject: (map['subject'] as String?) ?? (map['title'] as String? ?? ''),
      taskId: map['taskId'] as int?,
      plannedMinutes: map['plannedMinutes'] as int? ?? (map['durationMinutes'] as int? ?? 25),
      actualMinutes: map['actualMinutes'] as int? ?? (map['durationMinutes'] as int? ?? 0),
      interruptions: map['interruptions'] as int? ?? 0,
      date: map['date'] as String,
      startTime: stStr != null ? DateTime.tryParse(stStr) : null,
      endTime: etStr != null ? DateTime.tryParse(etStr) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'subject': subject,
      'title': subject, // Keep legacy column populated
      'taskId': taskId,
      'plannedMinutes': plannedMinutes,
      'actualMinutes': actualMinutes,
      'durationMinutes': plannedMinutes, // Keep legacy column populated
      'interruptions': interruptions,
      'date': date,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  FocusSession copyWith({
    int? id,
    String? subject,
    int? taskId,
    int? plannedMinutes,
    int? actualMinutes,
    int? interruptions,
    String? date,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return FocusSession(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      taskId: taskId ?? this.taskId,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      interruptions: interruptions ?? this.interruptions,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  String toString() => 'FocusSession(id: $id, subject: $subject, planned: ${plannedMinutes}min, actual: ${actualMinutes}min)';
}
