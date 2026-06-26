import 'dart:convert';

PollModel pollModelFromJson(String str) => PollModel.fromJson(json.decode(str));

String pollModelToJson(PollModel data) => json.encode(data.toJson());

class PollModel {
  bool status;
  String message;
  List<PollData> data;

  PollModel({required this.status, required this.message, required this.data});

  factory PollModel.fromJson(Map<String, dynamic> json) => PollModel(
    status: json["status"],
    message: json["message"],
    data: List<PollData>.from(json["data"].map((x) => PollData.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class PollData {
  int pollId;
  String question;
  String description;
  String status;
  String timer;
  String userSelected;
  String totalUsers;
  String totalAnswered;
  List<Option> options;

  PollData({
    required this.pollId,
    required this.question,
    required this.description,
    required this.status,
    required this.timer,
    required this.userSelected,
    required this.totalUsers,
    required this.totalAnswered,
    required this.options,
  });

  factory PollData.fromJson(Map<String, dynamic> json) => PollData(
    pollId: json["poll_id"] ?? 0,
    question: json["question"] ?? "",
    description: json["description"] ?? json["text_content"] ?? "",
    status: json["status"] ?? "",
    timer: json["timer"] ?? "",
    userSelected: json["user_selected"] ?? "",
    totalUsers: json["total_users"] ?? "",
    totalAnswered: json["total_answered"] ?? "",
    options: List<Option>.from(json["options"].map((x) => Option.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "poll_id": pollId,
    "question": question,
    "description": description,
    "status": status,
    "timer": timer,
    "user_selected": userSelected,
    "total_users": totalUsers,
    "total_answered": totalAnswered,
    "options": List<dynamic>.from(options.map((x) => x.toJson())),
  };
}

class Option {
  int optionId;
  String optionText;
  String percentage;

  Option({
    required this.optionId,
    required this.optionText,
    required this.percentage,
  });

  factory Option.fromJson(Map<String, dynamic> json) => Option(
    optionId: json["option_id"] ?? 0,
    optionText: json["option_text"] ?? "",
    percentage: json["percentage"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "option_id": optionId,
    "option_text": optionText,
    "percentage": percentage,
  };
}
