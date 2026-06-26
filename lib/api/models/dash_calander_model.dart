import 'dart:convert';

DashCalanderModel dashCalanderModelFromJson(String str) =>
    DashCalanderModel.fromJson(json.decode(str));

String dashCalanderModelToJson(DashCalanderModel data) =>
    json.encode(data.toJson());

class DashCalanderModel {
  bool status;
  String message;
  DashCalanderData data;

  DashCalanderModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory DashCalanderModel.fromJson(Map<String, dynamic> json) =>
      DashCalanderModel(
        status: json["status"],
        message: json["message"],
        data: DashCalanderData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class DashCalanderData {
  String month;
  List<DailyActivities> dailyActivity;
  List<UpcomingReminder> upcomingReminders;

  DashCalanderData({
    required this.month,
    required this.dailyActivity,
    required this.upcomingReminders,
  });

  factory DashCalanderData.fromJson(Map<String, dynamic> json) =>
      DashCalanderData(
        month: json["month"],
        dailyActivity: List<DailyActivities>.from(
          json["daily_activity"].map((x) => DailyActivities.fromJson(x)),
        ),
        upcomingReminders: List<UpcomingReminder>.from(
          json["upcoming_reminders"].map((x) => UpcomingReminder.fromJson(x)),
        ),
      );

  Map<String, dynamic> toJson() => {
    "month": month,
    "daily_activity": List<dynamic>.from(dailyActivity.map((x) => x.toJson())),
    "upcoming_reminders": List<dynamic>.from(
      upcomingReminders.map((x) => x.toJson()),
    ),
  };
}

class DailyActivities {
  int id;
  String userId;
  DateTime date;
  Mood mood;
  String emojiImg;

  DailyActivities({
    required this.id,
    required this.userId,
    required this.date,
    required this.mood,
    required this.emojiImg,
  });

  factory DailyActivities.fromJson(Map<String, dynamic> json) =>
      DailyActivities(
        id: json["id"] ?? 0,
        userId: json["user_id"] ?? "",
        date: DateTime.parse(json["date"]),
        mood: moodValues.map[json["mood"]] ?? Mood.EMPTY, // FIXED
        emojiImg: json["mood_image"] ?? "",
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "date":
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
    "mood": moodValues.reverse[mood],
  };
}

enum Mood { DISGUST, EMPTY, LOVE }

final moodValues = EnumValues({
  "disgust": Mood.DISGUST,
  "": Mood.EMPTY,
  "love": Mood.LOVE,
});

class UpcomingReminder {
  int id;
  String title;
  DateTime date;
  String time;
  String notes;
  String uploadFile;
  String status;

  UpcomingReminder({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.notes,
    required this.uploadFile,
    required this.status,
  });

  factory UpcomingReminder.fromJson(Map<String, dynamic> json) =>
      UpcomingReminder(
        id: json["id"],
        title: json["title"],
        date: DateTime.parse(json["date"]),
        time: json["time"],
        notes: json["notes"],
        uploadFile: json["upload_file"],
        status: json["status"],
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "date":
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
    "time": time,
    "notes": notes,
    "upload_file": uploadFile,
    "status": status,
  };
}

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
