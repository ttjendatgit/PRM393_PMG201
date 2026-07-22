/// Central API configuration.
///
/// To switch base URLs without recompiling:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5048
class ApiConfig {
  ApiConfig._();

  /// Windows local development — used by default.
  static const String baseUrlWindows = 'http://localhost:5048';

  /// Android emulator — 10.0.2.2 routes to the host machine's localhost.
  static const String baseUrlAndroid = 'http://10.0.2.2:5048';

  /// Active base URL. Override at build time with --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: baseUrlWindows,
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 120);
  static const Duration sendTimeout = Duration(seconds: 120);
}
