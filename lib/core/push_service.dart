import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_manager.dart';

class PushService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _supabase = Supabase.instance.client;

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Cihaz için benzersiz token oluştur ve kaydet
    await _registerPushToken();
  }

  static Future<void> _registerPushToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Token zaten varsa tekrar oluşturma
      String? token = prefs.getString('push_token');
      
      if (token == null) {
        // Benzersiz cihaz token'ı oluştur
        final random = Random.secure();
        final bytes = List<int>.generate(32, (_) => random.nextInt(256));
        token = base64Url.encode(bytes);
        await prefs.setString('push_token', token);
      }

      // Supabase'e kaydet
      final email = await SessionManager.getEmail();
      if (email == null) return;

      await _supabase
          .from('users')
          .update({'push_token': token})
          .eq('email', email);
    } catch (e) {
      debugPrint('Push token register error: $e');
    }
  }

  // Local notification göster (uygulama açıkken)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'enginet_channel',
      'EngiNet Notifications',
      channelDescription: 'EngiNet platform notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    // payload'a göre yönlendir
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      // NavigationService ile yönlendirme yapılacak
      debugPrint('Notification tapped: $data');
    } catch (e) {
      debugPrint('Notification payload parse error: $e');
    }
  }

  // Supabase Realtime'dan gelen bildirim için local notification göster
  static Future<void> handleRealtimeNotification(
    Map<String, dynamic> notification,
  ) async {
    await showLocalNotification(
      title: 'EngiNet',
      body: notification['message']?.toString() ?? 'New notification',
      payload: jsonEncode({
        'type': notification['type'] ?? '',
        'book_id': notification['book_id'],
        'article_id': notification['article_id'],
        'question_id': notification['question_id'],
        'post_id': notification['post_id'],
      }),
    );
  }
}