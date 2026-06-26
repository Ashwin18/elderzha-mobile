

import 'dart:convert';

AlarmReminderModel alarmReminderModelFromJson(String str) => AlarmReminderModel.fromJson(json.decode(str));

String alarmReminderModelToJson(AlarmReminderModel data) => json.encode(data.toJson());

class AlarmReminderModel {
  bool status;
  String message;
  List<AlarmReminderData> data;

  AlarmReminderModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory AlarmReminderModel.fromJson(Map<String, dynamic> json) => AlarmReminderModel(
    status: json["status"],
    message: json["message"],
    data: List<AlarmReminderData>.from(json["data"].map((x) => AlarmReminderData.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class AlarmReminderData {
  String title;
  String date;
  String time;
  String notes;
  String uploadFile;
  String ringtone;

  AlarmReminderData({
    required this.title,
    required this.date,
    required this.time,
    required this.notes,
    required this.uploadFile,
    required this.ringtone,
  });

  factory AlarmReminderData.fromJson(Map<String, dynamic> json) => AlarmReminderData(
    title: json["title"]??"",
    date: json["date"],
    time: json["time"]??"",
    notes: json["notes"]??"",
    uploadFile: json["upload_file"]??"",
    ringtone: json["ringtone"]??"",
  );

  Map<String, dynamic> toJson() => {
    "title": title,
    "date": date,
    "time": time,
    "notes": notes,
    "upload_file": uploadFile,
    "ringtone": ringtone,
  };
}
