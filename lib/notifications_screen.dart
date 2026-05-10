import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/questions_screen.dart';
import 'package:enginet/book_detail.dart';
import 'package:enginet/article_detail.dart';
import 'package:enginet/article_comments_screen.dart';
import 'package:enginet/course_comments_screen.dart';
import 'package:enginet/post_comments_screen.dart';
import 'dart:async';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;

  List _notifications = [];
  bool _isLoading = true;
  int? _currentUserId;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSub;
  @override
void dispose() {
  _notificationsSub?.cancel();
  super.dispose();
}

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  void _startNotificationsRealtime() {
  if (_currentUserId == null) return;

  _notificationsSub?.cancel();

  _notificationsSub = _supabase
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', _currentUserId!)
      .order('created_at', ascending: false)
      .listen((data) {
        if (!mounted) return;

        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      });
}

  Future<void> _loadData() async {
    await _fetchNotifications();
    await _markAsRead();
  }

  Future<void> _fetchNotifications() async {
    try {
      final email = await SessionManager.getEmail();
      if (email == null || email.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final userRes = await _supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .single();

      _currentUserId = userRes['id'] as int;
      _startNotificationsRealtime();

      final res = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _notifications = res;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      if (_currentUserId == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': 1})
          .eq('user_id', _currentUserId!)
          .eq('is_read', 0);
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> _openNotification(dynamic notification) async {
  final questionId = notification['question_id'];
  final bookId = notification['book_id'];
  final articleId = notification['article_id'];
  final courseId = notification['course_id'];
  final type = notification['type']?.toString() ?? '';
  final postId = notification['post_id'];

  debugPrint('NOTIFICATION CLICKED: $notification');
  debugPrint('NOTIFICATION CLICKED: $notification');

if (postId != null) {
  final post = await _supabase
      .from('posts')
      .select()
      .eq('id', postId)
      .maybeSingle();

  if (post == null) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PostCommentsScreen(post: post),
    ),
  );
  return;
}


  if (courseId != null) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CourseCommentsScreen(
        courseId: courseId.toString(),
      ),
    ),
  );
  return;
}

  if (articleId != null) {
    if (type == 'article_comment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleCommentsScreen(
            articleId: articleId.toString(),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(
            articleId: articleId.toString(),
          ),
        ),
      );
    }
    return;
  }

  if (bookId != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(bookId: bookId.toString()),
      ),
    );
    return;
  }

  if (questionId != null) {
    final question = await _supabase
        .from('questions')
        .select()
        .eq('id', questionId)
        .single();

    final user = await _supabase
        .from('users')
        .select('username, profile_image')
        .eq('id', question['user_id'])
        .maybeSingle();

    question['username'] = user?['username'] ?? '';
    question['profile_image'] = user?['profile_image'] ?? '';

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnswerScreen(question: question),
      ),
    );
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
        title: Text(
          "Notifications",
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 24,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE3C39D)),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_off_outlined,
                        color: Colors.white24,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No notifications yet",
                        style: GoogleFonts.robotoCondensed(
                          color: Colors.white38,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (_, i) {
                    final n = _notifications[i];
                    final isRead = n["is_read"] == 1;

                    return GestureDetector(
                      onTap: () => _openNotification(n),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isRead
                              ? const Color(0xFF1E3A5F)
                              : const Color(0xFF4B6382),
                          borderRadius: BorderRadius.circular(14),
                          border: isRead
                              ? null
                              : Border.all(color: const Color(0xFFE3C39D)),
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
                              child: Icon(
                                Icons.notifications,
                                color: isRead
                                    ? Colors.white38
                                    : const Color(0xFF071739),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n["message"] ?? "",
                                    style: TextStyle(
                                      color: isRead
                                          ? Colors.white70
                                          : Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _timeAgo(n["created_at"] ?? ""),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
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
                      ),
                    );
                  },
                ),
    );
  }
}