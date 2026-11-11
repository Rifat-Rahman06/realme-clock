import 'package:flutter/services.dart';

class NativeClockService {
  static const MethodChannel _channel = MethodChannel('com.example.realme_alarm/native_clock');

  /// Requests Realme Clock to schedule an alarm at the given hour and minute.
  /// Returns a map with success status and target package.
  static Future<Map<String, dynamic>> setAlarm({
    required int hour,
    required int minutes,
    required String message,
    bool skipUi = false,
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
    } on PlatformException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'PlatformException occurred',
      };
    }
  }

  /// Opens the installed Realme Clock app so the user can verify or manually delete alarms.
  static Future<bool> openClockApp() async {
    try {
      final res = await _channel.invokeMethod<bool>('openClockApp');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if Android can resolve standard SET_ALARM intent.
  static Future<bool> isClockAvailable() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkClockAvailability');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks Realme X battery optimization whitelist status.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkBatteryOptimization');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
