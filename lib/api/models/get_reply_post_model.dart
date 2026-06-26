// To parse this JSON data, do
//
//     final getReplyPostModel = getReplyPostModelFromJson(jsonString);

import 'dart:convert';

GetReplyPostModel getReplyPostModelFromJson(String str) =>
    GetReplyPostModel.fromJson(json.decode(str));

String getReplyPostModelToJson(GetReplyPostModel data) =>
    json.encode(data.toJson());

class GetReplyPostModel {
  bool status;
  String message;
  ReplyPostDetails data;

  GetReplyPostModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetReplyPostModel.fromJson(Map<String, dynamic> json) =>
      GetReplyPostModel(
        status: json["status"],
        message: json["message"],
        data: ReplyPostDetails.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class ReplyPostDetails {
  int currentPage;
  List<PostDetails>? data;
  String firstPageUrl;
  int from;
  int lastPage;
  String lastPageUrl;
  dynamic nextPageUrl;
  String path;
  int perPage;
  dynamic prevPageUrl;
  int to;
  int total;

  ReplyPostDetails({
    required this.currentPage,
    required this.data,
    required this.firstPageUrl,
    required this.from,
    required this.lastPage,
    required this.lastPageUrl,
    required this.nextPageUrl,
    required this.path,
    required this.perPage,
    required this.prevPageUrl,
    required this.to,
    required this.total,
  });

  factory ReplyPostDetails.fromJson(Map<String, dynamic> json) =>
      ReplyPostDetails(
        currentPage: json["current_page"] ?? 0,
        data:
            json["data"] == null
                ? null
                : List<PostDetails>.from(
                  json["data"].map((x) => PostDetails.fromJson(x)),
                ),
        firstPageUrl: json["first_page_url"] ?? "",
        from: json["from"] ?? 0,
        lastPage: json["last_page"] ?? 0,
        lastPageUrl: json["last_page_url"] ?? "",
        nextPageUrl: json["next_page_url"] ?? "",
        path: json["path"] ?? "",
        perPage: json["per_page"] ?? "",
        prevPageUrl: json["prev_page_url"] ?? "",
        to: json["to"] ?? 0,
        total: json["total"] ?? 0,
      );

  Map<String, dynamic> toJson() => {
    "current_page": currentPage,
    "data": List<dynamic>.from(data!.map((x) => x.toJson())),
    "first_page_url": firstPageUrl,
    "from": from,
    "last_page": lastPage,
    "last_page_url": lastPageUrl,
    "next_page_url": nextPageUrl,
    "path": path,
    "per_page": perPage,
    "prev_page_url": prevPageUrl,
    "to": to,
    "total": total,
  };
}

class PostDetails {
  String type;
  int id;
  String notes;
  dynamic image;
  int likesCount;
  bool isLiked;
  DateTime? createdAt;
  int userId;        // ✅ String → int
  String userName;
  dynamic userImage;

  PostDetails({
    required this.type,
    required this.id,
    required this.notes,
    required this.image,
    required this.likesCount,
    required this.isLiked,
    required this.createdAt,
    required this.userId,
    required this.userName,
    required this.userImage,
  });

  factory PostDetails.fromJson(Map<String, dynamic> json) => PostDetails(
    id: json["id"] ?? 0,
    type: json["type"]?.toString() ?? "",
    notes: json["notes"]?.toString() ?? "",
    image: json["image"]?.toString() ?? "",
    likesCount: json["likes_count"] ?? 0,
    isLiked: json["is_liked"] ?? false,
    userId: json["user_id"] ?? 0,                              // ✅ int
    userName: json["user_name"]?.toString() ?? "",
    userImage: json["user_image"]?.toString() ?? "",
    createdAt: json["created_at"] != null                      // ✅ DateTime
        ? DateTime.tryParse(json["created_at"].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "id": id,
    "notes": notes,
    "image": image,
    "likes_count": likesCount,
    "is_liked": isLiked,
    "created_at": createdAt?.toIso8601String(),               // ✅ null safe
    "user_id": userId,
    "user_name": userName,
    "user_image": userImage,
  };
}
