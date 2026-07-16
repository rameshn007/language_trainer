import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'storage_service.dart';
import '../main.dart';
import '../ui/quiz/quiz_screen.dart';

class NotificationService {
  final StorageService _storage;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  NotificationResponse? _pendingResponse;

  NotificationService(this._storage);

  Future<void> init() async {
    tz_data.initializeTimeZones();
    final String timeZoneName =
        (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    debugPrint('NotificationService: Initializing...');
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    debugPrint('NotificationService: Initialized.');

    // Check if app was launched from a notification
    final NotificationAppLaunchDetails? launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    debugPrint(
      'NotificationService: Launch details - didLaunchApp: ${launchDetails?.didNotificationLaunchApp}',
    );
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _onNotificationTapped(launchDetails!.notificationResponse!);
    }

    // Initial scheduling based on saved settings
    await updateReminders();
  }

  void handlePendingNotification() {
    debugPrint(
      'NotificationService: Checking for pending notification... (Has pending: ${_pendingResponse != null})',
    );
    if (_pendingResponse != null) {
      _onNotificationTapped(_pendingResponse!);
      _pendingResponse = null;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      'NotificationService: Notification tapped! (Action ID: ${response.actionId}, Payload: ${response.payload})',
    );
    if (navigatorKey.currentState == null) {
      debugPrint(
        'NotificationService: Navigator state is NULL, saving as pending.',
      );
      _pendingResponse = response;
      return;
    }
    debugPrint('NotificationService: Navigating to Lucky Quiz...');
    // Navigate to "I'm feeling lucky" quiz
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => const QuizScreen(isLuckyQuiz: true),
      ),
    );
  }

  Future<bool> requestPermissions() async {
    debugPrint('NotificationService: Requesting permissions...');
    final bool? result = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    debugPrint('NotificationService: Permissions granted: $result');
    return result ?? false;
  }

  Future<void> requestPermissionsIfFirstTime() async {
    final hasRequested =
        _storage.getSetting('has_requested_notifications', defaultValue: false)
            as bool;
    if (!hasRequested) {
      await requestPermissions();
      await _storage.saveSetting('has_requested_notifications', true);
    }
  }

  Future<void> updateReminders() async {
    final enabled = _storage.remindersEnabled;
    if (!enabled) {
      await _notificationsPlugin.cancelAll();
      return;
    }

    final hour = _storage.reminderHour;
    final minute = _storage.reminderMinute;
    await scheduleDailyReminder(hour, minute);
  }

  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    debugPrint(
      'NotificationService: Scheduling test notification for 5 seconds from now...',
    );
    final scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(seconds: 5));

    try {
      await _notificationsPlugin.zonedSchedule(
        id: 99,
        title: 'Test Notification',
        body: 'This is a test notification to verify deep linking. Tap me!',
        scheduledDate: scheduledDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint(
        'NotificationService: Test notification scheduled successfully for $scheduledDate',
      );
    } catch (e) {
      debugPrint('NotificationService: Error scheduling test notification: $e');
    }
  }

  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await _notificationsPlugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint(
      'Scheduling daily reminder for $hour:$minute (Local time: $scheduledDate)',
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminders',
          channelDescription:
              'Notifications to remind you to practice your language skills',
          importance: Importance.max,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: 0,
      title: 'Time to Practice!',
      body: "Keep the momentum going! Let's do a quick session.",
      scheduledDate: scheduledDate,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
