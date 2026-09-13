// lib/navigation_key.dart
//
// Kept in its own file (rather than main.dart) so services like
// AuthService can trigger navigation (e.g. forcing a deleted
// account back to the registration screen) without creating a
// circular import — main.dart pulls in services/services.dart,
// which exports auth_service.dart, so auth_service.dart importing
// main.dart directly would cycle back on itself.
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
