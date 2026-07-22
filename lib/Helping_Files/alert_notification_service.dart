import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'browser_notifier_stub.dart'
    if (dart.library.html) 'browser_notifier_web.dart';
import 'alert_store.dart';
import 'app_theme.dart';

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

/// Broadcasts in-app heads-up alerts AND device tray notifications.
class AlertNotificationService {
  AlertNotificationService._();

  static final ValueNotifier<AlertNotification?> currentAlert =
      ValueNotifier<AlertNotification?>(null);

  static Timer? _autoDismissTimer;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isPluginInitialized = false;

  static Future<void> initLocalNotifications() async {
    if (kIsWeb) return;
    if (_isPluginInitialized) return;

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
      await _localNotificationsPlugin.initialize(initSettings);
      _isPluginInitialized = true;
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

    // Trigger real device status bar / lock screen tray notification
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
