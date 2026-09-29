import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class ConnectButton extends StatefulWidget {
  final VpnConnectionState state;
  final VoidCallback onTap;

  const ConnectButton({super.key, required this.state, required this.onTap});

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isConnected => widget.state == VpnConnectionState.connected;
  bool get _isBusy =>
      widget.state == VpnConnectionState.connecting || widget.state == VpnConnectionState.disconnecting;

  @override
  Widget build(BuildContext context) {
    final gradient = _isConnected ? AppColors.connectedGradient : AppColors.disconnectedGradient;

    return GestureDetector(
      onTap: _isBusy ? null : widget.onTap,
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isConnected)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final value = _pulseController.value;
                  return Container(
                    width: 220 * (1 + value * 0.3),
                    height: 220 * (1 + value * 0.3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gradient.first.withOpacity((1 - value) * 0.25),
                    ),
                  );
                },
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: gradient.first.withOpacity(0.4), blurRadius: 40, spreadRadius: 4)],
              ),
              child: Center(
                child: _isBusy
                    ? const SizedBox(
                        width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Icon(
                        _isConnected ? Icons.shield_rounded : Icons.power_settings_new_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
