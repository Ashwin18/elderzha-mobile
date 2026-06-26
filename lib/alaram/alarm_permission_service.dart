import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _alarmPermissionChannel = MethodChannel('alarm_service');

class AlarmPermissionService {
  static bool _hasCheckedFullScreenPermission = false;

  static Future<void> ensureFullScreenIntentPermission() async {
    if (!Platform.isAndroid || _hasCheckedFullScreenPermission) {
      return;
    }

    try {
      final allowed =
          await _alarmPermissionChannel.invokeMethod<bool>(
            'canUseFullScreenIntent',
          ) ??
          true;

      if (!allowed) {
        await _alarmPermissionChannel.invokeMethod(
          'requestFullScreenIntentPermission',
        );
      }
    } catch (_) {
      // Ignore permission bridge failures and keep alarm scheduling functional.
    } finally {
      _hasCheckedFullScreenPermission = true;
    }
  }
}
