
import 'dart:convert';

ReminderListModel reminderListModelFromJson(String str) => ReminderListModel.fromJson(json.decode(str));

String reminderListModelToJson(ReminderListModel data) => json.encode(data.toJson());

class ReminderListModel {
  bool status;
  String message;
  List<ReminderListDatum> data;

  ReminderListModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ReminderListModel.fromJson(Map<String, dynamic> json) => ReminderListModel(
    status: json["status"],
    message: json["message"],
    data: List<ReminderListDatum>.from(json["data"].map((x) => ReminderListDatum.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class ReminderListDatum {
  int id;
  String title;
  String date;
  String time;
  String notes;
  String uploadFile;
  String status;

  ReminderListDatum({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.notes,
    required this.uploadFile,
    required this.status,
  });

  factory ReminderListDatum.fromJson(Map<String, dynamic> json) => ReminderListDatum(
    id: json["id"] ?? 0,
    title: json["title"] ?? "",
    date: json["date"] ?? "",
    time: json["time"] ?? "",
    notes: json["notes"] ?? "",
    uploadFile: json["upload_file"] ?? "",
    status: json["status"]?.toString() ?? "",  // ✅ int → String convert
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "date": date,
    "time": time,
    "notes": notes,
    "upload_file": uploadFile,
    "status": status,
  };
}
