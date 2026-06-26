// To parse this JSON data, do
//
//     final getIssueTypeModel = getIssueTypeModelFromJson(jsonString);

import 'dart:convert';

GetIssueTypeModel getIssueTypeModelFromJson(String str) =>
    GetIssueTypeModel.fromJson(json.decode(str));

String getIssueTypeModelToJson(GetIssueTypeModel data) =>
    json.encode(data.toJson());

class GetIssueTypeModel {
  bool status;
  String message;
  List<IssueTypeModel> data;

  GetIssueTypeModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetIssueTypeModel.fromJson(Map<String, dynamic> json) =>
      GetIssueTypeModel(
        status: json["status"],
        message: json["message"],
        data: List<IssueTypeModel>.from(
          json["data"].map((x) => IssueTypeModel.fromJson(x)),
        ),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class IssueTypeModel {
  int id;
  String name;
  String description;

  IssueTypeModel({
    required this.id,
    required this.name,
    required this.description,
  });

  factory IssueTypeModel.fromJson(Map<String, dynamic> json) => IssueTypeModel(
    id: json["id"] ?? 0,
    name: json["name"] ?? "",
    description: json["description"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "description": description,
  };
}
