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
