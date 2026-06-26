// To parse this JSON data, do
//
//     final viewActivityModel = viewActivityModelFromJson(jsonString);

import 'dart:convert';

ViewActivityModel viewActivityModelFromJson(String str) => ViewActivityModel.fromJson(json.decode(str));

String viewActivityModelToJson(ViewActivityModel data) => json.encode(data.toJson());

class ViewActivityModel {
  bool status;
  String message;
  ViewActivitiesData data;

  ViewActivityModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ViewActivityModel.fromJson(Map<String, dynamic> json) => ViewActivityModel(
    status: json["status"],
    message: json["message"],
    data: ViewActivitiesData.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class ViewActivitiesData {
  String currentPage;
  String perPage;
  String total;
  String lastPage;
  List<ViewActivities> data;

  ViewActivitiesData({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.data,
  });

  factory ViewActivitiesData.fromJson(Map<String, dynamic> json) => ViewActivitiesData(
    currentPage: json["current_page"]??"",
    perPage: json["per_page"]??"",
    total: json["total"]??"",
    lastPage: json["last_page"]??"",
    data: List<ViewActivities>.from(json["data"].map((x) => ViewActivities.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "current_page": currentPage,
    "per_page": perPage,
    "total": total,
    "last_page": lastPage,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class ViewActivities {
  int activityId;
  String title;
  String description;
  DateTime date;
  String time;
  String status;
  String sharedStatus;
  String replyAvailable;
  String shareAvailable;
  String expiry;
  String media;

  ViewActivities({
    required this.activityId,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.status,
    required this.replyAvailable,
    required this.expiry,
    required this.sharedStatus,
    required this.shareAvailable,
    required this.media,
  });

  factory ViewActivities.fromJson(Map<String, dynamic> json) => ViewActivities(
    activityId: json["activity_id"]??0,
    title: json["title"]??"",
    description: json["description"]??"",
    date: DateTime.parse(json["date"]),
    time: json["time"]??"",
    status: json["status"]??"",
    replyAvailable: json["reply_available"]??"",
    expiry: json["expiry"]??"",
    sharedStatus: json["shared_status"]??"",
    shareAvailable: json["share_available"]??"",
    media: json["media_url"]??"",
  );

  Map<String, dynamic> toJson() => {
    "activity_id": activityId,
    "title": title,
    "description": description,
    "date": "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
    "time": time,
    "status": status,
    "reply_available": replyAvailable,
    "shared_status": sharedStatus,
    "expiry": expiry,
    "share_available": shareAvailable,
    "media_url": media,
  };
}
