// To parse this JSON data, do
//
//     final getPaymentHistoryModel = getPaymentHistoryModelFromJson(jsonString);

import 'dart:convert';

GetPaymentHistoryModel getPaymentHistoryModelFromJson(String str) =>
    GetPaymentHistoryModel.fromJson(json.decode(str));

String getPaymentHistoryModelToJson(GetPaymentHistoryModel data) =>
    json.encode(data.toJson());

class GetPaymentHistoryModel {
  bool status;
  String message;
  List<PaymentHistoryModel> data;

  GetPaymentHistoryModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetPaymentHistoryModel.fromJson(Map<String, dynamic> json) =>
      GetPaymentHistoryModel(
        status: json["status"],
        message: json["message"],
        data: List<PaymentHistoryModel>.from(
          json["data"].map((x) => PaymentHistoryModel.fromJson(x)),
        ),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class PaymentHistoryModel {
  String id;
  String amount;
  DateTime? purchaseDate;
  DateTime? expiryDate;
  String paymentStatus;
  String transactionId;
  String referenceId;
  DateTime? createdAt;

  PaymentHistoryModel({
    required this.id,
    required this.amount,
    required this.purchaseDate,
    required this.expiryDate,
    required this.paymentStatus,
    required this.transactionId,
    required this.referenceId,
    required this.createdAt,
  });

  factory PaymentHistoryModel.fromJson(Map<String, dynamic> json) =>
      PaymentHistoryModel(
        id: json["id"] ?? "",
        amount: json["amount"] ?? "",
        purchaseDate:
            json["purchase_date"] == null
                ? null
                : DateTime.parse(json["purchase_date"]),
        expiryDate:
            json["expiry_date"] == null
                ? null
                : DateTime.parse(json["expiry_date"]),
        paymentStatus: json["payment_status"] ?? "",
        transactionId: json["transaction_id"] ?? "",
        referenceId: json["reference_id"] ?? "",
        createdAt:
            json["created_at"] == null
                ? null
                : DateTime.parse(json["created_at"]),
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "amount": amount,
    "purchase_date":
        "${purchaseDate!.year.toString().padLeft(4, '0')}-${purchaseDate!.month.toString().padLeft(2, '0')}-${purchaseDate!.day.toString().padLeft(2, '0')}",
    "expiry_date":
        "${expiryDate!.year.toString().padLeft(4, '0')}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}",
    "payment_status": paymentStatus,
    "transaction_id": transactionId,
    "reference_id": referenceId,
    "created_at": createdAt!.toIso8601String(),
  };
}
