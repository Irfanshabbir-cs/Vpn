import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/server_model.dart';
import '../../providers/server_provider.dart';
import '../../providers/vpn_connection_provider.dart';
import 'widgets/server_card.dart';

class ServerListScreen extends ConsumerStatefulWidget {
  const ServerListScreen({super.key});

  @override
  ConsumerState<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends ConsumerState<ServerListScreen> {
  final _searchCtrl = TextEditingController();
  bool get _canImport => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _importProfile() async {
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['conf'],
        withData: true,
      );
      if (selection == null || selection.files.isEmpty) return;
      final file = selection.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('The selected config file could not be read.');
      final name = file.name.replaceFirst(RegExp(r'\.conf$', caseSensitive: false), '');
      final profile = await ref.read(wireGuardProfileStoreProvider).importConfig(
            name: name.isEmpty ? 'WireGuard profile' : name,
            config: utf8.decode(bytes),
          );
      ref.read(selectedServerProvider.notifier).state = profile.toServerModel();
      ref.read(selectedProtocolProvider.notifier).state = VpnProtocol.wireGuard;
      ref.invalidate(serversProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not import config: $error')));
    }
  }

  static const _categoryLabels = {
    null: 'All',
    ServerCategory.streaming: 'Streaming',
    ServerCategory.gaming: 'Gaming',
    ServerCategory.p2p: 'P2P',
    ServerCategory.doubleVpn: 'Double VPN',
  };

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(filteredServersProvider);
    final favorites = ref.watch(favoriteServerIdsProvider);
    final selected = ref.watch(selectedServerProvider);
    final category = ref.watch(serverCategoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        actions: [
          if (_canImport)
            IconButton(
              tooltip: 'Import WireGuard config',
              onPressed: _importProfile,
              icon: const Icon(Icons.file_open_rounded),
            ),
          PopupMenuButton<ServerSort>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) => ref.read(serverSortProvider.notifier).state = v,
            itemBuilder: (context) => const [
              PopupMenuItem(value: ServerSort.fastest, child: Text('Fastest')),
              PopupMenuItem(value: ServerSort.lowestLoad, child: Text('Lowest load')),
              PopupMenuItem(value: ServerSort.alphabetical, child: Text('Alphabetical')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => ref.read(serverSearchQueryProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Search country or city',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _categoryLabels.entries.map((entry) {
                final isSelected = category == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) => ref.read(serverCategoryFilterProvider.notifier).state = entry.key,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.when(
              loading: () => _LoadingShimmer(),
              error: (e, _) => Center(child: Text('Failed to load servers: $e')),
              data: (servers) {
                if (servers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _canImport
                            ? 'Import a WireGuard .conf profile to add a server.'
                            : 'Real WireGuard connections are currently available on Android.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: servers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final server = servers[i];
                    return ServerCard(
                      server: server,
                      isFavorite: favorites.contains(server.id),
                      isSelected: selected?.id == server.id,
                      onTap: () {
                        ref.read(selectedServerProvider.notifier).state = server;
                        if (server.isWireGuardProfile) {
                          ref.read(selectedProtocolProvider.notifier).state = VpnProtocol.wireGuard;
                        }
                        final recents = [...ref.read(recentServerIdsProvider)];
                        recents.remove(server.id);
                        recents.insert(0, server.id);
                        ref.read(recentServerIdsProvider.notifier).state = recents.take(5).toList();
                        Navigator.of(context).pop();
                      },
                      onFavoriteTap: () {
                        final next = {...favorites};
                        next.contains(server.id) ? next.remove(server.id) : next.add(server.id);
                        ref.read(favoriteServerIdsProvider.notifier).state = next;
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).cardColor,
      highlightColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 72,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
