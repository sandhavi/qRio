# QRio – Scan. Connect. Chat.

QRio lets two people instantly connect and chat by simply sharing and scanning a QR code. Chats are fast, private, and temporary, with history stored locally on-device.

- Multi-platform: Android, iOS, Web, Windows, macOS, Linux
- Tech: Flutter (Dart), Firebase Firestore (real-time chat), local-only history

## Features

- Generate and scan QR codes to start a session
- Real-time messaging via Firestore
- Typing indicators and session lifecycle
- Local-only chat history for privacy

## Project Structure

- App config and deps: [pubspec.yaml](pubspec.yaml)
- Web entry: [web/index.html](web/index.html)
- Platform scaffolding:
  - Windows: [windows/CMakeLists.txt](windows/CMakeLists.txt), [windows/flutter/CMakeLists.txt](windows/flutter/CMakeLists.txt), [windows/runner/CMakeLists.txt](windows/runner/CMakeLists.txt)
  - Linux: [linux/CMakeLists.txt](linux/CMakeLists.txt), [linux/flutter/CMakeLists.txt](linux/flutter/CMakeLists.txt), [linux/runner/CMakeLists.txt](linux/runner/CMakeLists.txt)
  - iOS/macOS CocoaPods: [ios/Podfile](ios/Podfile), [macos/Podfile](macos/Podfile)
- Firestore rules guidance: [FIRESTORE_SETUP.md](FIRESTORE_SETUP.md)

## Prerequisites

- Flutter SDK (stable). Verify with:
  - Windows PowerShell:
    ```powershell
    flutter doctor -v
    ```
- Platform toolchains:
  - Android: Android Studio + SDK/Emulator
  - iOS/macOS: Xcode + CocoaPods
  - Windows: Visual Studio with “Desktop development with C++” (CMake 3.14+)
  - Linux: GTK3, CMake 3.13+, build-essential, pkg-config
  - Web: Chrome (or any supported browser)

## Setup

1. Install dependencies:
   ```powershell
   flutter pub get
   ```
2. Environment variables
   - This app reads a .env file declared in [pubspec.yaml](pubspec.yaml) under flutter/assets.
   - Create a .env file at the project root:
     ```dotenv
     # Example (adjust to your Firebase project and app needs)
     FIREBASE_API_KEY=YOUR_API_KEY
     FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
     FIREBASE_APP_ID=YOUR_APP_ID
     FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID
     FIREBASE_AUTH_DOMAIN=YOUR_PROJECT_ID.firebaseapp.com
     FIREBASE_STORAGE_BUCKET=YOUR_PROJECT_ID.appspot.com
     FIREBASE_MEASUREMENT_ID=G-XXXXXXXXXX
     ```
   - Do not commit secrets.
3. Firebase/Firestore rules
   - If you see PERMISSION_DENIED in console, update rules per [FIRESTORE_SETUP.md](FIRESTORE_SETUP.md).
4. (Optional, native Firebase SDKs) Add platform config:
   - Android: android/app/google-services.json
   - iOS: ios/Runner/GoogleService-Info.plist
   - macOS: macos/Runner/GoogleService-Info.plist
   - Web: ensure Firebase config is initialized before run (e.g., in web/index.html or a config bootstrap)

## Run

- Android:
  ```powershell
  flutter run -d android
  ```
- iOS (on macOS):
  ```bash
  flutter run -d ios
  ```
- Web (Chrome):
  ```powershell
  flutter run -d chrome
  ```
- Windows:
  ```powershell
  flutter run -d windows
  ```
- macOS / Linux:
  ```bash
  flutter run -d macos
  flutter run -d linux
  ```

## Build

- Android APK/AppBundle:
  ```powershell
  flutter build apk
  flutter build appbundle
  ```
- iOS (archive via Xcode after):
  ```bash
  flutter build ipa
  ```
- Web:
  ```powershell
  flutter build web --release
  ```
- Windows / macOS / Linux:
  ```powershell
  flutter build windows
  ```
  ```bash
  flutter build macos
  flutter build linux
  ```

## Linting, Format, Tests

- Analyze:
  ```powershell
  flutter analyze
  ```
- Format:
  ```powershell
  dart format .
  ```
- Tests:
  ```powershell
  flutter test
  ```

## Firestore Rules

Apply/adjust rules per [FIRESTORE_SETUP.md](FIRESTORE_SETUP.md). This enables:
- Scoped user document access
- Session documents with messages and typing subcollections
- Authenticated read/write where appropriate

## Troubleshooting

- Firestore permission errors: update rules via [FIRESTORE_SETUP.md](FIRESTORE_SETUP.md).
- iOS/macOS CocoaPods:
  ```bash
  cd ios && pod install && cd ..
  cd macos && pod install && cd ..
  ```
- Windows CMake/Build errors: ensure Visual Studio C++ workload is installed and matches CMake requirements in [windows/CMakeLists.txt](windows/CMakeLists.txt) and [windows/flutter/CMakeLists.txt](windows/flutter/CMakeLists.txt).
- Stale/cached artifacts:
  ```powershell
  flutter clean && flutter pub get
  ```

## Privacy

- Chats are intended to be temporary with local-only history. Review code and adjust retention as needed for your use case.

