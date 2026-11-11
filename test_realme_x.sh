# 1. Verify installed Clock packages on Realme X via ADB
adb shell pm list packages | grep -E "coloros.alarm|deskclock"

# 2. Test manual SET_ALARM intent for 7:30 AM with skip UI
adb shell am start -a android.intent.action.SET_ALARM \
    --ei android.intent.extra.alarm.HOUR 7 \
    --ei android.intent.extra.alarm.MINUTES 30 \
    --es android.intent.extra.alarm.MESSAGE "Test Wake Up" \
    --ez android.intent.extra.alarm.SKIP_UI true

# 3. Direct launcher for Realme / ColorOS Clock app
adb shell am start -n com.coloros.alarm/.AlarmClock

# 4. Check battery optimization status on Android 11 for the package
adb shell dumpsys deviceidle whitelist | grep com.example.realme_alarm_manager
