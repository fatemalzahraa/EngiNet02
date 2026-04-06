import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _tokenKey    = 'auth_token';
  static const _roleKey     = 'role';
  static const _usernameKey = 'username';
  static const _emailKey    = 'email';

  static Future<void> saveSession({
    required String token,
    required String role,
    required String username,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey,    token);
    await prefs.setString(_roleKey,     role);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_emailKey,    email);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /// Returns true only if a token exists AND has not expired.
  static Future<bool> hasSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    return !_isTokenExpired(token);
  }

  // ── JWT expiry check (no external package needed) ──────
  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      // Base64url → base64 padding
      String payload = parts[1];
      final mod = payload.length % 4;
      if (mod != 0) payload += '=' * (4 - mod);
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');

      final decoded = utf8.decode(base64.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp == null) return false; // no expiry → treat as valid

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (exp as int) * 1000,
        isUtc: true,
      );
      // Add 30-second grace window for clock skew
      return DateTime.now().toUtc().isAfter(expiry.subtract(const Duration(seconds: 30)));
    } catch (_) {
      return true; // malformed token → treat as expired
    }
  }
}