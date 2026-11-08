abstract final class AppConfig {
  static const uiPreview = bool.fromEnvironment('UI_PREVIEW');
  static const mockLoyalty = bool.fromEnvironment('MOCK_LOYALTY', defaultValue: true);
  static const mockStoreSettings = bool.fromEnvironment('MOCK_STORE_SETTINGS', defaultValue: true);
  static const mockAccountRecovery = bool.fromEnvironment('MOCK_RECOVERY', defaultValue: true);

  /// Enable fast login UI (PIN + biometrics).
  /// Enabled by default. To disable for a hotfix build, pass:
  ///   --dart-define=FAST_LOGIN_ENABLED=false
  static const fastLoginEnabled = bool.fromEnvironment(
    'FAST_LOGIN_ENABLED',
    defaultValue: true,
  );

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

  // The public-facing domain used in referral invite links and deep links.
  // The same Django backend serves both dashboard.yoko-sun.kz (admin) and
  // app.yoko-sun.kz (mobile API + invite links). Invite links use the
  // mobile-facing domain so Android App Links / iOS Universal Links
  // verification is against app.yoko-sun.kz, not the admin dashboard.
  static const inviteDomain = String.fromEnvironment(
    'INVITE_DOMAIN',
    defaultValue: 'https://app.yoko-sun.kz',
  );
}
