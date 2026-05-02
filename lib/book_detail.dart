import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BookDetailScreen extends StatefulWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final supabase = Supabase.instance.client;

  // ─── State ───────────────────────────────────────────────────────────────
  Map<String, dynamic>? book;
  Map<String, dynamic>? _currentUser;   // cached once, never re-fetched
  bool isLoading = true;
  bool isBookmarked = false;
  bool isLiked = false;
  List<Map<String, dynamic>> comments = [];
  int selectedRating = 0;
  String? replyingToCommentId;
  String? replyingToUsername;

  // Debounce flags
  bool _isProcessingLike = false;
  bool _isProcessingBookmark = false;
  bool _isProcessingRating = false;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // ─── Parsed bookId (safe) ────────────────────────────────────────────────
  int get _bookId {
    return int.tryParse(widget.bookId) ?? 0;
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Init: fetch user once, then load everything in parallel ─────────────
  Future<void> _initData() async {
    if (_bookId == 0) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      _currentUser = await _fetchCurrentUser();
      await Future.wait([
        loadBook(),
        checkLike(),
        checkBookmark(),
        loadComments(),
      ]);
    } catch (e) {
      debugPrint('❌ _initData error: $e');
    }

    if (mounted) setState(() => isLoading = false);
  }

  /// Fetch the logged-in user row from Supabase (called only once).
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

  // ─── Load book ───────────────────────────────────────────────────────────
  Future<void> loadBook() async {
    try {
      final res = await supabase
          .from('books')
          .select()
          .eq('id', _bookId)
          .single();

      final engineer = await supabase
          .from('users')
          .select('username, profile_image')
          .eq('username', res['author_username'] ?? '')
          .maybeSingle();

      res['engineer'] = engineer;

      if (_currentUser != null) {
        final existingRating = await supabase
            .from('book_ratings')
            .select('rating')
            .eq('user_id', _currentUser!['id'])
            .eq('book_id', _bookId)
            .maybeSingle();

        if (mounted) {
          setState(() => selectedRating = existingRating?['rating'] ?? 0);
        }
      }

      if (!mounted) return;
      setState(() => book = res);
    } catch (e) {
      debugPrint('❌ loadBook error: $e');
    }
  }

  // ─── Comments ─────────────────────────────────────────────────────────────
  Future<void> loadComments() async {
    try {
      final res = await supabase
          .from('comments')
          .select()
          .eq('book_id', _bookId)
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
        'book_id': _bookId,
        'parent_comment_id': replyingToCommentId,
      });

      // Send notification
      if (replyingToCommentId != null) {
        await _notifyReply();
      } else {
        await _notifyBookOwner();
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

  Future<void> _notifyReply() async {
    try {
      final parentComment = await supabase
          .from('comments')
          .select('comment_user_id')
          .eq('id', replyingToCommentId!)
          .single();

      if (parentComment['comment_user_id'] != _currentUser!['id']) {
        await supabase.from('notifications').insert({
          'user_id': parentComment['comment_user_id'],
          'message': '${_currentUser!['username']} replied to your comment',
          'is_read': 0,
          'book_id': _bookId,
        });
      }
    } catch (e) {
      debugPrint('❌ _notifyReply error: $e');
    }
  }

  Future<void> _notifyBookOwner() async {
    try {
      final ownerUsername =
          book?['author_username'] ?? book?['author'];
      if (ownerUsername == null ||
          ownerUsername == _currentUser!['username']) return;

      final owner = await supabase
          .from('users')
          .select('id')
          .eq('username', ownerUsername)
          .maybeSingle();

      if (owner != null) {
        await supabase.from('notifications').insert({
          'user_id': owner['id'],
          'message':
              '${_currentUser!['username']} commented on your book.',
          'is_read': 0,
          'book_id': _bookId,
        });
      }
    } catch (e) {
      debugPrint('❌ _notifyBookOwner error: $e');
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
          .eq('book_id', _bookId)
          .maybeSingle();

      if (!mounted) return;
      setState(() => isLiked = res != null);
    } catch (e) {
      debugPrint('❌ checkLike error: $e');
    }
  }

  Future<void> toggleLike() async {
    if (_currentUser == null || book == null) return;
    if (_isProcessingLike) return; // debounce

    _isProcessingLike = true;
    final userId = _currentUser!['id'];
    final wasLiked = isLiked;
    final currentLikes = (book!['likes'] ?? 0) as int;

    // Optimistic UI update
    setState(() {
      isLiked = !wasLiked;
      book!['likes'] = wasLiked
          ? (currentLikes > 0 ? currentLikes - 1 : 0)
          : currentLikes + 1;
    });

    try {
      if (wasLiked) {
        await supabase
            .from('likes')
            .delete()
            .eq('user_id', userId)
            .eq('book_id', _bookId);

        await supabase.from('books').update({
          'likes': currentLikes > 0 ? currentLikes - 1 : 0,
        }).eq('id', _bookId);
      } else {
        await supabase.from('likes').insert({
          'user_id': userId,
          'book_id': _bookId,
        });

        await supabase.from('books').update({
          'likes': currentLikes + 1,
        }).eq('id', _bookId);
      }
    } catch (e) {
      debugPrint('❌ toggleLike error: $e');
      // Revert on failure
      if (!mounted) return;
      setState(() {
        isLiked = wasLiked;
        book!['likes'] = currentLikes;
      });
      _showSnack('Failed to update like. Please try again.');
    } finally {
      _isProcessingLike = false;
    }
  }

  // ─── Rating ───────────────────────────────────────────────────────────────
  Future<void> rateBook(int ratingValue) async {
    if (_currentUser == null || book == null) return;
    if (_isProcessingRating) return; // debounce

    _isProcessingRating = true;
    final userId = _currentUser!['id'];
    final prevRating = selectedRating;

    // Optimistic UI update
    setState(() {
      selectedRating =
          selectedRating == ratingValue ? 0 : ratingValue;
    });

    try {
      if (prevRating == ratingValue) {
        await supabase
            .from('book_ratings')
            .delete()
            .eq('user_id', userId)
            .eq('book_id', _bookId);
      } else {
       await supabase.from('book_ratings').upsert(
  {
    'user_id': userId,
    'book_id': _bookId,
    'rating': ratingValue,
  },
  onConflict: 'user_id,book_id',
);
      }

      // Recalculate average from DB
      final allRatings = await supabase
          .from('book_ratings')
          .select('rating')
          .eq('book_id', _bookId);

      double newAvg = 0.0;
      final list = allRatings as List;
      if (list.isNotEmpty) {
        final sum =
            list.fold<int>(0, (prev, r) => prev + (r['rating'] as int));
        newAvg = sum / list.length;
      }

      await supabase.from('books').update({
        'rating': newAvg.toStringAsFixed(1),
      }).eq('id', _bookId);

      if (!mounted) return;
      setState(() => book!['rating'] = newAvg.toStringAsFixed(1));
    } catch (e) {
      debugPrint('❌ rateBook error: $e');
      // Revert on failure
      if (!mounted) return;
      setState(() => selectedRating = prevRating);
      _showSnack('Failed to submit rating. Please try again.');
    } finally {
      _isProcessingRating = false;
    }
  }

  // ─── Bookmark ─────────────────────────────────────────────────────────────
  Future<void> checkBookmark() async {
    if (_currentUser == null) return;
    try {
      final res = await supabase
          .from('bookmarks')
          .select()
          .eq('user_id', _currentUser!['id'])
          .eq('book_id', _bookId)
          .maybeSingle();

      if (!mounted) return;
      setState(() => isBookmarked = res != null);
    } catch (e) {
      debugPrint('❌ checkBookmark error: $e');
    }
  }

  Future<void> toggleBookmark() async {
    if (_currentUser == null) return;
    if (_isProcessingBookmark) return; // debounce

    _isProcessingBookmark = true;
    final wasBookmarked = isBookmarked;

    // Optimistic UI update
    setState(() => isBookmarked = !wasBookmarked);

    try {
      if (wasBookmarked) {
        await supabase
            .from('bookmarks')
            .delete()
            .eq('user_id', _currentUser!['id'])
            .eq('book_id', _bookId);
      } else {
        await supabase.from('bookmarks').insert({
          'user_id': _currentUser!['id'],
          'book_id': _bookId,
        });
      }
    } catch (e) {
      debugPrint('❌ toggleBookmark error: $e');
      // Revert on failure
      if (!mounted) return;
      setState(() => isBookmarked = wasBookmarked);
      _showSnack('Failed to update bookmark. Please try again.');
    } finally {
      _isProcessingBookmark = false;
    }
  }

  // ─── URL helpers ──────────────────────────────────────────────────────────
  Future<void> readBook(String url) async {
    if (url.isEmpty) {
      _showSnack('No book file/link available');
      return;
    }
    final viewerUrl =
        'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(url)}';
    try {
      await launchUrl(Uri.parse(viewerUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ readBook error: $e');
      _showSnack('Could not open the book.');
    }
  }

  Future<void> openUrl(String url) async {
    if (url.isEmpty) {
      _showSnack('No book file/link available');
      return;
    }
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ openUrl error: $e');
      _showSnack('Could not open the link.');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Build a Map for O(1) parent-comment lookup.
  Map<String, Map<String, dynamic>> get _commentsMap {
    return {for (final c in comments) c['id'].toString(): c};
  }

  // ─── Comment widgets ──────────────────────────────────────────────────────
  Widget _buildComment(Map<String, dynamic> c, bool isReply) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6, left: isReply ? 40 : 0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isReply
              ? const Color(0xFFDDD4C4)
              : const Color(0xFFE8DED0),
          borderRadius: BorderRadius.circular(10),
          border: isReply
              ? const Border(
                  left:
                      BorderSide(color: Color(0xFF6C94C6), width: 3),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 13 : 16,
              backgroundImage:
                  (c['profile_image'] ?? '').toString().isNotEmpty
                      ? NetworkImage(c['profile_image'])
                      : null,
              backgroundColor: const Color(0xFF6C94C6),
              child: (c['profile_image'] ?? '').toString().isEmpty
                  ? Icon(Icons.person,
                      size: isReply ? 13 : 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['username'] ?? 'User',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isReply) _buildParentPreview(c),
                  Text(
                    c['content'] ?? '',
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  if (!isReply)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          replyingToCommentId = c['id'].toString();
                          replyingToUsername = c['username'];
                        });
                        // Auto-focus the comment field
                        FocusScope.of(context)
                            .requestFocus(_commentFocusNode);
                      },
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B7FA6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a preview of the parent comment inside a reply — uses Map for O(1) lookup.
  Widget _buildParentPreview(Map<String, dynamic> c) {
    final parentId = c['parent_comment_id']?.toString();
    if (parentId == null) return const SizedBox.shrink();

    final parent = _commentsMap[parentId];
    final parentUsername = parent?['username']?.toString() ?? '';
    final parentContent = parent?['content']?.toString() ?? '';

    if (parentUsername.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF6C94C6).withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parentUsername,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF5B7FA6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            parentContent.length > 60
                ? '${parentContent.substring(0, 60)}...'
                : parentContent,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCommentsTree() {
    final map = _commentsMap; // build once per render
    final parentComments =
        comments.where((c) => c['parent_comment_id'] == null).toList();

    final widgets = <Widget>[];
    for (final parent in parentComments) {
      widgets.add(_buildComment(Map<String, dynamic>.from(parent), false));

      final replies = comments
          .where((c) =>
              c['parent_comment_id']?.toString() ==
              parent['id'].toString())
          .toList();

      for (final reply in replies) {
        widgets.add(
            _buildComment(Map<String, dynamic>.from(reply), true));
      }
    }

    // suppress unused variable warning
    map;
    return widgets;
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF071739),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF6C94C6))),
      );
    }

    if (book == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF071739),
        appBar: AppBar(backgroundColor: const Color(0xFF071739)),
        body: const Center(
          child: Text('Book not found',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final title = book!['title']?.toString() ?? '';
    final author = book!['engineer']?['username']?.toString() ??
        book!['author_username']?.toString() ??
        book!['author']?.toString() ??
        '';
    final authorImage =
        book!['engineer']?['profile_image']?.toString() ?? '';
    final imageUrl = book!['image_url']?.toString() ?? '';
    final fileUrl = (book!['book_url']?.toString().isNotEmpty == true
            ? book!['book_url'].toString()
            : book!['file_url']?.toString()) ??
        '';
    final description = book!['description']?.toString() ?? '';
    final averageRating =
        double.tryParse(book!['rating']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(
                            context, '/home');
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3C39D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Book details',
                    style: GoogleFonts.agbalumo(
                      fontSize: 28,
                      color: const Color(0xFFE3C39D),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 12),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8C09A),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF3E8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Author row
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: authorImage.isNotEmpty
                                    ? NetworkImage(authorImage)
                                    : null,
                                backgroundColor:
                                    const Color(0xFF6C94C6),
                                child: authorImage.isEmpty
                                    ? const Icon(Icons.person,
                                        color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                author,
                                style: GoogleFonts.agbalumo(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Cover image
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      height: 200,
                                      width: 160,
                                      fit: BoxFit.cover,
                                      errorWidget: (c, u, e) =>
                                          _placeholderCover(),
                                      placeholder: (c, u) =>
                                          Shimmer.fromColors(
                                        baseColor:
                                            const Color(0xFF1A2F55),
                                        highlightColor:
                                            const Color(0xFF2A4A7F),
                                        child: Container(
                                          height: 200,
                                          width: 160,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : _placeholderCover(),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Description
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Read / Download buttons
                          Row(
                            children: [
                              Expanded(
                                child: _actionButton(
                                  label: 'Read',
                                  icon: Icons.menu_book,
                                  onTap: () => readBook(fileUrl),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _actionButton(
                                  label: 'Download',
                                  icon: Icons.download,
                                  onTap: () => openUrl(fileUrl),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Rating / likes / bookmark row
                          Row(
                            children: [
                              // Stars
                              ...List.generate(5, (index) {
                                return GestureDetector(
                                  onTap: () => rateBook(index + 1),
                                  child: Icon(
                                    index < selectedRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: index < selectedRating
                                        ? Colors.orange
                                        : Colors.grey,
                                    size: 22,
                                  ),
                                );
                              }),
                              const SizedBox(width: 4),
                              Text(
                                averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Comment count
                              const Icon(Icons.chat_bubble,
                                  color: Color(0xFF5B7FA6), size: 18),
                              const SizedBox(width: 4),
                              Text('${comments.length}'),
                              const SizedBox(width: 12),

                              // Like
                              GestureDetector(
                                onTap: toggleLike,
                                child: Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('${book!['likes'] ?? 0}'),

                              const Spacer(),

                              // Bookmark
                              GestureDetector(
                                onTap: toggleBookmark,
                                child: Icon(
                                  isBookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: const Color(0xFF071739),
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Comments section
                          const Text(
                            'Comments',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._buildCommentsTree(),
                          const SizedBox(height: 10),

                          // Reply indicator
                          if (replyingToUsername != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Replying to $replyingToUsername',
                                      style: const TextStyle(
                                          color: Colors.black87),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 18),
                                    onPressed: () {
                                      setState(() {
                                        replyingToCommentId = null;
                                        replyingToUsername = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),

                          // Comment input
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  focusNode: _commentFocusNode,
                                  decoration: InputDecoration(
                                    hintText:
                                        replyingToUsername == null
                                            ? 'Write a comment...'
                                            : 'Write a reply...',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: addComment,
                                icon: const Icon(
                                  Icons.send,
                                  color: Color(0xFF6C94C6),
                                ),
                              ),
                            ],
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

  // ─── Small helpers ────────────────────────────────────────────────────────
  Widget _placeholderCover() => Container(
        height: 200,
        width: 160,
        color: const Color(0xFFE0D5C5),
        child:
            const Icon(Icons.book, size: 60, color: Colors.brown),
      );

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF6C94C6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.agbalumo(
                  color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}