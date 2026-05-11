import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/session_manager.dart';
import 'article_comments_screen.dart';
import 'package:enginet/engineer_profile.dart';

class ArticleDetailScreen extends StatefulWidget {
  final String articleId;
  const ArticleDetailScreen({super.key, required this.articleId});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final supabase = Supabase.instance.client;

  // ─── State ───────────────────────────────────────────────────────────────
  Map<String, dynamic>? article;
  Map<String, dynamic>? _currentUser; // cached once
  bool isLoading = true;
  bool isLiked = false;
  bool isSaved = false;
  List<Map<String, dynamic>> comments = [];
  String? replyingToCommentId;
  String? replyingToUsername;
  int myRating = 0;
bool _isRating = false;

  // Debounce flags
  bool _isProcessingLike = false;
  bool _isProcessingBookmark = false;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  // ─── Safe articleId as int ────────────────────────────────────────────────
  int get _articleId => int.tryParse(widget.articleId) ?? 0;

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }
Future<void> _openAuthorProfile() async {
  final authorName = article?['author_name']?.toString() ?? '';
  if (authorName.isEmpty) return;

  try {
    final owner = await supabase
        .from('users')
        .select('id')
        .eq('username', authorName)
        .maybeSingle();

    if (owner == null || owner['id'] == null) {
      _showSnack('User profile not found');
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EngineerProfileScreen(
          targetUserId: owner['id'],
        ),
      ),
    );
  } catch (e) {
    debugPrint('❌ open author profile error: $e');
    _showSnack('Failed to open profile');
  }
}

