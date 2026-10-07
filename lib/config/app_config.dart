abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://dashboard.yoko-sun.kz/api/v1',
  );

  static String get apiOrigin =>
      apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
}
