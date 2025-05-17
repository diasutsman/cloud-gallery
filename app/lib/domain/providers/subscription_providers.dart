import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:data/services/subscription_service.dart';

/// Provider that exposes the current user's subscription status
final isSubscribedProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  
  // If not logged in, not subscribed
  if (user == null) return false;
  
  // Check subscription status
  final subscriptionService = ref.read(subscriptionServiceProvider);
  return await subscriptionService.isSubscribed(user.uid);
});

/// Stream provider that listens for subscription status changes
final subscriptionStatusStreamProvider = StreamProvider<bool>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(false);
  
  final subscriptionService = ref.read(subscriptionServiceProvider);
  return subscriptionService.subscriptionStatusStream;
});

/// Helper to check if the current user has an active subscription
Future<bool> checkSubscription(WidgetRef ref) async {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  
  final subscriptionService = ref.read(subscriptionServiceProvider);
  return await subscriptionService.isSubscribed(user.uid);
}
