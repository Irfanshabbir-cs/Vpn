import 'package:flutter/material.dart';
import '../../../../data/models/server_model.dart';

class ServerCard extends StatelessWidget {
  final ServerModel server;
  final bool isFavorite;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  const ServerCard({
    super.key,
    required this.server,
    required this.isFavorite,
    required this.isSelected,
    required this.onTap,
    required this.onFavoriteTap,
  });

  Color _loadColor(double load) {
    if (load < 40) return Colors.green;
    if (load < 75) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Text(
                  _flagEmoji(server.countryCode),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(server.countryName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (server.isPremium) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.amber),
                        ],
                      ],
                    ),
                    Text(
                      server.city,
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              if (server.isWireGuardProfile)
                const Text('WireGuard', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${server.latencyMs} ms', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: _loadColor(server.loadPercent)),
                        const SizedBox(width: 4),
                        Text('${server.loadPercent.toStringAsFixed(0)}% load', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite ? Colors.amber : null,
                ),
                onPressed: onFavoriteTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _flagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🏳️';
    final base = 0x1F1E6;
    final first = countryCode.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0) + base;
    final second = countryCode.toUpperCase().codeUnitAt(1) - 'A'.codeUnitAt(0) + base;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}
