

import 'dart:convert';

FaqModel faqModelFromJson(String str) => FaqModel.fromJson(json.decode(str));

String faqModelToJson(FaqModel data) => json.encode(data.toJson());

class FaqModel {
  bool status;
  String message;
  List<FaqData> data;

  FaqModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory FaqModel.fromJson(Map<String, dynamic> json) => FaqModel(
    status: json["status"],
    message: json["message"],
    data: List<FaqData>.from(json["data"].map((x) => FaqData.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class FaqData {
  int id;
  String name;
  String value;

  FaqData({
    required this.id,
    required this.name,
    required this.value,
  });

  factory FaqData.fromJson(Map<String, dynamic> json) => FaqData(
    id: json["id"]??0,
    name: json["name"]??'',
    value: json["value"]??"",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "value": value,
  };
}
