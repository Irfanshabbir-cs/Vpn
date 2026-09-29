import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../providers/server_provider.dart';
import '../../providers/vpn_connection_provider.dart';
import 'widgets/connect_button.dart';
import 'widgets/status_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-select the fastest server so the first tap on Home just works.
    Future.microtask(() async {
      final servers = await ref.read(serversProvider.future);
      if (servers.isNotEmpty && ref.read(selectedServerProvider) == null) {
        final fastest = [...servers]..sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
        ref.read(selectedServerProvider.notifier).state = fastest.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(vpnConnectionStateProvider).valueOrNull ?? VpnConnectionState.disconnected;
    final statsAsync = ref.watch(connectionStatsProvider);
    final selectedServer = ref.watch(selectedServerProvider);
    final protocol = ref.watch(selectedProtocolProvider);
    final connected = connState == VpnConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShieldVPN'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => context.push(AppRoutes.servers),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).cardColor,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.public_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedServer != null
                              ? '${selectedServer.countryName} · ${selectedServer.city}'
                              : 'Choose a server',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Text(
                connected
                    ? 'You are protected'
                    : connState == VpnConnectionState.connecting
                        ? 'Connecting…'
                        : 'You are not protected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ConnectButton(
                state: connState,
                onTap: () async {
                  try {
                    await ref.read(vpnConnectionControllerProvider).toggleConnection();
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
                    );
                  }
                },
              ),
              const SizedBox(height: 36),
              StatusCard(
                stats: statsAsync.valueOrNull,
                countryName: selectedServer?.countryName,
                protocolLabel: protocol.label,
                connected: connected,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.dns_rounded), label: 'Servers'),
          NavigationDestination(icon: Icon(Icons.map_rounded), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.speed_rounded), label: 'Speed Test'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Account'),
        ],
        onDestinationSelected: (i) {
          if (i == 1) context.push(AppRoutes.servers);
          // Map / Speed Test / Account screens follow the same pattern in the
          // next build pass (see docs/ARCHITECTURE.md for the planned routes).
        },
      ),
    );
  }
}
