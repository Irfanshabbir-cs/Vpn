import 'vpn_repository.dart';
import 'vpn_repository_factory_stub.dart'
    if (dart.library.io) 'vpn_repository_factory_io.dart' as platform;

VpnRepository createVpnRepository(WireGuardProfileStore profiles) => platform.createVpnRepository(profiles);