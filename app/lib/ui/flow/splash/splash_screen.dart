import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:style/extensions/context_extensions.dart';

import '../../../domain/utils/app_switcher.dart';
import '../../../domain/utils/disguise_preferences.dart';
import '../../../gen/assets.gen.dart';
import '../../navigation/app_route.dart';
import '../../../domain/services/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isDisguiseActive = false;
  AppDisguiseType _activeDisguiseType = AppDisguiseType.none;

  @override
  void initState() {
    super.initState();
    // Check if disguise is active immediately to display correct splash screen
    _checkDisguiseStatus();
    // Check authentication after a short delay to allow the splash screen to be shown
    Future.delayed(const Duration(seconds: 2), () {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkDisguiseStatus() async {
    final disguiseType = await AppSwitcher.getCurrentDisguiseType();
    if (mounted) {
      setState(() {
        _activeDisguiseType = disguiseType;
        _isDisguiseActive = disguiseType != AppDisguiseType.none;
      });
    }
  }

  void _checkAuthAndNavigate() async {
    // Check authentication state
    final authState = ref.read(authStateProvider);

    authState.when(
      data: (user) async {
        // If user is logged in, check disguise status
        if (user != null) {
          // Get the current disguise type
          final disguiseType = await AppSwitcher.getCurrentDisguiseType();
          // Update the provider
          ref.read(disguiseTypeProvider.notifier).state = disguiseType;

          if (disguiseType != AppDisguiseType.none) {
            // If disguise is active, show the disguise screen first
            DisguiseRoute().go(context);
          } else {
            // Otherwise, go directly to home
            HomeRoute().go(context);
          }
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
    // When disguise is active, show the corresponding disguise app icon
    if (_isDisguiseActive) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Image.asset(
            _getDisguiseIconPath(),
            width: 120,
          ),
        ),
      );
    }

    // Regular splash screen with logo for normal mode
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

  // Get the icon path based on the active disguise type
  String _getDisguiseIconPath() {
    switch (_activeDisguiseType) {
      case AppDisguiseType.calculator:
        return 'assets/images/ic_calculator.png';
      case AppDisguiseType.calendar:
        return 'assets/images/ic_calendar.png';
      case AppDisguiseType.notes:
        return 'assets/images/ic_notes.png';
      case AppDisguiseType.clock:
        return 'assets/images/ic_clock.png';
      case AppDisguiseType.weather:
        return 'assets/images/ic_weather.png';
      case AppDisguiseType.none:
        return Assets.images.appIcon.path;
    }
  }
}
