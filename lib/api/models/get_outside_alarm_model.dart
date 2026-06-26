

import 'dart:convert';

GetAutoRingAlarmModel getAutoRingAlarmModelFromJson(String str) => GetAutoRingAlarmModel.fromJson(json.decode(str));

String getAutoRingAlarmModelToJson(GetAutoRingAlarmModel data) => json.encode(data.toJson());

class GetAutoRingAlarmModel {
  bool status;
  String message;
  OutsideAlarmData data;

  GetAutoRingAlarmModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetAutoRingAlarmModel.fromJson(Map<String, dynamic> json) => GetAutoRingAlarmModel(
    status: json["status"],
    message: json["message"],
    data: OutsideAlarmData.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class OutsideAlarmData {
  String mBeforeFood;
  String mAfterFood;
  String afBeforeFood;
  String afAfterFood;
  String nBeforeFood;
  String nAfterFood;
  String medicalFile;
  String foodFile;
  String alaramTone;

  OutsideAlarmData({
    required this.mBeforeFood,
    required this.mAfterFood,
    required this.afBeforeFood,
    required this.afAfterFood,
    required this.nBeforeFood,
    required this.nAfterFood,
    required this.medicalFile,
    required this.foodFile,
    required this.alaramTone,
  });

  factory OutsideAlarmData.fromJson(Map<String, dynamic> json) => OutsideAlarmData(
    mBeforeFood: json["m_before_food"]??"",
    mAfterFood: json["m_after_food"]??"",
    afBeforeFood: json["af_before_food"]??"",
    afAfterFood: json["af_after_food"]??"",
    nBeforeFood: json["n_before_food"]??"",
    nAfterFood: json["n_after_food"]??"",
    medicalFile: json["medical_file"]??"",
    foodFile: json["food_file"]??"",
    alaramTone: json["alaram_tone"]??"",
  );

  Map<String, dynamic> toJson() => {
    "m_before_food": mBeforeFood,
    "m_after_food": mAfterFood,
    "af_before_food": afBeforeFood,
    "af_after_food": afAfterFood,
    "n_before_food": nBeforeFood,
    "n_after_food": nAfterFood,
    "medical_file": medicalFile,
    "food_file": foodFile,
    "alaram_tone": alaramTone,
  };
}
