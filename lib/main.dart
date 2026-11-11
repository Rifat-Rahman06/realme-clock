import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const RealmeAlarmApp());
}

// ==========================================
// Native Realme Clock Platform Bridge
// ==========================================
class NativeClockService {
  static const MethodChannel _channel = MethodChannel('com.example.realme_alarm/native_clock');

  static Future<Map<String, dynamic>> setAlarm({
    required int hour,
    required int minutes,
    required String message,
    bool skipUi = true,
    bool vibrate = true,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('setAlarm', {
        'hour': hour,
        'minutes': minutes,
        'message': message,
        'skipUi': skipUi,
        'vibrate': vibrate,
      });
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<bool> openClockApp() async {
    try {
      final res = await _channel.invokeMethod<bool>('openClockApp');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> dismissAlarm({required int hour, required int minutes}) async {
    try {
      final res = await _channel.invokeMethod<bool>('dismissAlarm', {
        'hour': hour,
        'minutes': minutes,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}

// ==========================================
// Data Models
// ==========================================
class AlarmItemRecord {
  final String id;
  final int hour;
  final int minute;
  final String displayTime;
  final String dateText;
  final int sequenceIndex;
  final int totalInGroup;
  bool isSelected;

  AlarmItemRecord({
    required this.id,
    required this.hour,
    required this.minute,
    required this.displayTime,
    required this.dateText,
    required this.sequenceIndex,
    required this.totalInGroup,
    this.isSelected = false,
  });
}

class AlarmGroupRecord {
  final String id;
  final String title;
  final String initialTargetTime;
  final int alarmCount;
  final int intervalMinutes;
  final DateTime createdAt;
  final List<AlarmItemRecord> alarms;
  bool isSelected;

  AlarmGroupRecord({
    required this.id,
    required this.title,
    required this.initialTargetTime,
    required this.alarmCount,
    required this.intervalMinutes,
    required this.createdAt,
    required this.alarms,
    this.isSelected = false,
  });
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

  void _addNewAlarmGroup(AlarmGroupRecord group) {
    setState(() {
      _alarmGroups.insert(0, group);
    });
  }

  void _deleteSingleAlarm(String groupId, String alarmId) {
    AlarmItemRecord? target;
    for (final grp in _alarmGroups) {
      if (grp.id == groupId) {
        for (final a in grp.alarms) {
          if (a.id == alarmId) target = a;
        }
      }
    }
    if (target != null) {
      NativeClockService.dismissAlarm(hour: target.hour, minutes: target.minute);
    }

    setState(() {
      for (final grp in _alarmGroups) {
        if (grp.id == groupId) {
          grp.alarms.removeWhere((a) => a.id == alarmId);
        }
      }
      _alarmGroups.removeWhere((grp) => grp.alarms.isEmpty);
    });
    _showDeleteNotice('Alarm removed from manager.');
  }

  void _deleteGroup(String groupId) {
    for (final grp in _alarmGroups) {
      if (grp.id == groupId) {
        for (final a in grp.alarms) {
          NativeClockService.dismissAlarm(hour: a.hour, minutes: a.minute);
        }
      }
    }
    setState(() {
      _alarmGroups.removeWhere((grp) => grp.id == groupId);
    });
    _showDeleteNotice('Alarm group removed from manager.');
  }

  void _deleteSelectedItems() {
    for (final grp in _alarmGroups) {
      if (grp.isSelected) {
        for (final a in grp.alarms) {
          NativeClockService.dismissAlarm(hour: a.hour, minutes: a.minute);
        }
      } else {
        for (final a in grp.alarms.where((item) => item.isSelected)) {
          NativeClockService.dismissAlarm(hour: a.hour, minutes: a.minute);
        }
      }
    }
    setState(() {
      for (final grp in _alarmGroups) {
        if (grp.isSelected) {
          grp.alarms.clear();
        } else {
          grp.alarms.removeWhere((a) => a.isSelected);
        }
      }
      _alarmGroups.removeWhere((grp) => grp.alarms.isEmpty);
    });
    _showDeleteNotice('Selected alarms removed from manager.');
  }

  void _showDeleteNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
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
      body: IndexedStack(
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
              label: 'Alarms',
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
  final Function(AlarmGroupRecord) onAlarmGroupCreated;
  const HomeScreen({super.key, required this.onAlarmGroupCreated});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _durationHours = 7;
  int _durationMinutes = 0;
  late DateTime _targetTime;

  int _totalAlarms = 5;
  int _intervalMinutes = 5;
  bool _isDispatching = false;

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
    _recalculateTargetFromDuration();
  }

  void _recalculateTargetFromDuration() {
    final now = DateTime.now();
    setState(() {
      _targetTime = now.add(Duration(hours: _durationHours, minutes: _durationMinutes));
    });
  }

  void _recalculateDurationFromTarget(DateTime newTarget) {
    final now = DateTime.now();
    var diff = newTarget.difference(now);
    if (diff.isNegative) {
      newTarget = newTarget.add(const Duration(days: 1));
      diff = newTarget.difference(now);
    }

    final totalMins = diff.inMinutes;
    setState(() {
      _targetTime = newTarget;
      _durationHours = (totalMins / 60).floor().clamp(0, 24);
      _durationMinutes = (totalMins % 60).clamp(0, 59);
    });
  }

  void _adjustHours(int delta) {
    final newH = (_durationHours + delta).clamp(0, 24);
    setState(() => _durationHours = newH);
    _recalculateTargetFromDuration();
  }

  void _adjustMinutes(int delta) {
    var newM = _durationMinutes + delta;
    var newH = _durationHours;
    if (newM >= 60) {
      newM = 0;
      newH = (newH + 1).clamp(0, 24);
    } else if (newM < 0) {
      if (newH > 0) {
        newM = 55;
        newH -= 1;
      } else {
        newM = 0;
      }
    }
    setState(() {
      _durationMinutes = newM;
      _durationHours = newH;
    });
    _recalculateTargetFromDuration();
  }

  void _openTargetTimeEditor() async {
    final now = _targetTime;
    int currentHour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    int currentMinute = now.minute;
    bool isPm = now.hour >= 12;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Target Wakeup Time',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildWheelSelector('Hour', currentHour12, 1, 12, (v) {
                        setModalState(() => currentHour12 = v);
                      }),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(':', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      _buildWheelSelector('Minute', currentMinute, 0, 59, (v) {
                        setModalState(() => currentMinute = v);
                      }),
                      const SizedBox(width: 20),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => setModalState(() => isPm = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: !isPm ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'AM',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !isPm ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => setModalState(() => isPm = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isPm ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'PM',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isPm ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      int calculatedHour = currentHour12 % 12;
                      if (isPm) calculatedHour += 12;

                      final baseDate = DateTime.now();
                      DateTime updated = DateTime(
                        baseDate.year,
                        baseDate.month,
                        baseDate.day,
                        calculatedHour,
                        currentMinute,
                      );

                      if (updated.isBefore(baseDate)) {
                        updated = updated.add(const Duration(days: 1));
                      }

                      _recalculateDurationFromTarget(updated);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply Target Time', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWheelSelector(String label, int val, int min, int max, Function(int) onChange) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF60A5FA)),
          onPressed: () => onChange(val >= max ? min : val + 1),
        ),
        Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Text(
            val.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF60A5FA)),
          onPressed: () => onChange(val <= min ? max : val - 1),
        ),
      ],
    );
  }

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
                            items: List.generate(24, (i) => i + 1)
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

  Future<void> _setTheAlarm() async {
    setState(() => _isDispatching = true);

    final groupId = 'grp_${DateTime.now().millisecondsSinceEpoch}';
    final childAlarms = <AlarmItemRecord>[];
    final timeFormat = DateFormat('hh:mm a');
    final dateFormat = DateFormat('EEE, MMM d');

    for (int i = 0; i < _totalAlarms; i++) {
      final alarmTime = _targetTime.add(Duration(minutes: i * _intervalMinutes));
      final message = 'Alarm (${i + 1}/$_totalAlarms)';

      await NativeClockService.setAlarm(
        hour: alarmTime.hour,
        minutes: alarmTime.minute,
        message: message,
        skipUi: true,
        vibrate: true,
      );

      childAlarms.add(
        AlarmItemRecord(
          id: 'alm_${groupId}_$i',
          hour: alarmTime.hour,
          minute: alarmTime.minute,
          displayTime: timeFormat.format(alarmTime),
          dateText: dateFormat.format(alarmTime),
          sequenceIndex: i + 1,
          totalInGroup: _totalAlarms,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 350));
    }

    final newGroup = AlarmGroupRecord(
      id: groupId,
      title: 'Wake Up Session ($_totalAlarms Alarms)',
      initialTargetTime: timeFormat.format(_targetTime),
      alarmCount: _totalAlarms,
      intervalMinutes: _intervalMinutes,
      createdAt: DateTime.now(),
      alarms: childAlarms,
    );

    widget.onAlarmGroupCreated(newGroup);
    setState(() => _isDispatching = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully scheduled $_totalAlarms alarms in Realme Clock!'),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('hh:mm a');
    final dateFormat = DateFormat('EEE, MMM d');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Target Wakeup Time Section (Editable)
          GestureDetector(
            onTap: _openTargetTimeEditor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                        'TARGET WAKEUP TIME',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 12, color: Color(0xFF60A5FA)),
                            SizedBox(width: 4),
                            Text('Tap to edit', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeFormat.format(_targetTime),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'monospace',
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(_targetTime),
                    style: const TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2 & 3. Relative Sleep Duration & Circular Ring Dial
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RELATIVE SLEEP DURATION',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Synchronized',
                      style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                CircularDurationRingDial(
                  hours: _durationHours,
                  minutes: _durationMinutes,
                  onDurationChanged: (h, m) {
                    setState(() {
                      _durationHours = h;
                      _durationMinutes = m;
                    });
                    _recalculateTargetFromDuration();
                  },
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStepperBox(
                      label: 'Hours',
                      value: _durationHours,
                      suffix: 'h',
                      onMinus: () => _adjustHours(-1),
                      onPlus: () => _adjustHours(1),
                    ),
                    _buildStepperBox(
                      label: 'Minutes',
                      value: _durationMinutes,
                      suffix: 'm',
                      onMinus: () => _adjustMinutes(-5),
                      onPlus: () => _adjustMinutes(5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. Total Alarms & Interval
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Alarms', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    DropdownButton<int>(
                      value: _totalAlarms,
                      dropdownColor: const Color(0xFF1E293B),
                      underline: const SizedBox(),
                      items: [1, 2, 3, 5, 8, 10]
                          .map((val) => DropdownMenuItem(value: val, child: Text('$val alarms', style: const TextStyle(color: Color(0xFF60A5FA)))))
                          .toList(),
                      onChanged: (v) => setState(() => _totalAlarms = v ?? 5),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B), height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Alarm Interval', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    DropdownButton<int>(
                      value: _intervalMinutes,
                      dropdownColor: const Color(0xFF1E293B),
                      underline: const SizedBox(),
                      items: [2, 3, 5, 10, 15]
                          .map((val) => DropdownMenuItem(value: val, child: Text('$val minutes', style: const TextStyle(color: Color(0xFF60A5FA)))))
                          .toList(),
                      onChanged: (v) => setState(() => _intervalMinutes = v ?? 5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // "Set the Alarm" Button
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
                    'Set the Alarm',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.3),
                  ),
          ),
          const SizedBox(height: 20),

          // 5. Quick Presets Section
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
                        _recalculateTargetFromDuration();
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

  Widget _buildStepperBox({
    required String label,
    required int value,
    required String suffix,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onMinus,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF0F172A), shape: BoxShape.circle),
              child: const Icon(Icons.remove, size: 16, color: Color(0xFF60A5FA)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                Text(
                  '$value$suffix',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                ),
                Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
          InkWell(
            onTap: onPlus,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF0F172A), shape: BoxShape.circle),
              child: const Icon(Icons.add, size: 16, color: Color(0xFF60A5FA)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. Circular Ring-Style Time Gesture Dial
// ==========================================
class CircularDurationRingDial extends StatelessWidget {
  final int hours;
  final int minutes;
  final Function(int, int) onDurationChanged;

  const CircularDurationRingDial({
    super.key,
    required this.hours,
    required this.minutes,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalMinutes = (hours * 60 + minutes).clamp(0, 1440);
    final progress = (totalMinutes % 720) / 720.0;

    return GestureDetector(
      onPanUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final center = box.size.center(Offset.zero);
        final position = details.localPosition;
        final touchPoint = position - center;

        double angle = math.atan2(touchPoint.dy, touchPoint.dx) + (math.pi / 2);
        if (angle < 0) angle += 2 * math.pi;

        final rawProgress = angle / (2 * math.pi);
        final calculatedMins = (rawProgress * 720).round();

        final roundedMins = (calculatedMins / 5).round() * 5;
        final newH = (hours >= 12 ? 12 : 0) + (roundedMins / 60).floor();
        final newM = roundedMins % 60;

        onDurationChanged(newH.clamp(0, 24), newM.clamp(0, 59));
      },
      child: Center(
        child: SizedBox(
          width: 170,
          height: 170,
          child: CustomPaint(
            painter: RingDialPainter(progress: progress),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${hours}h ${minutes.toString().padLeft(2, '0')}m',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Slide to adjust',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RingDialPainter extends CustomPainter {
  final double progress;
  RingDialPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 14;

    final trackPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
        startAngle: 0.0,
        endAngle: math.pi * 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startAngle = -math.pi / 2;
    final sweepAngle = (2 * math.pi) * progress.clamp(0.01, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );

    final thumbAngle = startAngle + sweepAngle;
    final thumbX = center.dx + radius * math.cos(thumbAngle);
    final thumbY = center.dy + radius * math.sin(thumbAngle);

    final thumbPaint = Paint()..color = const Color(0xFF60A5FA);
    final thumbBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(thumbX, thumbY), 8, thumbPaint);
    canvas.drawCircle(Offset(thumbX, thumbY), 8, thumbBorder);
  }

  @override
  bool shouldRepaint(covariant RingDialPainter oldDelegate) => oldDelegate.progress != progress;
}

// ==========================================
// Tab 2: Alarms Tab (Group-Based Management)
// ==========================================
class AlarmsTabScreen extends StatefulWidget {
  final List<AlarmGroupRecord> groups;
  final Function(String, String) onDeleteAlarm;
  final Function(String) onDeleteGroup;
  final VoidCallback onDeleteSelected;

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
                'No Alarms Set',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create alarms in the Home tab to delegate them to your Realme Clock.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Notice about Android OEM Clock Database separation
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF60A5FA)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Android prevents apps from directly erasing system clock databases. Tap OPEN to clear in Realme Clock.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.3),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => NativeClockService.openClockApp(),
                child: const Text('OPEN', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Selection & Delete Toolbar
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
                      onPressed: widget.onDeleteSelected,
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Group List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    // Group Header Row
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                ),
                                Text(
                                  'First: ${group.initialTargetTime} · ${group.intervalMinutes}m interval',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF60A5FA)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 20),
                            tooltip: 'Delete Group',
                            onPressed: () => widget.onDeleteGroup(group.id),
                          ),
                        ],
                      ),
                    ),

                    // Child Alarms List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: group.alarms.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
                      itemBuilder: (context, aIndex) {
                        final alarm = group.alarms[aIndex];
                        return ListTile(
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
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
                            ],
                          ),
                          subtitle: Text(
                            alarm.dateText,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                            tooltip: 'Delete Alarm',
                            onPressed: () => widget.onDeleteAlarm(group.id, alarm.id),
                          ),
                        );
                      },
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
