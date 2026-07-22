import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'browser_notifier_stub.dart'
    if (dart.library.html) 'browser_notifier_web.dart';
import 'alert_store.dart';
import 'app_theme.dart';
import 'schedule_store.dart';
import 'app_location.dart';

class AlertNotification {
  final String id;
  final String title;
  final String message;
  final String utility;
  final DateTime timestamp;
  final IconData icon;

  AlertNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.utility,
    required this.timestamp,
    required this.icon,
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM automatically presents the notification payload natively on Android/iOS
  // when the app is closed or backgrounded. We do not call local notifications
  // here to prevent creating duplicate system tray notifications.
}

/// Broadcasts in-app heads-up alerts, device tray notifications, and handles background Push Notifications.
class AlertNotificationService {
  AlertNotificationService._();

  static final ValueNotifier<AlertNotification?> currentAlert =
      ValueNotifier<AlertNotification?>(null);

  static Timer? _autoDismissTimer;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isPluginInitialized = false;

  static String? _subscribedTopic;

  static Future<void> initLocalNotifications() async {
    if (kIsWeb) return;
    if (_isPluginInitialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Handle tap on notification tray item
        },
      );
      _isPluginInitialized = true;

      // Register FCM background handler & request permissions
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final String? reporterUid = message.data['reporterUid'];
          final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (reporterUid != null && reporterUid.isNotEmpty && reporterUid == currentUid) {
            return; // Ignore self notifications when app is open
          }

