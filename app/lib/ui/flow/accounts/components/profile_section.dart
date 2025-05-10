import 'package:cloud_gallery/domain/extensions/context_extensions.dart';
import 'package:cloud_gallery/domain/services/auth_service.dart';
import 'package:cloud_gallery/ui/navigation/app_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:style/extensions/context_extensions.dart';
import 'package:style/text/app_text_style.dart';

/// Profile section for the accounts screen that shows user information when logged in
/// and provides options to login/signup when not logged in
class ProfileSection extends ConsumerWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: authState.when(
          data: (User? user) {
            if (user != null) {
              // User is logged in, show profile info
              return _buildUserProfile(context, ref, user);
            } else {
              // User is not logged in, show login options
              return _buildLoginOptions(context);
            }
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildErrorState(context, error),
        ),
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context, WidgetRef ref, User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: context.colorScheme.primary.withOpacity(0.2),
              child: user.photoURL != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        user.photoURL!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: 30,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 30,
                      color: context.colorScheme.primary,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'Cloud Gallery User',
                    style: AppTextStyles.subtitle1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? '',
                    style: AppTextStyles.body2.copyWith(
                      color: context.colorScheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        _buildProfileOption(
          context,
          Icons.account_circle,
          'Edit Profile',
          () {
            // Navigate to edit profile screen
            Fluttertoast.showToast(
              msg: 'Edit profile functionality coming soon!',
              toastLength: Toast.LENGTH_SHORT,
            );
          },
        ),
        _buildProfileOption(
          context,
          Icons.logout,
          'Sign Out',
          () async {
            try {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                Fluttertoast.showToast(
                  msg: 'Successfully signed out',
                  toastLength: Toast.LENGTH_SHORT,
                );
              }
            } catch (e) {
              if (context.mounted) {
                Fluttertoast.showToast(
                  msg: 'Error signing out: ${e.toString()}',
                  toastLength: Toast.LENGTH_LONG,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildLoginOptions(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.account_circle,
          size: 60,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          'Sign in to your account',
          style: AppTextStyles.subtitle1.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colorScheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Access all your media across devices and keep your memories secure',
          textAlign: TextAlign.center,
          style: AppTextStyles.body2.copyWith(
            color: context.colorScheme.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go(AppRoutePath.login),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: context.colorScheme.primary,
            foregroundColor: context.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Login',
            style: AppTextStyles.button,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(AppRoutePath.signup),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Create Account',
            style: AppTextStyles.button.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline,
          size: 48,
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        Text(
          'Authentication Error',
          style: AppTextStyles.subtitle1.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          error.toString(),
          textAlign: TextAlign.center,
          style: AppTextStyles.body2,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.go(AppRoutePath.login),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: context.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _buildProfileOption(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: context.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: AppTextStyles.subtitle2.copyWith(
                color: context.colorScheme.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
