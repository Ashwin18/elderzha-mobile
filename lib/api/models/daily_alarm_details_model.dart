// To parse this JSON data, do
//
//     final getDailyAlarmDetailsModel = getDailyAlarmDetailsModelFromJson(jsonString);

import 'dart:convert';

GetDailyAlarmDetailsModel getDailyAlarmDetailsModelFromJson(String str) =>
    GetDailyAlarmDetailsModel.fromJson(json.decode(str));

String getDailyAlarmDetailsModelToJson(GetDailyAlarmDetailsModel data) =>
    json.encode(data.toJson());

class GetDailyAlarmDetailsModel {
  bool status;
  String message;
  AlarmDetails data;

  GetDailyAlarmDetailsModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetDailyAlarmDetailsModel.fromJson(Map<String, dynamic> json) =>
      GetDailyAlarmDetailsModel(
        status: json["status"],
        message: json["message"],
        data: AlarmDetails.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class AlarmDetails {
  String alarmTone;
  MedicalAlarm? medicalAlarm;
  FoodAlarm? foodAlarm;

  AlarmDetails({
    required this.alarmTone,
    required this.medicalAlarm,
    required this.foodAlarm,
  });

  factory AlarmDetails.fromJson(Map<String, dynamic> json) => AlarmDetails(
    alarmTone: json["alarmTone"] ?? "",
    medicalAlarm:
        json["medical_alarm"] == null
            ? null
            : MedicalAlarm.fromJson(json["medical_alarm"]),
    foodAlarm:
        json["food_alarm"] == null
            ? null
            : FoodAlarm.fromJson(json["food_alarm"]),
  );

  Map<String, dynamic> toJson() => {
    "alarmTone": alarmTone,
    "medical_alarm": medicalAlarm!.toJson(),
    "food_alarm": foodAlarm!.toJson(),
  };
}

class FoodAlarm {
  bool isEnable;
  String imageFile;
  Breakfast? breakfast;
  Breakfast? lunch;
  Breakfast? dinner;

  FoodAlarm({
    required this.isEnable,
    required this.imageFile,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  factory FoodAlarm.fromJson(Map<String, dynamic> json) => FoodAlarm(
    isEnable: json["isEnable"] ?? false,
    imageFile: json["imageFile"] ?? "",
    breakfast:
        json["breakfast"] == null
            ? null
            : Breakfast.fromJson(json["breakfast"]),
    lunch: json["lunch"] == null ? null : Breakfast.fromJson(json["lunch"]),
    dinner: json["dinner"] == null ? null : Breakfast.fromJson(json["dinner"]),
  );

  Map<String, dynamic> toJson() => {
    "isEnable": isEnable,
    "imageFile": imageFile,
    "breakfast": breakfast!.toJson(),
    "lunch": lunch!.toJson(),
    "dinner": dinner!.toJson(),
  };
}

class Breakfast {
  bool isEnable;
  String time;

  Breakfast({required this.isEnable, required this.time});

  factory Breakfast.fromJson(Map<String, dynamic> json) =>
      Breakfast(isEnable: json["isEnable"] ?? false, time: json["time"] ?? "");

  Map<String, dynamic> toJson() => {"isEnable": isEnable, "time": time};
}

class MedicalAlarm {
  bool isEnable;
  String imageFile;
  Morning? morning;
  Morning? noon;
  Morning? night;

  MedicalAlarm({
    required this.isEnable,
    required this.imageFile,
    required this.morning,
    required this.noon,
    required this.night,
  });

  factory MedicalAlarm.fromJson(Map<String, dynamic> json) => MedicalAlarm(
    isEnable: json["isEnable"] ?? false,
    imageFile: json["imageFile"] ?? "",
    morning: json["morning"] == null ? null : Morning.fromJson(json["morning"]),
    noon: json["noon"] == null ? null : Morning.fromJson(json["noon"]),
    night: json["night"] == null ? null : Morning.fromJson(json["night"]),
  );

  Map<String, dynamic> toJson() => {
    "isEnable": isEnable,
    "imageFile": imageFile,
    "morning": morning!.toJson(),
    "noon": noon!.toJson(),
    "night": night!.toJson(),
  };
}

class Morning {
  bool isEnable;
  String beforeFood;
  String afterFood;

  Morning({
    required this.isEnable,
    required this.beforeFood,
    required this.afterFood,
  });

  factory Morning.fromJson(Map<String, dynamic> json) => Morning(
    isEnable: json["isEnable"] ?? false,
    beforeFood: json["beforeFood"] ?? "",
    afterFood: json["afterFood"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "isEnable": isEnable,
    "beforeFood": beforeFood,
    "afterFood": afterFood,
  };
}
