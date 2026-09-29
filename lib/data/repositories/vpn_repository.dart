import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../models/server_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/wireguard_profile.dart';

class ConnectionStats {
  final String? ip;
  final int? pingMs;
  final double? uploadMbps;
  final double? downloadMbps;
  final Duration duration;

  const ConnectionStats({
    this.ip,
    this.pingMs,
    this.uploadMbps,
    this.downloadMbps,
    required this.duration,
  });
}

abstract class VpnRepository {
  Stream<VpnConnectionState> get stateStream;
  Future<void> connect(ServerModel server, VpnProtocol protocol);
  Future<void> disconnect();
  Future<ConnectionStats> currentStats();
}

class WireGuardProfileStore {
  static const _prefix = 'wireguard_profile_';
  final FlutterSecureStorage _storage;

  const WireGuardProfileStore({FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage;

  Future<List<WireGuardProfile>> readAll() async {
    final entries = await _storage.readAll();
    return entries.entries
        .where((entry) => entry.key.startsWith(_prefix))
        .map((entry) => WireGuardProfile.fromJson(
              Map<String, dynamic>.from(jsonDecode(entry.value) as Map),
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<WireGuardProfile> read(String id) async {
    final value = await _storage.read(key: '$_prefix$id');
    if (value == null) throw StateError('The selected WireGuard profile is no longer available.');
    return WireGuardProfile.fromJson(Map<String, dynamic>.from(jsonDecode(value) as Map));
  }

  Future<WireGuardProfile> importConfig({required String name, required String config}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final profile = WireGuardProfile.parse(id: id, name: name, config: config);
    await _storage.write(key: '$_prefix$id', value: jsonEncode(profile.toJson()));
    return profile;
  }

  Future<void> delete(String id) => _storage.delete(key: '$_prefix$id');
}

class UnsupportedVpnRepository implements VpnRepository {
  @override
  Stream<VpnConnectionState> get stateStream => const Stream.empty();

  @override
  Future<void> connect(ServerModel server, VpnProtocol protocol) async {
    throw UnsupportedError('A real WireGuard tunnel is currently configured for Android only.');
  }

  @override
  Future<void> disconnect() async {
    throw UnsupportedError('A real WireGuard tunnel is currently configured for Android only.');
  }

  @override
  Future<ConnectionStats> currentStats() async => const ConnectionStats(duration: Duration.zero);
}
