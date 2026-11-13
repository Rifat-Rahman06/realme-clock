# Realme X Custom Alarm Manager

Target device: Realme X (China ROM RMX1901) — Android 11.

## What it does

- Build a wake-up chain: pick the actual alarm time with the embedded wheel
  picker, choose how many alarms you want (1x–6x) and the interval between
  them (2–15 minutes).
- Tap **Set Alarm** to send the chain to the phone's own Clock app
  (`com.coloros.alarm` / `com.heytap.deskclock` / AOSP / Google Clock).
- The app is a dispatcher only. Realme Clock remains the alarm owner and the
  source of truth. Android has no public API to read the Clock app's alarm
  list, so this app cannot verify or manage those alarms afterwards. Always
  confirm the alarms in the Clock app.
- There is no alarm deletion or “Sent” history in the app. Use the Clock app
  itself if you need to remove an alarm.

## How to build the APK with GitHub Actions

1. Upload these files to a GitHub repository.
2. GitHub automatically triggers `.github/workflows/build.yaml`.
3. After a couple of minutes, open the **Actions** tab and download the
   `realme-x-alarm-release-apk` artifact.

The workflow runs `flutter create --overwrite` to generate the Android Gradle
scaffold because this repository only ships the custom manifest, Kotlin bridge
and Dart code.

## UI layout

The app has a single full-screen Home page. The top bar shows **Alarm Manager**
and an open-in-new icon that launches the Realme Clock app.

1. **Actual Alarm Time** — directly embedded, looping Flutter wheel picker
   (no bottom sheet): hour (1–12), minute (00–59), AM/PM. The wheels wrap
   around continuously in both directions.
2. **Relative time** — hour selector (0–12 h) and minute selector (0–60 m in
   5-minute steps), side by side with stepped sliders. Selecting 0 hours lets
   you schedule a chain in minutes only.
3. **Total alarms** — six rectangular selector tabs (1x–6x).
4. **Alarm interval** — five rectangular selector tabs (2, 3, 5, 10, 15 m).
   The interval becomes active only when 2x or more alarms are selected.
5. **Set Alarm** button, followed by **Quick Presets**.
6. **Quick Presets** — tap a preset to apply it. User-added presets show a
   small **×** so they can be removed (with Undo). Built-in presets cannot be
   deleted.

## Permissions and limits

- `SET_ALARM` lets the app hand a time of day to the system Clock app.
- The alarm is dispatched with `EXTRA_SKIP_UI=true` and without repeat days,
  so it is intended as a single-occurrence alarm.
- Some Realme/ColorOS builds may ignore parts of the intent or apply their own
  defaults. The app reports only whether the intent was accepted, not whether
  the Clock app actually stored the alarm.
