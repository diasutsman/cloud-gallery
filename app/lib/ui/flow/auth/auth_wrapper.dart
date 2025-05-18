import 'package:cloud_gallery/domain/services/auth_service.dart';
import 'package:cloud_gallery/ui/navigation/app_route.dart';
import 'package:data/storage/app_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Auth Wrapper checks authentication state and redirects accordingly
class AuthWrapper extends ConsumerWidget {
  final Widget child;

  const AuthWrapper({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (User? user) {
        if (user != null) {
          // User is logged in, no redirection needed
          return child;
        } else {
          // If onboarding is complete but the user is not logged in,
          // let them continue as guest for now, as that seems to be the app's current behavior
          final isOnBoardComplete = ref.read(AppPreferences.isOnBoardComplete);
          
          if (!isOnBoardComplete) {
            // If onboarding is not complete, show onboarding first
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(AppRoutePath.onBoard);
            });
          }
          
          return child;
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) {
        // On auth error, reset to onboarding
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(AppRoutePath.onBoard);
        });
        return const Scaffold(
          body: Center(
            child: Text('Authentication error. Please try again.'),
          ),
        );
      },
    );
  }
}

// Provider to check if user is logged in
final isUserLoggedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});
