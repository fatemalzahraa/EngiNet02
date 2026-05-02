import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/session_manager.dart';

class CourseCommentsScreen extends StatefulWidget {
  final String courseId;

  const CourseCommentsScreen({super.key, required this.courseId});

  @override
  State<CourseCommentsScreen> createState() => _CourseCommentsScreenState();
}

class _CourseCommentsScreenState extends State<CourseCommentsScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> comments = [];
  Map<String, dynamic>? user;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final email = await SessionManager.getEmail();

    if (email != null) {
      user = await supabase
          .from('users')
          .select('id, username, profile_image')
          .eq('email', email)
          .maybeSingle();
    }

    await _loadComments();
  }

  Future<void> _loadComments() async {
    final res = await supabase
        .from('course_comments')
        .select()
        .eq('course_id', int.parse(widget.courseId))
        .order('created_at', ascending: true);

    if (!mounted) return;

    setState(() {
      comments = List<Map<String, dynamic>>.from(res);
    });
  }

  Future<void> _addComment() async {
    if (user == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await supabase.from('course_comments').insert({
      'course_id': int.parse(widget.courseId),
      'comment_user_id': user!['id'],
      'username': user!['username'],
      'profile_image': user!['profile_image'],
      'content': text,
    });

    _controller.clear();
    await _loadComments();
  }

  Future<void> _deleteComment(int commentId) async {
    await supabase
        .from('course_comments')
        .delete()
        .eq('id', commentId);

    await _loadComments();
  }

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final controller = TextEditingController(text: comment['content']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF071739),
        title: const Text(
          'Edit Comment',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Edit your comment...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await supabase
                  .from('course_comments')
                  .update({'content': controller.text})
                  .eq('id', comment['id']);

              Navigator.pop(context);
              await _loadComments();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),

      // 🔥 زر الرجوع الصح
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        elevation: 0,
        leadingWidth: 64,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE3C39D),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Color(0xFF071739),
              size: 24,
            ),
          ),
        ),
        title: Text(
          'Comments',
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 22,
          ),
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: comments.isEmpty
                ? const Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final c = comments[index];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (c['profile_image'] ?? '')
                                  .toString()
                                  .isNotEmpty
                              ? NetworkImage(c['profile_image'])
                              : null,
                          backgroundColor: const Color(0xFF4A6FA5),
                        ),

                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c['username'] ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),

                            // 🔥 الثلاث نقاط
                            if (user != null &&
                                user!['id'] == c['comment_user_id'])
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white70),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editComment(c);
                                  } else if (value == 'delete') {
                                    _deleteComment(c['id']);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Delete')),
                                ],
                              ),
                          ],
                        ),

                        subtitle: Text(
                          c['content'] ?? '',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  ),
          ),

          // ✍️ input التعليق
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF2C3E50),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send, color: Color(0xFFE3C39D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}