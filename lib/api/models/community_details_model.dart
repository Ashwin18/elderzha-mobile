import 'dart:convert';

CommunityDetailsModel communityDetailsModelFromJson(String str) =>
    CommunityDetailsModel.fromJson(json.decode(str));

String communityDetailsModelToJson(CommunityDetailsModel data) =>
    json.encode(data.toJson());

bool _isTruthy(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalized = value?.toString().toLowerCase().trim();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

class CommunityDetailsModel {
  bool status;
  String message;
  CommunityDetails data;

  CommunityDetailsModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory CommunityDetailsModel.fromJson(Map<String, dynamic> json) =>
      CommunityDetailsModel(
        status: json["status"],
        message: json["message"],
        data: CommunityDetails.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

class CommunityDetails {
  List<Activity> activities;
  List<Feed> feed;

  CommunityDetails({required this.activities, required this.feed});

  factory CommunityDetails.fromJson(Map<String, dynamic> json) =>
      CommunityDetails(
        activities:
            json["activities"] == null
                ? []
                : List<Activity>.from(
                  json["activities"].map((x) => Activity.fromJson(x)),
                ),
        feed:
            json["feed"] == null
                ? []
                : List<Feed>.from(json["feed"].map((x) => Feed.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
    "activities": List<dynamic>.from(activities.map((x) => x.toJson())),
    "feed": List<dynamic>.from(feed.map((x) => x.toJson())),
  };
}

class Activity {
  String type;
  int activityId;
  String title;
  DateTime? date;
  String time;
  String status;
  String postType;
  String textContent;
  String mediaUrl;
  String youtubeLink;
  DateTime? createdAt;
  String adminName;
  String adminImage;
  bool replySent;
  String approvalStatus;
  bool replyApproved;

  Activity({
    required this.type,
    required this.activityId,
    required this.title,
    required this.date,
    required this.time,
    required this.status,
    required this.postType,
    required this.textContent,
    required this.mediaUrl,
    required this.youtubeLink,
    required this.createdAt,
    required this.adminName,
    required this.adminImage,
    required this.replySent,
    required this.approvalStatus,
    required this.replyApproved,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    final status = (json["status"] ?? "").toString();
    final approvalStatus = (json["approval_status"] ?? "").toString();
    final replySent =
        _isTruthy(json["reply_sent"]) ||
        status.toLowerCase() == "completed" ||
        status.toLowerCase() == "pending_review";
    final replyApproved =
        _isTruthy(json["reply_approved"]) ||
        approvalStatus.toLowerCase() == "approved";

    return Activity(
      type: json["type"] ?? "",
      activityId: json["activity_id"] ?? 0,
      title: json["title"] ?? "",
      date: json["date"] == null ? null : DateTime.tryParse(json["date"]),
      time: json["time"] ?? "",
      status: status,
      postType: json["post_type"] ?? "",
      textContent: json["text_content"] ?? json["description"] ?? "",
      mediaUrl: json["media_url"] ?? "",
      youtubeLink: json["youtube_link"] ?? "",
      createdAt:
          json["created_at"] == null
              ? null
              : DateTime.tryParse(json["created_at"]),
      adminName: json["admin_name"] ?? "",
      adminImage: json["admin_image"] ?? "",
      replySent: replySent,
      approvalStatus: approvalStatus,
      replyApproved: replyApproved,
    );
  }

  Map<String, dynamic> toJson() => {
    "type": type,
    "activity_id": activityId,
    "title": title,
    "date":
        date == null
            ? null
            : "${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}",
    "time": time,
    "status": status,
    "post_type": postType,
    "text_content": textContent,
    "media_url": mediaUrl,
    "youtube_link": youtubeLink,
    "created_at": createdAt?.toIso8601String(),
    "admin_name": adminName,
    "admin_image": adminImage,
    "reply_sent": replySent,
    "approval_status": approvalStatus,
    "reply_approved": replyApproved,
  };
}

class Feed {
  String type;

  // Common
  int id;
  int activityId;
  String title;
  String postType;
  String textContent;
  String mediaUrl;
  String youtubeLink;
  DateTime? createdAt;

  // Admin post fields
  String notes;
  String image;
  int likesCount;
  bool isLiked;
  String createdBy;
  String userId; // ✅ fixed: API returns int
  String userName;
  String userImage;
  String adminName;
  String adminImage;
  String activityDate;
  String activityTime;
  String discription;

  // Poll fields
  String question;
  String status;
  String userSelected;
  int totalUsers; // ✅ fixed: API returns int
  int totalAnswered; // ✅ fixed: API returns int
  List<Option> options;

  Feed({
    required this.type,
    required this.id,
    required this.activityId,
    required this.title,
    required this.postType,
    required this.textContent,
    required this.mediaUrl,
    required this.youtubeLink,
    required this.createdAt,
    required this.notes,
    required this.image,
    required this.likesCount,
    required this.isLiked,
    required this.createdBy,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.activityDate,
    required this.activityTime,
    required this.discription,
    required this.question,
    required this.status,
    required this.userSelected,
    required this.totalUsers,
    required this.totalAnswered,
    required this.options,
    required this.adminImage,
    required this.adminName,
  });

  factory Feed.fromJson(Map<String, dynamic> json) => Feed(
    type: json["type"] ?? "",
    id: json["id"] ?? 0,
    activityId: json["activity_id"] ?? 0,
    title: json["title"] ?? "",
    postType: json["post_type"] ?? "",
    textContent: json["text_content"] ?? json["description"] ?? "",
    mediaUrl: json["media_url"] ?? "",
    youtubeLink: json["youtube_link"] ?? "",
    createdAt:
        json["created_at"] == null
            ? null
            : DateTime.tryParse(json["created_at"]),

    // Admin post
    notes: json["notes"] ?? "",
    image: json["image"] ?? "",
    likesCount: json["likes_count"] ?? 0,
    isLiked: json["is_liked"] ?? false,
    createdBy: json["created_by"] ?? "",
    userId: json["user_id"] ?? "", // ✅ int
    userName: json["user_name"] ?? "",
    userImage: json["user_image"] ?? "",
    activityDate: json["activity_date"] ?? "",
    activityTime: json["activity_time"] ?? "",
    discription: json["discription"] ?? "",
    adminImage: json["admin_image"] ?? "",
    adminName: json["admin_name"] ?? "",

    // Poll
    question: json["question"] ?? "",
    status: json["status"] ?? "",
    userSelected: json["user_selected"]?.toString() ?? "",
    totalUsers: int.tryParse(json["total_users"]?.toString() ?? "0") ?? 0,
    totalAnswered: int.tryParse(json["total_answered"]?.toString() ?? "0") ?? 0,
    options:
        json["options"] == null
            ? []
            : List<Option>.from(json["options"].map((x) => Option.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "id": id,
    "activity_id": activityId,
    "title": title,
    "post_type": postType,
    "text_content": textContent,
    "media_url": mediaUrl,
    "admin_image": adminImage,
    "admin_name": adminName,
    "youtube_link": youtubeLink,
    "created_at": createdAt?.toIso8601String(),
    "notes": notes,
    "image": image,
    "likes_count": likesCount,
    "is_liked": isLiked,
    "created_by": createdBy,
    "user_id": userId,
    "user_name": userName,
    "user_image": userImage,
    "activity_date": activityDate,
    "activity_time": activityTime,
    "discription": discription,
    "question": question,
    "status": status,
    "user_selected": userSelected,
    "total_users": totalUsers,
    "total_answered": totalAnswered,
    "options": List<dynamic>.from(options.map((x) => x.toJson())),
  };
}

class Option {
  int optionId;
  String optionText;
  int voteCount; // ✅ NEW: was missing
  int percentage; // ✅ fixed: API returns int, not String

  Option({
    required this.optionId,
    required this.optionText,
    required this.voteCount,
    required this.percentage,
  });

  factory Option.fromJson(Map<String, dynamic> json) => Option(
    optionId: json["option_id"] ?? 0,
    optionText: json["option_text"] ?? "",
    voteCount: int.tryParse(json["vote_count"]?.toString() ?? "0") ?? 0,
    percentage: int.tryParse(json["percentage"]?.toString() ?? "0") ?? 0,
  );

  Map<String, dynamic> toJson() => {
    "option_id": optionId,
    "option_text": optionText,
    "vote_count": voteCount, // ✅ NEW
    "percentage": percentage,
  };
}
