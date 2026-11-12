import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'database/alarm_database.dart';
import 'models/alarm_models.dart';
import 'services/native_clock_service.dart';

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
// Main Navigation (Two Tabs: Home & Alarms)
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentTabIndex = 0;
  final List<AlarmGroupRecord> _alarmGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    List<AlarmGroupRecord> groups = const [];
    try {
      groups = await AlarmDatabase.instance.loadGroups();
    } catch (_) {
      groups = const [];
    }
    if (!mounted) return;
    setState(() {
      _alarmGroups
        ..clear()
        ..addAll(groups);
      _isLoading = false;
    });
  }

  Future<void> _addNewAlarmGroup(AlarmGroupRecord group) async {
    try {
      await AlarmDatabase.instance.saveGroup(group);
    } catch (_) {
      // Keep the in-memory record even if persistence fails.
    }
    if (!mounted) return;
    setState(() => _alarmGroups.insert(0, group));
  }

  Future<void> _deleteSingleAlarm(String groupId, String alarmId) async {
    AlarmItemRecord? target;
    for (final grp in _alarmGroups) {
      if (grp.id != groupId) continue;
      for (final alarm in grp.alarms) {
        if (alarm.id == alarmId) {
          target = alarm;
          break;
        }
      }
    }

    var dismissStarted = false;
    if (target != null) {
      final res = await NativeClockService.dismissAlarm(
        hour: target.hour,
        minutes: target.minute,
      );
      dismissStarted = res['success'] == true;
    }

    try {
      await AlarmDatabase.instance.deleteAlarm(groupId, alarmId);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      for (final grp in _alarmGroups) {
        if (grp.id == groupId) {
          grp.alarms.removeWhere((a) => a.id == alarmId);
        }
      }
      _alarmGroups.removeWhere((grp) => grp.alarms.isEmpty);
    });

    _showDeleteNotice(
      dismissStarted
          ? 'Cancel request sent. Confirm in Realme Clock — this app cannot verify it.'
          : 'Record removed here, but the Clock app may still keep this alarm.',
    );
  }

  Future<void> _deleteGroup(String groupId) async {
    final alarms = <AlarmItemRecord>[];
    for (final grp in _alarmGroups) {
      if (grp.id == groupId) alarms.addAll(grp.alarms);
    }

    var dismissCount = 0;
    for (final alarm in alarms) {
      final res = await NativeClockService.dismissAlarm(
        hour: alarm.hour,
        minutes: alarm.minute,
      );
      if (res['success'] == true) dismissCount++;
      await Future.delayed(const Duration(milliseconds: 150));
    }

    try {
      await AlarmDatabase.instance.deleteGroup(groupId);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _alarmGroups.removeWhere((grp) => grp.id == groupId));

    _showDeleteNotice(
      alarms.isNotEmpty && dismissCount == alarms.length
          ? 'Cancel requests sent for ${alarms.length} alarm(s). Confirm in Realme Clock.'
          : 'Group removed here. Some alarms may remain in Realme Clock.',
    );
  }

  Future<void> _deleteSelectedItems() async {
    final fullySelectedGroups = <String>{};
    final selectedAlarms = <AlarmItemRecord>[];

    for (final grp in _alarmGroups) {
      if (grp.isSelected) {
        fullySelectedGroups.add(grp.id);
        selectedAlarms.addAll(grp.alarms);
      } else {
        selectedAlarms.addAll(grp.alarms.where((a) => a.isSelected));
      }
    }
    if (selectedAlarms.isEmpty) return;

    var dismissCount = 0;
    for (final alarm in selectedAlarms) {
      final res = await NativeClockService.dismissAlarm(
        hour: alarm.hour,
        minutes: alarm.minute,
      );
      if (res['success'] == true) dismissCount++;
      await Future.delayed(const Duration(milliseconds: 150));
    }

    try {
      for (final groupId in fullySelectedGroups) {
        await AlarmDatabase.instance.deleteGroup(groupId);
      }
      for (final alarm in selectedAlarms) {
        if (fullySelectedGroups.contains(alarm.groupId)) continue;
        await AlarmDatabase.instance.deleteAlarm(alarm.groupId, alarm.id);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      for (final grp in _alarmGroups) {
        if (fullySelectedGroups.contains(grp.id)) {
          grp.alarms.clear();
        } else {
          grp.alarms.removeWhere((a) => a.isSelected);
        }
      }
      _alarmGroups.removeWhere((grp) => grp.alarms.isEmpty);
    });

    _showDeleteNotice(
      dismissCount == selectedAlarms.length
          ? 'Cancel requests sent for ${selectedAlarms.length} alarm(s). Confirm in Realme Clock.'
          : 'Removed here, but ${selectedAlarms.length - dismissCount} cancel request(s) failed. Check Realme Clock.',
    );
  }

  void _showDeleteNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OPEN CLOCK',
          textColor: const Color(0xFF60A5FA),
          onPressed: () => NativeClockService.openClockApp(),
        ),
      ),
    );
  }

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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            )
          : IndexedStack(
              index: _currentTabIndex,
              children: [
                HomeScreen(onAlarmGroupCreated: _addNewAlarmGroup),
                AlarmsTabScreen(
                  groups: _alarmGroups,
                  onDeleteAlarm: _deleteSingleAlarm,
                  onDeleteGroup: _deleteGroup,
                  onDeleteSelected: _deleteSelectedItems,
                ),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
          backgroundColor: const Color(0xFF0F172A),
          selectedItemColor: const Color(0xFF3B82F6),
          unselectedItemColor: const Color(0xFF64748B),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.alarm_outlined),
              activeIcon: Icon(Icons.alarm),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.format_list_bulleted_outlined),
                  if (_alarmGroups.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.format_list_bulleted),
              label: 'Sent',
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// Tab 1: Home Screen
// ==========================================
class HomeScreen extends StatefulWidget {
  final Future<void> Function(AlarmGroupRecord) onAlarmGroupCreated;
  const HomeScreen({super.key, required this.onAlarmGroupCreated});

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
  int _totalAlarms = 4; // Default selected
  int _intervalMinutes = 5; // Default selected
  bool _isDispatching = false;

