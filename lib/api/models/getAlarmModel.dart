import 'dart:convert';

GetAlarmModel getAlarmModelFromJson(String str) =>
    GetAlarmModel.fromJson(json.decode(str));

String getAlarmModelToJson(GetAlarmModel data) => json.encode(data.toJson());

class GetAlarmModel {
  bool status;
  String message;
  AlarmData? data;

  GetAlarmModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetAlarmModel.fromJson(Map<String, dynamic> json) => GetAlarmModel(
    status: json["status"],
    message: json["message"],
    data: json["data"] == null ? null : AlarmData.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data!.toJson(),
  };
}

class AlarmData {
  int id;
  String userId;
  bool medicalAlarm;
  bool morningStatus;
  String mBeforeFood;
  String mAfterFood;
  bool afternoonStatus;
  String afBeforeFood;
  String afAfterFood;
  bool nightStatus;
  String nBeforeFood;
  String nAfterFood;
  dynamic medicalFile;
  bool foodAlaram;
  bool breakfastStatus;
  String bfTime;
  bool lunchStatus;
  String lTime;
  bool dinnerStatus;
  String dTime;
  String alarmTone;
  dynamic foodFile;
  dynamic alaramTone;
  DateTime createdAt;
  DateTime updatedAt;

  AlarmData({
    required this.id,
    required this.userId,
    required this.medicalAlarm,
    required this.morningStatus,
    required this.mBeforeFood,
    required this.mAfterFood,
    required this.afternoonStatus,
    required this.afBeforeFood,
    required this.afAfterFood,
    required this.nightStatus,
    required this.nBeforeFood,
    required this.nAfterFood,
    required this.medicalFile,
    required this.foodAlaram,
    required this.breakfastStatus,
    required this.bfTime,
    required this.lunchStatus,
    required this.lTime,
    required this.dinnerStatus,
    required this.dTime,
    required this.foodFile,
    required this.alaramTone,
    required this.createdAt,
    required this.updatedAt,
    required this.alarmTone,
  });

  factory AlarmData.fromJson(Map<String, dynamic> json) => AlarmData(
    id: json["id"] ?? 0,
    userId: json["user_id"]?.toString() ?? "",

    medicalAlarm: json["medical_alarm"] ?? false,
    morningStatus: json["morning_status"] ?? false,
    mBeforeFood: json["m_before_food"] ?? "",
    mAfterFood: json["m_after_food"] ?? "",

    afternoonStatus: json["afternoon_status"] ?? false,
    afBeforeFood: json["af_before_food"] ?? "",
    afAfterFood: json["af_after_food"] ?? "",

    nightStatus: json["night_status"] ?? false,
    nBeforeFood: json["n_before_food"] ?? "",
    nAfterFood: json["n_after_food"] ?? "",

    medicalFile: json["medical_file"],
    alarmTone: json["alaram_tone"] ?? "",

    foodAlaram: json["food_alaram"] ?? json["food_alarm"] ?? false,
    breakfastStatus: json["breakfast_status"] ?? false,
    bfTime: json["bf_time"] ?? "",

    lunchStatus: json["lunch_status"] ?? false,
    lTime: json["l_time"] ?? "",

    dinnerStatus: json["dinner_status"] ?? false,
    dTime: json["d_time"] ?? "",

    foodFile: json["food_file"],
    alaramTone: json["alaram_tone"],

    createdAt: DateTime.tryParse(json["created_at"] ?? "") ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json["updated_at"] ?? "") ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
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
    "food_alaram": foodAlaram,
    "breakfast_status": breakfastStatus,
    "bf_time": bfTime,
    "alaram_tone": alarmTone,
    "lunch_status": lunchStatus,
    "l_time": lTime,
    "dinner_status": dinnerStatus,
    "d_time": dTime,
    "food_file": foodFile,
    "created_at": createdAt.toIso8601String(),
    "updated_at": updatedAt.toIso8601String(),
  };
}
