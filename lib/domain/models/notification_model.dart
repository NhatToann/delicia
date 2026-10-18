/// NotificationModel — stub created in UC-12 so the rest of the team can
/// already reference the shape. The actual FCM/local-notification wiring
/// lives in UC-12 (Member C owns most of it, but we expose the model
/// here so the dashboard can show the icon when the app receives a push).
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'order_new' | 'order_dispatched' | 'order_delivered' | 'promo'
  final DateTime timestamp;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory NotificationModel.fromJson(Map<dynamic, dynamic> json) =>
      NotificationModel(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        type: (json['type'] ?? 'general').toString(),
        timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
            DateTime.now(),
        isRead: (json['isRead'] ?? false) as bool,
      );

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        title: title,
        body: body,
        type: type,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NotificationModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}