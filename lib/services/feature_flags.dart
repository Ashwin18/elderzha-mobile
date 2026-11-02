import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Whether this member should see the newest features (Refer a Friend,
/// Register now). The admin decides in Admin > Early Access: a list of
/// mobile numbers, or a switch that turns it on for everyone.
class FeatureFlags {
  static final ApiClient _api = ApiClient();

  static final ValueNotifier<bool> newFeatures = ValueNotifier<bool>(false);

  static Future<void> load() async {
    final res = await _api.safeGet('/user/features');
    if (res != null && res['status'] == true && res['data'] is Map) {
      newFeatures.value = (res['data'] as Map)['new_features'] == true;
    }
  }

  static void reset() => newFeatures.value = false;
}
