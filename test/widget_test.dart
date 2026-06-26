import 'package:flutter_test/flutter_test.dart';

import 'package:elderzha/utils/app_routes.dart';

void main() {
  test('critical app routes are registered names', () {
    expect(AppRoutes.splash, '/');
    expect(AppRoutes.home, '/home');
    expect(AppRoutes.notifications, '/notifications');
    expect(AppRoutes.community, '/community');
    expect(AppRoutes.offers, '/offers');
  });
}
