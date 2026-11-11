import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/native_clock_service.dart';

void main() {
  runApp(const RealmeAlarmApp());
}

class RealmeAlarmApp extends StatelessWidget {
  const RealmeAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realme Alarm Manager',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFBBF24),
          secondary: Color(0xFFF59E0B),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const AlarmHomePage(),
    );
  }
}

class AlarmHomePage extends StatefulWidget {
  const AlarmHomePage({super.key});

  @override
  State<AlarmHomePage> createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<AlarmHomePage> {
  int _hours = 7;
  int _minutes = 0;
  int _alarmCount = 5;
  int _intervalMinutes = 5;
  String _label = 'Morning Rise';
  bool _skipUi = true;
  bool _isDispatching = false;

  DateTime get _targetWakeTime {
    return DateTime.now().add(Duration(hours: _hours, minutes: _minutes));
  }

  List<DateTime> get _alarmTimes {
    final list = <DateTime>[];
    for (int i = 0; i < _alarmCount; i++) {
      list.add(_targetWakeTime.add(Duration(minutes: i * _intervalMinutes)));
    }
    return list;
  }

  Future<void> _dispatchAlarms() async {
    setState(() => _isDispatching = true);
    final times = _alarmTimes;

    for (int i = 0; i < times.length; i++) {
      final t = times[i];
      final message = '$_label (${i + 1}/$_alarmCount)';
      await NativeClockService.setAlarm(
        hour: t.hour,
        minutes: t.minute,
        message: message,
        skipUi: _skipUi,
        vibrate: true,
      );
      // Stagger by 350ms to prevent ColorOS ActivityManager dropping consecutive intents
      await Future.delayed(const Duration(milliseconds: 350));
    }

    setState(() => _isDispatching = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispatched $_alarmCount alarms to Realme Clock!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('hh:mm a');
    final dateFormat = DateFormat('EEE, MMM d');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realme Alarm Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Color(0xFFFBBF24)),
            tooltip: 'Open Realme Clock',
            onPressed: () => NativeClockService.openClockApp(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Target wake card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('TARGET WAKE-UP TIME', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    timeFormat.format(_targetWakeTime),
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                  ),
                  Text(
                    dateFormat.format(_targetWakeTime),
                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Relative duration picker
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RELATIVE SLEEP DURATION', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberStepper('Hours', _hours, 0, 24, (v) => setState(() => _hours = v)),
                      _buildNumberStepper('Minutes', _minutes, 0, 55, (v) => setState(() => _minutes = v), step: 5),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Alarm Count & Interval
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Alarms:'),
                      DropdownButton<int>(
                        value: _alarmCount,
                        dropdownColor: const Color(0xFF1E293B),
                        items: [1, 2, 3, 5, 8, 10].map((e) => DropdownMenuItem(value: e, child: Text('$e alarms'))).toList(),
                        onChanged: (v) => setState(() => _alarmCount = v ?? 5),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Interval:'),
                      DropdownButton<int>(
                        value: _intervalMinutes,
                        dropdownColor: const Color(0xFF1E293B),
                        items: [2, 3, 5, 10, 15].map((e) => DropdownMenuItem(value: e, child: Text('$e min'))).toList(),
                        onChanged: (v) => setState(() => _intervalMinutes = v ?? 5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dispatch CTA
            ElevatedButton(
              onPressed: _isDispatching ? null : _dispatchAlarms,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBBF24),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isDispatching
                  ? const CircularProgressIndicator()
                  : Text('Dispatch $_alarmCount Alarms to Realme Clock', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberStepper(String label, int val, int min, int max, Function(int) onChange, {int step = 1}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: val > min ? () => onChange(val - step) : null,
            ),
            Text('$val', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: val < max ? () => onChange(val + step) : null,
            ),
          ],
        ),
      ],
    );
  }
}
