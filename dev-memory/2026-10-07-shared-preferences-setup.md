# SharedPreferences setup

- Problem: the cart persistence code imported `shared_preferences`, but the local Flutter package configuration had not been refreshed.
- Fix: ran `flutter pub get`, which installed the package and completed its transitive lock-file entries.
- Replaced the typed `Future.catchError` chain with `async`/`try-catch`, so plugin or storage failures can never become an unhandled exception during cart interaction.
- Removed an unused Cart variable reported by `flutter analyze`.
