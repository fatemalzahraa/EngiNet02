import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/session_manager.dart';
import 'dart:async';
class PostCommentsScreen extends StatefulWidget {
  final dynamic post;

  const PostCommentsScreen({super.key, required this.post});

  @override
  State<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends State<PostCommentsScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _comments = [];
  Map<String, dynamic>? _currentUser;
  final TextEditingController _ctrl = TextEditingController();
  bool _isPosting = false;
  StreamSubscription<List<Map<String, dynamic>>>? _commentsSub;

  int get _postId => int.tryParse(widget.post['id'].toString()) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
_ctrl.dispose();
super.dispose();
  }
Future<void> _editComment(Map<String, dynamic> comment) async {
  final editCtrl = TextEditingController(
    text: comment['content']?.toString() ?? '',
  );

  final newText = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Comment'),
      content: TextField(
        controller: editCtrl,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Edit your comment...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, editCtrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (newText == null || newText.isEmpty) return;

  await supabase
      .from('comments')
      .update({'content': newText})
      .eq('id', comment['id']);

  if (!mounted) return;

  setState(() {
    final index = _comments.indexWhere((c) => c['id'] == comment['id']);
    if (index != -1) {
      _comments[index]['content'] = newText;
    }
  });
}

Future<void> _deleteComment(Map<String, dynamic> comment) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Comment'),
      content: const Text('Are you sure you want to delete this comment?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Yes, delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await supabase
      .from('comments')
      .delete()
      .eq('id', comment['id']);

  if (!mounted) return;

  setState(() {
    _comments.removeWhere((c) => c['id'] == comment['id']);
  });
}
  Future<void> _loadAll() async {
    final email = await SessionManager.getEmail();

    if (email != null) {
      _currentUser = await supabase
          .from('users')
          .select('id, username, profile_image')
          .eq('email', email)
          .maybeSingle();
    }

    await _fetchComments();
    _startCommentsRealtime();
  }
  void _startCommentsRealtime() {
  _commentsSub?.cancel();

  _commentsSub = supabase
      .from('comments')
      .stream(primaryKey: ['id'])
      .eq('post_id', _postId)
      .order('created_at', ascending: true)
      .listen((data) {
        if (!mounted) return;

        setState(() {
          _comments = data;
        });
      });
}

  Future<void> _fetchComments() async {
    try {
      final res = await supabase
          .from('comments')
          .select()
          .eq('post_id', _postId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _comments = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('❌ Error fetching post comments: $e');
    }
  }

  Future<void> _postComment() async {
    if (_ctrl.text.trim().isEmpty || _isPosting) return;
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    setState(() => _isPosting = true);
    final commentText = _ctrl.text.trim();

final tempComment = {
  'id': DateTime.now().millisecondsSinceEpoch,
  'post_id': _postId,
  'comment_user_id': _currentUser!['id'],
  'username': _currentUser!['username'],
  'profile_image': _currentUser!['profile_image'],
  'content': commentText,
  'created_at': DateTime.now().toIso8601String(),
};

setState(() {
  _comments.add(tempComment);
});

_ctrl.clear();

    try {
      await supabase.from('comments').insert({
  'post_id': _postId,
  'comment_user_id': _currentUser!['id'],
  'username': _currentUser!['username'],
  'profile_image': _currentUser!['profile_image'],
  'content': commentText,
});



final postOwnerId = widget.post['user_id'];


if (postOwnerId != null && postOwnerId != _currentUser!['id']) {
  await supabase.from('notifications').insert({
    'user_id': postOwnerId,
    'post_id': _postId,
    'type': 'post_comment',
    'message': '${_currentUser!['username']} commented on your post',
    'is_read': 0,
  });
}

    } catch (e) {
      debugPrint('❌ Error posting comment: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.post['username']?.toString() ?? '';
    final profileImage = widget.post['profile_image']?.toString() ?? '';
    final content = widget.post['content']?.toString() ?? '';
    final likes = widget.post['likes'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE3C39D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Comments',
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3C39D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                      backgroundColor: const Color(0xFF4B6382),
                      child: profileImage.isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      username,
                      style: GoogleFonts.robotoCondensed(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF071739),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  content,
                  style: const TextStyle(color: Color(0xFF071739)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.favorite_border,
                        color: Color(0xFF071739), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '$likes',
                      style: const TextStyle(color: Color(0xFF071739)),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.chat_bubble_outline,
                        color: Color(0xFF071739), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${_comments.length}',
                      style: const TextStyle(color: Color(0xFF071739)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Comments (${_comments.length})',
                style: GoogleFonts.agbalumo(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
          ),

          Expanded(
            child: _comments.isEmpty
                ? const Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      final cUsername = c['username']?.toString() ?? '';
                      final cProfileImage = c['profile_image']?.toString() ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA68868),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundImage: cProfileImage.isNotEmpty
                                      ? NetworkImage(cProfileImage)
                                      : null,
                                  backgroundColor: const Color(0xFF4B6382),
                                  child: cProfileImage.isEmpty
                                      ? const Icon(Icons.person,
                                          size: 15, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cUsername,
                                  style: GoogleFonts.robotoCondensed(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF071739),
                                  ),
                                ),
                                const Spacer(),

if (_currentUser != null &&
    c['comment_user_id'] == _currentUser!['id'])
  PopupMenuButton<String>(
    onSelected: (value) {
      if (value == 'edit') {
        _editComment(c);
      } else if (value == 'delete') {
        _deleteComment(c);
      }
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: 'edit',
        child: Text('Edit'),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text('Delete'),
      ),
    ],
  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c['content']?.toString() ?? '',
                              style: const TextStyle(color: Color(0xFF071739)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: const Color(0xFF0D2240),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Write your comment...',
                        hintStyle: TextStyle(color: Colors.white38),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _postComment,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: _isPosting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}