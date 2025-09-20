import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isNotificationActive = false;

  bool get isNotificationActive => _isNotificationActive;

  // Initialize notification service (without requesting permission)
  Future<void> initialize() async {
    try {
      print('=== NOTIFICATION SERVICE INITIALIZE ===');
      
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false, // Don't request permission here
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android 8.0+
      await _createNotificationChannel();
      
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  // Request notification permission (to be called from permission screen)
  Future<bool> requestNotificationPermission() async {
    try {
      print('=== REQUESTING NOTIFICATION PERMISSION ===');
      
      final status = await Permission.notification.request();
      print('Notification permission status: $status');
      
      if (status == PermissionStatus.granted) {
        print('Notification permission granted');
        return true;
      } else {
        print('Notification permission denied');
        return false;
      }
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  // Check if notification permission is granted
  Future<bool> isNotificationPermissionGranted() async {
    try {
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      print('Error checking notification permission: $e');
      return false;
    }
  }

  // Create Android notification channel
  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'tracking_channel',
        'Project Nexus Tracking',
        description: 'Persistent notification for location tracking',
        importance: Importance.low, // Changed to low importance
        enableVibration: false,
        playSound: false,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      print('Android notification channel created: tracking_channel');
    } catch (e) {
      print('Error creating notification channel: $e');
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.actionId}');
    if (response.actionId == 'logout_action') {
      handleNotificationAction('logout_action');
    }
  }

  // Show persistent tracking notification
  Future<void> showTrackingNotification({
    required String title,
    required String body,
    required String status,
  }) async {
    try {
      print('=== SHOWING TRACKING NOTIFICATION ===');
      print('Title: $title');
      print('Body: $body');
      print('Status: $status');
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'tracking_channel',
        'Project Nexus Tracking',
        channelDescription: 'Persistent notification for location tracking',
        importance: Importance.low, // Changed to low to reduce popup
        priority: Priority.low, // Changed to low priority
        ongoing: true, // Makes notification persistent
        autoCancel: false, // Prevents dismissal by swiping
        showWhen: false, // Don't show timestamp
        when: null,
        silent: true, // Make it silent
        playSound: false, // No sound
        enableVibration: false, // No vibration
        actions: [
          AndroidNotificationAction(
            'logout_action',
            'Logout',
            showsUserInterface: true,
          ),
        ],
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: false, // No popup on iOS
        presentBadge: true,
        presentSound: false, // No sound
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _notifications.show(
        999, // Unique ID for tracking notification
        title,
        body,
        notificationDetails,
      );

      _isNotificationActive = true;
      print('Persistent tracking notification shown');
    } catch (e) {
      print('Error showing tracking notification: $e');
    }
  }

  // Update tracking notification
  Future<void> updateTrackingNotification({
    required String title,
    required String body,
    required String status,
  }) async {
    if (!_isNotificationActive) return;

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'tracking_channel',
        'Project Nexus Tracking',
        channelDescription: 'Persistent notification for location tracking',
        importance: Importance.low, // Changed to low to reduce popup
        priority: Priority.low, // Changed to low priority
        ongoing: true,
        autoCancel: false,
        showWhen: false, // Don't show timestamp
        when: null,
        silent: true, // Make it silent
        playSound: false, // No sound
        enableVibration: false, // No vibration
        actions: [
          AndroidNotificationAction(
            'logout_action',
            'Logout',
            showsUserInterface: true,
          ),
        ],
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: false, // No popup on iOS
        presentBadge: true,
        presentSound: false, // No sound
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _notifications.show(
        999, // Same ID to update existing notification
        title,
        body,
        notificationDetails,
      );

      print('Tracking notification updated');
    } catch (e) {
      print('Error updating tracking notification: $e');
    }
  }

  // Hide tracking notification (only on logout)
  Future<void> hideTrackingNotification() async {
    try {
      await _notifications.cancel(999);
      _isNotificationActive = false;
      print('Tracking notification hidden');
    } catch (e) {
      print('Error hiding tracking notification: $e');
    }
  }

  // Handle notification actions
  void handleNotificationAction(String actionId) {
    switch (actionId) {
      case 'logout_action':
        print('Logout action triggered from notification');
        // This will be handled by the main app
        break;
    }
  }
}
