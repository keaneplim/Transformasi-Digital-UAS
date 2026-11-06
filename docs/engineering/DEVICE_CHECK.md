# DEVICE CHECK — test phones

Do this **before the coders write device-dependent code** (GPS, audio, notifications, pedometer). It takes about 30 minutes per phone. Record the results in the table at the bottom and commit it.

## 0. iPhone 14 — read this first

**Jelajah Taman is an Android app** (PRD §8.1: "Flutter (Dart), target Android"; PB01: "≥2 perangkat uji Android"). **An iPhone cannot install or run the APK.** iPhone-only team members can't test the app on their own phone.

What iPhone 14 has (Apple tech specs, support.apple.com/en-us/111850):
- GNSS: GPS, GLONASS, Galileo, QZSS, BeiDou. **Not** the "precision dual-frequency GPS" of the 14 Pro, so expect normal single-frequency accuracy under the canopy.
- Barometer (useful: better relative elevation than GPS altitude), compass, accelerometer, gyro.
- Built-in step counting (Motion coprocessor; Health app).

Options, in order of recommendation:

| Option | What it takes | Verdict |
|---|---|---|
| **A. Get ≥2 Android phones** (team members, family, borrowed) | Nothing new; matches the PRD | **Do this.** Two different brands if possible (one Samsung/Pixel-like, one Xiaomi/Oppo/Vivo-like) so the battery-killer risk is tested. |
| B. Also build for iOS | A **Mac with Xcode** (Flutter can't build iOS on Windows); a free Apple ID can install on your own iPhone but the install expires after 7 days; extra iOS work: background-location mode, `Info.plist` permission texts, a different notification/audio setup; every test case run twice | Don't, unless someone has a Mac **and** the team accepts the extra testing. It is not in the PRD scope; adding it is a Change Log item. |
| C. Use the iPhone for what it's good at | Nothing | **Yes, in addition to A:** survey GPX recording, photos, barometric elevation, reference readings, the stopwatch for ETA tests. |

**Decision needed today:** whose Android phones are the two test devices? If none exist in the team, borrowing two is now the most urgent blocker. Record the decision in PROGRESS.md.

---

## 1. Android test phone checklist

Do every step and fill in the table in §3.

### 1.1 Basics
- **Settings → About phone:** brand, model, Android version, free storage (need ≥1 GB).
- **Developer options:** tap *Build number* 7×, then enable **USB debugging**. Plug into a coder's laptop and run `flutter devices`; the phone must be listed.
- **Android 14+?** Fine, but note it: the manifest needs `FOREGROUND_SERVICE_LOCATION` (already planned).
- **Android 13+?** The notification permission is asked at runtime (planned in onboarding).

### 1.2 GPS quality (needed for F01/F02)
- Install **GPSTest** (Sean Barbeau, Play Store). Outdoors with open sky, wait 1 min, then note:
  - time to first fix,
  - horizontal accuracy (m),
  - satellites used,
  - whether it shows **L5/E5** signals (dual-frequency; better under trees).
- Repeat under trees if you're near any. Expect accuracy to get worse; that's normal, just record it.

### 1.3 Step counter sensor (needed for F08, TC-12)
- Install a sensor viewer app (e.g., "Sensor Test" / "Sensors Multitool") and look for **"Step Counter"** (type `TYPE_STEP_COUNTER`). It must be a hardware sensor, not just an accelerometer.
- Or with USB debugging: `adb shell dumpsys sensorservice | grep -i step`
- **No step counter → this phone can't pass TC-12.** It can still test everything else.
- Quick sanity test: walk 50 counted steps with the sensor app open; note the counted value.

### 1.4 Offline Indonesian TTS voice (needed for F04)
- **Settings → System → Languages & input → Text-to-speech output** (wording varies per brand).
- Preferred engine: **Speech Services by Google**. Open its settings → *Install voice data* → **Indonesian (Indonesia)** → download.
- Test: turn on **airplane mode**, go back to the TTS screen, set language Indonesian, tap *Play*/*Listen to an example*. It must speak Indonesian with no internet.
- If the engine is the brand's own (Samsung TTS, etc.), install Google's engine anyway and set it as preferred.

### 1.5 Battery killer (needed for F01 screen-off tracking, TC-06)
Look up the brand on **dontkillmyapp.com** and note its score. Prepare these settings (they'll be applied to the app once it's installed):

| Brand | Settings to change for the app |
|---|---|
| All | Settings → Apps → *app* → Battery → **Unrestricted** (or "Don't optimize") |
| Xiaomi / Redmi / POCO (MIUI/HyperOS) | Autostart **on**; Battery saver → **No restrictions**; lock the app in Recents |
| Oppo / Realme / OnePlus (ColorOS) | Allow background activity; Allow auto launch; disable "Optimize battery use" |
| Vivo (Funtouch/OriginOS) | High background power consumption **allow**; Autostart on |
| Samsung (One UI) | Remove from "Sleeping/Deep sleeping apps"; add to **"Never sleeping apps"** |
| Huawei/Honor | App launch → Manage manually: all three toggles on |

**Real test (once the location module exists, S3):** start a session, lock the screen, put the phone in a pocket for 15 min while walking, then check the location log has fixes every ~3 s with no gap. Record the result per phone. This is the test that decides whether TC-06 can pass on that phone.

### 1.6 Audio & notifications
- Earphones available (wired or Bluetooth) and the play/pause button works with any music app on the lock screen.
- Notifications show on the lock screen (Settings → Notifications → Lock screen → show all content).

---

## 2. iPhone 14 checklist (for survey use, option C)

- iOS version noted.
- **Settings → Privacy & Security → Location Services:** on; the GPX app set to *While Using* + **Precise Location on**.
- **Settings → Privacy & Security → Motion & Fitness → Fitness Tracking:** on (if you use step data for reference).
- GPX recorder installed and tested once around the block (e.g., OsmAnd, or Open GPX Tracker). Check that exported `.gpx` files include timestamps and elevation.
- An app that shows **horizontal accuracy in metres** for point readings (iOS doesn't show it natively; OsmAnd and most "GPS status" apps do).
- Low Power Mode **off** during recording (it reduces location updates). Bring a power bank.

---

## 3. Results (fill in and commit)

| Field | Phone 1 | Phone 2 | Phone 3 (spare) |
|---|---|---|---|
| Owner | | | |
| Brand / model | | | |
| Android version | | | |
| Free storage | | | |
| `flutter devices` sees it | ☐ | ☐ | ☐ |
| GPS: first fix / accuracy open sky / L5 | | | |
| Step counter sensor present | ☐ | ☐ | ☐ |
| 50-step sanity count | | | |
| Offline Indonesian TTS works in airplane mode | ☐ | ☐ | ☐ |
| dontkillmyapp score | | | |
| Battery settings applied | ☐ | ☐ | ☐ |
| Screen-off 15 min test (S3): gaps? | | | |
| Earphone button controls lock-screen media | ☐ | ☐ | ☐ |

**Minimum to proceed:** at least 2 Android phones with a step counter and offline Indonesian TTS, and at least one of them from a "bad" battery brand so the risk is tested early, not at the S5 field test.
