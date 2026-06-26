// To parse this JSON data, do
//
//     final notificationDetailsModel = notificationDetailsModelFromJson(jsonString);

import 'dart:convert';

NotificationDetailsModel notificationDetailsModelFromJson(String str) => NotificationDetailsModel.fromJson(json.decode(str));

String notificationDetailsModelToJson(NotificationDetailsModel data) => json.encode(data.toJson());

class NotificationDetailsModel {
    bool status;
    String message;
    List<NotificationDetails> data;

    NotificationDetailsModel({
        required this.status,
        required this.message,
        required this.data,
    });

    factory NotificationDetailsModel.fromJson(Map<String, dynamic> json) => NotificationDetailsModel(
        status: json["status"],
        message: json["message"],
        data: List<NotificationDetails>.from(json["data"].map((x) => NotificationDetails.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
    };
}

class NotificationDetails {
    String date;
    List<Notification>? notifications;

    NotificationDetails({
        required this.date,
        required this.notifications,
    });

    factory NotificationDetails.fromJson(Map<String, dynamic> json) => NotificationDetails(
        date: json["date"] ?? "",
        notifications: json["notifications"] == null ? null : List<Notification>.from(json["notifications"].map((x) => Notification.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "date": date,
        "notifications": List<dynamic>.from(notifications!.map((x) => x.toJson())),
    };
}

class Notification {
    String id;
    String title;
    String message;
    String status;
    String timeline;

    Notification({
        required this.id,
        required this.title,
        required this.message,
        required this.status,
        required this.timeline,
    });

    factory Notification.fromJson(Map<String, dynamic> json) => Notification(
        id: json["id"] ?? "",
        title: json["title"] ?? "",
        message: json["message"] ?? "",
        status: json["status"],
        timeline: json["timeline"] ?? "",
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "message": message,
        "status": status,
        "timeline": timeline,
    };
}

