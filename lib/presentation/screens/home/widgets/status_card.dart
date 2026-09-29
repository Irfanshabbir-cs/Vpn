import 'package:flutter/material.dart';
import '../../../../data/repositories/vpn_repository.dart';

class StatusCard extends StatelessWidget {
  final ConnectionStats? stats;
  final String? countryName;
  final String protocolLabel;
  final bool connected;

  const StatusCard({
    super.key,
    required this.stats,
    required this.countryName,
    required this.protocolLabel,
    required this.connected,
  });

  String _fmtDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatTile(icon: Icons.public_rounded, label: 'Location', value: countryName ?? '—'),
                _StatTile(icon: Icons.podcasts_rounded, label: 'Protocol', value: protocolLabel),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatTile(icon: Icons.wifi_tethering_rounded, label: 'IP', value: s?.ip ?? '—'),
                _StatTile(icon: Icons.speed_rounded, label: 'Ping', value: s?.pingMs == null ? '—' : '${s!.pingMs} ms'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatTile(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Upload',
                  value: s?.uploadMbps == null ? '—' : '${s!.uploadMbps!.toStringAsFixed(1)} Mbps',
                ),
                _StatTile(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Download',
                  value: s?.downloadMbps == null ? '—' : '${s!.downloadMbps!.toStringAsFixed(1)} Mbps',
                ),
              ],
            ),
            if (connected) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                _fmtDuration(s?.duration ?? Duration.zero),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
              Text('Connected', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
      ],
    );
  }
}
