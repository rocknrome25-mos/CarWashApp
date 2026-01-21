import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/admin_session.dart';

class SessionStore {
  static const _kKey = 'admin_session_v1';

  Future<void> save(AdminSession session) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, jsonEncode(session.toJson()));
  }

  Future<AdminSession?> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kKey);
    if (s == null || s.isEmpty) return null;
    final map = jsonDecode(s) as Map<String, dynamic>;
    return AdminSession.fromJson(map);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
  }
}
