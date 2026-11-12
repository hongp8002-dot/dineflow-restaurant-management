/// Model thông báo in-app của khách hàng (reservation_confirmed / reservation_cancelled).
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null,
      isRead: json['read'] == true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
