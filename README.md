# YokoMarket

YokoMarket is a Flutter shopping application for baby-care and household
products. Its interface uses a clean purple-and-yellow visual identity inspired
by the design reference stored in `design-referrences/main-app.jpg`.

## Features

- Russian-language storefront
- Product search and category browsing
- Promotional banners and featured brands
- Product details and favorites
- Shopping cart with quantity controls
- Customer profile screen
- Material 3 interface with responsive layouts

## Technology

- Flutter and Dart
- Provider for application state
- Material 3 components

## Getting started

Install Flutter, connect an Android device or start an emulator, and run:

```bash
flutter pub get
flutter run
```

## Quality checks

```bash
flutter analyze
flutter test
flutter build apk --debug
```

The generated debug APK is written to
`build/app/outputs/flutter-apk/app-debug.apk`.

## Project structure

```text
lib/
  models/       Data models
  providers/    Application state
  screens/      Storefront and account screens
test/           Widget tests
design-referrences/  Visual design reference
dev-memory/          Short engineering change records
```
