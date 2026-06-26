# Razorpay Flutter Setup Guide

## 1. pubspec.yaml (already added)
```yaml
razorpay_flutter: ^1.3.6
```

## 2. Android — android/app/build.gradle
```gradle
android {
    ...
    defaultConfig {
        ...
        minSdkVersion 21   // razorpay requires min 21
    }
}
```

## 3. Android — android/app/src/main/AndroidManifest.xml
Add inside <application> tag:
```xml
<activity
  android:name="com.razorpay.CheckoutActivity"
  android:configChanges="keyboard|keyboardHidden|orientation|screenSize"
  android:exported="true"
  android:theme="@style/CheckoutTheme">
</activity>
```

Also add permission:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## 4. ProGuard (android/app/proguard-rules.pro)
```
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
```

## 5. Payment Flow Summary

### Auto Pay (Subscription):
1. User selects plan, toggles Auto Pay ON
2. App calls POST /user/subscription/create → gets subscription_id
3. Razorpay checkout opens with subscription_id
4. On success → App calls POST /user/subscription/confirm
5. Navigate to PaymentSuccess screen

### One-time Payment:
1. User selects plan, toggles Auto Pay OFF
2. App calls POST /user/purchase/plan → gets order_id + amount
3. Razorpay checkout opens with order_id
4. On success → App calls POST /user/razorpay/sucess
5. Navigate to PaymentSuccess screen

## 6. Cancel Subscription
- Subscription screen → Cancel Auto Pay → calls POST /user/subscription/cancel
