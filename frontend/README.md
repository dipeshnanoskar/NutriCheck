# NutriCheck Flutter App

Flutter rewrite of the original React/Figma-Make NutriCheck prototype. All screens
talk to the real Flask + MongoDB backend in `../backend` — there is no mock data
anywhere in this app.

## Screens

Splash → Login/Register (profile setup) → Home → live camera Barcode Scan →
Product Detail → Analyzing → Result, with a parallel OCR flow (Not Found →
OCR Camera → OCR Review → Analyzing → Result) plus Scan History and Profile tabs,
matching the original design's screen list one-for-one.

## 1. Prerequisites

- Flutter SDK 3.22+ (`flutter --version`)
- The backend running and reachable (see `../backend/README.md`)
- A physical device or emulator with a camera for barcode/OCR scanning

## 2. Generate native platform folders

This package ships only the `lib/` (Dart) source and `pubspec.yaml`. Generate the
Android/iOS/etc. platform projects once with:

```bash
cd frontend
flutter create --platforms=android,ios .
```

This will not overwrite `lib/main.dart` or `pubspec.yaml`.

## 3. Add camera permissions

**Android** — `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS** — `ios/Runner/Info.plist`, inside the top-level `<dict>`:
```xml
<key>NSCameraUsageDescription</key>
<string>NutriCheck needs camera access to scan barcodes and ingredient labels.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>NutriCheck needs photo library access to select a label photo.</string>
```

## 4. Install dependencies

```bash
flutter pub get
```

## 5. Point the app at your backend

The API base URL is compiled in via `--dart-define` (see `lib/core/constants.dart`):

```bash
# Android emulator (backend running on your host machine):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api

# iOS simulator:
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api

# Physical device (replace with your machine's LAN IP):
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5000/api

# Production build:
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api
flutter build ios --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

## Project structure

```
lib/
  core/            # theme, API client, constants
  models/          # Product, AnalysisResult, HistoryItem, UserProfile
  services/        # auth/product/analysis/history HTTP services
  providers/       # ChangeNotifier state (auth, scan flow, history)
  screens/         # one file per screen, matching the original design
    auth/
  widgets/         # shared UI pieces (status badge, bottom nav, cards)
```

## Key packages

- `mobile_scanner` — real camera-based EAN/UPC barcode detection (ML Kit)
- `image_picker` — camera/gallery capture for the OCR ingredient-label flow
- `flutter_secure_storage` — JWT access/refresh token storage
- `provider` — app state management
