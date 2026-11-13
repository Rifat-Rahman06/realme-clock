import 'dart:convert';
import 'dart:io';

import '../models/alarm_models.dart';
import 'native_clock_service.dart';

/// Stores the user's quick presets in a tiny JSON file inside the app's
/// private files directory. The path comes from the existing Kotlin bridge,
/// so no database or extra Flutter package is needed.
class PresetStore {
  Future<File?> _file() async {
    final path = await NativeClockService.getPresetStoragePath();
    if (path == null || path.isEmpty) return null;
    return File(path);
  }

  Future<List<QuickPresetItem>> load() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) {
        return <QuickPresetItem>[];
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return <QuickPresetItem>[];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return <QuickPresetItem>[];

      return decoded
          .whereType<Map>()
          .map((item) => QuickPresetItem.fromJson(Map<String, dynamic>.from(item)))
          .where((preset) =>
              preset.label.trim().isNotEmpty &&
              (preset.hours > 0 || preset.minutes > 0))
          .toList();
    } catch (_) {
      // A missing or damaged file should never stop the app from starting.
      return <QuickPresetItem>[];
    }
  }

  Future<void> save(List<QuickPresetItem> presets) async {
    try {
      final file = await _file();
      if (file == null) return;

      await file.parent.create(recursive: true);
      final payload = jsonEncode(
        presets.map((preset) => preset.toJson()).toList(),
      );
      await file.writeAsString(payload, flush: true);
    } catch (_) {
      // Best effort: the presets still work for the current session.
    }
  }
}
