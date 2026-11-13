# Realme X Alarm Manager

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

1. **Actual Alarm Time** — directly embedded Flutter wheel picker (no bottom
   sheet): hour (1–12) and minute (00–59) wrap around continuously; AM/PM is a
   simple two-option wheel without wrapping.
2. **Relative time** — hour selector (0–12 h) and minute selector (0–60 m in
   5-minute steps), side by side with stepped sliders. The sliders use minimal
   padding so they extend across the card. Selecting 0 hours lets you schedule
   a chain in minutes only.
3. **Total alarms** — six rectangular selector tabs (1x–6x), defaulting to 1x.
4. **Alarm interval** — five rectangular selector tabs (2, 3, 5, 10, 15 m).
   The interval is disabled by default and becomes active only when 2x or more
   alarms are selected.
5. **Set Alarm** button, followed by **Quick Presets**.
6. **Quick Presets** — there are no built-in presets. In normal mode a preset
   is only selectable. Tap **Edit** to enter edit mode, where you can add
   presets, tap a preset to change its label/delay, or tap its **×** to delete
   it (with Undo). Tap **Done** to return to normal selection mode.

## Permissions and limits

- `SET_ALARM` lets the app hand a time of day to the system Clock app.
- The alarm is dispatched with `EXTRA_SKIP_UI=true` and without repeat days,
  so it is intended as a single-occurrence alarm.
- Some Realme/ColorOS builds may ignore parts of the intent or apply their own
  defaults. The app reports only whether the intent was accepted, not whether
  the Clock app actually stored the alarm.
