//
//
// import 'dart:convert';
//
// ActivityModel activityModelFromJson(String str) => ActivityModel.fromJson(json.decode(str));
//
// String activityModelToJson(ActivityModel data) => json.encode(data.toJson());
//
// class ActivityModel {
//   bool status;
//   String message;
//   Data data;
//
//   ActivityModel({
//     required this.status,
//     required this.message,
//     required this.data,
//   });
//
//   factory ActivityModel.fromJson(Map<String, dynamic> json) => ActivityModel(
//     status: json["status"],
//     message: json["message"],
//     data: Data.fromJson(json["data"]),
//   );
//
//   Map<String, dynamic> toJson() => {
//     "status": status,
//     "message": message,
//     "data": data.toJson(),
//   };
// }
//
//
// class Data {
//   List<TodayActivity> todayActivities;
//   CommunityPosts? communityPosts;
//
//   Data({
//     required this.todayActivities,
//     this.communityPosts,
//   });
//
//   factory Data.fromJson(Map<String, dynamic> json) => Data(
//     todayActivities: json["today_activities"] != null
//         ? List<TodayActivity>.from(
//       json["today_activities"]
//           .map((x) => TodayActivity.fromJson(x)),
//     )
//         : [],
//     communityPosts: json["community_posts"] != null
//         ? CommunityPosts.fromJson(json["community_posts"])
//         : null,
//   );
//
//   Map<String, dynamic> toJson() => {
//     "today_activities":
//     List<dynamic>.from(todayActivities.map((x) => x.toJson())),
//     "community_posts": communityPosts?.toJson(),
//   };
// }
//
// class CommunityPosts {
//   int currentPage;
//   int perPage;
//   int total;
//   int lastPage;
//   List<ActivityView> data;
//
//   CommunityPosts({
//     required this.currentPage,
//     required this.perPage,
//     required this.total,
//     required this.lastPage,
//     required this.data,
//   });
//
//   factory CommunityPosts.fromJson(Map<String, dynamic> json) => CommunityPosts(
//     currentPage: json["current_page"] ?? 1,
//     perPage: json["per_page"] ?? 10,
//     total: json["total"] ?? 0,
//     lastPage: json["last_page"] ?? 1,
//     data: json["data"] != null
//         ? List<ActivityView>.from(
//       json["data"].map((x) => ActivityView.fromJson(x)),
//     )
//         : [],
//   );
//
//   // ✅ ADD THIS METHOD
//   Map<String, dynamic> toJson() => {
//     "current_page": currentPage,
//     "per_page": perPage,
//     "total": total,
//     "last_page": lastPage,
//     "data": List<dynamic>.from(data.map((x) => x.toJson())),
//   };
// }
//
// class ActivityView {
//   int postId;
//   String activityId;
//   String activityTitle;
//   String userId;
//   String userName;
//   String? userImage;
//   String notes;
//   String image;
//   int likesCount;
//   bool isLiked;
//   String createdAt;
//
//   ActivityView({
//     required this.postId,
//     required this.activityId,
//     required this.activityTitle,
//     required this.userId,
//     required this.userName,
//     this.userImage,
//     required this.notes,
//     required this.image,
//     required this.likesCount,
//     required this.isLiked,
//     required this.createdAt,
//   });
//
//   factory ActivityView.fromJson(Map<String, dynamic> json) => ActivityView(
//     postId: json["post_id"] ?? 0,
//     activityId: json["activity_id"] ?? "",
//     activityTitle: json["activity_title"] ?? "",
//     userId: json["user_id"] ?? "",
//     userName: json["user_name"] ?? "",
//     userImage: json["user_image"],
//     notes: json["notes"] ?? "",
//     image: json["image"] ?? "",
//     likesCount: json["likes_count"] ?? 0,
//     isLiked: json["is_liked"] ?? false,
//     createdAt: json["created_at"] ?? "",
//   );
//
//   // ✅ REQUIRED
//   Map<String, dynamic> toJson() => {
//     "post_id": postId,
//     "activity_id": activityId,
//     "activity_title": activityTitle,
//     "user_id": userId,
//     "user_name": userName,
//     "user_image": userImage,
//     "notes": notes,
//     "image": image,
//     "likes_count": likesCount,
//     "is_liked": isLiked,
//     "created_at": createdAt,
//   };
// }
//
// class TodayActivity {
//   String activityId;
//   String title;
//   String description;
//   DateTime date;
//   String time;
//   String status;
//   bool replyAvailable;
//   bool shareAvailable;
//   String postType;
//
//   String? mediaUrl;      // image / video
//   String? youtubeLink;   // youtube only
//
//   TodayActivity({
//     required this.activityId,
//     required this.title,
//     required this.description,
//     required this.date,
//     required this.time,
//     required this.status,
//     required this.replyAvailable,
//     required this.shareAvailable,
//     required this.postType,
//     this.mediaUrl,
//     this.youtubeLink,
//   });
//
//   // factory TodayActivity.fromJson(Map<String, dynamic> json) => TodayActivity(
//   //   activityId: json["activity_id"] ?? '',
//   //   title: json["title"] ?? "",
//   //   description: json["description"] ?? "",
//   //   date: DateTime.parse(json["date"]),
//   //   time: json["time"] ?? "",
//   //   status: json["status"] ?? "",
//   //   replyAvailable: json["reply_available"] ?? false,
//   //   shareAvailable: json["share_available"] ?? false,
//   //   postType: json["post_type"] ?? "",
//   //
//   //   // ✅ Correct mapping
//   //   mediaUrl: json["media_url"],       // image / video
//   //   youtubeLink: json["youtube_link"], // youtube
//   // );
//
//   factory TodayActivity.fromJson(Map<String, dynamic> json) => TodayActivity(
//     activityId: json["activity_id"] ?? '',
//     title: json["title"] ?? "",
//     description: json["description"] ?? "",
//     date: json["date"] != null
//         ? DateTime.parse(json["date"])
//         : DateTime.now(),
//     time: json["time"] ?? "",
//     status: json["status"] ?? "",
//     replyAvailable: json["reply_available"] ?? false,
//     shareAvailable: json["share_available"] ?? false,
//     postType: json["post_type"] ?? "",
//     mediaUrl: json["media_url"],
//     youtubeLink: json["youtube_link"],
//   );
//
//
//   // ✅ ADD THIS
//   Map<String, dynamic> toJson() => {
//     "activity_id": activityId,
//     "title": title,
//     "description": description,
//     "date":
//     "${date.year.toString().padLeft(4, '0')}-"
//         "${date.month.toString().padLeft(2, '0')}-"
//         "${date.day.toString().padLeft(2, '0')}",
//     "time": time,
//     "status": status,
//     "reply_available": replyAvailable,
//     "share_available": shareAvailable,
//     "post_type": postType,
//     "media_url": mediaUrl,
//     "youtube_link": youtubeLink,
//   };
//
// }
//
//

