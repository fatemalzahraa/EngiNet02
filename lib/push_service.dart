class PushService {
  static Future<void> initialize() async {
    // هنا تهيئة الإشعارات (Firebase أو local notifications)
    print("PushService initialized");
  }

  static Future<void> handleRealtimeNotification(Map<String, dynamic> data) async {
    print("New notification: $data");

    // هنا لاحقًا تضيف local notification
  }
}