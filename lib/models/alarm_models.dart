class QuickPresetItem {
  final String label;
  final int hours;
  final int minutes;

  /// Presets bundled with the app cannot be deleted. Presets added by the
  /// user can be removed from the chips row.
  final bool isCustom;

  QuickPresetItem({
    required this.label,
    required this.hours,
    this.minutes = 0,
    this.isCustom = false,
  });
}
