import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data/services/subscription_service.dart';
import '../paywall/subscription_guard.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the subscription service
    ref.read(subscriptionServiceProvider).initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SubscriptionGuard(
                    showPaywallImmediately: true,
                    child: PremiumFeaturesScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Regular content available to all users
          // Expanded(
          //   flex: 1,
          //   child: _buildFreeSection(),
          // ),

          // Premium content that requires subscription
          Expanded(
            flex: 2,
            child: SubscriptionGuard(
              child: _buildPremiumSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeSection() {
    return Container(
      color: Colors.blue.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Basic Features',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Available to all users',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to basic features
              },
              child: const Text('View Gallery'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSection() {
    return Container(
      color: Colors.amber.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Premium Features',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlimited storage & advanced features',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to premium features
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
              ),
              child: const Text('Explore Premium'),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumFeaturesScreen extends StatelessWidget {
  const PremiumFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Features'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFeatureCard(
            title: 'Unlimited Cloud Storage',
            description: 'Store as many photos and videos as you want',
            icon: Icons.cloud_upload,
          ),
          _buildFeatureCard(
            title: 'Advanced Filters',
            description: 'Access to our premium collection of photo filters',
            icon: Icons.filter,
          ),
          _buildFeatureCard(
            title: 'Auto Organization',
            description:
                'AI-powered photo organization by faces, places, and events',
            icon: Icons.auto_awesome,
          ),
          _buildFeatureCard(
            title: 'Priority Support',
            description: '24/7 support with faster response times',
            icon: Icons.support_agent,
          ),
          _buildFeatureCard(
            title: 'Ad-Free Experience',
            description: 'Enjoy the app without any advertisements',
            icon: Icons.block,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.amber),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
