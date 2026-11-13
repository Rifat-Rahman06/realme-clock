class QuickPresetItem {
  final String label;
  final int hours;
  final int minutes;

  QuickPresetItem({
    required this.label,
    required this.hours,
    this.minutes = 0,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'hours': hours,
        'minutes': minutes,
      };

  factory QuickPresetItem.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final hours = json['hours'];
    final minutes = json['minutes'];

    final h = hours is num ? hours.toInt() : 0;
    final m = minutes is num ? minutes.toInt() : 0;

    return QuickPresetItem(
      label: label is String ? label.trim() : '',
      hours: h < 0 ? 0 : (h > 12 ? 12 : h),
      minutes: m < 0 ? 0 : (m > 55 ? 55 : m),
    );
  }
}
