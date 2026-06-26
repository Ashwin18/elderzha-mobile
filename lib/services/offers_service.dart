import 'api_client.dart';

/// Covers:
///   GET /user/offers/list          ← list all offers
///   GET /user/offer/details/{id}   ← single offer detail

class OffersService {
  final _api = ApiClient();

  Future<Map<String, dynamic>?> getOffersList() async {
    final candidates = [
      '/user/offers/list',
      '/user/offer/list',
      '/user/offers',
      '/user/offer/all',
      '/user/get/offers',
      '/user/coupon/list',
      '/user/coupons',
    ];
    Map<String, dynamic>? fallback;
    for (final path in candidates) {
      final res = await _api.safeGet(path);
      if (res == null) continue;
      if (_firstList(res).isNotEmpty) return res;
      if (res['status'] != false) fallback ??= res;
    }
    return fallback;
  }

  List _firstList(dynamic value) {
    if (value is List) return value;
    if (value is! Map) return [];
    for (final key in [
      'data',
      'offers',
      'offer',
      'coupons',
      'list',
      'items',
      'records',
      'results',
    ]) {
      final child = value[key];
      final list = _firstList(child);
      if (list.isNotEmpty) return list;
    }
    for (final child in value.values) {
      final list = _firstList(child);
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  Future<Map<String, dynamic>?> getOfferDetails(int id) =>
      _api.safeGet('/user/offer/details/$id');
}
