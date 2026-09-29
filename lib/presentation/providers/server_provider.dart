import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/server_model.dart';
import '../../data/repositories/remote_server_repository.dart';
import 'vpn_connection_provider.dart';

final serversProvider = FutureProvider<List<ServerModel>>((ref) {
  if (kIsWeb) return RemoteServerRepository().fetchServers();
  if (defaultTargetPlatform != TargetPlatform.android) return Future.value(const []);
  return ref.watch(wireGuardProfileStoreProvider).readAll().then(
        (profiles) => profiles.map((profile) => profile.toServerModel()).toList(),
      );
});

final favoriteServerIdsProvider = StateProvider<Set<String>>((ref) => {});
final recentServerIdsProvider = StateProvider<List<String>>((ref) => []);

final serverSearchQueryProvider = StateProvider<String>((ref) => '');
final serverCategoryFilterProvider = StateProvider<ServerCategory?>((ref) => null);

enum ServerSort { fastest, lowestLoad, alphabetical }
final serverSortProvider = StateProvider<ServerSort>((ref) => ServerSort.fastest);

/// Derived, filtered + sorted list driven by search/category/sort providers.
final filteredServersProvider = Provider<AsyncValue<List<ServerModel>>>((ref) {
  final serversAsync = ref.watch(serversProvider);
  final query = ref.watch(serverSearchQueryProvider).toLowerCase();
  final category = ref.watch(serverCategoryFilterProvider);
  final sort = ref.watch(serverSortProvider);

  return serversAsync.whenData((servers) {
    var list = servers.where((s) {
      final matchesQuery = query.isEmpty ||
          s.countryName.toLowerCase().contains(query) ||
          s.city.toLowerCase().contains(query);
      final matchesCategory = category == null || s.categories.contains(category);
      return matchesQuery && matchesCategory;
    }).toList();

    switch (sort) {
      case ServerSort.fastest:
        list.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
        break;
      case ServerSort.lowestLoad:
        list.sort((a, b) => a.loadPercent.compareTo(b.loadPercent));
        break;
      case ServerSort.alphabetical:
        list.sort((a, b) => a.countryName.compareTo(b.countryName));
        break;
    }
    return list;
  });
});
