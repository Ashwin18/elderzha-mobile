import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Whether this member should see the newest features (Refer & Earn,
/// Register now). The admin decides in Admin > Early Access: a list of
/// mobile numbers, or a switch that turns it on for everyone.
class FeatureFlags {
  static final ApiClient _api = ApiClient();

  static final ValueNotifier<bool> newFeatures = ValueNotifier<bool>(false);

  /// Admin-set seeds a member earns per successful referral.
  static final ValueNotifier<int> seedsPerReferral = ValueNotifier<int>(100);

  /// Zha Seeds this member has earned so far, and seeds not yet celebrated.
  static final ValueNotifier<int> seedsTotal = ValueNotifier<int>(0);
  static int unseenSeeds = 0;

  static Future<void> load() async {
    final res = await _api.safeGet('/user/features');
    if (res != null && res['status'] == true && res['data'] is Map) {
      final d = res['data'] as Map;
      seedsPerReferral.value = int.tryParse('${d['seeds_per_referral'] ?? 100}') ?? 100;
      seedsTotal.value = int.tryParse('${d['seeds_total'] ?? 0}') ?? 0;
      unseenSeeds = int.tryParse('${d['unseen_seeds'] ?? 0}') ?? 0;
      newFeatures.value = d['new_features'] == true;
    }
  }

  static void reset() {
    newFeatures.value = false;
    seedsTotal.value = 0;
    unseenSeeds = 0;
  }
}
