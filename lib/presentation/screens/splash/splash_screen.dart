import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Give the auth provider's async bootstrap + splash animation a floor
    // so the logo doesn't flash for <100ms on fast devices.
    final prefs = SharedPreferences.getInstance();
    final results = await Future.wait([
      prefs,
      Future.delayed(const Duration(milliseconds: 1200)),
    ]);
    final sharedPrefs = results[0] as SharedPreferences;
    final onboardingDone = sharedPrefs.getBool(AppConstants.keyOnboardingComplete) ?? false;

    if (!mounted) return;

    // Wait for auth bootstrap (currentUser lookup) to resolve.
    while (ref.read(authProvider).status == AuthStatus.unknown) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      context.go(AppRoutes.home);
    } else if (!onboardingDone) {
      context.go(AppRoutes.onboarding);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E0F1A), Color(0xFF1B1D3A)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _controller,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFF5B5FEF), Color(0xFF00D68F)]),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF5B5FEF).withOpacity(0.4), blurRadius: 40),
                      ],
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ShieldVPN',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
