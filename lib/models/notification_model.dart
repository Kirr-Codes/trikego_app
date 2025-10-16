import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification model for passenger app
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.timestamp,
    this.isRead = false,
  });

  /// Create from Firestore document
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['recipientId'] ?? data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'general',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      timestamp: (data['sentAt'] as Timestamp?)?.toDate() ?? 
                 (data['timestamp'] as Timestamp?)?.toDate() ?? 
                 DateTime.now(),
      isRead: data['processed'] == true || data['isRead'] == true,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  /// Create a copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Get icon based on notification type
  String get iconType {
    switch (type) {
      case 'booking':
      case 'booking_accepted':
        return 'check_circle';
      case 'booking_cancellation':
      case 'booking_cancelled':
        return 'cancel';
      case 'driver_approaching':
        return 'directions_car';
      case 'driver_arrived':
        return 'location_on';
      case 'trip_started':
        return 'play_arrow';
      case 'trip_completed':
        return 'flag';
      case 'payment_received':
        return 'payment';
      default:
        return 'notifications';
    }
  }

  /// Get formatted time string
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
