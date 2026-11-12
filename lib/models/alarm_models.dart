import 'package:intl/intl.dart';

/// One alarm that was sent to the phone's Clock app.
///
/// The Clock app is the source of truth. This object is only the record of
/// what we asked it to schedule.
class AlarmItemRecord {
  final String id;
  final String groupId;
  final DateTime scheduledAt;
  final int sequenceIndex;
  final int totalInGroup;

  /// Whether the platform bridge reported that the alarm intent was
  /// successfully handed to a Clock app.
  final bool delivered;

  /// Package that accepted the intent, for example `com.coloros.alarm`.
  final String? targetPackage;

  /// Error reported by the platform bridge when [delivered] is false.
  final String? error;

  bool isSelected;

  AlarmItemRecord({
    required this.id,
    required this.groupId,
    required this.scheduledAt,
    required this.sequenceIndex,
    required this.totalInGroup,
    this.delivered = true,
    this.targetPackage,
    this.error,
    this.isSelected = false,
  });

  int get hour => scheduledAt.hour;
  int get minute => scheduledAt.minute;
  String get displayTime => DateFormat('hh:mm a').format(scheduledAt);
  String get dateText => DateFormat('EEE, MMM d').format(scheduledAt);
  bool get isPast => scheduledAt.isBefore(DateTime.now());
}

/// A wake-up chain: N alarms starting at [initialTargetTime] and repeating
/// every [intervalMinutes].
class AlarmGroupRecord {
  final String id;
  final String title;
  final String initialTargetTime;
  final int alarmCount;
  final int intervalMinutes;
  final int durationHours;
  final int durationMinutes;
  final DateTime createdAt;
  final List<AlarmItemRecord> alarms;
  bool isSelected;

  AlarmGroupRecord({
    required this.id,
    required this.title,
    required this.initialTargetTime,
    required this.alarmCount,
    required this.intervalMinutes,
    required this.durationHours,
    required this.durationMinutes,
    required this.createdAt,
    required this.alarms,
    this.isSelected = false,
  });

  int get deliveredCount => alarms.where((a) => a.delivered).length;
  int get failedCount => alarms.where((a) => !a.delivered).length;
  bool get allDelivered => alarms.isNotEmpty && failedCount == 0;
  bool get noneDelivered => alarms.isNotEmpty && deliveredCount == 0;
}

class QuickPresetItem {
  final String label;
  final int hours;
  final int minutes;

  QuickPresetItem({
    required this.label,
    required this.hours,
    this.minutes = 0,
  });
}
