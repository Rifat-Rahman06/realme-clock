import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'models/alarm_models.dart';
import 'services/native_clock_service.dart';
import 'services/preset_store.dart';

void main() {
  runApp(const RealmeAlarmApp());
}

// ==========================================
// Root Application (Theme: Black & Blue)
// ==========================================
class RealmeAlarmApp extends StatelessWidget {
  const RealmeAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070A13),
        primaryColor: const Color(0xFF3B82F6),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF60A5FA),
          surface: Color(0xFF0F172A),
          background: Color(0xFF070A13),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF070A13),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ==========================================
// Single-screen shell
// ==========================================
class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Color(0xFF60A5FA)),
            tooltip: 'Open Realme Clock',
            onPressed: () => NativeClockService.openClockApp(),
          ),
        ],
      ),
      body: const HomeScreen(),
    );
  }
}

// ==========================================
// Home Screen
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Synchronized state
  int _durationHours = 7;
  int _durationMinutes = 0;
  late DateTime _targetTime;

  // Direct Flutter Wheel Picker Controllers for Actual Alarm Time (Top Header)
  late FixedExtentScrollController _hourWheelController;
  late FixedExtentScrollController _minuteWheelController;
  late FixedExtentScrollController _amPmWheelController;
  bool _isSyncing = false;

  // Options
  int _totalAlarms = 1; // One alarm by default
  int _intervalMinutes = 5; // Default selected
  bool _isDispatching = false;

  // Presets are fully user-managed and persisted to a small JSON file.
  final List<QuickPresetItem> _presets = [];
  final PresetStore _presetStore = PresetStore();
  bool _presetsLoaded = false;
  bool _isEditingPresets = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPresets());

    final now = DateTime.now();
    _targetTime = now.add(Duration(hours: _durationHours, minutes: _durationMinutes));

    final h12 = _targetTime.hour % 12 == 0 ? 12 : _targetTime.hour % 12;
    // Large starting offsets give the looping hour and minute pickers room to
    // scroll backwards while still showing the correct value (the delegate
    // maps by modulo).
    _hourWheelController = FixedExtentScrollController(initialItem: (h12 - 1) + 1200);
    _minuteWheelController = FixedExtentScrollController(initialItem: _targetTime.minute + 1200);
    _amPmWheelController = FixedExtentScrollController(
      initialItem: _targetTime.hour >= 12 ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _hourWheelController.dispose();
    _minuteWheelController.dispose();
    _amPmWheelController.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    final loaded = await _presetStore.load();
    if (!mounted) return;

    setState(() {
      for (final preset in loaded) {
        final alreadyPresent = _presets.any((existing) =>
            existing.label == preset.label &&
            existing.hours == preset.hours &&
            existing.minutes == preset.minutes);
        if (!alreadyPresent) {
          _presets.add(preset);
        }
      }
      _presetsLoaded = true;
    });
  }

  void _savePresets() {
    unawaited(_presetStore.save(List<QuickPresetItem>.of(_presets)));
  }

  // 1. Wheel Picker -> Relative Time Sync
  void _onWheelChanged() {
    if (_isSyncing) return;
    _isSyncing = true;
    HapticFeedback.selectionClick();

    final hourIndex = _hourWheelController.selectedItem % 12;
    final hour12 = hourIndex + 1; // 1 to 12
    final minute = _minuteWheelController.selectedItem % 60; // 0 to 59
    final isPm = _amPmWheelController.selectedItem == 1;

    int hour24 = hour12 % 12;
    if (isPm) hour24 += 12;

    final now = DateTime.now();
    var newTarget = DateTime(now.year, now.month, now.day, hour24, minute);
    if (newTarget.isBefore(now)) {
      newTarget = newTarget.add(const Duration(days: 1));
    }

    final diff = newTarget.difference(now);
    final totalMins = diff.inMinutes;

    var hours = totalMins ~/ 60;
    var minutes = ((totalMins % 60) / 5).round() * 5;
    if (minutes == 60) {
      hours += 1;
      minutes = 0;
    }

    setState(() {
      _targetTime = newTarget;
      _durationHours = hours.clamp(0, 12);
      _durationMinutes = minutes.clamp(0, 60);
    });

    _isSyncing = false;
  }

  /// Returns the absolute item index closest to [current] that shows
  /// [desired] in a looping picker with [count] items.
  int _nearestLoopIndex(int current, int desired, int count) {
    final currentMod = current % count;
    var delta = (desired - currentMod) % count;
    if (delta > count ~/ 2) delta -= count;
    return current + delta;
  }

  // 2. Relative Time -> Wheel Picker Sync
  Future<void> _syncTargetFromDuration() async {
    final now = DateTime.now();
    final newTarget = now.add(Duration(hours: _durationHours, minutes: _durationMinutes));

    setState(() {
      _targetTime = newTarget;
    });

    if (_isSyncing) return;
    _isSyncing = true;

    final h12 = newTarget.hour % 12 == 0 ? 12 : newTarget.hour % 12;
    final hIndex = h12 - 1;
    final mIndex = newTarget.minute;
    final amPmIndex = newTarget.hour >= 12 ? 1 : 0;

    try {
      if (_hourWheelController.hasClients) {
        final target = _nearestLoopIndex(_hourWheelController.selectedItem, hIndex, 12);
        if (_hourWheelController.selectedItem != target) {
          await _hourWheelController.animateToItem(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      }
      if (_minuteWheelController.hasClients) {
        final target = _nearestLoopIndex(_minuteWheelController.selectedItem, mIndex, 60);
        if (_minuteWheelController.selectedItem != target) {
          await _minuteWheelController.animateToItem(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      }
      if (_amPmWheelController.hasClients &&
          _amPmWheelController.selectedItem != amPmIndex) {
        await _amPmWheelController.animateToItem(
          amPmIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
      // The picker can be disposed while the animation is running.
    } finally {
      // Keep the guard on across the whole animation so the picker callbacks
      // do not overwrite the value the user just chose.
      _isSyncing = false;
    }
  }

  // Add Custom Quick Preset Dialog
  void _showAddPresetDialog({QuickPresetItem? existing}) {
    final isEditing = existing != null;
    int inputHours = existing?.hours ?? 3;
    int inputMinutes = existing?.minutes ?? 0;
    final textController = TextEditingController(text: existing?.label ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final totalMinutes = inputHours * 60 + inputMinutes;
            final previewLabel = _presetLabel(inputHours, inputMinutes);

            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_outlined : Icons.bolt_rounded,
                      color: const Color(0xFF60A5FA),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Quick Preset' : 'New Quick Preset',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEditing
                              ? 'Update the name or delay.'
                              : 'Name it, then choose the delay.',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: textController,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Label (optional)',
                        hintText: previewLabel,
                        hintStyle: const TextStyle(color: Color(0xFF475569)),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'DELAY',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: inputHours,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF60A5FA)),
                            decoration: _dialogDropdownDecoration('Hours'),
                            items: List.generate(13, (i) => i)
                                .map((h) => DropdownMenuItem(value: h, child: Text('$h')))
                                .toList(),
                            onChanged: (v) => setDialogState(() => inputHours = v ?? 0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: inputMinutes,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF60A5FA)),
                            decoration: _dialogDropdownDecoration('Minutes'),
                            items: List.generate(12, (i) => i * 5)
                                .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                                .toList(),
                            onChanged: (v) => setDialogState(() => inputMinutes = v ?? 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            totalMinutes == 0 ? Icons.error_outline : Icons.alarm,
                            size: 16,
                            color: totalMinutes == 0
                                ? const Color(0xFFF87171)
                                : const Color(0xFF60A5FA),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              totalMinutes == 0
                                  ? 'Choose at least 1 minute.'
                                  : 'Alarm in $previewLabel',
                              style: TextStyle(
                                color: totalMinutes == 0
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF1E293B),
                    disabledForegroundColor: const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: totalMinutes == 0
                      ? null
                      : () {
                          final typed = textController.text.trim();
                          final updated = QuickPresetItem(
                            label: typed.isEmpty ? previewLabel : typed,
                            hours: inputHours,
                            minutes: inputMinutes,
                          );
                          setState(() {
                            if (existing != null) {
                              final index = _presets.indexOf(existing);
                              if (index != -1) _presets[index] = updated;
                            } else {
                              _presets.add(updated);
                            }
                          });
                          _savePresets();
                          Navigator.pop(ctx);
                        },
                  child: Text(
                    isEditing ? 'Save Changes' : 'Add Preset',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Wait for the dialog's close animation before disposing the controller.
      Future.delayed(const Duration(milliseconds: 300), textController.dispose);
    });
  }

  String _presetLabel(int hours, int minutes) {
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  InputDecoration _dialogDropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      isDense: true,
    );
  }

  void _deletePreset(QuickPresetItem preset) {
    final index = _presets.indexOf(preset);
    if (index == -1) return;

    setState(() => _presets.removeAt(index));
    _savePresets();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${preset.label}"'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFF60A5FA),
          onPressed: () {
            if (!mounted) return;
            final restoreAt = index > _presets.length ? _presets.length : index;
            setState(() => _presets.insert(restoreAt, preset));
            _savePresets();
          },
        ),
      ),
    );
  }

  // Sends the selected number of alarms to the Realme Clock app.
  Future<void> _setTheAlarm() async {
    if (_isDispatching) return;
    setState(() => _isDispatching = true);

    final interval = _totalAlarms > 1 ? _intervalMinutes : 0;
    var delivered = 0;

    try {
      for (int i = 0; i < _totalAlarms; i++) {
        final raw = _targetTime.add(Duration(minutes: i * interval));
        // The Clock intent only accepts a time of day, so normalise seconds.
        final alarmTime = DateTime(raw.year, raw.month, raw.day, raw.hour, raw.minute);

        final result = await NativeClockService.setAlarm(
          hour: alarmTime.hour,
          minutes: alarmTime.minute,
          message: 'Alarm ${i + 1}/$_totalAlarms',
          skipUi: true,
          vibrate: true,
        );
        if (result['success'] == true) delivered++;

        // Stagger requests so the Realme Clock queue is not flooded.
        if (i < _totalAlarms - 1) {
          await Future.delayed(const Duration(milliseconds: 350));
        }
      }
    } finally {
      if (mounted) setState(() => _isDispatching = false);
    }

    if (!mounted) return;

    final failed = _totalAlarms - delivered;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Set $_totalAlarms alarm(s) in Realme Clock.'
              : 'Set $delivered of $_totalAlarms. $failed failed — open Clock to check.',
        ),
        backgroundColor:
            failed == 0 ? const Color(0xFF2563EB) : const Color(0xFF9A3412),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OPEN CLOCK',
          textColor: const Color(0xFF93C5FD),
          onPressed: () => NativeClockService.openClockApp(),
        ),
      ),
    );
  }

  // 3. Total Number of Alarms: 6 rectangular selector-style tabs
  Widget _buildTotalAlarmsSelector() {
    final options = [1, 2, 3, 4, 5, 6];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL ALARMS',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: options.map((count) {
              final isSelected = _totalAlarms == count;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _totalAlarms = count);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF334155),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${count}x',
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 4. Alarm Interval: 5 rectangular selector-style tabs
  Widget _buildIntervalSelector() {
    final intervals = [2, 3, 5, 10, 15];
    final enabled = _totalAlarms > 1;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ALARM INTERVAL',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (!enabled)
                    const Text(
                      'NEEDS 2+ ALARMS',
                      style: TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
          Row(
            children: intervals.map((mins) {
              final isSelected = enabled && _intervalMinutes == mins;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _intervalMinutes = mins);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF334155),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Actual Alarm Time (Top Header) with Direct Embedded Wheel Picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ACTUAL ALARM TIME',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      dateFormat.format(_targetTime),
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Directly embedded 3-column Flutter Wheel Picker
                SizedBox(
                  height: 150,
                  child: Row(
                    children: [
                      // Hour Wheel (1 - 12)
                      Expanded(
                        flex: 3,
                        child: CupertinoPicker(
                          itemExtent: 40,
                          scrollController: _hourWheelController,
                          looping: true,
                          selectionOverlay: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.symmetric(
                                horizontal: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.4), width: 1),
                              ),
                            ),
                          ),
                          onSelectedItemChanged: (index) {
                            _onWheelChanged();
                          },
                          children: List.generate(12, (i) {
                            final val = (i + 1).toString().padLeft(2, '0');
                            return Center(
                              child: Text(
                                val,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(
                        width: 14,
                        child: Center(
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF60A5FA),
                            ),
                          ),
                        ),
                      ),
                      // Minute Wheel (00 - 59)
                      Expanded(
                        flex: 3,
                        child: CupertinoPicker(
                          itemExtent: 40,
                          scrollController: _minuteWheelController,
                          looping: true,
                          selectionOverlay: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.symmetric(
                                horizontal: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.4), width: 1),
                              ),
                            ),
                          ),
                          onSelectedItemChanged: (index) {
                            _onWheelChanged();
                          },
                          children: List.generate(60, (i) {
                            final val = i.toString().padLeft(2, '0');
                            return Center(
                              child: Text(
                                val,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // AM / PM Wheel
                      Expanded(
                        flex: 2,
                        child: CupertinoPicker(
                          itemExtent: 40,
                          scrollController: _amPmWheelController,
                          selectionOverlay: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.symmetric(
                                horizontal: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.4), width: 1),
                              ),
                            ),
                          ),
                          onSelectedItemChanged: (index) {
                            _onWheelChanged();
                          },
                          children: const [
                            Center(
                              child: Text(
                                'AM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Center(
                              child: Text(
                                'PM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Relative Time Selector (Side by side Hour & Minute with Stepped Sliders)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Hour Selector (Left)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('HOUR', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                Text('${_durationHours}h', style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 7,
                                activeTrackColor: const Color(0xFF3B82F6),
                                inactiveTrackColor: const Color(0xFF1E293B),
                                thumbColor: const Color(0xFF60A5FA),
                                overlayColor: const Color(0xFF3B82F6).withOpacity(0.15),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
                                activeTickMarkColor: Colors.white70,
                                inactiveTickMarkColor: const Color(0xFF334155),
                              ),
                              child: Slider(
                                value: _durationHours.toDouble().clamp(0.0, 12.0),
                                min: 0.0,
                                max: 12.0,
                                divisions: 12,
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  final newH = val.round();
                                  if (newH != _durationHours) {
                                    final now = DateTime.now();
                                    setState(() {
                                      _durationHours = newH;
                                      _targetTime = now.add(Duration(
                                        hours: _durationHours,
                                        minutes: _durationMinutes,
                                      ));
                                    });
                                  }
                                },
                                onChangeEnd: (_) => _syncTargetFromDuration(),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('0h', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                  Text('6h', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                  Text('12h', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Minute Selector (Right)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('MINUTE', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                Text('${_durationMinutes.toString().padLeft(2, '0')}m', style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 7,
                                activeTrackColor: const Color(0xFF3B82F6),
                                inactiveTrackColor: const Color(0xFF1E293B),
                                thumbColor: const Color(0xFF60A5FA),
                                overlayColor: const Color(0xFF3B82F6).withOpacity(0.15),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
                                activeTickMarkColor: Colors.white70,
                                inactiveTickMarkColor: const Color(0xFF334155),
                              ),
                              child: Slider(
                                value: _durationMinutes.toDouble().clamp(0.0, 60.0),
                                min: 0.0,
                                max: 60.0,
                                divisions: 12,
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  final newM = (val / 5).round() * 5;
                                  if (newM != _durationMinutes) {
                                    final now = DateTime.now();
                                    setState(() {
                                      _durationMinutes = newM;
                                      _targetTime = now.add(Duration(
                                        hours: _durationHours,
                                        minutes: _durationMinutes,
                                      ));
                                    });
                                  }
                                },
                                onChangeEnd: (_) => _syncTargetFromDuration(),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('0m', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                  Text('30m', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                  Text('60m', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Total Number of Alarms Selector (6 rectangular selector tabs)
          _buildTotalAlarmsSelector(),
          const SizedBox(height: 18),

          // 4. Alarm Interval Selector (5 rectangular selector tabs)
          _buildIntervalSelector(),
          const SizedBox(height: 22),

          // 5. Set Alarm Button
          ElevatedButton(
            onPressed: _isDispatching ? null : _setTheAlarm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 4,
              shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isDispatching
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text(
                    'Set Alarm',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.3),
                  ),
          ),
          const SizedBox(height: 20),

          // Quick Presets Section (Directly below Set Alarm)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'QUICK PRESETS',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _isEditingPresets = !_isEditingPresets);
                    },
                    icon: Icon(
                      _isEditingPresets ? Icons.check_rounded : Icons.edit_outlined,
                      size: 15,
                    ),
                    label: Text(_isEditingPresets ? 'Done' : 'Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: _isEditingPresets
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF94A3B8),
                      backgroundColor: _isEditingPresets
                          ? const Color(0xFF3B82F6).withOpacity(0.12)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_presetsLoaded && _presets.isEmpty && !_isEditingPresets)
                const Text(
                  'No presets yet. Tap Edit to create one.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              if (_isEditingPresets && _presets.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tap a preset to edit it, or × to delete.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ),
              if (_presets.isNotEmpty || _isEditingPresets)
                Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._presets.map((preset) {
                    final isCurrent = _durationHours == preset.hours && _durationMinutes == preset.minutes;
                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _isEditingPresets
                                  ? () => _showAddPresetDialog(existing: preset)
                                  : () {
                                      setState(() {
                                        _durationHours = preset.hours;
                                        _durationMinutes = preset.minutes;
                                      });
                                      _syncTargetFromDuration();
                                    },
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 14,
                                  right: _isEditingPresets ? 8 : 14,
                                  top: 10,
                                  bottom: 10,
                                ),
                                child: Text(
                                  preset.label,
                                  style: TextStyle(
                                    color: isCurrent ? Colors.white : const Color(0xFF94A3B8),
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (_isEditingPresets)
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _deletePreset(preset),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 2,
                                    right: 8,
                                    top: 8,
                                    bottom: 8,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: isCurrent
                                        ? Colors.white70
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  // Add is only available while editing presets.
                  if (_isEditingPresets)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showAddPresetDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: Color(0xFF60A5FA)),
                            SizedBox(width: 4),
                            Text(
                              'Add',
                              style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
