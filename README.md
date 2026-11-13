# Alarm Manager

A small Flutter app for the **Realme X** (China ROM, Android 11) that sends a
silent, one-time alarm chain to the phone's built-in Clock app.

<p align="center">
  <img src="docs/icon.png" width="140" alt="Alarm Manager app icon">
</p>

## What it does

- Pick the actual alarm time with an embedded 12-hour wheel picker: the hour
  and minute wheels wrap continuously, while AM/PM is a two-option wheel.
- Choose a relative delay with the hour (0–12 h) and minute (0–60 m, in
  5-minute steps) sliders.
- Send **1x–6x** alarms, spaced 2/3/5/10/15 minutes apart. The interval
  selector is disabled when 1x is selected.
- Save your own **Quick Presets**. Normal mode only selects a preset; **Edit**
  mode adds, changes, or deletes presets, with Undo.
- Presets are stored in `quick_presets.json` in the app's private files
  directory and restored on the next launch.
- The top-bar open-in-new icon opens the Realme Clock app so you can check
  the alarms.

The app is a **dispatcher only**. The Realme Clock app owns the alarms and is
the source of truth. Android does not expose a public API for reading or
deleting another app's alarms, so Alarm Manager cannot verify or manage them
after they are sent. The app does not keep a sent-alarm history.

## Requirements

- Flutter 3.19.x (the version this project was built with; Dart 3.x)
- Android SDK / Android Studio for local builds
- A Realme X (RMX1901, ColorOS 11 / Android 11), or a compatible Android
  device with a Clock app that handles `AlarmClock.ACTION_SET_ALARM`

## Getting started

This repository is a complete Flutter Android project, so no `flutter create`
step is needed.

```bash
flutter pub get
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

> The release build currently signs with the debug key so it can be installed
> directly. Create a proper signing config before distributing it.

## Project structure

```
android/                    Complete Android/Gradle project
  app/src/main/
    AndroidManifest.xml     App name, icon, SET_ALARM permission and queries
    kotlin/.../MainActivity.kt
                            Sends SET_ALARM intents and exposes the preset path
    res/                    Custom adaptive launcher icon and launch theme
lib/
  main.dart                 Single-screen Home UI
  models/alarm_models.dart
  services/native_clock_service.dart
  services/preset_store.dart
docs/icon.png               App icon for the README
tools/test_realme_x.sh      Optional ADB checks for the target phone
```

## How the alarm chain works

Each alarm is sent to the Clock app with `AlarmClock.ACTION_SET_ALARM`:

- `EXTRA_HOUR` / `EXTRA_MINUTES` — the calculated alarm time
- `EXTRA_MESSAGE` — `Alarm i/N`
- `EXTRA_SKIP_UI` — `true` (silent dispatch)
- `EXTRA_VIBRATE` — `true`
- no `EXTRA_DAYS` — intended as a one-shot alarm

Requests are sent 350 ms apart so the Clock app can process each one. The app
tries the known Realme/ColorOS packages first (`com.coloros.alarm`,
`com.heytap.deskclock`), then falls back to AOSP/Google Clock or the system
default handler.

The result shown by the app means only that Android accepted the intent. It
does not prove that Realme Clock stored the alarm. Always confirm the alarms
in the Clock app.

## Preset storage

Presets are stored as a JSON array:

```json
[
  { "label": "Wake up", "hours": 8, "minutes": 0 },
  { "label": "Snooze", "hours": 0, "minutes": 10 }
]
```

The file lives at:

```
/data/user/0/com.example.realme_alarm_manager/files/quick_presets.json
```

The path is provided by the Kotlin bridge. No SQL database or extra storage
package is used.

## Permissions

- `com.android.alarm.permission.SET_ALARM` — hand an alarm request to the
  Clock app.
- `VIBRATE` — request a vibrating alarm (the Clock app may ignore it).
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — optional prompt to keep ColorOS
  from restricting the app. The app itself does not run a background service.
- Android 11 package visibility is handled with `<queries>` entries for the
  known Clock apps.

## Known limitations

- The app cannot read, verify, edit, or delete alarms owned by the Clock app.
- Some Realme/ColorOS builds ignore parts of the intent or apply their own
  defaults.
- Alarms created by an intent without repeat days and with `EXTRA_SKIP_UI`
  may be treated as one-shot alarms by Realme Clock and can disappear after
  they ring or are stopped. Manually created alarms behave differently.
- The UI is designed for the Realme X screen and has not been verified on
  other devices.

## Testing on the target phone

`tools/test_realme_x.sh` contains optional ADB commands to:

- list the installed Clock packages,
- fire a manual `SET_ALARM` intent,
- open the Realme Clock app,
- check the app's battery-optimization whitelist status.

Run the commands from the repository root after connecting the phone with USB
debugging enabled.

## Notes

- Application ID: `com.example.realme_alarm_manager`. Change it (and the
  Kotlin package/manifest references) before publishing under a different
  identity.
- The launcher label is **Alarm Manager**.
- This project is not affiliated with Realme or ColorOS.

## License

This is a personal project. Add an appropriate license if you plan to publish
or redistribute it.
