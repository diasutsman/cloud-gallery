import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:logger/logger.dart';

class SubscriptionService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Product IDs for subscription
  static const String _monthlySubscriptionId = 'cloud_gallery_monthly';

  // Completer to handle purchase completion
  Completer<bool>? _purchaseCompleter;

  // Controller for subscription status updates
  final StreamController<bool> _subscriptionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get subscriptionStatusStream =>
      _subscriptionStatusController.stream;

  // Initialize the service and listen for purchase updates
  Future<void> initialize() async {
    // Set up the purchase stream
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        // Handle error
      },
    );

    // Load products
    await _loadProducts();
  }

  Future<List<ProductDetails>> _loadProducts() async {
    Logger().d('_monthlySubscriptionId: ${_monthlySubscriptionId}');

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(
      {_monthlySubscriptionId},
    );

    Logger().d('response: ${response.productDetails}');

    if (response.error != null) {
      return [];
    }

    return response.productDetails;
  }

  Future<List<ProductDetails>> getSubscriptionProducts() async {
    return await _loadProducts();
  }

  // Get discount from Firestore
  Future<double> getDiscount(String code) async {
    if (code.isEmpty) return 0.0;

    final doc = await firestore.collection('discounts').doc(code).get();
    if (!doc.exists) return 0.0;
    final data = doc.data() as Map<String, dynamic>;
    return (data['amount'] as num?)?.toDouble() ?? 0.0;
  }

  // Apply discount to a purchase
  Future<void> applyDiscount(
    String userId,
    String discountCode,
    double discountAmount,
  ) async {
    if (discountCode.isEmpty || discountAmount <= 0) return;

    // Save this discount application in Firebase
    await firestore
        .collection('users')
        .doc(userId)
        .collection('discounts')
        .add({
      'code': discountCode,
      'amount': discountAmount,
      'appliedAt': FieldValue.serverTimestamp(),
      'used': false,
    });
  }

  // Start a subscription purchase
  Future<bool> subscribe(String userId, {String? discountCode}) async {
    // Get products
    final products = await _loadProducts();
    if (products.isEmpty) return false;

    // Find the monthly subscription product
    final monthlyProduct = products.firstWhere(
      (product) => product.id == _monthlySubscriptionId,
      orElse: () => throw Exception('Monthly subscription product not found'),
    );

    // Create the purchase completer
    _purchaseCompleter = Completer<bool>();

    // Start the purchase
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: monthlyProduct,
      applicationUserName: userId,
    );

    try {
      // Buy the subscription
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      // Wait for the purchase to complete (this will be completed in _onPurchaseUpdate)
      return await _purchaseCompleter!.future;
    } catch (e) {
      _purchaseCompleter?.complete(false);
      return false;
    }
  }

  // Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show a loading UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle error
          _purchaseCompleter?.complete(false);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Verify the purchase
          final valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            // Record the subscription in Firestore
            await _recordSubscription(purchaseDetails);
            _purchaseCompleter?.complete(true);
            _subscriptionStatusController.add(true);
          } else {
            _purchaseCompleter?.complete(false);
          }
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  // Verify the purchase is valid
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // In a real app, you should verify the purchase on your server
    // For demo purposes, we'll just check that we have a valid receipt
    return purchaseDetails.status == PurchaseStatus.purchased;
  }

  // Record the subscription in Firestore
  Future<void> _recordSubscription(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.purchaseID == null) return;

    // Get the user ID from the application username
    final userId = purchaseDetails.purchaseID!.split('_').first;
    if (userId.isEmpty) return;

    final receiptData = purchaseDetails.verificationData.serverVerificationData;
    final now = DateTime.now();

    // Calculate expiry - one month from now
    final expiry = DateTime(now.year, now.month + 1, now.day);

    // Hash the receipt for a more secure storage
    final receiptHash = sha256.convert(utf8.encode(receiptData)).toString();

    // Store in Firestore
    await firestore.collection('subscriptions').doc(userId).set(
      {
        'active': true,
        'productId': purchaseDetails.productID,
        'purchaseId': purchaseDetails.purchaseID,
        'purchaseTime': now.toIso8601String(),
        'expiryTime': expiry.toIso8601String(),
        'receiptHash': receiptHash,
        'platform': Platform.isAndroid
            ? 'android'
            : Platform.isIOS
                ? 'ios'
                : 'unknown',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Also check for applied discounts and mark them as used
    await firestore
        .collection('users')
        .doc(userId)
        .collection('discounts')
        .where('used', isEqualTo: false)
        .get()
        .then((snapshot) {
      for (final doc in snapshot.docs) {
        doc.reference.update({'used': true});
      }
    });
  }

  // Check if a user is subscribed
  Future<bool> isSubscribed(String userId) async {
    if (userId.isEmpty) return false;

    try {
      final doc = await firestore.collection('subscriptions').doc(userId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final active = data['active'] as bool? ?? false;
      final expiryStr = data['expiryTime'] as String?;

      // Check expiry
      if (expiryStr != null) {
        final expiry = DateTime.parse(expiryStr);
        if (expiry.isAfter(DateTime.now()) && active) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Clean up resources
  void dispose() async {
    // End billing client connection first to prevent 'Service not registered' errors
    try {
      await Future.delayed(
        Duration.zero,
      ); // Allow pending operations to complete
      _subscription?.cancel();
      _subscription = null;
    } catch (e) {
      Logger().e('Error during subscription cancel: $e');
    }

    // Close the stream controller
    if (!_subscriptionStatusController.isClosed) {
      _subscriptionStatusController.close();
    }
  }
}

// Provider for the subscription service
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});
