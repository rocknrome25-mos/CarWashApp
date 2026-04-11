class AppConfig {
  static const String defaultBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://95.174.95.1:3000',
  );
}