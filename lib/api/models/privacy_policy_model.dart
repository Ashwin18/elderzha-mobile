// To parse this JSON data, do
//
//     final getPrivacyPolicyDetailsModel = getPrivacyPolicyDetailsModelFromJson(jsonString);

import 'dart:convert';

GetPrivacyPolicyDetailsModel getPrivacyPolicyDetailsModelFromJson(String str) =>
    GetPrivacyPolicyDetailsModel.fromJson(json.decode(str));

String getPrivacyPolicyDetailsModelToJson(GetPrivacyPolicyDetailsModel data) =>
    json.encode(data.toJson());

class GetPrivacyPolicyDetailsModel {
  bool status;
  String message;
  PolicyDetails data;

  GetPrivacyPolicyDetailsModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetPrivacyPolicyDetailsModel.fromJson(Map<String, dynamic> json) =>
      GetPrivacyPolicyDetailsModel(
        status: json["status"],
        message: json["message"],
        data: PolicyDetails.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class PolicyDetails {
  int id;
  String type;
  String title;
  String content;
  String status;

  PolicyDetails({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.status,
  });

  factory PolicyDetails.fromJson(Map<String, dynamic> json) => PolicyDetails(
    id: json["id"] ?? 0,
    type: json["type"] ?? "",
    title: json["title"] ?? "",
    content: json["content"] ?? "",
    status: json["status"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "type": type,
    "title": title,
    "content": content,
    "status": status,
  };
}
