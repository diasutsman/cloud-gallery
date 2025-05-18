import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/subscription_providers.dart';
import 'package:data/services/subscription_service.dart';
import 'paywall_screen.dart';

/// Helper class to manage subscription-related functionality throughout the app
class SubscriptionManager {
  static SubscriptionManager? _instance;

  /// Get the singleton instance of the subscription manager
  static SubscriptionManager get instance {
    _instance ??= SubscriptionManager._();
    return _instance!;
  }

  SubscriptionManager._();

  /// Initialize the subscription system
  Future<void> initialize(WidgetRef ref) async {
    await ref.read(subscriptionServiceProvider).initialize();
  }

  /// Check if a feature is available based on subscription status
  Future<bool> canAccessFeature(WidgetRef ref, String featureId) async {
    // Some features might be available to all users
    if (_isFreeFeature(featureId)) {
      return true;
    }

    // Otherwise check subscription
    return await checkSubscription(ref);
  }

  /// Show the subscription paywall if the user isn't subscribed
  Future<bool> showPaywallIfNeeded(BuildContext context, WidgetRef ref) async {
    final isSubscribed = await checkSubscription(ref);

    if (!isSubscribed) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (context) => const PaywallScreen()),
      );

      return result == true;
    }

    return true; // Already subscribed
  }

  /// Check if the user is currently subscribed
  Future<bool> isUserSubscribed(WidgetRef ref) async {
    return await checkSubscription(ref);
  }

  /// Create a new discount code in Firebase for testing
  Future<void> createDiscountCode(
    WidgetRef ref,
    String code,
    double amount, {
    String? description,
    DateTime? expiryDate,
    int? maxUses,
  }) async {
    final service = ref.read(subscriptionServiceProvider);
    final firestore =
        service.firestore; // Accessing private field for admin purposes

    await firestore.collection('discounts').doc(code).set({
      'amount': amount,
      'description': description ?? 'Discount code: $code',
      'expiryDate': expiryDate?.toIso8601String(),
      'maxUses': maxUses,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Helper method to determine if a feature is free or premium
  bool _isFreeFeature(String featureId) {
    // List of features available to non-subscribers
    const freeFeatures = [
      'basic_gallery',
      'limited_storage',
      'single_device_sync',
      'standard_security',
    ];

    return freeFeatures.contains(featureId);
  }

  /// Utility method to check if a specific feature requires subscription
  bool doesFeatureRequireSubscription(String featureId) {
    return !_isFreeFeature(featureId);
  }

  /// Get a user-friendly description of what they'll get with premium
  List<Map<String, dynamic>> getPremiumFeatures() {
    return [
      {
        'id': 'unlimited_storage',
        'title': 'Unlimited Storage',
        'description': 'Store as many photos and videos as you want',
        'icon': Icons.cloud_upload,
      },
      {
        'id': 'advanced_filters',
        'title': 'Advanced Filters',
        'description': 'Premium photo filters for perfect edits',
        'icon': Icons.filter,
      },
      {
        'id': 'auto_organization',
        'title': 'Auto Organization',
        'description': 'AI-powered organization by faces, places, and events',
        'icon': Icons.auto_awesome,
      },
      {
        'id': 'ad_free',
        'title': 'Ad-Free Experience',
        'description': 'No advertisements to interrupt your experience',
        'icon': Icons.block,
      },
      {
        'id': 'priority_support',
        'title': 'Priority Support',
        'description': '24/7 support with faster response times',
        'icon': Icons.support_agent,
      },
    ];
  }
}
