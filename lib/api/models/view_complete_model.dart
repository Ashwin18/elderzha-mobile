
import 'dart:convert';

ViewCompleteDetails viewCompleteDetailsFromJson(String str) => ViewCompleteDetails.fromJson(json.decode(str));

String viewCompleteDetailsToJson(ViewCompleteDetails data) => json.encode(data.toJson());

class ViewCompleteDetails {
  bool status;
  String message;
  viewCompleteData data;

  ViewCompleteDetails({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ViewCompleteDetails.fromJson(Map<String, dynamic> json) => ViewCompleteDetails(
    status: json["status"],
    message: json["message"],
    data: viewCompleteData.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class viewCompleteData {
  String activityId;
  String title;
  String description;
  DateTime date;
  String time;
  String status;
  String notes;
  String uploadImage;

  viewCompleteData({
    required this.activityId,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.status,
    required this.notes,
    required this.uploadImage,
  });

  factory viewCompleteData.fromJson(Map<String, dynamic> json) => viewCompleteData(
    activityId: json["activity_id"]??"",
    title: json["title"]??"",
    description: json["description"]??"",
    date: DateTime.parse(json["date"]),
    time: json["time"]??"",
    status: json["status"]??"",
    notes: json["notes"]??"",
    uploadImage: json["upload_image"]??"",
  );

  Map<String, dynamic> toJson() => {
    "activity_id": activityId,
    "title": title,
    "description": description,
    "date": "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
    "time": time,
    "status": status,
    "notes": notes,
    "upload_image": uploadImage,
  };
}
