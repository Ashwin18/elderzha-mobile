import 'dart:convert';

EditModelMaster editModelMasterFromJson(String str) =>
    EditModelMaster.fromJson(json.decode(str));

String editModelMasterToJson(EditModelMaster data) =>
    json.encode(data.toJson());

class EditModelMaster {
  bool status;
  String message;
  List<EditMaster> data;

  EditModelMaster({
    required this.status,
    required this.message,
    required this.data,
  });

  factory EditModelMaster.fromJson(Map<String, dynamic> json) =>
      EditModelMaster(
        status: json["status"] ?? false,
        message: json["message"] ?? "",
        data: json["data"] == null
            ? []
            : List<EditMaster>.from(
            json["data"].map((x) => EditMaster.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class EditMaster {
  String id;
  Type type;
  String name;
  String icon;

  EditMaster({
    required this.id,
    required this.type,
    required this.name,
    required this.icon,
  });

  factory EditMaster.fromJson(Map<String, dynamic> json) => EditMaster(
    id: json["id"]?.toString() ?? "",
    type: typeValues.map[json["type"]] ??
        Type.UNKNOWN, // <-- safe fallback
    name: json["name"]?.toString() ?? "",
    icon: json["icon"]?.toString() ?? "",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "type": typeValues.reverse[type],
    "name": name,
    "icon": icon,
  };
}

enum Type {
  EVENT,
  RELATION,
  UNKNOWN, // <-- handles any unexpected value safely
}

final typeValues = EnumValues({
  "event": Type.EVENT,
  "relation": Type.RELATION,
});

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
