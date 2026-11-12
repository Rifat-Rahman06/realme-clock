# Realme X Custom Alarm Manager

Target device: Realme X (China ROM RMX1901) — Android 11.

## What it does

- Build a wake-up chain: pick the actual alarm time with the embedded wheel
  picker, choose how many alarms you want (1x–6x) and the interval between
  them (2–15 minutes).
- Tap **Set Alarm** to send the chain to the phone's own Clock app
  (`com.coloros.alarm` / `com.heytap.deskclock` / AOSP / Google Clock).
- The **Sent** tab keeps a local record (SQLite) of what was requested,
  including any alarm that failed to dispatch.
- Realme Clock is the source of truth. Android has no public API to read the
  Clock app's alarm list, so this app cannot verify or truly manage those
  alarms. Deleting a record only sends a best-effort cancel request; always
  confirm in the Clock app.

## How to build the APK with GitHub Actions

1. Upload these files to a GitHub repository.
2. GitHub automatically triggers `.github/workflows/build.yaml`.
3. After a couple of minutes, open the **Actions** tab and download the
   `realme-x-alarm-release-apk` artifact.

The workflow runs `flutter create --overwrite` to generate the Android Gradle
scaffold because this repository only ships the custom manifest, Kotlin bridge
and Dart code.

## UI layout

1. **Actual Alarm Time** — directly embedded Flutter wheel picker (no bottom
   sheet): hour (1–12), minute (00–59), AM/PM.
2. **Relative time** — hour selector (1–12 h) and minute selector (0–60 m in
   5-minute steps), side by side with stepped sliders.
3. **Total alarms** — six rectangular selector tabs (1x–6x).
4. **Alarm interval** — five rectangular selector tabs (2, 3, 5, 10, 15 m).
5. **Set Alarm** button, followed by **Quick Presets**.
