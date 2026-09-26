# Build and Test

## Backend

```bash
npm install
npm run test:all
npm start
```

Before release, verify `/api/health`, authentication, bootstrap, one read, one write, offline queue recovery, export, and admin authorization.

## Android

Use Flutter 3.38+ and JDK 17:

```bash
cd mobile
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## iOS

Requires macOS, Xcode 15+, Flutter, CocoaPods, Firebase iOS configuration, signing certificates, and `REVERSED_CLIENT_ID` for Google Sign-In.

```bash
cd mobile
flutter create --platforms=ios .
cd ios && pod install
cd ..
flutter run -d iPhone
```

## Smoke test

Open signup/login, profile analysis, nutrition, workout, FAQ, community, account, offline writes, notifications, and account export. Background and resume the app and verify that no duplicate polling or cross-account cache appears.
