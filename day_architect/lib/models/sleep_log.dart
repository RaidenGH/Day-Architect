/// Represents a single night's sleep log.
class SleepLog {
  final int? id;
  final String date; // ISO-8601 date string (yyyy-MM-dd)
  final int actualDuration;    // Renamed from 'sleepDurationMinutes'
  final int targetDuration;    // Renamed from 'goalDurationMinutes'
  final DateTime? bedtime;     // New: bedtime timestamp
  final DateTime? wakeTime;    // New: wake time timestamp

  SleepLog({
    this.id,
    required this.date,
    this.actualDuration = 0,
    this.targetDuration = 450, // 7h 30m default
    this.bedtime,
    this.wakeTime,
  });

  // Backwards-compat aliases
  int get sleepDurationMinutes => actualDuration;
  int get goalDurationMinutes => targetDuration;

  factory SleepLog.fromMap(Map<String, dynamic> map) {
    final btStr = map['bedtime'] as String?;
    final wtStr = map['wakeTime'] as String?;
    return SleepLog(
      id: map['id'] as int?,
      date: map['date'] as String,
      actualDuration: map['actualDuration'] as int? ?? (map['sleepDurationMinutes'] as int? ?? 0),
      targetDuration: map['targetDuration'] as int? ?? (map['goalDurationMinutes'] as int? ?? 450),
      bedtime: btStr != null ? DateTime.tryParse(btStr) : null,
      wakeTime: wtStr != null ? DateTime.tryParse(wtStr) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'actualDuration': actualDuration,
      'targetDuration': targetDuration,
      'sleepDurationMinutes': actualDuration,
      'goalDurationMinutes': targetDuration,
      'bedtime': bedtime?.toIso8601String(),
      'wakeTime': wakeTime?.toIso8601String(),
    };
  }

  SleepLog copyWith({
    int? id,
    String? date,
    int? actualDuration,
    int? targetDuration,
    DateTime? bedtime,
    DateTime? wakeTime,
  }) {
    return SleepLog(
      id: id ?? this.id,
      date: date ?? this.date,
      actualDuration: actualDuration ?? this.actualDuration,
      targetDuration: targetDuration ?? this.targetDuration,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
    );
  }

  /// Format minutes as "Xh Ym" string
  String get formattedDuration {
    final hours = actualDuration ~/ 60;
    final minutes = actualDuration % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '0m';
  }

  /// Fraction of goal achieved (0.0–1.0+)
  double get fractionOfGoal => targetDuration > 0 ? actualDuration / targetDuration : 0.0;

  @override
  String toString() => 'SleepLog(id: $id, date: $date, sleep: $formattedDuration)';
}
