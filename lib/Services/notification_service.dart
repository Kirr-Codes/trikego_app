import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _notificationsCollection = 'pending_notifications';
  
  final _notificationsController = StreamController<List<NotificationModel>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();
  
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  
  List<NotificationModel> _lastNotifications = [];
  int _lastUnreadCount = 0;
  
  Stream<List<NotificationModel>> get notificationsStream => _notificationsController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  List<NotificationModel> get currentNotifications => _lastNotifications;
  int get currentUnreadCount => _lastUnreadCount;
  
  void initialize() {
    final user = _auth.currentUser;
    if (user == null) return;
    
    _listenToNotifications(user.uid);
  }
  
  void _listenToNotifications(String userId) {
    _notificationsSubscription?.cancel();
    
    _notificationsSubscription = _firestore
        .collection(_notificationsCollection)
        .where('recipientId', isEqualTo: userId)
        .where('recipientType', isEqualTo: 'passenger')
        .snapshots()
        .listen(
      (snapshot) {
        final notifications = snapshot.docs
            .map((doc) {
              try {
                return NotificationModel.fromFirestore(doc);
              } catch (e) {
                return null;
              }
            })
            .whereType<NotificationModel>()
            .toList();
        
        notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final limitedNotifications = notifications.take(100).toList();
        
        _lastNotifications = limitedNotifications;
        _notificationsController.add(limitedNotifications);
        
        final unreadCount = limitedNotifications.where((n) => !n.isRead).length;
        _lastUnreadCount = unreadCount;
        _unreadCountController.add(unreadCount);
      },
      onError: (error) {
        _notificationsController.add([]);
        _unreadCountController.add(0);
      },
    );
  }
  
  Future<void> storeNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final bookingId = data?['bookingId'] ?? data?['booking_id'] ?? '';
      final tenSecondsAgo = DateTime.now().subtract(const Duration(seconds: 10));
      
      final existingNotifications = await _firestore
          .collection(_notificationsCollection)
          .where('recipientId', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .where('sentAt', isGreaterThan: Timestamp.fromDate(tenSecondsAgo))
          .limit(5)
          .get();
      
      for (final doc in existingNotifications.docs) {
        final docData = doc.data();
        final docBookingId = docData['data']?['bookingId'] ?? docData['data']?['booking_id'] ?? '';
        if (docBookingId == bookingId && bookingId.isNotEmpty) return;
      }
      
      await _firestore.collection(_notificationsCollection).add({
        'recipientId': userId,
        'recipientType': 'passenger',
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'sentAt': FieldValue.serverTimestamp(),
        'processed': false,
        'isRead': false,
        'status': 'sent',
      });
    } catch (_) {}
  }
  
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({
            'processed': true,
            'isRead': true,
          });
    } catch (e) {}
  }
  
  Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final unreadNotifications = await _firestore
          .collection(_notificationsCollection)
          .where('recipientId', isEqualTo: user.uid)
          .where('recipientType', isEqualTo: 'passenger')
          .where('processed', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'processed': true,
          'isRead': true,
        });
      }
      
      await batch.commit();
    } catch (e) {}
  }
  
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .delete();
    } catch (e) {}
  }
  
  Future<void> deleteAllNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final notifications = await _firestore
          .collection(_notificationsCollection)
          .where('recipientId', isEqualTo: user.uid)
          .where('recipientType', isEqualTo: 'passenger')
          .get();
      
      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {}
  }
  
  Future<int> getUnreadCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;
      
      final snapshot = await _firestore
          .collection(_notificationsCollection)
          .where('recipientId', isEqualTo: user.uid)
          .where('recipientType', isEqualTo: 'passenger')
          .where('processed', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
  
  Future<List<NotificationModel>> getAllNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final snapshot = await _firestore
          .collection(_notificationsCollection)
          .where('recipientId', isEqualTo: user.uid)
          .where('recipientType', isEqualTo: 'passenger')
          .get();
      
      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications.take(100).toList();
    } catch (e) {
      return [];
    }
  }
  
  void dispose() {
    _notificationsSubscription?.cancel();
    _notificationsController.close();
    _unreadCountController.close();
  }
}
