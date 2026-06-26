class OfferListResponse {
  OfferListResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  final bool status;
  final String message;
  final OfferPagination data;

  factory OfferListResponse.fromJson(Map<String, dynamic> json) {
    return OfferListResponse(
      status: json["status"] == true,
      message: json["message"]?.toString() ?? "",
      data: OfferPagination.fromJson(
        json["data"] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class OfferDetailsResponse {
  OfferDetailsResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  final bool status;
  final String message;
  final OfferData? data;

  factory OfferDetailsResponse.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json["data"];

    return OfferDetailsResponse(
      status: json["status"] == true,
      message: json["message"]?.toString() ?? "",
      data:
          rawData is Map<String, dynamic> ? OfferData.fromJson(rawData) : null,
    );
  }
}

class OfferPagination {
  OfferPagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.data,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final List<OfferData> data;

  factory OfferPagination.fromJson(Map<String, dynamic> json) {
    final List<dynamic> offers = json["data"] as List<dynamic>? ?? <dynamic>[];

    return OfferPagination(
      currentPage: _asInt(json["current_page"], fallback: 1),
      perPage: _asInt(json["per_page"], fallback: 10),
      total: _asInt(json["total"]),
      lastPage: _asInt(json["last_page"], fallback: 1),
      data:
          offers
              .whereType<Map<String, dynamic>>()
              .map(OfferData.fromJson)
              .toList(),
    );
  }
}

class OfferData {
  OfferData({
    required this.offerId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.couponCode,
    required this.startDate,
    required this.endDate,
    required this.badgeText,
    required this.badgeType,
    required this.status,
    required this.availableQuantity,
    required this.iconUrl,
    required this.bannerUrl,
    required this.storeLocation,
    required this.storeLink,
    required this.mapPreviewQuery,
  });

  final int offerId;
  final String title;
  final String subtitle;
  final String description;
  final String couponCode;
  final String startDate;
  final String endDate;
  final String badgeText;
  final String badgeType;
  final String status;
  final String availableQuantity;
  final String iconUrl;
  final String bannerUrl;
  final String storeLocation;
  final String storeLink;
  final String mapPreviewQuery;

  bool get hasBadge => badgeText.trim().isNotEmpty;
  bool get hasIcon => iconUrl.trim().isNotEmpty;
  bool get hasBanner => bannerUrl.trim().isNotEmpty;
  bool get hasStoreLink => storeLink.trim().isNotEmpty;
  bool get hasStoreLocation => storeLocation.trim().isNotEmpty;

  factory OfferData.fromJson(Map<String, dynamic> json) {
    return OfferData(
      offerId: _asInt(json["offer_id"]),
      title: json["title"]?.toString() ?? "",
      subtitle: json["subtitle"]?.toString() ?? "",
      description: json["description"]?.toString() ?? "",
      couponCode: json["coupon_code"]?.toString() ?? "",
      startDate: json["start_date"]?.toString() ?? "",
      endDate: json["end_date"]?.toString() ?? "",
      badgeText: json["badge_text"]?.toString() ?? "",
      badgeType: json["badge_type"]?.toString() ?? "",
      status: json["status"]?.toString() ?? "",
      availableQuantity: json["available_quantity"]?.toString() ?? "",
      iconUrl: json["icon_url"]?.toString() ?? "",
      bannerUrl: json["banner_url"]?.toString() ?? "",
      storeLocation: json["store_location"]?.toString() ?? "",
      storeLink: json["store_link"]?.toString() ?? "",
      mapPreviewQuery: json["map_preview_query"]?.toString() ?? "",
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? "") ?? fallback;
}
