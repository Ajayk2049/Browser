/// Application configuration for the standalone browser & download manager.
class Env {
  Env._();

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Gecko Browser',
  );

  /// Maximum concurrent download connections (1DM+ style)
  static const int maxDownloadThreads = int.fromEnvironment(
    'MAX_DOWNLOAD_THREADS',
    defaultValue: 8,
  );

  static const int connectTimeoutMs = int.fromEnvironment(
    'CONNECT_TIMEOUT_MS',
    defaultValue: 15000,
  );

  static const int receiveTimeoutMs = int.fromEnvironment(
    'RECEIVE_TIMEOUT_MS',
    defaultValue: 30000,
  );

  static const bool enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: true,
  );
}
