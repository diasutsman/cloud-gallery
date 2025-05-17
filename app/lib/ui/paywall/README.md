# Cloud Gallery Subscription System

This folder contains the subscription system for Cloud Gallery, allowing users to subscribe for $3.99/month with support for discount codes.

## Features
- In-app purchase subscription using official Flutter `in_app_purchase` package
- Firebase integration to track subscription status
- Discount code system (stored in Firebase)
- Subscription guard to protect premium features

## How to Use

### 1. Protect Premium Features

Wrap any premium feature with `SubscriptionGuard`:

```dart
SubscriptionGuard(
  child: YourPremiumFeature(),
)
```

This will automatically show a subscription prompt if the user isn't subscribed.

### 2. Check Subscription Status

You can check subscription status in your code:

```dart
// Using the provider (reactive)
final isSubscribed = ref.watch(isSubscribedProvider);

// Or using the helper (imperative)
final hasSubscription = await checkSubscription(ref);
```

### 3. Create Discount Codes

Add discount codes to Firebase collection `/discounts/{code}` with this structure:
```
{
  "amount": 2.00,  // Discount amount in dollars
  "description": "Welcome discount",
  "expiryDate": "2025-12-31",  // Optional expiry date
  "maxUses": 100  // Optional usage limit
}
```

## Platform Setup

### Android

1. Add your subscription product in Google Play Console
2. Set the product ID to `cloud_gallery_monthly`
3. Update `android/app/src/main/AndroidManifest.xml` with this permission:

```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

### iOS

1. Add your subscription product in App Store Connect
2. Set the product ID to `cloud_gallery_monthly`
3. No additional setup required for iOS

## Production Requirements

For a production environment:
1. Implement server-side receipt validation
2. Add receipt verification logic in `SubscriptionService._verifyPurchase()`
3. Consider adding subscription restoration functionality

## Testing

Use test accounts during development:
- Android: Create test accounts in Google Play Console
- iOS: Use sandbox testers in App Store Connect
