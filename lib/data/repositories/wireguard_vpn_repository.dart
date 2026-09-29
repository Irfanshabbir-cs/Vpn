import 'package:wireguard_flutter/wireguard_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/server_model.dart';
import 'vpn_repository.dart';

class WireGuardVpnRepository implements VpnRepository {
  final WireGuardProfileStore _profiles;
  late final _wireGuard = WireGuardFlutter.instance;
  DateTime? _connectedAt;
  bool _initialized = false;

  WireGuardVpnRepository(this._profiles);

  @override
  Stream<VpnConnectionState> get stateStream => _wireGuard.vpnStageSnapshot.map((stage) {
        final state = switch (stage) {
          VpnStage.connecting || VpnStage.preparing || VpnStage.authenticating => VpnConnectionState.connecting,
          VpnStage.connected => VpnConnectionState.connected,
          VpnStage.disconnecting || VpnStage.exiting => VpnConnectionState.disconnecting,
          VpnStage.disconnected || VpnStage.noConnection || VpnStage.waitingConnection => VpnConnectionState.disconnected,
          VpnStage.denied => VpnConnectionState.error,
          VpnStage.reconnect => VpnConnectionState.connecting,
        };
        if (state == VpnConnectionState.connected) _connectedAt ??= DateTime.now();
        if (state == VpnConnectionState.disconnected) _connectedAt = null;
        return state;
      });

  @override
  Future<void> connect(ServerModel server, VpnProtocol protocol) async {
    if (!server.isWireGuardProfile) {
      throw StateError('Choose an imported WireGuard profile before connecting.');
    }
    if (protocol != VpnProtocol.automatic && protocol != VpnProtocol.wireGuard) {
      throw UnsupportedError('This profile uses WireGuard. Select the WireGuard protocol.');
    }
    final profile = await _profiles.read(server.id);
    if (!_initialized) {
      await _wireGuard.initialize(interfaceName: 'shieldvpn');
      _initialized = true;
    }
    await _wireGuard.startVpn(
      serverAddress: profile.endpoint,
      wgQuickConfig: profile.config,
      providerBundleIdentifier: 'com.yourcompany.vpn_app',
    );
  }

  @override
  Future<void> disconnect() => _wireGuard.stopVpn();

  @override
  Future<ConnectionStats> currentStats() async => ConnectionStats(
        duration: _connectedAt == null ? Duration.zero : DateTime.now().difference(_connectedAt!),
      );
}