import 'dart:convert';

ActivityModel activityModelFromJson(String str) =>
    ActivityModel.fromJson(json.decode(str));

String activityModelToJson(ActivityModel data) => json.encode(data.toJson());

bool _isTruthy(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalized = value?.toString().toLowerCase().trim();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

// ─────────────────────────────────────────────
// ROOT
// ─────────────────────────────────────────────
class ActivityModel {
  bool status;
  String message;
  Data data;

  ActivityModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) => ActivityModel(
    status: json["status"] ?? false,
    message: json["message"] ?? "",
    data: Data.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data.toJson(),
  };
}

// ─────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────
class Data {
  List<TodayActivity> activities; // OLD key: today_activities
  List<FeedItem> feed; // OLD key: community_posts (was paginated)

  Data({required this.activities, required this.feed});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    activities:
        json["activities"] != null
            ? List<TodayActivity>.from(
              (json["activities"] as List).map(
                (x) => TodayActivity.fromJson(x),
              ),
            )
            : [],
    feed:
        json["feed"] != null
            ? List<FeedItem>.from(
              (json["feed"] as List).map((x) => FeedItem.fromJson(x)),
            )
            : [],
  );

  Map<String, dynamic> toJson() => {
    "activities": activities.map((x) => x.toJson()).toList(),
    "feed": feed.map((x) => x.toJson()).toList(),
  };
}

// ─────────────────────────────────────────────
// TODAY ACTIVITY  (from "activities" array)
// ─────────────────────────────────────────────
class TodayActivity {
  String activityId;
  String title;
  String textContent; // OLD field: description
  DateTime date;
  String time;
  String status;
  String postType;
  String? mediaUrl;
  String? youtubeLink;
  String adminName; // NEW
  String adminImage; // NEW
  String createdAt; // NEW
  bool replySent;
  String approvalStatus;
  bool replyApproved;

