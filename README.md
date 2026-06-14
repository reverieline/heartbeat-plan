# Heartbeat Plan

A Bluetooth Low Energy (BLE) heart rate training app for Android. Connect any GATT-compatible HR monitor (chest strap, fitness watch), run structured multi-stage training plans, and get real-time audio coaching based on your heart rate zone.

## Features

### Training Plans

- Create and edit multi-stage plans with named stages and configurable durations
- Per-stage heart rate targets: Free, Minimum, Maximum, or Range (min–max BPM)

### Live Training Session

- Real-time BPM display updated continuously from your HR monitor
- Automatic stage progression with timer and audio announcements
- Tone cues: ascending tones (go faster) and descending tones (slow down)
- Text-to-speech stage name and target zone announcements
- Beep cooldown (default 20 s) prevents excessive cuing
- Pause and resume support
- Screen kept on during active sessions

### BLE Device Management

- Scans for Heart Rate Service devices (UUID 0x180D)
- Displays device name, address, and HR capability
- Saves last-used device and auto-reconnects on startup and after signal drops
- Reconnect retry with backoff (5 s initial, 10 s subsequent)
- Battery level reading and display

### Session Analytics

- Detailed session log: timestamped BPM samples, stage transitions, connect/disconnect events, battery readings, and audio cues
- HR zone breakdown using the Karvonen formula (5 zones)
- Calorie estimate using sex-specific Keytel regression formula
- Post-session summary screen with zone time chart
- History screen with swipeable log viewer and bulk-delete option

### User Profile

- Age, weight, sex, resting HR, max HR
- Used for Karvonen zone calculation and calorie estimation
- Persisted locally; editable in Settings

### Audio & Notifications

- TTS voice, speed, and pitch configurable in Settings
- Foreground service notification during training: shows stage name, BPM, and elapsed time
- Lock-screen controls: Stop, Pause/Resume
- Android MediaSession integration for system playback controls
- Serial audio queue keeps TTS announcements and beeps ordered correctly_

## Requirements

| Requirement        | Version          |
| ------------------ | ---------------- |
| Flutter SDK        | 3.44 or later    |
| Dart SDK           | 3.12 or later    |
| Android min SDK    | 21 (Android 5.0) |
| Android target SDK | 35               |
| Java               | 17               |

A physical Android device with Bluetooth is required for full functionality. The BLE scanner cannot run on an emulator.

## Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/reverieline/heartbeat-plan.git
cd heartbeat-plan

# 2. Install dependencies
flutter pub get

# 3. Run code generation (freezed + json_serializable)
dart run build_runner build --delete-conflicting-outputs

# 4. Connect an Android device (USB debugging on), then run
flutter run

# 5. Build release APK
flutter build apk --release
```

The built APK is at `build/app/outputs/flutter-apk/app-release.apk`.

## Permissions

The app requests the following Android permissions at runtime:

| Permission                                                   | Purpose                                          |
| ------------------------------------------------------------ | ------------------------------------------------ |
| `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (API 31+)             | BLE device discovery and connection              |
| `BLUETOOTH` / `BLUETOOTH_ADMIN` (API < 31)                   | Legacy BLE access                                |
| `ACCESS_FINE_LOCATION`                                       | Required by Android for BLE scanning on API < 31 |
| `POST_NOTIFICATIONS` (API 33+)                               | Foreground training notification                 |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_CONNECTED_DEVICE` | Background training session                      |
| `WAKE_LOCK`                                                  | Keep screen on during workouts                   |

## Project Structure

```
root/
└── lib/
    ├── main.dart                          # App entry point, providers, theme
    ├── models/
    │   ├── hr_zone.dart                   # HR zones, training summary
    │   ├── session_log.dart               # Session log entry types
    │   ├── training_plan.dart             # TrainingPlan, TrainingStage, TargetMode
    │   └── user_profile.dart              # UserProfile biometrics
    ├── services/
    │   ├── audio_service.dart             # TTS + tone cues, serial audio queue
    │   ├── ble_service.dart               # BLE scanning, connection, HR parsing
    │   ├── config_service.dart            # SharedPreferences persistence
    │   ├── foreground_notification_service.dart  # Notification + lock-screen controls
    │   ├── log_service.dart               # Session log file I/O
    │   ├── media_session_service.dart     # Android MediaSession bridge
    │   ├── plan_service.dart              # Plan file management
    │   └── training_service.dart          # Session timer, stage progression, cuing logic
    ├── providers/
    │   ├── app_providers.dart             # Config, plan list, selection state
    │   └── ble_provider.dart              # BLE connection state
    └── screens/
        ├── home_screen.dart               # Dashboard: device, HR, plan selector, start
        ├── device_scanner_screen.dart     # BLE device discovery list
        ├── active_session_screen.dart     # Live training view
        ├── summary_screen.dart            # Post-session analytics and chart
        ├── history_screen.dart            # Past session log viewer
        ├── plan_list_screen.dart          # Plan management
        ├── plan_editor_screen.dart        # Create / edit a training plan
        └── settings_screen.dart           # User profile, TTS, audio settings
```

## Key Dependencies

| Package                         | Purpose                                       |
| ------------------------------- | --------------------------------------------- |
| `flutter_blue_plus`             | BLE device scanning and GATT communication    |
| `flutter_tts`                   | Text-to-speech stage announcements            |
| `audioplayers`                  | Tone generation for biofeedback beeps         |
| `flutter_riverpod`              | Reactive state management                     |
| `flutter_foreground_task`       | Foreground service + lock-screen notification |
| `fl_chart`                      | HR zone chart in post-session summary         |
| `permission_handler`            | Runtime permission requests                   |
| `shared_preferences`            | User profile and settings storage             |
| `path_provider`                 | App documents directory for plans and logs    |
| `wakelock_plus`                 | Keep screen on during active sessions         |
| `freezed` + `json_serializable` | Immutable data models with JSON serialization |

## BLE Protocol

The app communicates using standard GATT profiles:

| GATT UUID      | Purpose                               |
| -------------- | ------------------------------------- |
| `0000180D-...` | Heart Rate Service                    |
| `00002A37-...` | Heart Rate Measurement characteristic |
| `00002A19-...` | Battery Level characteristic          |

Any BLE heart rate monitor that implements the standard Heart Rate Profile (HRP) is compatible — Polar, Garmin, Wahoo, Magene, and most chest straps.

# 
