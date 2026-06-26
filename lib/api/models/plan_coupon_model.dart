class PlanCouponResponse {
  bool status;
  String message;
  PlanCouponData? data;

  PlanCouponResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory PlanCouponResponse.fromJson(Map<String, dynamic> json) {
    return PlanCouponResponse(
      status: json["status"] ?? false,
      message: json["message"] ?? "",
      data:
          json["data"] is Map<String, dynamic>
              ? PlanCouponData.fromJson(json["data"])
              : null,
    );
  }
}

class PlanCouponData {
  int planId;
  String planName;
  String mobileNumber;
  bool couponAvailable;
  bool couponApplied;
  int? couponId;
  String couponCode;
  String couponAmount;
  String discountAmount;
  String planAmount;
  String finalAmount;
  String usageStatus;
  int isActive;
  String? expiryDate;
  bool activateWithoutPayment;

  PlanCouponData({
    required this.planId,
    required this.planName,
    required this.mobileNumber,
    required this.couponAvailable,
    required this.couponApplied,
    required this.couponId,
    required this.couponCode,
    required this.couponAmount,
    required this.discountAmount,
    required this.planAmount,
    required this.finalAmount,
    required this.usageStatus,
    required this.isActive,
    required this.expiryDate,
    required this.activateWithoutPayment,
  });

  factory PlanCouponData.fromJson(Map<String, dynamic> json) {
    return PlanCouponData(
      planId: json["plan_id"] ?? 0,
      planName: json["plan_name"]?.toString() ?? "",
      mobileNumber: json["mobile_number"]?.toString() ?? "",
      couponAvailable: json["coupon_available"] == true,
      couponApplied: json["coupon_applied"] == true,
      couponId: json["coupon_id"] as int?,
      couponCode: json["coupon_code"]?.toString() ?? "",
      couponAmount: json["coupon_amount"]?.toString() ?? "0.00",
      discountAmount: json["discount_amount"]?.toString() ?? "0.00",
      planAmount: json["plan_amount"]?.toString() ?? "0.00",
      finalAmount: json["final_amount"]?.toString() ?? "0.00",
      usageStatus: json["usage_status"]?.toString() ?? "unused",
      isActive: json["is_active"] ?? 0,
      expiryDate: json["expiry_date"]?.toString(),
      activateWithoutPayment: json["activate_without_payment"] == true,
    );
  }
}
