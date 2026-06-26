// To parse this JSON data, do
//
//     final getTodayMoodModel = getTodayMoodModelFromJson(jsonString);

import 'dart:convert';

GetTodayMoodModel getTodayMoodModelFromJson(String str) =>
    GetTodayMoodModel.fromJson(json.decode(str));

String getTodayMoodModelToJson(GetTodayMoodModel data) =>
    json.encode(data.toJson());

class GetTodayMoodModel {
  bool status;
  String message;
  TodayMoodDetails data;

  GetTodayMoodModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetTodayMoodModel.fromJson(Map<String, dynamic> json) =>
      GetTodayMoodModel(
        status: json["status"],
        message: json["message"],
        data: TodayMoodDetails.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class TodayMoodDetails {
  int id;
  String userId;
  DateTime? date;
  String mood;
  List<String> peopleMet;
  List<String> placesVisited;
  List<String> activitiesDone;
  String weather;
  String sleepTime;
  String notes;

  TodayMoodDetails({
    required this.id,
    required this.userId,
    required this.date,
    required this.mood,
    required this.peopleMet,
    required this.placesVisited,
    required this.activitiesDone,
    required this.weather,
    required this.sleepTime,
    required this.notes,
  });

  factory TodayMoodDetails.fromJson(Map<String, dynamic> json) =>
      TodayMoodDetails(
        id: json["id"] ?? 0,
        userId: json["user_id"] ?? "",
        date: json["date"] == null ? null : DateTime.parse(json["date"]),
        mood: json["mood"] ?? "",
        peopleMet:
            json["people_met"] == null
                ? []
                : List<String>.from(json["people_met"].map((x) => x)),
        placesVisited:
            json["places_visited"] == null
                ? []
                : List<String>.from(json["places_visited"].map((x) => x)),
        activitiesDone:
            json["activities_done"] == null
                ? []
                : List<String>.from(json["activities_done"].map((x) => x)),
        weather: json["weather"] ?? "",
        sleepTime: json["sleep_time"] ?? "",
        notes: json["notes"] ?? "",
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "date": date!.toIso8601String(),
    "mood": mood,
    "people_met": List<dynamic>.from(peopleMet.map((x) => x)),
    "places_visited": List<dynamic>.from(placesVisited.map((x) => x)),
    "activities_done": List<dynamic>.from(activitiesDone.map((x) => x)),
    "weather": weather,
    "sleep_time": sleepTime,
    "notes": notes,
  };
}
