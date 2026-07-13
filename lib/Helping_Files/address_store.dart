import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny wrapper around SharedPreferences for saving/loading the address
/// picked during onboarding. On Flutter web this is backed by the
/// browser's localStorage, so it survives a page refresh — which plain
/// Navigator route arguments do NOT, since those only live in memory
/// and are wiped the moment the page reloads.
class AddressStore {
  static const _key = 'ra_address';

  static Future<void> save(Map<String, dynamic> address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(address));
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}