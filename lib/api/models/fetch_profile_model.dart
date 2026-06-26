import 'dart:convert';

Empty emptyFromJson(String str) => Empty.fromJson(json.decode(str));

String emptyToJson(Empty data) => json.encode(data.toJson());

class Empty {
  bool status;
  String message;
  Data data;

  Empty({required this.status, required this.message, required this.data});

  factory Empty.fromJson(Map<String, dynamic> json) => Empty(
    status: json["status"],
    message: json["message"],
    data: Data.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class Data {
  User user;
  List<FamilyMember> familyMembers;

  Data({required this.user, required this.familyMembers});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    user: User.fromJson(json["user"]),
    familyMembers: List<FamilyMember>.from(
      json["family_members"].map((x) => FamilyMember.fromJson(x)),
    ),
  );

  Map<String, dynamic> toJson() => {
    "user": user.toJson(),
    "family_members": List<dynamic>.from(familyMembers.map((x) => x.toJson())),
  };
}

class FamilyMember {
  String id;
  String type;
  String status;
  String name;
  String eventDate;
  Event relation;
  Event event;

  FamilyMember({
    required this.id,
    required this.type,
    required this.status,
    required this.name,
    required this.eventDate,
    required this.relation,
    required this.event,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: json["id"] ?? "",
    type: json["type"] ?? "",
    status: json["status"] ?? "",
    name: json["name"] ?? "",
    eventDate: json["event_date"] ?? "",
    relation: Event.fromJson(json["relation"]),
    event: Event.fromJson(json["event"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "type": type,
    "status": status,
    "name": name,
    "event_date": eventDate,
    "relation": relation.toJson(),
    "event": event.toJson(),
  };
}

class Event {
  String id;
  String name;

  Event({required this.id, required this.name});

  factory Event.fromJson(Map<String, dynamic> json) =>
      Event(id: json["id"] ?? "", name: json["name"] ?? "");

  Map<String, dynamic> toJson() => {"id": id, "name": name};
}

class User {
  String id;
  String name;
  String email;
  String phone;
  String countryCode;
  String dob;
  String gender;
  String maritalStatus;
  String anniversaryDate;
  String spouseName;
  String spouseDob;
  String image;
  String alarmDone;
  String setProDone;
  String plan;
  int isPlanActive;
  int mood;
  int percent;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.countryCode,
    required this.dob,
    required this.gender,
    required this.maritalStatus,
    required this.anniversaryDate,
    required this.spouseName,
    required this.spouseDob,
    required this.image,
    required this.alarmDone,
    required this.setProDone,
    required this.percent,
    required this.plan,
    required this.mood,
    required this.isPlanActive,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"] ?? "",
    name: json["name"] ?? "",
    email: json["email"] ?? "",
    phone: json["phone"] ?? "",
    countryCode: json["country_code"] ?? "",
    dob: json["dob"] ?? "",
    gender: json["gender"] ?? "",
    maritalStatus: json["marital_status"] ?? "",
    anniversaryDate: json["anniversary_date"] ?? "",
    spouseName: json["spouse_name"] ?? "",
    spouseDob: json["spouse_dob"] ?? "",
    alarmDone: json["medicalSetting_status"] ?? "",
    setProDone: json["is_profile_updated"] ?? "",
    image: json["image"] ?? "",
    percent: json["profile_updated_percentage"] ?? 0,
    mood: json["mood_submitted_today"] ?? 0,
    plan: json["plan_status"] ?? "",
    isPlanActive: json["is_plan_active"] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "email": email,
    "phone": phone,
    "country_code": countryCode,
    "dob": dob,
    "gender": gender,
    "marital_status": maritalStatus,
    "anniversary_date": anniversaryDate,
    "spouse_name": spouseName,
    "medicalSetting_status": alarmDone,
    "spouse_dob": spouseDob,
    "is_profile_updated": setProDone,
    "image": image,
    "profile_updated_percentage": percent,
    "plan_status": plan,
    "mood_submitted_today": mood,
  };
}
