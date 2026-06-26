// To parse this JSON data, do
//
//     final getAutoRingAlarmModel = getAutoRingAlarmModelFromJson(jsonString);

import 'dart:convert';

GetAutoRingAlarmModel getAutoRingAlarmModelFromJson(String str) =>
    GetAutoRingAlarmModel.fromJson(json.decode(str));

String getAutoRingAlarmModelToJson(GetAutoRingAlarmModel data) =>
    json.encode(data.toJson());

class GetAutoRingAlarmModel {
  bool? status;
  String? message;
  Data? data;

  GetAutoRingAlarmModel({this.status, this.message, this.data});

  factory GetAutoRingAlarmModel.fromJson(Map<String, dynamic> json) =>
      GetAutoRingAlarmModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] != null ? Data.fromJson(json["data"]) : null,
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data?.toJson(),
  };
}

class Data {
  String? userId;
  MedicalData? medicalData;
  FoodData? foodData;
  String? alaramTone;

  Data({this.userId, this.medicalData, this.foodData, this.alaramTone});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    userId: json["user_id"],
    medicalData:
        json["medical_data"] != null
            ? MedicalData.fromJson(json["medical_data"])
            : null,
    foodData:
        json["food_data"] != null ? FoodData.fromJson(json["food_data"]) : null,
    alaramTone: json["alaram_tone"],
  );

  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "medical_data": medicalData?.toJson(),
    "food_data": foodData?.toJson(),
    "alaram_tone": alaramTone,
  };
}

class FoodData {
  bool? foodAlaram;
  bool? breakfastStatus;
  String? bfTime;
  bool? lunchStatus;
  String? lTime;
  bool? dinnerStatus;
  String? dTime;
  String? foodFile;

  FoodData({
    this.foodAlaram,
    this.breakfastStatus,
    this.bfTime,
    this.lunchStatus,
    this.lTime,
    this.dinnerStatus,
    this.dTime,
    this.foodFile,
  });

  factory FoodData.fromJson(Map<String, dynamic> json) => FoodData(
    foodAlaram: json["food_alaram"] ?? json["food_alarm"],
    breakfastStatus: json["breakfast_status"],
    bfTime: json["bf_time"],
    lunchStatus: json["lunch_status"],
    lTime: json["l_time"],
    dinnerStatus: json["dinner_status"],
    dTime: json["d_time"],
    foodFile: json["food_file"],
  );

  Map<String, dynamic> toJson() => {
    "food_alaram": foodAlaram,
    "breakfast_status": breakfastStatus,
    "bf_time": bfTime,
    "lunch_status": lunchStatus,
    "l_time": lTime,
    "dinner_status": dinnerStatus,
    "d_time": dTime,
    "food_file": foodFile,
  };
}

class MedicalData {
  bool? medicalAlarm;
  bool? morningStatus;
  String? mBeforeFood;
  String? mAfterFood;
  bool? afternoonStatus;
  String? afBeforeFood;
  String? afAfterFood;
  bool? nightStatus;
  String? nBeforeFood;
  String? nAfterFood;
  String? medicalFile;

  MedicalData({
    this.medicalAlarm,
    this.morningStatus,
    this.mBeforeFood,
    this.mAfterFood,
    this.afternoonStatus,
    this.afBeforeFood,
    this.afAfterFood,
    this.nightStatus,
    this.nBeforeFood,
    this.nAfterFood,
    this.medicalFile,
  });

  factory MedicalData.fromJson(Map<String, dynamic> json) => MedicalData(
    medicalAlarm: json["medical_alarm"],
    morningStatus: json["morning_status"],
    mBeforeFood: json["m_before_food"],
    mAfterFood: json["m_after_food"],
    afternoonStatus: json["afternoon_status"],
    afBeforeFood: json["af_before_food"],
    afAfterFood: json["af_after_food"],
    nightStatus: json["night_status"],
    nBeforeFood: json["n_before_food"],
    nAfterFood: json["n_after_food"],
    medicalFile: json["medical_file"],
  );

  Map<String, dynamic> toJson() => {
    "medical_alarm": medicalAlarm,
    "morning_status": morningStatus,
    "m_before_food": mBeforeFood,
    "m_after_food": mAfterFood,
    "afternoon_status": afternoonStatus,
    "af_before_food": afBeforeFood,
    "af_after_food": afAfterFood,
    "night_status": nightStatus,
    "n_before_food": nBeforeFood,
    "n_after_food": nAfterFood,
    "medical_file": medicalFile,
  };
}
