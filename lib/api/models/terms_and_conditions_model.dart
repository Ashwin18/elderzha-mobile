// To parse this JSON data, do
//
//     final getTermsAndConditionDetailsModel = getTermsAndConditionDetailsModelFromJson(jsonString);

import 'dart:convert';

GetTermsAndConditionDetailsModel getTermsAndConditionDetailsModelFromJson(
  String str,
) => GetTermsAndConditionDetailsModel.fromJson(json.decode(str));

String getTermsAndConditionDetailsModelToJson(
  GetTermsAndConditionDetailsModel data,
) => json.encode(data.toJson());

class GetTermsAndConditionDetailsModel {
  bool status;
  String message;
  TermsDetails data;

  GetTermsAndConditionDetailsModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetTermsAndConditionDetailsModel.fromJson(
    Map<String, dynamic> json,
  ) => GetTermsAndConditionDetailsModel(
    status: json["status"],
    message: json["message"],
    data: TermsDetails.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class TermsDetails {
  int id;
  String type;
  String title;
  String content;
  String status;

  TermsDetails({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.status,
  });

  factory TermsDetails.fromJson(Map<String, dynamic> json) => TermsDetails(
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
