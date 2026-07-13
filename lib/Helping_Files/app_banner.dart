import 'package:flutter/foundation.dart';

/// Global "pending confirmation message" queue.
///
/// Any screen can set AppBanner.pendingMessage.value = 'Some text' to
/// have Home display it as a top banner — regardless of HOW that screen
/// was reached (the "Report an Outage" button, the bottom nav tab, a
/// deep link, etc). This avoids relying on Navigator.pop(context, result),
/// which only works if the screen was reached via Navigator.push in the
/// first place — using pop() after pushReplacementNamed (like tapping a
/// bottom nav tab) has nothing to pop back to and crashes.
class AppBanner {
  AppBanner._();

  static final ValueNotifier<String?> pendingMessage = ValueNotifier<String?>(
    null,
  );
}