  TodayActivity({
    required this.activityId,
    required this.title,
    required this.textContent,
    required this.date,
    required this.time,
    required this.status,
    required this.postType,
    this.mediaUrl,
    this.youtubeLink,
    required this.adminName,
    required this.adminImage,
    required this.createdAt,
    required this.replySent,
    required this.approvalStatus,
    required this.replyApproved,
  });

  factory TodayActivity.fromJson(Map<String, dynamic> json) {
    final status = (json["status"] ?? "").toString();
    final approvalStatus = (json["approval_status"] ?? "").toString();
    final replySent =
        _isTruthy(json["reply_sent"]) ||
        status.toLowerCase() == "completed" ||
        status.toLowerCase() == "pending_review" ||
        status.toLowerCase() == "skipped";
    final replyApproved =
        _isTruthy(json["reply_approved"]) ||
        approvalStatus.toLowerCase() == "approved";

    return TodayActivity(
      activityId: json["activity_id"]?.toString() ?? '',
      title: json["title"] ?? "",
      textContent: json["text_content"] ?? "",
      date:
          json["date"] != null
              ? DateTime.tryParse(json["date"]) ?? DateTime.now()
              : DateTime.now(),
      time: json["time"] ?? "",
      status: status,
      postType: json["post_type"] ?? "",
      mediaUrl:
          (json["media_url"] != null && json["media_url"].toString().isNotEmpty)
              ? json["media_url"]
              : null,
      youtubeLink:
          (json["youtube_link"] != null &&
                  json["youtube_link"].toString().isNotEmpty)
              ? json["youtube_link"]
              : null,
      adminName: json["admin_name"] ?? "",
      adminImage: json["admin_image"] ?? "",
      createdAt: json["created_at"] ?? "",
      replySent: replySent,
      approvalStatus: approvalStatus,
      replyApproved: replyApproved,
    );
  }

  Map<String, dynamic> toJson() => {
    "activity_id": activityId,
    "title": title,
    "text_content": textContent,
    "date":
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
    "time": time,
    "status": status,
    "post_type": postType,
    "media_url": mediaUrl,
    "youtube_link": youtubeLink,
    "admin_name": adminName,
    "admin_image": adminImage,
    "created_at": createdAt,
    "reply_sent": replySent,
    "approval_status": approvalStatus,
    "reply_approved": replyApproved,
  };
}

// ─────────────────────────────────────────────
// FEED ITEM WRAPPER  (from "feed" array)
// type = "user_post" | "admin_post" | "poll"
// ─────────────────────────────────────────────
class FeedItem {
  String type;
  UserPostFeed? userPost;
  AdminPostFeed? adminPost;
  PollFeed? poll;

  FeedItem({required this.type, this.userPost, this.adminPost, this.poll});

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final type = json["type"] ?? "";
    return FeedItem(
      type: type,
      userPost: type == "user_post" ? UserPostFeed.fromJson(json) : null,
      adminPost: type == "admin_post" ? AdminPostFeed.fromJson(json) : null,
      poll: type == "poll" ? PollFeed.fromJson(json) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    "type": type,
    if (userPost != null) ...userPost!.toJson(),
    if (adminPost != null) ...adminPost!.toJson(),
    if (poll != null) ...poll!.toJson(),
  };
}

// ─────────────────────────────────────────────
// USER POST  (type = "user_post")
// name  → admin_name  |  image → admin_image
// ─────────────────────────────────────────────
class UserPostFeed {
  String activityId;
  String title;
  String postType;
  String textContent;
  String? mediaUrl;
  String? youtubeLink;
  String createdAt;
  String adminName;
  String adminImage;

  UserPostFeed({
    required this.activityId,
    required this.title,
    required this.postType,
    required this.textContent,
    this.mediaUrl,
    this.youtubeLink,
    required this.createdAt,
    required this.adminName,
    required this.adminImage,
  });

