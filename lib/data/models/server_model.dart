enum ServerCategory { standard, streaming, gaming, p2p, obfuscated, doubleVpn, dedicatedIp }

class ServerModel {
  final String id;
  final String countryCode; // ISO 3166-1 alpha-2, used for flag rendering
  final String countryName;
  final String city;
  final double latitude;
  final double longitude;
  final int latencyMs;
  final double loadPercent; // 0-100
  final int currentUsers;
  final List<ServerCategory> categories;
  final bool isPremium;
  final bool isWireGuardProfile;

  const ServerModel({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.latencyMs,
    required this.loadPercent,
    required this.currentUsers,
    this.categories = const [ServerCategory.standard],
    this.isPremium = false,
    this.isWireGuardProfile = false,
  });

  factory ServerModel.fromJson(Map<String, dynamic> json) => ServerModel(
        id: json['id'] as String,
        countryCode: json['country_code'] as String,
        countryName: json['country_name'] as String,
        city: json['city'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        latencyMs: json['latency_ms'] as int,
        loadPercent: (json['load_percent'] as num).toDouble(),
        currentUsers: json['current_users'] as int,
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((c) => ServerCategory.values.firstWhere((e) => e.name == c,
                orElse: () => ServerCategory.standard))
            .toList(),
        isPremium: json['is_premium'] as bool? ?? false,
        isWireGuardProfile: json['is_wireguard_profile'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'country_code': countryCode,
        'country_name': countryName,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'latency_ms': latencyMs,
        'load_percent': loadPercent,
        'current_users': currentUsers,
        'categories': categories.map((c) => c.name).toList(),
        'is_premium': isPremium,
        'is_wireguard_profile': isWireGuardProfile,
      };
}
