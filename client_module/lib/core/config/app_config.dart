class AppConfig {
  /// Android emulator: 10.0.2.2 -> host machine localhost
  /// Windows app / Web: use localhost
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