  // Presets list (user-editable)
  final List<QuickPresetItem> _presets = [
    QuickPresetItem(label: '1h', hours: 1),
    QuickPresetItem(label: '2h', hours: 2),
    QuickPresetItem(label: '4h', hours: 4),
    QuickPresetItem(label: '6h', hours: 6),
    QuickPresetItem(label: '7h 30m', hours: 7, minutes: 30),
    QuickPresetItem(label: '8h', hours: 8),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _targetTime = now.add(Duration(hours: _durationHours, minutes: _durationMinutes));

    final h12 = _targetTime.hour % 12 == 0 ? 12 : _targetTime.hour % 12;
    _hourWheelController = FixedExtentScrollController(initialItem: h12 - 1);
    _minuteWheelController = FixedExtentScrollController(initialItem: _targetTime.minute);
    _amPmWheelController = FixedExtentScrollController(initialItem: _targetTime.hour >= 12 ? 1 : 0);
  }

  @override
  void dispose() {
    _hourWheelController.dispose();
    _minuteWheelController.dispose();
    _amPmWheelController.dispose();
    super.dispose();
  }

  // 1. Wheel Picker -> Relative Time Sync
  void _onWheelChanged() {
    if (_isSyncing) return;
    _isSyncing = true;
    HapticFeedback.selectionClick();

    final hour12 = _hourWheelController.selectedItem + 1; // 1 to 12
    final minute = _minuteWheelController.selectedItem; // 0 to 59
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

    setState(() {
      _targetTime = newTarget;
      _durationHours = (totalMins ~/ 60).clamp(1, 12);
      final rawM = totalMins % 60;
      _durationMinutes = ((rawM / 5).round() * 5).clamp(0, 60);
    });

    _isSyncing = false;
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
      if (_hourWheelController.hasClients && _hourWheelController.selectedItem != hIndex) {
        await _hourWheelController.animateToItem(
          hIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
      if (_minuteWheelController.hasClients && _minuteWheelController.selectedItem != mIndex) {
        await _minuteWheelController.animateToItem(
          mIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
      if (_amPmWheelController.hasClients && _amPmWheelController.selectedItem != amPmIndex) {
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
  void _showAddPresetDialog() {
    int inputHours = 3;
    int inputMinutes = 0;
    final textController = TextEditingController(text: '3h Rest');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Quick Preset', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Preset Label',
                      labelStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text('Hours', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          DropdownButton<int>(
                            value: inputHours,
                            dropdownColor: const Color(0xFF1E293B),
                            items: List.generate(12, (i) => i + 1)
                                .map((h) => DropdownMenuItem(value: h, child: Text('$h hrs')))
                                .toList(),
                            onChanged: (v) => setDialogState(() => inputHours = v ?? 1),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Minutes', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          DropdownButton<int>(
                            value: inputMinutes,
                            dropdownColor: const Color(0xFF1E293B),
                            items: [0, 15, 30, 45]
                                .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                                .toList(),
                            onChanged: (v) => setDialogState(() => inputMinutes = v ?? 0),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final label = textController.text.trim().isEmpty ? '${inputHours}h' : textController.text.trim();
                    setState(() {
                      _presets.add(QuickPresetItem(label: label, hours: inputHours, minutes: inputMinutes));
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add Preset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Sends the chain to the Realme Clock app and records what happened.
  Future<void> _setTheAlarm() async {
    if (_isDispatching) return;
    setState(() => _isDispatching = true);

    final now = DateTime.now();
    final groupId = 'grp_${now.millisecondsSinceEpoch}';
    final childAlarms = <AlarmItemRecord>[];
    final timeFormat = DateFormat('hh:mm a');
    var delivered = 0;

    try {
      for (int i = 0; i < _totalAlarms; i++) {
        final raw = _targetTime.add(Duration(minutes: i * _intervalMinutes));
        // The Clock intent only accepts a time of day, so normalise seconds.
        final alarmTime = DateTime(raw.year, raw.month, raw.day, raw.hour, raw.minute);
        final message = 'Alarm ${i + 1}/$_totalAlarms';

        final result = await NativeClockService.setAlarm(
          hour: alarmTime.hour,
          minutes: alarmTime.minute,
          message: message,
          skipUi: true,
          vibrate: true,
        );
        final ok = result['success'] == true;
        if (ok) delivered++;

        childAlarms.add(
          AlarmItemRecord(
            id: 'alm_${groupId}_$i',
            groupId: groupId,
            scheduledAt: alarmTime,
            sequenceIndex: i + 1,
            totalInGroup: _totalAlarms,
            delivered: ok,
            targetPackage: result['targetPackage']?.toString(),
            error: ok ? null : (result['error']?.toString() ?? 'Unknown error'),
          ),
        );

        // Stagger requests so the Realme Clock queue is not flooded.
        if (i < _totalAlarms - 1) {
          await Future.delayed(const Duration(milliseconds: 350));
        }
      }

      final newGroup = AlarmGroupRecord(
        id: groupId,
        title: 'Wake-up chain · $_totalAlarms alarms',
        initialTargetTime: timeFormat.format(_targetTime),
        alarmCount: _totalAlarms,
        intervalMinutes: _intervalMinutes,
        durationHours: _durationHours,
        durationMinutes: _durationMinutes,
        createdAt: now,
        alarms: childAlarms,
      );

      await widget.onAlarmGroupCreated(newGroup);
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
              ? 'Sent $_totalAlarms alarm(s) to Realme Clock. Check the Clock app to confirm.'
              : 'Sent $delivered of $_totalAlarms. $failed failed — open Clock to check.',
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
            'ALARM INTERVAL',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: intervals.map((mins) {
              final isSelected = _intervalMinutes == mins;
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                  height: 116,
                  child: Row(
                    children: [
                      // Hour Wheel (1 - 12)
                      Expanded(
                        flex: 3,
                        child: CupertinoPicker(
                          itemExtent: 36,
                          scrollController: _hourWheelController,
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
                          itemExtent: 36,
                          scrollController: _minuteWheelController,
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
                          itemExtent: 36,
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
            padding: const EdgeInsets.all(18),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                                trackHeight: 4,
                                activeTrackColor: const Color(0xFF3B82F6),
                                inactiveTrackColor: const Color(0xFF1E293B),
                                thumbColor: const Color(0xFF60A5FA),
                                overlayColor: const Color(0xFF3B82F6).withOpacity(0.15),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
                                activeTickMarkColor: Colors.white70,
                                inactiveTickMarkColor: const Color(0xFF334155),
                              ),
                              child: Slider(
                                value: _durationHours.toDouble().clamp(1.0, 12.0),
                                min: 1.0,
                                max: 12.0,
                                divisions: 11,
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
                                  Text('1h', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                  Text('6h', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                  Text('12h', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Minute Selector (Right)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                                trackHeight: 4,
                                activeTrackColor: const Color(0xFF3B82F6),
                                inactiveTrackColor: const Color(0xFF1E293B),
                                thumbColor: const Color(0xFF60A5FA),
                                overlayColor: const Color(0xFF3B82F6).withOpacity(0.15),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
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
              const Text(
                'QUICK PRESETS',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._presets.map((preset) {
                    final isCurrent = _durationHours == preset.hours && _durationMinutes == preset.minutes;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _durationHours = preset.hours;
                          _durationMinutes = preset.minutes;
                        });
                        _syncTargetFromDuration();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                          ),
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
                    );
                  }),
                  // Plus (+) Button to Add Preset
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showAddPresetDialog,
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

// ==========================================
// Tab 2: Sent Alarms (audit list, not a live manager)
// ==========================================
class AlarmsTabScreen extends StatefulWidget {
  final List<AlarmGroupRecord> groups;
  final Future<void> Function(String groupId, String alarmId) onDeleteAlarm;
  final Future<void> Function(String groupId) onDeleteGroup;
  final Future<void> Function() onDeleteSelected;

  const AlarmsTabScreen({
    super.key,
    required this.groups,
    required this.onDeleteAlarm,
    required this.onDeleteGroup,
    required this.onDeleteSelected,
  });

  @override
  State<AlarmsTabScreen> createState() => _AlarmsTabScreenState();
}

class _AlarmsTabScreenState extends State<AlarmsTabScreen> {
  int get _selectedCount {
    int count = 0;
    for (final grp in widget.groups) {
      if (grp.isSelected) {
        count += grp.alarms.length;
      } else {
        count += grp.alarms.where((a) => a.isSelected).length;
      }
    }
    return count;
  }

  void _toggleGroupSelection(AlarmGroupRecord grp, bool? value) {
    setState(() {
      grp.isSelected = value ?? false;
      for (final a in grp.alarms) {
        a.isSelected = grp.isSelected;
      }
    });
  }

  void _toggleAlarmSelection(AlarmGroupRecord grp, AlarmItemRecord alm, bool? value) {
    setState(() {
      alm.isSelected = value ?? false;
      grp.isSelected = grp.alarms.every((a) => a.isSelected);
    });
  }

  void _selectAll(bool select) {
    setState(() {
      for (final grp in widget.groups) {
        grp.isSelected = select;
        for (final a in grp.alarms) {
          a.isSelected = select;
        }
      }
    });
  }

  Future<void> _openClock() async {
    final opened = await NativeClockService.openClockApp();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the Clock app. Open it from your app drawer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _statusColor(AlarmGroupRecord group) {
    if (group.allDelivered) return const Color(0xFF22C55E);
    if (group.noneDelivered) return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  String _statusText(AlarmGroupRecord group) {
    if (group.allDelivered) return 'SENT';
    if (group.noneDelivered) return 'FAILED';
    return '${group.deliveredCount}/${group.alarmCount}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm_off_outlined, size: 48, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nothing sent yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Build a wake-up chain in Home and tap "Set Alarm".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _openClock,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('OPEN REALME CLOCK'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF60A5FA)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This is a record of what was sent. Realme Clock is the source of truth. '
                  'Deleting here only asks the Clock app to cancel an alarm; this app cannot confirm it worked.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        if (_selectedCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_selectedCount selected',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _selectAll(false),
                      child: const Text('Deselect', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      onPressed: () => widget.onDeleteSelected(),
                    ),
                  ],
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: widget.groups.length,
            itemBuilder: (ctx, index) {
              final group = widget.groups[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: group.isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF131B2E),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: group.isSelected,
                            activeColor: const Color(0xFF3B82F6),
                            onChanged: (val) => _toggleGroupSelection(group, val),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                ),
                                Text(
                                  'First: ${group.initialTargetTime} · ${group.intervalMinutes}m interval',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF60A5FA)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(group).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _statusColor(group).withOpacity(0.5)),
                            ),
                            child: Text(
                              _statusText(group),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(group),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 20),
                            tooltip: 'Delete group',
                            onPressed: () => widget.onDeleteGroup(group.id),
                          ),
                        ],
                      ),
                    ),

                    ...group.alarms.map((alarm) {
                      final alarmColor = !alarm.delivered
                          ? const Color(0xFFF59E0B)
                          : alarm.isPast
                              ? const Color(0xFF64748B)
                              : Colors.white;
                      return Column(
                        children: [
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: Checkbox(
                              value: alarm.isSelected,
                              activeColor: const Color(0xFF3B82F6),
                              onChanged: (val) => _toggleAlarmSelection(group, alarm, val),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  alarm.displayTime,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: alarmColor,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${alarm.sequenceIndex} of ${alarm.totalInGroup}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  ),
                                ),
                                if (alarm.isPast) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    'PAST',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              alarm.delivered
                                  ? alarm.dateText
                                  : '${alarm.dateText} · not confirmed: ${alarm.error ?? 'unknown error'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: alarm.delivered ? const Color(0xFF94A3B8) : const Color(0xFFF59E0B),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                              tooltip: 'Delete alarm',
                              onPressed: () => widget.onDeleteAlarm(group.id, alarm.id),
                            ),
                          ),
                          if (alarm != group.alarms.last)
                            const Divider(color: Color(0xFF1E293B), height: 1),
                        ],
                      );
                    }),

                    if (group.failedCount > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                        child: Text(
                          '${group.failedCount} alarm(s) were not confirmed. Open the Clock app and set them manually.',
                          style: const TextStyle(fontSize: 10, color: Color(0xFFF59E0B)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
