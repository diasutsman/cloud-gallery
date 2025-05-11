import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:style/extensions/context_extensions.dart';

import '../../../gen/assets.gen.dart';
import '../../navigation/app_route.dart';
import '../../../domain/services/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Check authentication after a short delay to allow the splash screen to be shown
    Future.delayed(const Duration(seconds: 2), () {
      _checkAuthAndNavigate();
    });
  }

  void _checkAuthAndNavigate() {
    // Check authentication state
    final authState = ref.read(authStateProvider);
    
    authState.when(
      data: (user) {
        // If user is logged in, navigate to home, otherwise to login
        if (user != null) {
          HomeRoute().go(context);
        } else {
          LoginRoute().go(context);
        }
      },
      loading: () {
        // If still loading auth state, wait a bit longer and try again
        Future.delayed(const Duration(milliseconds: 500), () {
          _checkAuthAndNavigate();
        });
      },
      error: (_, __) {
        // If error, navigate to login
        LoginRoute().go(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  context.colorScheme.primary.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Center(
            child: Image.asset(
              Assets.images.appIcon.path,
              width: 250,
            ),
          ),
        ],
      ),
    );
  }
}
