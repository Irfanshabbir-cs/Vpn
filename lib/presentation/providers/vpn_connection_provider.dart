import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/server_model.dart';
import '../../data/repositories/vpn_repository.dart';
import '../../data/repositories/vpn_repository_factory.dart';

final wireGuardProfileStoreProvider = Provider<WireGuardProfileStore>((ref) => const WireGuardProfileStore());

final vpnRepositoryProvider = Provider<VpnRepository>((ref) {
  return createVpnRepository(ref.watch(wireGuardProfileStoreProvider));
});

final selectedServerProvider = StateProvider<ServerModel?>((ref) => null);
final selectedProtocolProvider = StateProvider<VpnProtocol>((ref) => VpnProtocol.automatic);

final vpnConnectionStateProvider = StreamProvider<VpnConnectionState>((ref) {
  return ref.watch(vpnRepositoryProvider).stateStream;
});

final connectionStatsProvider = FutureProvider.autoDispose<ConnectionStats>((ref) async {
  // Refresh once per second while connected so Home shows live speed/ping.
  final connState = ref.watch(vpnConnectionStateProvider).valueOrNull;
  if (connState == VpnConnectionState.connected) {
    final timer = Timer(const Duration(seconds: 1), () => ref.invalidateSelf());
    ref.onDispose(timer.cancel);
  }
  return ref.watch(vpnRepositoryProvider).currentStats();
});

class VpnConnectionController {
  final Ref ref;
  VpnConnectionController(this.ref);

  Future<void> toggleConnection() async {
    final repo = ref.read(vpnRepositoryProvider);
    final state = ref.read(vpnConnectionStateProvider).valueOrNull ?? VpnConnectionState.disconnected;
    final server = ref.read(selectedServerProvider);
    final protocol = ref.read(selectedProtocolProvider);

    if (state == VpnConnectionState.connected) {
      await repo.disconnect();
    } else if ((state == VpnConnectionState.disconnected || state == VpnConnectionState.error) && server != null) {
      await repo.connect(server, protocol);
    }
  }
}

final vpnConnectionControllerProvider = Provider((ref) => VpnConnectionController(ref));
