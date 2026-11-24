/// Central place to configure the backend base URL per build target.
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000/api
///   flutter build apk --dart-define=API_BASE_URL=https://api.nutricheck.app/api
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Android emulator loopback to host machine's localhost:5000.
    // Use your machine's LAN IP for a physical device, and your real
    // domain for production.
    defaultValue: 'http://localhost:5000/api',
  );

  static const Duration requestTimeout = Duration(seconds: 20);
}

class StorageKeys {
  StorageKeys._();
  static const accessToken = 'nutricheck_access_token';
  static const refreshToken = 'nutricheck_refresh_token';
  static const userProfile = 'nutricheck_user_profile';
}
