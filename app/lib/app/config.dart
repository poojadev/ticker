import 'dart:io';

/// Where the mock market server lives.
///
/// Override for a real device on your Wi-Fi:
///   flutter run --dart-define=API_HOST=192.168.1.20
class AppConfig {
  static const _hostOverride = String.fromEnvironment('API_HOST');
  static const port = int.fromEnvironment('API_PORT', defaultValue: 8080);

  /// Android emulators reach the host machine via 10.0.2.2.
  static String get host => _hostOverride.isNotEmpty
      ? _hostOverride
      : (Platform.isAndroid ? '10.0.2.2' : 'localhost');

  static String get httpBase => 'http://$host:$port';
  static Uri get streamUri => Uri.parse('ws://$host:$port/stream');
}