  factory UserPostFeed.fromJson(Map<String, dynamic> json) => UserPostFeed(
    activityId: json["activity_id"]?.toString() ?? '',
    title: json["title"] ?? "",
    postType: json["post_type"] ?? "",
    textContent: json["text_content"] ?? "",
    mediaUrl:
        (json["media_url"] != null && json["media_url"].toString().isNotEmpty)
            ? json["media_url"]
            : null,
    youtubeLink:
        (json["youtube_link"] != null &&
                json["youtube_link"].toString().isNotEmpty)
            ? json["youtube_link"]
            : null,
    createdAt: json["created_at"] ?? "",
    adminName: json["admin_name"] ?? "",
    adminImage: json["admin_image"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "activity_id": activityId,
    "title": title,
    "post_type": postType,
    "text_content": textContent,
    "media_url": mediaUrl,
    "youtube_link": youtubeLink,
    "created_at": createdAt,
    "admin_name": adminName,
    "admin_image": adminImage,
  };
}

// ─────────────────────────────────────────────
// ADMIN POST  (type = "admin_post")
// name  → user_name  |  image → user_image
// ─────────────────────────────────────────────
class AdminPostFeed {
  int postId;
  String title;
  String notes;
  String image;
  int likesCount;
  bool isLiked;
  String createdAt;
  String userName;
  String userImage;
  String adminPage;

  AdminPostFeed({
    required this.postId,
    required this.title,
    required this.notes,
    required this.image,
    required this.likesCount,
    required this.isLiked,
    required this.createdAt,
    required this.userName,
    required this.userImage,
    required this.adminPage,
  });

  factory AdminPostFeed.fromJson(Map<String, dynamic> json) => AdminPostFeed(
    postId: json["id"] ?? 0,
    title: json["title"] ?? "",
    notes: json["notes"] ?? "",
    image: json["image"] ?? "",
    likesCount: json["likes_count"] ?? 0,
    isLiked: json["is_liked"] ?? false,
    createdAt: json["created_at"] ?? "",
    userName: json["user_name"] ?? "",
    userImage: json["user_image"] ?? "",
    adminPage: json["admin_image"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "id": postId,
    "title": title,
    "notes": notes,
    "image": image,
    "likes_count": likesCount,
    "is_liked": isLiked,
    "created_at": createdAt,
    "user_name": userName,
    "user_image": userImage,
    "admin_image": adminPage,
  };
}

// ─────────────────────────────────────────────
// POLL  (type = "poll")
// ─────────────────────────────────────────────
class PollFeed {
  int pollId;
  String question;
  String description;
  String status;
  String userSelected;
  int totalUsers;
  int totalAnswered;
  List<PollOption> options;
  String createdAt;

  PollFeed({
    required this.pollId,
    required this.question,
    required this.description,
    required this.status,
    required this.userSelected,
    required this.totalUsers,
    required this.totalAnswered,
    required this.options,
    required this.createdAt,
  });

  factory PollFeed.fromJson(Map<String, dynamic> json) => PollFeed(
    pollId: json["id"] ?? 0,
    question: json["question"] ?? "",
    description: json["description"] ?? json["text_content"] ?? "",
    status: json["status"] ?? "",
    userSelected: json["user_selected"]?.toString() ?? "",
    totalUsers: json["total_users"] ?? 0,
    totalAnswered: json["total_answered"] ?? 0,
    options:
        json["options"] != null
            ? List<PollOption>.from(
              (json["options"] as List).map((x) => PollOption.fromJson(x)),
            )
            : [],
    createdAt: json["created_at"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "id": pollId,
    "question": question,
    "description": description,
    "status": status,
    "user_selected": userSelected,
    "total_users": totalUsers,
    "total_answered": totalAnswered,
    "options": options.map((x) => x.toJson()).toList(),
    "created_at": createdAt,
  };
}

class PollOption {
  int optionId;
  String optionText;
  int voteCount;
  int percentage;

  PollOption({
    required this.optionId,
    required this.optionText,
    required this.voteCount,
    required this.percentage,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
    optionId: json["option_id"] ?? 0,
    optionText: json["option_text"] ?? "",
    voteCount: json["vote_count"] ?? 0,
    percentage:
        json["percentage"] is int
            ? json["percentage"]
            : int.tryParse(json["percentage"]?.toString() ?? '') ?? 0,
  );

  Map<String, dynamic> toJson() => {
    "option_id": optionId,
    "option_text": optionText,
    "vote_count": voteCount,
    "percentage": percentage,
  };
}
