import 'server_model.dart';

class WireGuardProfile {
  final String id;
  final String name;
  final String config;
  final String endpoint;

  const WireGuardProfile({
    required this.id,
    required this.name,
    required this.config,
    required this.endpoint,
  });

  factory WireGuardProfile.parse({
    required String id,
    required String name,
    required String config,
  }) {
    final sections = <String, Map<String, String>>{};
    String? section;
    for (final rawLine in config.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line.substring(1, line.length - 1).trim();
        sections.putIfAbsent(section, () => {});
        continue;
      }
      final separator = line.indexOf('=');
      if (section == null || separator < 1) continue;
      sections[section]![line.substring(0, separator).trim()] = line.substring(separator + 1).trim();
    }

    final interface = sections['Interface'];
    final peer = sections['Peer'];
    if (interface == null || peer == null ||
        _isMissing(interface['PrivateKey']) || _isMissing(interface['Address']) ||
        _isMissing(peer['PublicKey']) || _isMissing(peer['AllowedIPs'])) {
      throw const FormatException('Config is missing required WireGuard interface or peer fields.');
    }

    final endpoint = peer['Endpoint'];
    if (_isMissing(endpoint) || !_hasValidEndpoint(endpoint!)) {
      throw const FormatException('Config must contain a valid Peer Endpoint host and port.');
    }

    return WireGuardProfile(id: id, name: name, config: config, endpoint: endpoint);
  }

  ServerModel toServerModel() {
    final host = endpoint.startsWith('[') ? endpoint.substring(1, endpoint.indexOf(']')) : endpoint.split(':').first;
    return ServerModel(
      id: id,
      countryCode: 'WG',
      countryName: name,
      city: host,
      latitude: 0,
      longitude: 0,
      latencyMs: 0,
      loadPercent: 0,
      currentUsers: 0,
      isWireGuardProfile: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'config': config,
        'endpoint': endpoint,
      };

  factory WireGuardProfile.fromJson(Map<String, dynamic> json) => WireGuardProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        config: json['config'] as String,
        endpoint: json['endpoint'] as String,
      );

  static bool _isMissing(String? value) => value == null || value.trim().isEmpty;

  static bool _hasValidEndpoint(String endpoint) {
    String? port;
    if (endpoint.startsWith('[')) {
      final closeBracket = endpoint.indexOf(']');
      if (closeBracket <= 1 || closeBracket + 2 >= endpoint.length || endpoint[closeBracket + 1] != ':') {
        return false;
      }
      port = endpoint.substring(closeBracket + 2);
    } else {
      final separator = endpoint.lastIndexOf(':');
      if (separator <= 0) return false;
      port = endpoint.substring(separator + 1);
    }
    final number = int.tryParse(port);
    return number != null && number > 0 && number <= 65535;
  }
}