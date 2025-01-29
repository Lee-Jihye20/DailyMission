import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

Future<void> initialize() async {
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true, // 最初に許可をリクエストする
    requestBadgePermission: true, // バッジの権限をリクエスト
    requestSoundPermission: true, // サウンドの権限をリクエスト
    defaultPresentAlert: true,
    defaultPresentBadge: true,
    defaultPresentSound: true,
  );

  const initializationSettings = InitializationSettings(
    iOS: iosSettings,
  );

  await _notifications.initialize(initializationSettings);
}


  Future<bool> checkNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('hasPromptedNotification') ?? false;
    
    if (!hasPrompted) {
      return false;
    }

    final settings = await _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings ?? false;
  }

  Future<bool> requestNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasPromptedNotification', true);

    final granted = await _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return granted ?? false;
  }

  Future<void> openNotificationSettings() async {
    await _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions();
  }

  Future<bool> _isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('isNotificationEnabled') ?? true;
    final hasPermission = await checkNotificationPermission();
    return isEnabled && hasPermission;
  }

  Future<void> scheduleTaskNotification(int id, String title, DateTime deadline) async {
    if (!await _isNotificationEnabled()) {
      await cancelNotification(id);
      return;
    }

    // 5時間前の通知
    final fiveHoursBefore = deadline.subtract(const Duration(hours: 5));
    if (fiveHoursBefore.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        id * 3,
        'タスクの期限が近づいています',
        '$titleが期限まであと5時間後です！',
        tz.TZDateTime.from(fiveHoursBefore, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    // 1時間前の通知
    final oneHourBefore = deadline.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        id * 3 + 1,
        'タスクの期限が近づいています',
        '1時間前です$titleが終わっていません！',
        tz.TZDateTime.from(oneHourBefore, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    // 5分前の通知
    final fiveMinutesBefore = deadline.subtract(const Duration(minutes: 5));
    if (fiveMinutesBefore.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        id * 3 + 2,
        'タスクの期限が近づいています',
        '5分前です$titleが終わっていません！',
        tz.TZDateTime.from(fiveMinutesBefore, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id * 3);
    await _notifications.cancel(id * 3 + 1);
    await _notifications.cancel(id * 3 + 2);
  }
} 