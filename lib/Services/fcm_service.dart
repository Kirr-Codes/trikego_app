import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'notification_service.dart';

/// FCM Service for passenger app
/// Handles Firebase Cloud Messaging token management and notifications
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final NotificationService _notificationService = NotificationService();
  
  static const String _fcmTokensCollection = 'fcm_tokens';
  final Map<String, DateTime> _notificationTimestamps = {};

  /// Initialize FCM service
  Future<void> initialize() async {
    try {
      await _initializeLocalNotifications();
      
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _getAndStoreFCMToken();
        
        _messaging.onTokenRefresh.listen((newToken) {
          _updateFCMToken(newToken);
        });
        
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
        
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      }
    } catch (e) {
      // Silent fail for production
    }
  }

  /// Get unique device identifier
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios_device';
    }
    
    return 'unknown_device';
  }

  /// Get and store FCM token
  Future<void> _getAndStoreFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _storeFCMToken(user.uid, token);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  /// Store FCM token in Firestore
  Future<void> _storeFCMToken(String userId, String token) async {
    try {
      final deviceId = await _getDeviceId();
      final docId = '${userId}_$deviceId';
      
      await _firestore.collection(_fcmTokensCollection).doc(docId).set({
        'userId': userId,
        'deviceId': deviceId,
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'appType': 'passenger',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      // Silent error handling
    }
  }

  /// Update FCM token when it refreshes
  Future<void> _updateFCMToken(String newToken) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _storeFCMToken(user.uid, newToken);
    } catch (e) {
      // Silent error handling
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    final messageType = message.data['type'] ?? 'general';
    final bookingId = message.data['bookingId'] ?? message.data['booking_id'] ?? '';
    final notificationKey = '${messageType}_$bookingId';
    
    final now = DateTime.now();
    if (_notificationTimestamps.containsKey(notificationKey)) {
      final lastShown = _notificationTimestamps[notificationKey]!;
      if (now.difference(lastShown).inSeconds < 30) return;
    }
    
    _notificationTimestamps[notificationKey] = now;
    _cleanupOldTimestamps();
    
    _showForegroundNotification(message).catchError((_) {});
    _storeNotificationInFirestore(message);
    
    switch (messageType) {
      case 'booking_cancellation':
        _handleBookingCancellation(message);
        break;
      case 'driver_approaching':
        _handleDriverApproaching(message);
        break;
      case 'driver_arrived':
        _handleDriverArrived(message);
        break;
      case 'trip_started':
        _handleTripStarted(message);
        break;
      case 'trip_completed':
        _handleTripCompleted(message);
        break;
    }
  }
  
  void _cleanupOldTimestamps() {
    final now = DateTime.now();
    _notificationTimestamps.removeWhere(
      (key, timestamp) => now.difference(timestamp).inMinutes > 5
    );
  }
  
  Future<void> _storeNotificationInFirestore(RemoteMessage message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _notificationService.storeNotification(
        userId: user.uid,
        title: message.notification?.title ?? 'Notification',
        body: message.notification?.body ?? 'You have a new notification',
        type: message.data['type'] ?? 'general',
        data: message.data,
      );
    } catch (_) {}
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
    await _createNotificationChannel();
    
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'passenger_notifications',
          'Passenger Notifications',
          channelDescription: 'Notifications for passenger app',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          icon: 'ic_notification',
          color: Color(0xFF0E4078),
          playSound: true,
          enableVibration: true,
        );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    final payload = message.data.containsKey('bookingId')
        ? 'booking|${message.data['bookingId']}'
        : '';
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? 'You have a new notification',
      notificationDetails,
      payload: payload,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // TODO: Implement navigation based on message.data['type']
  }

  void _handleBookingCancellation(RemoteMessage message) {}
  void _handleDriverApproaching(RemoteMessage message) {}
  void _handleDriverArrived(RemoteMessage message) {}
  void _handleTripStarted(RemoteMessage message) {}
  void _handleTripCompleted(RemoteMessage message) {}

  /// Store FCM token for current user (call this after login)
  Future<void> storeFCMTokenForCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _storeFCMToken(user.uid, token);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  /// Remove FCM token (call this on logout)
  Future<void> removeFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final deviceId = await _getDeviceId();
      final docId = '${user.uid}_$deviceId';
      
      await _firestore.collection(_fcmTokensCollection).doc(docId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silent error handling
    }
  }

  /// Reactivate FCM token (call this on login)
  Future<void> reactivateFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final deviceId = await _getDeviceId();
      final docId = '${user.uid}_$deviceId';
      
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection(_fcmTokensCollection).doc(docId).update({
          'token': token,
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
      }
    } catch (e) {
      // Silent error handling
    }
  }

  /// Debug method to check if FCM token exists for current user
  Future<bool> checkTokenExists() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final deviceId = await _getDeviceId();
      final docId = '${user.uid}_$deviceId';
      
      final tokenDoc = await _firestore.collection(_fcmTokensCollection).doc(docId).get();
      
      if (tokenDoc.exists) {
        final data = tokenDoc.data()!;
        return data['isActive'] == true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;
    
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'passenger_notifications',
        'Passenger Notifications',
        description: 'Notifications for passenger app',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (_) {}
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;
    
    try {
      final data = response.payload!.split('|');
      if (data.length >= 2 && data[0] == 'booking') {
        // TODO: Navigate to booking details
      }
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    await NotificationService().storeNotification(
      userId: user.uid,
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? 'You have a new notification',
      type: message.data['type'] ?? 'general',
      data: message.data,
    );
  } catch (_) {}
}
