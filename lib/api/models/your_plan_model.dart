

  class YourPlanModel {
    bool status;
    String message;
    List<PlanData> data;

    YourPlanModel({
      required this.status,
      required this.message,
      required this.data,
    });

    factory YourPlanModel.fromJson(Map<String, dynamic> json) => YourPlanModel(
      status: json["status"] ?? false,
      message: json["message"] ?? "",
      data: json["data"] == null
          ? []
          : List<PlanData>.from(
          json["data"].map((x) => PlanData.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
      "status": status,
      "message": message,
      "data": List<dynamic>.from(data.map((x) => x.toJson())),
    };
  }

  class PlanData {
    int id;
    String planAmount;
    String type;
    List<String> access;

    PlanData({
      required this.id,
      required this.planAmount,
      required this.type,
      required this.access,
    });

    factory PlanData.fromJson(Map<String, dynamic> json) => PlanData(
      id: json["id"] ?? 0,
      planAmount: json["plan_amount"] ?? "",
      type: json["type"] ?? "",
      access: json["access"] == null
          ? []
          : List<String>.from(json["access"].map((x) => x)),
    );

    Map<String, dynamic> toJson() => {
      "id": id,
      "plan_amount": planAmount,
      "type": type,
      "access": List<dynamic>.from(access.map((x) => x)),
    };
  }
