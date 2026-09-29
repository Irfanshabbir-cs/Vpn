import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_app/data/models/wireguard_profile.dart';

void main() {
  const config = '''[Interface]
PrivateKey = private-key
Address = 10.0.0.2/32

[Peer]
PublicKey = public-key
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = vpn.example.com:51820
''';

  test('parses a valid WireGuard profile and endpoint', () {
    final profile = WireGuardProfile.parse(id: 'profile-1', name: 'Test VPN', config: config);

    expect(profile.endpoint, 'vpn.example.com:51820');
    expect(profile.toServerModel().city, 'vpn.example.com');
    expect(profile.toServerModel().isWireGuardProfile, isTrue);
  });

  test('rejects a profile without a valid endpoint', () {
    expect(
      () => WireGuardProfile.parse(
        id: 'profile-2',
        name: 'Invalid VPN',
        config: config.replaceAll('Endpoint = vpn.example.com:51820', 'Endpoint = vpn.example.com'),
      ),
      throwsFormatException,
    );
  });
}