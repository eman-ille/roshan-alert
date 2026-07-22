// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> showBrowserNotification(String title, String message) async {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: message);
    } else if (html.Notification.permission != 'denied') {
      final permission = await html.Notification.requestPermission();
      if (permission == 'granted') {
        html.Notification(title, body: message);
      }
    }
  } catch (_) {}
}
