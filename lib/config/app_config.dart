abstract final class AppConfig {
  // Override at build time with --dart-define=API_BASE=<url>
  // Android emulator → local backend:  --dart-define=API_BASE=http://10.0.2.2:8010/api/v1
  // iOS Simulator   → local backend:  --dart-define=API_BASE=http://127.0.0.1:8010/api/v1
  // Real device on LAN:               --dart-define=API_BASE=http://<LAN_IP>:8010/api/v1
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://dashboard.yoko-sun.kz/api/v1',
  );

  static String get apiOrigin =>
      apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
}
