import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:data/services/subscription_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  final TextEditingController _discountController = TextEditingController();
  double _price = 3.99;
  double _discount = 0.0;
  bool _loading = false;
  String? _error;
  List<ProductDetails>? _products;

  @override
  void initState() {
    super.initState();
    _initializeIAP();
  }

  Future<void> _initializeIAP() async {
    setState(() {
      _loading = true;
    });

    try {
      final service = ref.read(subscriptionServiceProvider);
      await service.initialize();
      final products = await service.getSubscriptionProducts();
      Logger().d('products: $products');

      setState(() {
        _products = products;
        if (products.isNotEmpty) {
          // Get the price from the product
          final price = products.first.price;
          // Extract numeric price (removing currency symbol)
          final numericPrice = double.tryParse(
            price.replaceAll(RegExp(r'[^0-9\.]'), ''),
          );
          if (numericPrice != null) {
            _price = numericPrice;
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load subscription details.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _applyDiscount() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(subscriptionServiceProvider);
      final discount =
          await service.getDiscount(_discountController.text.trim());
      setState(() {
        _discount = discount;
      });

      if (discount <= 0) {
        setState(() {
          _error = 'Invalid discount code.';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Discount of \$${discount.toStringAsFixed(2)} applied!')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to apply discount code.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _subscribe() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'You must be signed in to subscribe.';
        _loading = false;
      });
      return;
    }

    try {
      final service = ref.read(subscriptionServiceProvider);

      // Apply discount if available
      if (_discount > 0) {
        await service.applyDiscount(
          user.uid,
          _discountController.text.trim(),
          _discount,
        );
      }

      // Start subscription
      final success = await service.subscribe(
        user.uid,
        discountCode: _discountController.text.trim(),
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully subscribed!')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _error = 'Subscription failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Subscription failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalPrice = (_price - _discount).clamp(0.0, _price);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Gallery Premium'),
        elevation: 0,
      ),
      body: _loading && _products == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_done,
                              size: 64, color: Colors.blue),
                          const SizedBox(height: 16),
                          const Text(
                            'Cloud Gallery Premium',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Unlock all features for only \$${finalPrice.toStringAsFixed(2)}/month',
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Features
                    const Text('Premium Features:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                        'Unlimited cloud storage', Icons.cloud_upload),
                    _buildFeatureItem('Ad-free experience', Icons.block),
                    _buildFeatureItem(
                        'Priority customer support', Icons.support_agent),
                    _buildFeatureItem(
                        'Exclusive filters and effects', Icons.auto_fix_high),
                    _buildFeatureItem(
                        'High-resolution backup', Icons.high_quality),

                    const SizedBox(height: 32),

                    // Discount code
                    const Text('Have a discount code?',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _discountController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Discount code',
                        hintText: 'Enter code',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: _loading ? null : _applyDiscount,
                        ),
                      ),
                    ),

                    if (_discount > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'Discount applied: -\$${_discount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Subscribe button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _subscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Subscribe Now',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'Subscription will auto-renew. Cancel anytime.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFeatureItem(String feature, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Text(feature, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }
}
