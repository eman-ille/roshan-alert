/// No-op stub used on every platform except web. dart:html doesn't
/// exist outside a browser, so this file exists purely so the app
/// compiles on Android/iOS/desktop without ever referencing it.
Future<void> showBrowserNotification(String title, String message) async {}
