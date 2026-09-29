/// Centralized constants. Swap [baseApiUrl] via --dart-define per environment.
class AppConstants {
  AppConstants._();

  static const String appName = 'ShieldVPN';

  static const String baseApiUrl = String.fromEnvironment(
    'BASE_API_URL',
    defaultValue: 'http://localhost:8080/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Hive box names
  static const String settingsBox = 'settings_box';
  static const String serversCacheBox = 'servers_cache_box';

  // Secure storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';

  // Riverpod/SharedPreferences keys
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyThemeMode = 'theme_mode';
}

enum VpnProtocol { wireGuard, openVpnUdp, openVpnTcp, ikeV2, automatic }

extension VpnProtocolLabel on VpnProtocol {
  String get label {
    switch (this) {
      case VpnProtocol.wireGuard:
        return 'WireGuard';
      case VpnProtocol.openVpnUdp:
        return 'OpenVPN (UDP)';
      case VpnProtocol.openVpnTcp:
        return 'OpenVPN (TCP)';
      case VpnProtocol.ikeV2:
        return 'IKEv2';
      case VpnProtocol.automatic:
        return 'Automatic';
    }
  }
}

enum VpnConnectionState { disconnected, connecting, connected, disconnecting, error }
