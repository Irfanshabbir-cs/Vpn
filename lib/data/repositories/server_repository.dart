import 'dart:math';
import '../models/server_model.dart';

abstract class ServerRepository {
  Future<List<ServerModel>> fetchServers();
  Future<ServerModel> fetchFastestServer();
}

/// Generates a realistic, varied mock server list so Server List / Map /
/// Home screens are fully demoable before the real `/servers` endpoint
/// (see docs/BACKEND_GUIDE.md) exists.
class MockServerRepository implements ServerRepository {
  static final List<Map<String, dynamic>> _seed = [
    {'code': 'US', 'name': 'United States', 'city': 'New York', 'lat': 40.71, 'lng': -74.00},
    {'code': 'US', 'name': 'United States', 'city': 'Los Angeles', 'lat': 34.05, 'lng': -118.24},
    {'code': 'GB', 'name': 'United Kingdom', 'city': 'London', 'lat': 51.51, 'lng': -0.13},
    {'code': 'DE', 'name': 'Germany', 'city': 'Frankfurt', 'lat': 50.11, 'lng': 8.68},
    {'code': 'FR', 'name': 'France', 'city': 'Paris', 'lat': 48.86, 'lng': 2.35},
    {'code': 'JP', 'name': 'Japan', 'city': 'Tokyo', 'lat': 35.68, 'lng': 139.69},
    {'code': 'SG', 'name': 'Singapore', 'city': 'Singapore', 'lat': 1.35, 'lng': 103.82},
    {'code': 'AU', 'name': 'Australia', 'city': 'Sydney', 'lat': -33.87, 'lng': 151.21},
    {'code': 'CA', 'name': 'Canada', 'city': 'Toronto', 'lat': 43.65, 'lng': -79.38},
    {'code': 'NL', 'name': 'Netherlands', 'city': 'Amsterdam', 'lat': 52.37, 'lng': 4.89},
    {'code': 'CH', 'name': 'Switzerland', 'city': 'Zurich', 'lat': 47.37, 'lng': 8.54},
    {'code': 'SE', 'name': 'Sweden', 'city': 'Stockholm', 'lat': 59.33, 'lng': 18.07},
    {'code': 'AE', 'name': 'UAE', 'city': 'Dubai', 'lat': 25.20, 'lng': 55.27},
    {'code': 'IN', 'name': 'India', 'city': 'Mumbai', 'lat': 19.08, 'lng': 72.88},
    {'code': 'BR', 'name': 'Brazil', 'city': 'Sao Paulo', 'lat': -23.55, 'lng': -46.63},
    {'code': 'PK', 'name': 'Pakistan', 'city': 'Islamabad', 'lat': 33.68, 'lng': 73.05},
  ];

  @override
  Future<List<ServerModel>> fetchServers() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final rnd = Random(42);
    return List.generate(_seed.length, (i) {
      final s = _seed[i];
      final categories = <ServerCategory>[ServerCategory.standard];
      if (rnd.nextBool()) categories.add(ServerCategory.streaming);
      if (rnd.nextDouble() > 0.7) categories.add(ServerCategory.p2p);
      if (rnd.nextDouble() > 0.85) categories.add(ServerCategory.gaming);
      return ServerModel(
        id: 'srv_${s['code']}_$i',
        countryCode: s['code'] as String,
        countryName: s['name'] as String,
        city: s['city'] as String,
        latitude: s['lat'] as double,
        longitude: s['lng'] as double,
        latencyMs: 15 + rnd.nextInt(180),
        loadPercent: (5 + rnd.nextInt(90)).toDouble(),
        currentUsers: 100 + rnd.nextInt(9000),
        categories: categories,
        isPremium: rnd.nextDouble() > 0.6,
      );
    });
  }

  @override
  Future<ServerModel> fetchFastestServer() async {
    final servers = await fetchServers();
    servers.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
    return servers.first;
  }
}
