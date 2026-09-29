import 'dart:io';
import 'vpn_repository.dart';
import 'wireguard_vpn_repository.dart';

VpnRepository createVpnRepository(WireGuardProfileStore profiles) =>
    Platform.isAndroid ? WireGuardVpnRepository(profiles) : UnsupportedVpnRepository();