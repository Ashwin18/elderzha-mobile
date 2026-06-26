class DailyActivityResponse {
  final bool? status;
  final String? message;
  final List<DailyActivity>? data;

  DailyActivityResponse({
    this.status,
    this.message,
    this.data,
  });

  factory DailyActivityResponse.fromJson(Map<String, dynamic> json) {
    return DailyActivityResponse(
      status: json['status'] as bool?,
      message: json['message'] as String?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => DailyActivity.fromJson(e))
          .toList() ??
          [],
    );
  }
}

class DailyActivity {
  final int? id;
  final String? title;
  final Map<String, String>? options; // 🔥 dynamic keys

  DailyActivity({
    this.id,
    this.title,
    this.options,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      id: json['id'] as int?,
      title: json['title'] as String?,
      options: (json['options'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, value.toString()))
          ?? {}, // 🔥 null-safe + dynamic
    );
  }
}
