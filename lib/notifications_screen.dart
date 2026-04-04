import 'dart:convert';

import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _fetchNotifications();
    await _markAsRead();
  }

  Future<void> _fetchNotifications() async {
    try {
      final token = await SessionManager.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch notifications');
      }

      final res = jsonDecode(response.body) as List<dynamic>;

      if (!mounted) return;
      setState(() {
        _notifications = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      final token = await SessionManager.getToken();
      if (token == null || token.isEmpty) return;

      await http.post(
        Uri.parse('${AppConstants.baseUrl}/notifications/read'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      // تجاهل الخطأ
    }
  }

  String _timeAgo(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return "";
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE3C39D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Notifications",
            style: GoogleFonts.agbalumo(
                color: const Color(0xFFE3C39D), fontSize: 24)),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFE3C39D)))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_off_outlined,
                          color: Colors.white24, size: 60),
                      const SizedBox(height: 16),
                      Text("No notifications yet",
                          style: GoogleFonts.robotoCondensed(
                              color: Colors.white38, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (_, i) {
                    final n = _notifications[i];
                    // ✅ Supabase يرجع bool مباشرة بدل 0/1
                    final isRead = n["is_read"] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isRead
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFF4B6382),
                        borderRadius: BorderRadius.circular(14),
                        border: isRead
                            ? null
                            : Border.all(
                                color: const Color(0xFFE3C39D)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isRead
                                  ? const Color(0xFF2A4A6F)
                                  : const Color(0xFFE3C39D),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.notifications,
                                color: isRead
                                    ? Colors.white38
                                    : const Color(0xFF071739),
                                size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(n["message"] ?? "",
                                    style: TextStyle(
                                        color: isRead
                                            ? Colors.white70
                                            : Colors.white,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                    _timeAgo(n["created_at"] ?? ""),
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE3C39D),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
