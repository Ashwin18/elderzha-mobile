// To parse this JSON data, do
//
//     final purchasedModel = purchasedModelFromJson(jsonString);

import 'dart:convert';

PurchasedModel purchasedModelFromJson(String str) => PurchasedModel.fromJson(json.decode(str));

String purchasedModelToJson(PurchasedModel data) => json.encode(data.toJson());

class PurchasedModel {
  bool status;
  String message;
  List<PurchasedData> data;

  PurchasedModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory PurchasedModel.fromJson(Map<String, dynamic> json) => PurchasedModel(
    status: json["status"],
    message: json["message"],
    data: List<PurchasedData>.from(json["data"].map((x) => PurchasedData.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class PurchasedData {
  int id;
  String planAmount;
  String type;
  List<String> access;

  PurchasedData({
    required this.id,
    required this.planAmount,
    required this.type,
    required this.access,
  });

  factory PurchasedData.fromJson(Map<String, dynamic> json) => PurchasedData(
    id: json["id"]??0,
    planAmount: json["plan_amount"]??"",
    type: json["type"]??"",
    access: List<String>.from(json["access"].map((x) => x)),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "plan_amount": planAmount,
    "type": type,
    "access": List<dynamic>.from(access.map((x) => x)),
  };
}