Future<void> loadMyRating() async {
  if (_currentUser == null) return;

  final res = await supabase
      .from('article_ratings')
      .select('rating')
      .eq('user_id', _currentUser!['id'])
      .eq('article_id', _articleId)
      .maybeSingle();

  if (!mounted) return;

  setState(() {
    myRating = res?['rating'] ?? 0;
  });
}
  // ─── Init: fetch user once, then everything in parallel ──────────────────
  Future<void> _initData() async {
    if (_articleId == 0) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      _currentUser = await _fetchCurrentUser();
      await Future.wait([
  loadArticle(),
  loadComments(),
  checkLike(),
  checkSaved(),
  loadMyRating(),
]);
    } catch (e) {
      debugPrint('❌ _initData error: $e');
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<Map<String, dynamic>?> _fetchCurrentUser() async {
    try {
      final email = await SessionManager.getEmail();
      if (email == null) return null;
      return await supabase
          .from('users')
          .select('id, username, profile_image')
          .eq('email', email)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ _fetchCurrentUser error: $e');
      return null;
    }
  }

  // ─── Load article ─────────────────────────────────────────────────────────
  Future<void> loadArticle() async {
    try {
      final res = await supabase
          .from('articles')
          .select()
          .eq('id', _articleId)
          .single();

      if (!mounted) return;
      setState(() => article = res);
    } catch (e) {
      debugPrint('❌ loadArticle error: $e');
    }
  }

  // ─── Comments ─────────────────────────────────────────────────────────────
  Future<void> loadComments() async {
    try {
      final res = await supabase
          .from('comments')
          .select()
          .eq('article_id', _articleId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        comments = List<Map<String, dynamic>>.from(res as List);
      });
    } catch (e) {
      debugPrint('❌ loadComments error: $e');
    }
  }

  Future<void> addComment() async {
    if (_currentUser == null) {
      _showSnack('Please log in to comment.');
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      await supabase.from('comments').insert({
        'comment_user_id': _currentUser!['id'],
        'username': _currentUser!['username'],
        'profile_image': _currentUser!['profile_image'],
        'content': text,
        'article_id': _articleId,
        'parent_comment_id': replyingToCommentId,
      });
      final owner = await supabase
    .from('users')
    .select('id')
    .eq('username', article!['author_name'])
    .maybeSingle();

if (owner != null && owner['id'] != _currentUser!['id']) {
  await supabase.from('notifications').insert({
    'user_id': owner['id'],
    'message': '${_currentUser!['username']} commented on your article.',
    'is_read': 0,
    'article_id': int.parse(widget.articleId),
    'type': 'article_comment',
  });
}

      _commentController.clear();
      if (!mounted) return;
      setState(() {
        replyingToCommentId = null;
        replyingToUsername = null;
      });

      await loadComments();
    } catch (e) {
      debugPrint('❌ addComment error: $e');
      _showSnack('Failed to post comment. Please try again.');
    }
  }

  // ─── Like ─────────────────────────────────────────────────────────────────
  Future<void> checkLike() async {
    if (_currentUser == null) return;
    try {
      final res = await supabase
          .from('likes')
          .select()
          .eq('user_id', _currentUser!['id'])
          .eq('article_id', _articleId)
          .maybeSingle();

      if (!mounted) return;
      setState(() => isLiked = res != null);
    } catch (e) {
      debugPrint('❌ checkLike error: $e');
    }
  }

  Future<void> toggleLike() async {
    if (_currentUser == null || article == null) return;
    if (_isProcessingLike) return;

    _isProcessingLike = true;
    final wasLiked = isLiked;
    final currentLikes = (article!['likes'] ?? 0) as int;

    // Optimistic UI
    setState(() {
      isLiked = !wasLiked;
      article!['likes'] =
          wasLiked ? (currentLikes > 0 ? currentLikes - 1 : 0) : currentLikes + 1;
    });

    try {
      if (wasLiked) {
        await supabase
            .from('likes')
            .delete()
            .eq('user_id', _currentUser!['id'])
            .eq('article_id', _articleId);

        await supabase.from('articles').update({
          'likes': currentLikes > 0 ? currentLikes - 1 : 0,
        }).eq('id', _articleId);
      } else {
  await supabase.from('likes').insert({
    'user_id': _currentUser!['id'],
    'article_id': _articleId,
  });

  await supabase.from('articles').update({
    'likes': currentLikes + 1,
  }).eq('id', _articleId);


  final owner = await supabase
    .from('users')
    .select('id')
    .eq('username', article!['author_name'])
    .maybeSingle();

if (owner != null && owner['id'] != _currentUser!['id']) {
  await supabase.from('notifications').insert({
    'user_id': owner['id'],
    'message': '${_currentUser!['username']} liked your article.',
    'is_read': 0,
    'article_id': _articleId,
    'type': 'article_like',
  });
}
}
    } catch (e) {
      debugPrint('❌ toggleLike error: $e');
      // Revert
      if (!mounted) return;
      setState(() {
        isLiked = wasLiked;
        article!['likes'] = currentLikes;
      });
      _showSnack('Failed to update like. Please try again.');
    } finally {
      _isProcessingLike = false;
    }
  }

  // ─── Bookmark / Save ──────────────────────────────────────────────────────
  Future<void> checkSaved() async {
    if (_currentUser == null) return;
    try {
      final res = await supabase
          .from('article_bookmarks')
          .select()
          .eq('user_id', _currentUser!['id'])
          .eq('article_id', _articleId)
          .maybeSingle();

      if (!mounted) return;
      setState(() => isSaved = res != null);
    } catch (e) {
      debugPrint('❌ checkSaved error: $e');
    }
  }

  Future<void> toggleSave() async {
    if (_currentUser == null) return;
    if (_isProcessingBookmark) return;

    _isProcessingBookmark = true;
    final wasSaved = isSaved;

    // Optimistic UI
    setState(() => isSaved = !wasSaved);

    try {
      if (wasSaved) {
        await supabase
            .from('article_bookmarks')
            .delete()
            .eq('user_id', _currentUser!['id'])
            .eq('article_id', _articleId);
      } else {
        await supabase.from('article_bookmarks').insert({
          'user_id': _currentUser!['id'],
          'article_id': _articleId,
        });
      }
    } catch (e) {
      debugPrint('❌ toggleSave error: $e');
      // Revert
      if (!mounted) return;
      setState(() => isSaved = wasSaved);
      _showSnack('Failed to update bookmark. Please try again.');
    } finally {
      _isProcessingBookmark = false;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
  Future<void> _confirmDeleteArticle() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Delete Article"),
      content: const Text("Are you sure you want to delete this article?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await _deleteArticle();
  }
}

Future<void> _deleteArticle() async {
  try {
    await supabase.from('articles').delete().eq('id', _articleId);

    if (!mounted) return;

    _showSnack('Article deleted successfully');
    Navigator.pop(context);
  } catch (e) {
    debugPrint('❌ deleteArticle error: $e');
    _showSnack('Failed to delete article');
  }
}
Future<void> rateArticle(int value) async {
  if (_currentUser == null || article == null || _isRating) return;

  setState(() {
    _isRating = true;
    myRating = value;
  });

  try {
   await supabase.from('article_ratings').upsert(
  {
    'user_id': _currentUser!['id'],
    'article_id': _articleId,
    'rating': value,
  },
  onConflict: 'user_id,article_id',
);

    final ratingsRes = await supabase
        .from('article_ratings')
        .select('rating')
        .eq('article_id', _articleId);

    final ratings = List<Map<String, dynamic>>.from(ratingsRes);
    final avg = ratings.isEmpty
        ? 0.0
        : ratings
                .map((r) => (r['rating'] as num).toDouble())
                .reduce((a, b) => a + b) /
            ratings.length;

    await supabase
        .from('articles')
        .update({'rating': avg})
        .eq('id', _articleId);

    if (!mounted) return;

    setState(() {
      article!['rating'] = avg;
    });
  } catch (e) {
    debugPrint('❌ rateArticle error: $e');
    _showSnack('Failed to rate article');
  } finally {
    if (mounted) {
      setState(() => _isRating = false);
    }
  }
}

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF071739),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C94C6)),
        ),
      );
    }

    if (article == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF071739),
        appBar: AppBar(backgroundColor: const Color(0xFF071739)),
        body: const Center(
          child: Text('Article not found',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final title = article!['title']?.toString() ?? '';
    final content = article!['content']?.toString() ?? '';
    final imageUrl = article!['image_url']?.toString() ?? '';
    final authorName = article!['author_name']?.toString() ?? '';
    final authorImage = article!['author_image']?.toString() ?? '';
    final rating =
        double.tryParse(article!['rating']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
  children: [
    GestureDetector(
      onTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xFFE3C39D),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back, color: Colors.black),
      ),
    ),

    const Spacer(),

if (_currentUser != null &&
    _currentUser!['username'] == article!['author_name'])
  GestureDetector(
    onTap: _confirmDeleteArticle,
    child: Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.delete,
        color: Colors.white,
        size: 20,
      ),
    ),
  ),
  ],
),
            ),

            // ── Body ─────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7D93B0),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Author
Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
  child: GestureDetector(
    onTap: _openAuthorProfile,
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage:
              authorImage.isNotEmpty ? NetworkImage(authorImage) : null,
          backgroundColor: const Color(0xFF6C94C6),
          child: authorImage.isEmpty
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          authorName,
          style: GoogleFonts.agbalumo(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  ),
),

                          // Cover image
                          if (imageUrl.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorWidget: (c, u, e) => Container(
                                    height: 200,
                                    color: const Color(0xFFDDE3EA),
                                    child: const Icon(Icons.article,
                                        size: 60, color: Colors.grey),
                                  ),
                                  placeholder: (c, u) => Shimmer.fromColors(
                                    baseColor: const Color(0xFF1A2F55),
                                    highlightColor:
                                        const Color(0xFF2A4A7F),
                                    child: Container(
                                        height: 200, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),

                          // Title + stars
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
  children: [
    ...List.generate(
      5,
      (i) {
        final starValue = i + 1;

        return GestureDetector(
          onTap: () => rateArticle(starValue),
          child: Icon(
            starValue <= myRating
                ? Icons.star
                : Icons.star_border,
            color: Colors.orange,
            size: 24,
          ),
        );
      },
    ),
    const SizedBox(width: 6),
    Text(
      ' ${rating.toStringAsFixed(1)}',
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
),
                              ],
                            ),
                          ),
                          Padding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  child: Row(
    children: [
      GestureDetector(
        onTap: toggleLike,
        child: Icon(
          isLiked ? Icons.favorite : Icons.favorite_border,
          color: Colors.red,
          size: 22,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        '${article!['likes'] ?? 0}',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(width: 16),

      GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArticleCommentsScreen(
                articleId: widget.articleId,
              ),
            ),
          ).then((_) => loadComments());
        },
        child: const Icon(
          Icons.chat_bubble,
          color: Color(0xFF5B7FA6),
          size: 20,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        '${comments.length}',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),

      const Spacer(),

      GestureDetector(
        onTap: toggleSave,
        child: Icon(
          isSaved ? Icons.bookmark : Icons.bookmark_border,
          color: const Color(0xFF071739),
          size: 28,
        ),
      ),
    ],
  ),
),

                          // Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              content,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.6,
                              ),
                            ),
                          ),

                          
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}