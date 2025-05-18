import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/subscription_providers.dart';
import 'paywall_screen.dart';

/// A widget that only shows its child if the user has an active subscription.
/// Otherwise, it shows a button to subscribe.
class SubscriptionGuard extends ConsumerWidget {
  final Widget child;
  final bool showPaywallImmediately;

  const SubscriptionGuard({
    super.key,
    required this.child,
    this.showPaywallImmediately = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubscribed = ref.watch(isSubscribedProvider);

    return isSubscribed.when(
      data: (hasSubscription) {
        if (hasSubscription) {
          return child;
        } else {
          if (showPaywallImmediately) {
            // Show paywall immediately
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showPaywall(context);
            });
          }

          return _buildSubscriptionNeededUI(context);
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildSubscriptionNeededUI(context),
    );
  }

  Widget _buildSubscriptionNeededUI(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Premium Feature',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This feature is only available with a premium subscription.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showPaywall(context),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Subscribe Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaywall(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PaywallScreen()),
    );

    // If subscription successful, refresh the screen
    if (result == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium features unlocked!')),
        );
      }
    }
  }
}
