/// Represents a single night's sleep log.
class SleepLog {
  final int? id;
  final String date; // ISO-8601 date string (yyyy-MM-dd)
  final int sleepDurationMinutes;
  final int goalDurationMinutes;

  SleepLog({
    this.id,
    required this.date,
    required this.sleepDurationMinutes,
    this.goalDurationMinutes = 450, // 7h 30m default
  });

  factory SleepLog.fromMap(Map<String, dynamic> map) {
    return SleepLog(
      id: map['id'] as int?,
      date: map['date'] as String,
      sleepDurationMinutes: map['sleepDurationMinutes'] as int,
      goalDurationMinutes: map['goalDurationMinutes'] as int? ?? 450,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'sleepDurationMinutes': sleepDurationMinutes,
      'goalDurationMinutes': goalDurationMinutes,
    };
  }

  SleepLog copyWith({
    int? id,
    String? date,
    int? sleepDurationMinutes,
    int? goalDurationMinutes,
  }) {
    return SleepLog(
      id: id ?? this.id,
      date: date ?? this.date,
      sleepDurationMinutes: sleepDurationMinutes ?? this.sleepDurationMinutes,
      goalDurationMinutes: goalDurationMinutes ?? this.goalDurationMinutes,
    );
  }

  /// Format minutes as "Xh Ym" string
  String get formattedDuration {
    final hours = sleepDurationMinutes ~/ 60;
    final minutes = sleepDurationMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '0m';
  }

  /// Fraction of goal achieved (0.0–1.0+)
  double get fractionOfGoal => sleepDurationMinutes / goalDurationMinutes;

  @override
  String toString() => 'SleepLog(id: $id, date: $date, sleep: $formattedDuration)';
}