          final notification = message.notification;
          if (notification != null) {
            showAlert(
              title: notification.title ?? '🚨 Roshan Alert',
              message: notification.body ?? 'Outage update received.',
              utility: message.data['utility'] ?? 'Electricity',
            );
          }
        });
      }

      // Sync topic subscription for user area
      syncAreaTopicSubscription();
    } catch (_) {}
  }

  /// Syncs area-based FCM topic subscription so background notifications trigger when another user in the area reports.
  static Future<void> syncAreaTopicSubscription() async {
    if (kIsWeb) return;
    final p = (AppLocation.province ?? 'punjab').toLowerCase().replaceAll(' ', '_');
    final c = (AppLocation.city ?? 'lahore').toLowerCase().replaceAll(' ', '_');
    final a = (AppLocation.area ?? 'dha_phase_5').toLowerCase().replaceAll(' ', '_');
    final u = AppLocation.utility.value.toLowerCase();
    final newTopic = 'ra_${p}_${c}_${a}_$u';

    if (_subscribedTopic == newTopic) return;

    try {
      if (_subscribedTopic != null) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_subscribedTopic!);
      }
      await FirebaseMessaging.instance.subscribeToTopic(newTopic);
      _subscribedTopic = newTopic;
    } catch (_) {}
  }

  /// Schedules daily system alarms for saved load shedding blocks (`zonedSchedule`).
  /// Fires even when the app is completely closed or device is locked.
  static Future<void> scheduleOutageBlockNotifications(List<ScheduleBlock> blocks, String utility) async {
    if (kIsWeb) return;
    try {
      await initLocalNotifications();
      await _localNotificationsPlugin.cancelAll();

      if (blocks.isEmpty) return;

      final now = tz.TZDateTime.now(tz.local);

      for (int i = 0; i < blocks.length; i++) {
        final block = blocks[i];

        // Start of Outage Alarm Notification
        final startHour = block.startMinutes ~/ 60;
        final startMin = block.startMinutes % 60;
        var startTarget = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          startHour,
          startMin,
        );
        if (startTarget.isBefore(now)) {
          startTarget = startTarget.add(const Duration(days: 1));
        }

        await _localNotificationsPlugin.zonedSchedule(
          i * 2,
          '🚨 Roshan Alert: $utility Outage',
          '$utility outage starting now (${block.timeRangeLabel})',
          startTarget,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'roshan_alert_channel',
              'Roshan Outage Alerts',
              channelDescription: 'Real-time & scheduled outage alerts',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );

        // End of Outage Alarm Notification
        final endHour = block.endMinutes ~/ 60;
        final endMin = block.endMinutes % 60;
        var endTarget = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          endHour,
          endMin,
        );
        if (endTarget.isBefore(now)) {
          endTarget = endTarget.add(const Duration(days: 1));
        }

        await _localNotificationsPlugin.zonedSchedule(
          i * 2 + 1,
          '💡 Roshan Alert: $utility Restored',
          '$utility outage block has ended',
          endTarget,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'roshan_alert_channel',
              'Roshan Outage Alerts',
              channelDescription: 'Real-time & scheduled outage alerts',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (_) {}
  }

  static Future<void> showDeviceNotification({
    required String title,
    required String message,
  }) async {
    if (kIsWeb) {
      await showBrowserNotification(title, message);
      return;
    }

    try {
      await initLocalNotifications();
      const androidDetails = AndroidNotificationDetails(
        'roshan_alert_channel',
        'Roshan Outage Alerts',
        channelDescription:
            'Real-time electricity and gas outage & recovery notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      await _localNotificationsPlugin.show(
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF,
        title,
        message,
        notificationDetails,
      );
    } catch (_) {}
  }

  static void showAlert({
    required String title,
    required String message,
    required String utility,
    IconData? icon,
  }) {
    if (!AlertStore.isAlertEnabledForUtility(utility)) return;

    _autoDismissTimer?.cancel();

    final alertIcon =
        icon ??
        (utility.toLowerCase() == 'gas'
            ? Icons.local_fire_department_rounded
            : Icons.bolt_rounded);

    currentAlert.value = AlertNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      utility: utility,
      timestamp: DateTime.now(),
      icon: alertIcon,
    );

    showDeviceNotification(title: title, message: message);

    _autoDismissTimer = Timer(const Duration(seconds: 5), () {
      dismissCurrentAlert();
    });
  }

  static void dismissCurrentAlert() {
    _autoDismissTimer?.cancel();
    currentAlert.value = null;
  }

  static void triggerOutageReportAlert({
    required String status,
    required String utility,
    required String location,
  }) {
    final String actionText = status == 'out' ? 'turned OFF' : 'turned ON';

    showAlert(
      title: '🚨 Roshan Alert',
      message: '$utility $actionText',
      utility: utility,
    );
  }

  /// Sends a direct FCM push notification to the area topic so other devices in the area
  /// receive lock-screen push notifications instantly, EVEN WHEN THEIR APP IS CLOSED.
  /// 100% Free on Firebase Spark plan (no Cloud Functions or Blaze plan required).
  static Future<void> sendAreaPushNotificationDirect({
    required String status,
    required String? province,
    required String? city,
    required String? area,
    required String utility,
  }) async {
    try {
      final p = (province ?? 'punjab').toLowerCase().trim().replaceAll(' ', '_');
      final c = (city ?? 'lahore').toLowerCase().trim().replaceAll(' ', '_');
      final a = (area ?? 'dha_phase_5').toLowerCase().trim().replaceAll(' ', '_');
      final u = utility.toLowerCase().trim();
      final topic = 'ra_${p}_${c}_${a}_$u';

      final isOut = status == 'out';
      final statusText = isOut ? 'turned OFF' : 'turned ON';
      final emoji = isOut ? '🚨' : '💡';

      final title = '$emoji Roshan Alert: $utility';
      final body = '$utility was reported $statusText in ${area ?? "your area"}.';

      if (kIsWeb) return;

      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
      final bodyPayload = jsonEncode({
        'to': '/topics/$topic',
        'priority': 'high',
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'channel_id': 'roshan_alert_channel',
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'utility': utility,
          'status': status,
        },
      });

      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.set('content-type', 'application/json');
      request.headers.set(
        'authorization',
        'key=AIzaSyBYjiUbn6qh59sZIzSTv-WGdktZxeCJBVc',
      );
      request.write(bodyPayload);
      final response = await request.close();
      await response.drain();
      client.close();
    } catch (_) {}
  }
}

/// UI Widget that renders the heads-up notification banner overlay at the top of the screen.
class HeadsUpAlertBanner extends StatelessWidget {
  const HeadsUpAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AlertNotification?>(
      valueListenable: AlertNotificationService.currentAlert,
      builder: (context, alert, _) {
        if (alert == null) return const SizedBox.shrink();

        return Positioned(
          top: 10,
          left: 14,
          right: 14,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            color: AppColors.black,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: Colors.amber, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(alert.icon, color: AppColors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert.message,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.white,
                      size: 18,
                    ),
                    onPressed: AlertNotificationService.dismissCurrentAlert,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
