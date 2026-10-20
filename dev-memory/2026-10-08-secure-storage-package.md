# Secure storage package setup

- Problem: `auth_service.dart` imported `flutter_secure_storage`, but the local package configuration had not been refreshed after pulling authentication changes.
- Fix: ran `flutter pub get`, installing the secure-storage package and completing its transitive entries in `pubspec.lock`.
- Restored the safe async cart-persistence error handling that was lost during branch synchronization and removed an unused Cart variable.
- A native plugin was added, so the running app must be stopped and started again instead of using hot restart.
- Updated the image widget fixture to use an existing local asset, preventing `pumpAndSettle` from waiting on a deliberately unreachable test URL.
- Made `AuthProvider` injectable at the app root so widget tests can use a non-native fake instead of waiting on the secure-storage MethodChannel.
