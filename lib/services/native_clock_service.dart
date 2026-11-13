import 'package:flutter/services.dart';

/// Thin bridge to the Android side.
///
/// Important: this app cannot read or verify the alarms stored by the Realme
/// Clock app. All calls here are requests, not commands. Treat the Clock app
/// as the source of truth.
class NativeClockService {
  static const MethodChannel _channel =
      MethodChannel('com.example.realme_alarm/native_clock');

  /// Asks the phone's Clock app to schedule an alarm.
  ///
  /// Returns a map with `success`, `targetPackage` and, on failure, `error`.
  static Future<Map<String, dynamic>> setAlarm({
    required int hour,
    required int minutes,
    required String message,
    bool skipUi = true,
    bool vibrate = true,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'setAlarm',
        {
          'hour': hour,
          'minutes': minutes,
          'message': message,
          'skipUi': skipUi,
          'vibrate': vibrate,
        },
      );
      return Map<String, dynamic>.from(result ?? <dynamic, dynamic>{});
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message ?? 'PlatformException'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Opens the Clock app so the user can verify the alarms.
  static Future<bool> openClockApp() async {
    try {
      final res = await _channel.invokeMethod<bool>('openClockApp');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether Android can resolve the standard SET_ALARM intent.
  static Future<bool> isClockAvailable() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkClockAvailability');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether the app is exempt from Realme/ColorOS battery killing.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkBatteryOptimization');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system dialog asking to exempt this app from battery limits.
  static Future<void> requestIgnoreBatteryOptimization() async {
    try {
      await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimization');
    } catch (_) {
      // The system dialog may not exist on every ROM. Nothing else to do.
    }
  }
}
