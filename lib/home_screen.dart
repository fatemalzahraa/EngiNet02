import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enginet/engineer_profile.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/post_comments_screen.dart';
import 'package:enginet/core/app_colors.dart';
import 'package:enginet/book_detail.dart';
import 'package:enginet/article_detail.dart';
import 'package:enginet/course_details.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> engineers = [];
  List<dynamic> posts = [];
  bool isLoading = true;
  int _page = 0;
  final int _limit = 10;
  bool _hasMore = true;
  bool _loadingMore = false;

  final ScrollController _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;

  String? currentUsername;
  int? currentUserId;
  Set<int> followedEngineerIds = {};
  String? _selectedSpecialty;
  Map<String, String> _engineerSpecialtyByUsername = {};

  final List<String> _specialties = [
    'All',
    'Computer Engineering',
    'Civil Engineering',
    'Mechanical Engineering',
    'Electrical Engineering',
    'Software Engineering',
    'Chemical Engineering',
    'Biomedical Engineering',
    'Environmental Engineering',
    'Industrial Engineering',
  ];

  @override
  void initState() {
    super.initState();
    loadData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final email = await SessionManager.getEmail();
    if (email == null || email.isEmpty) return;

    final userRes = await _supabase
        .from('users')
        .select('id, username')
        .eq('email', email)
        .maybeSingle();

    currentUserId = userRes?['id'];
    currentUsername =
        userRes?['username']?.toString() ?? await SessionManager.getUsername();
  }

  Future<List<dynamic>> _enrichPosts(List<dynamic> rawPosts) async {
    if (rawPosts.isEmpty) return [];

    final postIds = rawPosts.map((p) => p['id']).toList();

    // ── Comments count ──
    final comments = await _supabase
        .from('comments')
        .select('post_id')
        .inFilter('post_id', postIds);

    final commentsCount = <dynamic, int>{};
    for (var c in comments) {
      final pid = c['post_id'];
      commentsCount[pid] = (commentsCount[pid] ?? 0) + 1;
    }

    // ── Likes & saves ──
    Set<dynamic> likedIds = {};
    Set<dynamic> savedIds = {};

    if (currentUserId != null) {
      final likes = await _supabase
          .from('likes')
          .select('post_id')
          .eq('user_id', currentUserId!)
          .inFilter('post_id', postIds);

      final saves = await _supabase
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', currentUserId!)
          .inFilter('post_id', postIds);

      likedIds = likes.map((l) => l['post_id']).toSet();
      savedIds = saves.map((s) => s['post_id']).toSet();
    }

    // ── Linked courses ──
    final courseIds = rawPosts
        .where((p) => p['linked_course_id'] != null)
        .map((p) => int.tryParse(p['linked_course_id'].toString()))
        .whereType<int>()
        .toSet()
        .toList();

    final Map<int, Map<String, dynamic>> courseMap = {};
    if (courseIds.isNotEmpty) {
      final courses = await _supabase
          .from('courses')
          .select('id, title, image_url')
          .inFilter('id', courseIds);
      for (final c in courses) {
        courseMap[int.tryParse(c['id'].toString()) ?? 0] =
            Map<String, dynamic>.from(c);
      }
    }

    // ── Linked books ──
    final bookIds = rawPosts
        .where((p) => p['linked_book_id'] != null)
        .map((p) => int.tryParse(p['linked_book_id'].toString()))
        .whereType<int>()
        .toSet()
        .toList();

    final Map<int, Map<String, dynamic>> bookMap = {};
    if (bookIds.isNotEmpty) {
      final books = await _supabase
          .from('books')
          .select('id, title, image_url')
          .inFilter('id', bookIds);
      for (final b in books) {
        bookMap[int.tryParse(b['id'].toString()) ?? 0] =
            Map<String, dynamic>.from(b);
      }
    }

    // ── Linked articles ──
    final articleIds = rawPosts
        .where((p) => p['linked_article_id'] != null)
        .map((p) => int.tryParse(p['linked_article_id'].toString()))
        .whereType<int>()
        .toSet()
        .toList();

    final Map<int, Map<String, dynamic>> articleMap = {};
    if (articleIds.isNotEmpty) {
      final articles = await _supabase
          .from('articles')
          .select('id, title, image_url')
          .inFilter('id', articleIds);
      for (final a in articles) {
        articleMap[int.tryParse(a['id'].toString()) ?? 0] =
            Map<String, dynamic>.from(a);
      }
    }

    return rawPosts.map((post) {
      final pid = post['id'];
      final courseId = post['linked_course_id'] != null
          ? int.tryParse(post['linked_course_id'].toString())
          : null;
      final bookId = post['linked_book_id'] != null
          ? int.tryParse(post['linked_book_id'].toString())
          : null;
      final articleId = post['linked_article_id'] != null
          ? int.tryParse(post['linked_article_id'].toString())
          : null;

      return {
        ...post,
        'comments_count': commentsCount[pid] ?? 0,
        'is_liked': likedIds.contains(pid),
        'is_saved': savedIds.contains(pid),
        if (courseId != null && courseMap.containsKey(courseId))
          'linked_course': courseMap[courseId],
        if (bookId != null && bookMap.containsKey(bookId))
          'linked_book': bookMap[bookId],
        if (articleId != null && articleMap.containsKey(articleId))
          'linked_article': articleMap[articleId],
      };
    }).toList();
  }

  Future<void> loadData() async {
    if (mounted) setState(() => isLoading = true);
    try {
      await _loadCurrentUser();

      if (currentUserId != null) {
        final followsRes = await _supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', currentUserId!);

        followedEngineerIds =
            (followsRes as List).map((e) => e['following_id'] as int).toSet();
      }

      _page = 0;

      List<String> studentInterests = [];
      String studentSpecialty = '';

      if (currentUserId != null) {
        try {
          final profileRes = await _supabase
              .from('student_profiles')
              .select('interests, specialty')
              .eq('user_id', currentUserId!)
              .maybeSingle();

          if (profileRes != null) {
            studentSpecialty = profileRes['specialty']?.toString() ?? '';
            final interestsStr = profileRes['interests']?.toString() ?? '';
            studentInterests = interestsStr
                .split(',')
                .map((e) => e.trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (e) {
          debugPrint('Student profile fetch error: $e');
        }
      }

      final allEngineersRes = await _supabase
          .from('users')
          .select('id, username, profile_image, points, university')
          .eq('role', 'engineer');

      List<dynamic> allEngineers = allEngineersRes as List;

      List<dynamic> matchedEngineers = [];
      List<dynamic> otherEngineers = [];

      if (studentInterests.isNotEmpty || studentSpecialty.isNotEmpty) {
        final engineerIds = allEngineers.map((e) => e['id'] as int).toList();

        final engProfiles = engineerIds.isNotEmpty
            ? await _supabase
                  .from('engineer_profiles')
                  .select('user_id, specialty, skills')
                  .inFilter('user_id', engineerIds)
            : [];

        final profileMap = {
          for (var p in engProfiles) p['user_id'] as int: p
        };

        for (final eng in allEngineers) {
          final engId = eng['id'] as int;
          if (followedEngineerIds.contains(engId) || engId == currentUserId) {
            continue;
          }

          final profile = profileMap[engId];
          if (profile == null) {
            otherEngineers.add(eng);
            continue;
          }

          final engSpecialty =
              (profile['specialty'] ?? '').toString().toLowerCase();
          final engSkills = (profile['skills'] ?? '').toString().toLowerCase();

          final isMatch =
              studentInterests.any((interest) =>
                  engSpecialty.contains(interest) ||
                  engSkills.contains(interest)) ||
              (studentSpecialty.isNotEmpty &&
                  engSpecialty.contains(studentSpecialty.toLowerCase()));

          if (isMatch) {
            matchedEngineers.add(eng);
          } else {
            otherEngineers.add(eng);
          }
        }
      } else {
        otherEngineers = allEngineers
            .where((e) =>
                !followedEngineerIds.contains(e['id'] as int) &&
                e['id'] != currentUserId)
            .toList();
      }

      final allFinal = [...matchedEngineers, ...otherEngineers];
      final allFinalIds = allFinal.map((e) => e['id'] as int).toList();
      final specialtyProfiles = allFinalIds.isNotEmpty
          ? await _supabase
                .from('engineer_profiles')
                .select('user_id, specialty')
                .inFilter('user_id', allFinalIds)
          : [];
      final specialtyMap = {
        for (var p in specialtyProfiles)
          p['user_id'] as int: p['specialty']?.toString() ?? ''
      };
      final engineersData = allFinal
          .map((e) => {
                ...e,
                'specialty': specialtyMap[e['id'] as int] ?? '',
              })
          .toList();

      final allEngineerIds = allEngineers.map((e) => e['id'] as int).toList();
      final allSpecialtyProfiles = allEngineerIds.isNotEmpty
          ? await _supabase
                .from('engineer_profiles')
                .select('user_id, specialty')
                .inFilter('user_id', allEngineerIds)
          : [];
      final allSpecialtyMap = {
        for (var p in allSpecialtyProfiles)
          p['user_id'] as int: p['specialty']?.toString() ?? ''
      };
      final engineerSpecialtyByUsername = <String, String>{};
      for (final eng in allEngineers) {
        final username = eng['username']?.toString() ?? '';
        final userId = eng['id'] as int;
        engineerSpecialtyByUsername[username] = allSpecialtyMap[userId] ?? '';
      }

      List<dynamic> postsData = [];

      if (followedEngineerIds.isNotEmpty) {
        final followedUsernames = allEngineers
            .where((e) => followedEngineerIds.contains(e['id'] as int))
            .map((e) => e['username'].toString())
            .toList();

        final res = await _supabase
            .from('posts')
            .select('*')
            .or(
                'user_id.in.(${followedEngineerIds.join(',')}),username.in.(${followedUsernames.map((u) => '"$u"').join(',')})')
            .order('created_at', ascending: false)
            .limit(_limit);
        postsData = res as List<dynamic>;
      }

      final enrichedPosts = await _enrichPosts(postsData);

      if (!mounted) return;
      setState(() {
        engineers = engineersData;
        posts = enrichedPosts;
        _engineerSpecialtyByUsername = engineerSpecialtyByUsername;
        _hasMore = postsData.length == _limit;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> toggleFollowEngineer(int engineerId) async {
    if (currentUserId == null) return;

    final isFollowing = followedEngineerIds.contains(engineerId);

    if (!isFollowing) {
      setState(() => followedEngineerIds.add(engineerId));

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            engineers.removeWhere((e) => e['id'] == engineerId);
          });
        }
      });

      try {
        await _supabase.from('follows').insert({
          'follower_id': currentUserId!,
          'following_id': engineerId,
        });
      } catch (e) {
        debugPrint('Follow error: $e');
        if (mounted) setState(() => followedEngineerIds.remove(engineerId));
      }
    } else {
      setState(() => followedEngineerIds.remove(engineerId));

      try {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId!)
            .eq('following_id', engineerId);
      } catch (e) {
        debugPrint('Unfollow error: $e');
        if (mounted) setState(() => followedEngineerIds.add(engineerId));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      _page++;
      List<dynamic> newPosts = [];

      if (followedEngineerIds.isNotEmpty) {
        final res = await _supabase
            .from('posts')
            .select('*')
            .inFilter('user_id', followedEngineerIds.toList())
            .order('created_at', ascending: false)
            .range(_page * _limit, (_page + 1) * _limit - 1);
        newPosts = res as List<dynamic>;
      }

      final enrichedNewPosts = await _enrichPosts(newPosts);

      if (!mounted) return;
      setState(() {
        posts.addAll(enrichedNewPosts);
        _hasMore = newPosts.length == _limit;
      });
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _editPost(dynamic post, int index) {
    final controller = TextEditingController(text: post['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Post'),
        content: TextField(controller: controller, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _supabase
                  .from('posts')
                  .update({'content': controller.text})
                  .eq('id', post['id']);
              setState(() => posts[index]['content'] = controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(int postId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('posts').delete().eq('id', postId);
      if (!mounted) return;
      setState(() => posts.removeAt(index));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Post deleted')));
    } catch (e) {
      debugPrint('Delete error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to delete post')));
    }
  }

  Future<void> _sendPostLikeNotification(dynamic post, dynamic postId) async {
    if (currentUserId == null) return;

    int? postOwnerId;
    final rawOwnerId = post['user_id'];
    if (rawOwnerId is int) {
      postOwnerId = rawOwnerId;
    } else if (rawOwnerId != null) {
      postOwnerId = int.tryParse(rawOwnerId.toString());
    }

    if (postOwnerId == null) {
      final ownerUsername = post['username']?.toString() ?? '';
      if (ownerUsername.isNotEmpty && ownerUsername != currentUsername) {
        final owner = await _supabase
            .from('users')
            .select('id')
            .eq('username', ownerUsername)
            .maybeSingle();
        if (owner != null) postOwnerId = owner['id'] as int?;
      }
    }

    if (postOwnerId == null || postOwnerId == currentUserId) return;

    await _supabase.from('notifications').insert({
      'user_id': postOwnerId,
      'message': '${currentUsername ?? 'Someone'} liked your post.',
      'is_read': 0,
      'post_id': postId,
      'type': 'post_like',
    });
  }

  Future<void> likePost(int index) async {
    if (currentUserId == null) return;

    final post = posts[index];
    final postId = post['id'];
    final wasLiked = post['is_liked'] == true;
    final oldLikes = post['likes'] ?? 0;

    setState(() {
      posts[index]['is_liked'] = !wasLiked;
      posts[index]['likes'] =
          wasLiked ? (oldLikes > 0 ? oldLikes - 1 : 0) : oldLikes + 1;
    });

    try {
      if (wasLiked) {
        await _supabase
            .from('likes')
            .delete()
            .eq('user_id', currentUserId!)
            .eq('post_id', postId);
      } else {
        await _supabase.from('likes').insert({
          'user_id': currentUserId!,
          'post_id': postId,
        });
        await _sendPostLikeNotification(post, postId);
      }

      await _supabase
          .from('posts')
          .update({'likes': posts[index]['likes']})
          .eq('id', postId);
    } catch (e) {
      debugPrint('Like post error: $e');
      if (!mounted) return;
      setState(() {
        posts[index]['is_liked'] = wasLiked;
        posts[index]['likes'] = oldLikes;
      });
    }
  }

  Future<void> toggleSavePost(int index) async {
    if (currentUserId == null) return;

    final post = posts[index];
    final postId = post['id'];
    final wasSaved = post['is_saved'] == true;

    setState(() => posts[index]['is_saved'] = !wasSaved);

    try {
      if (wasSaved) {
        await _supabase
            .from('saved_posts')
            .delete()
            .eq('user_id', currentUserId!)
            .eq('post_id', postId);
      } else {
        await _supabase.from('saved_posts').insert({
          'user_id': currentUserId!,
          'post_id': postId,
        });
      }
    } catch (e) {
      debugPrint('Save post error: $e');
      if (!mounted) return;
      setState(() => posts[index]['is_saved'] = wasSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: isLoading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Engineers',
                    style: GoogleFonts.agbalumo(
                        color: const Color(0xFF6C94C6), fontSize: 24)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 165,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    itemBuilder: (_, __) => _buildEngineerSkeleton(),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Posts',
                    style: GoogleFonts.agbalumo(
                        color: const Color(0xFF6C94C6), fontSize: 24)),
                const SizedBox(height: 12),
                ...List.generate(3, (_) => _buildPostSkeleton()),
              ],
            )
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // ── Filtre satırı ──
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _specialties.length,
                      itemBuilder: (context, i) {
                        final spec = _specialties[i];
                        final isSelected =
                            (spec == 'All' && _selectedSpecialty == null) ||
                                spec == _selectedSpecialty;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedSpecialty = spec == 'All' ? null : spec;
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent
                                  : const Color(0xFF1A2F55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : Colors.white24,
                              ),
                            ),
                            child: Text(
                              spec,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.black : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Engineers ──
                  Text('Engineers',
                      style: GoogleFonts.agbalumo(
                          color: const Color(0xFF6C94C6), fontSize: 24)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 165,
                    child: Builder(builder: (context) {
                      final filtered = _selectedSpecialty == null
                          ? engineers
                          : engineers
                              .where((e) => (e['specialty'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(_selectedSpecialty!.toLowerCase()))
                              .toList();
                      return filtered.isEmpty
                          ? const Center(
                              child: Text('No engineers found',
                                  style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: filtered.length,
                              itemBuilder: (context, i) =>
                                  _buildEngineerCard(filtered[i]),
                            );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // ── Posts ──
                  Text('Posts',
                      style: GoogleFonts.agbalumo(
                          color: const Color(0xFF6C94C6), fontSize: 24)),
                  const SizedBox(height: 12),

                  Builder(builder: (context) {
                    final filteredPosts = _selectedSpecialty == null
                        ? posts
                        : posts.where((p) {
                            final username = p['username']?.toString() ?? '';
                            final spec =
                                (_engineerSpecialtyByUsername[username] ?? '')
                                    .toLowerCase()
                                    .trim();
                            final selected =
                                _selectedSpecialty!.toLowerCase().trim();
                            return spec.isNotEmpty &&
                                (spec.contains(selected
                                        .split(' ')
                                        .first
                                        .toLowerCase()) ||
                                    selected.contains(
                                        spec.split(' ').first.toLowerCase()));
                          }).toList();

                    if (filteredPosts.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 48, horizontal: 24),
                          child: Column(
                            children: [
                              const Icon(Icons.people_outline,
                                  size: 64, color: Colors.white24),
                              const SizedBox(height: 16),
                              Text(
                                followedEngineerIds.isEmpty
                                    ? 'Gönderi görmek için mühendisleri takip et'
                                    : 'Henüz gönderi yok',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: List.generate(filteredPosts.length,
                          (i) => _buildPostCard(i, filteredPosts[i])),
                    );
                  }),

                  if (_loadingMore)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                            color: Color(0xFF6C94C6)),
                      ),
                    ),
                  if (!_hasMore && posts.isNotEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No more posts',
                            style: TextStyle(color: Colors.white38)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildEngineerSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A2F55),
      highlightColor: const Color(0xFF2A4A7F),
      child: Container(
        width: 110,
        height: 140,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2F55),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildPostSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A2F55),
      highlightColor: const Color(0xFF2A4A7F),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2F55),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8))),
            ]),
            const SizedBox(height: 12),
            Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 8),
            Container(
                width: 200,
                height: 12,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8))),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineerCard(dynamic eng) {
    final name = eng['username']?.toString() ?? '';
    final image = eng['profile_image']?.toString() ?? '';
    final userId = eng['id'] as int?;
    final isFollowing =
        userId != null && followedEngineerIds.contains(userId);

    return GestureDetector(
      onTap: () {
        if (userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EngineerProfileScreen(targetUserId: userId),
            ),
          );
        }
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 14),
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFD8C09A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white24),
                    child: ClipOval(
                      child: image.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: image,
                              width: 85,
                              height: 85,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white54),
                              placeholder: (c, u) => Shimmer.fromColors(
                                baseColor: const Color(0xFF1A2F55),
                                highlightColor: const Color(0xFF2A4A7F),
                                child: Container(color: Colors.white),
                              ),
                            )
                          : const Icon(Icons.person,
                              size: 40, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      name,
                      style: GoogleFonts.agbalumo(
                          color: Colors.black87, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 55,
              right: 15,
              child: GestureDetector(
                onTap: () {
                  if (userId != null) toggleFollowEngineer(userId);
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isFollowing
                        ? const Color(0xFF4CAF50)
                        : const Color.fromARGB(255, 88, 16, 15),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFD8C09A), width: 2),
                  ),
                  child: Icon(isFollowing ? Icons.check : Icons.add,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedItemCard(dynamic post) {
    final linkedCourse = post['linked_course'] ?? post['courses'];
    final linkedCourseId = post['linked_course_id'];
    final linkedBookId = post['linked_book_id'];
    final linkedArticleId = post['linked_article_id'];
    final linkedBook = post['linked_book'];
    final linkedArticle = post['linked_article'];

    dynamic item;
    String type = '';
    String itemId = '';

    if (linkedCourse != null) {
      item = linkedCourse;
      type = 'course';
      itemId = (linkedCourseId ?? linkedCourse['id'])?.toString() ?? '';
    } else if (linkedCourseId != null) {
      type = 'course';
      itemId = linkedCourseId.toString();
    } else if (linkedBook != null) {
      item = linkedBook;
      type = 'book';
      itemId = (linkedBookId ?? linkedBook['id'])?.toString() ?? '';
    } else if (linkedBookId != null) {
      type = 'book';
      itemId = linkedBookId.toString();
    } else if (linkedArticle != null) {
      item = linkedArticle;
      type = 'article';
      itemId = (linkedArticleId ?? linkedArticle['id'])?.toString() ?? '';
    } else if (linkedArticleId != null) {
      type = 'article';
      itemId = linkedArticleId.toString();
    } else {
      return const SizedBox.shrink();
    }

    IconData fallbackIcon;
    Color iconColor;
    String typeLabel;
    String table;
    switch (type) {
      case 'book':
        fallbackIcon = Icons.menu_book;
        iconColor = Colors.brown;
        typeLabel = 'Book';
        table = 'books';
        break;
      case 'article':
        fallbackIcon = Icons.article;
        iconColor = const Color(0xFF5B7FA6);
        typeLabel = 'Article';
        table = 'articles';
        break;
      default:
        fallbackIcon = Icons.play_circle;
        iconColor = Colors.grey;
        typeLabel = 'Course';
        table = 'courses';
    }

    // item varsa direkt kullan, yoksa Supabase'den çek
    final Future<Map<String, dynamic>?> itemFuture = item != null
        ? Future.value(Map<String, dynamic>.from(item as Map))
        : (itemId.isNotEmpty
            ? _supabase
                .from(table)
                .select('id, title, image_url')
                .eq('id', int.parse(itemId))
                .maybeSingle()
                .then((v) =>
                    v != null ? Map<String, dynamic>.from(v) : null)
            : Future.value(null));

    return FutureBuilder<Map<String, dynamic>?>(
      future: itemFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final title = data?['title']?.toString() ?? '';
        final imageUrl = data?['image_url']?.toString() ?? '';
        final isWaiting =
            snapshot.connectionState == ConnectionState.waiting;

        return GestureDetector(
          onTap: () {
            if (itemId.isEmpty) return;
            if (type == 'course') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CourseDetailScreen(courseId: itemId)));
            } else if (type == 'book') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          BookDetailScreen(bookId: itemId)));
            } else if (type == 'article') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ArticleDetailScreen(articleId: itemId)));
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5ECD7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Image / icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isWaiting
                      ? Shimmer.fromColors(
                          baseColor: const Color(0xFF1A2F55),
                          highlightColor: const Color(0xFF2A4A7F),
                          child: Container(
                              width: 52,
                              height: 52,
                              color: Colors.white),
                        )
                      : imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => Container(
                                width: 52,
                                height: 52,
                                color: Colors.black38,
                                child: Icon(fallbackIcon,
                                    size: 32, color: iconColor),
                              ),
                              placeholder: (c, u) => Shimmer.fromColors(
                                baseColor: const Color(0xFF1A2F55),
                                highlightColor: const Color(0xFF2A4A7F),
                                child: Container(
                                    width: 52,
                                    height: 52,
                                    color: Colors.white),
                              ),
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              color: Colors.black38,
                              child: Icon(fallbackIcon,
                                  size: 32, color: iconColor),
                            ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                              fontSize: 10,
                              color: iconColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      isWaiting
                          ? Shimmer.fromColors(
                              baseColor: const Color(0xFF1A2F55),
                              highlightColor: const Color(0xFF2A4A7F),
                              child: Container(
                                  width: 120,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  )),
                            )
                          : Text(
                              title.isNotEmpty ? title : typeLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Colors.black38, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostCard(int index, dynamic post) {
    final content = post['content']?.toString() ?? '';
    final username = post['username']?.toString() ?? '';
    final profileImage = post['profile_image']?.toString() ?? '';
    final likes = post['likes'] ?? 0;
    final comments = post['comments_count'] ?? post['comments'] ?? 0;
    final postImageUrl = post['image_url']?.toString() ?? '';

    final hasLinkedItem = post['linked_course'] != null ||
        post['linked_course_id'] != null ||
        post['linked_book'] != null ||
        post['linked_book_id'] != null ||
        post['linked_article'] != null ||
        post['linked_article_id'] != null ||
        post['courses'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFD8C09A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildProfileAvatar(profileImage, size: 42),
              const SizedBox(width: 10),
              Text(username,
                  style: GoogleFonts.agbalumo(
                      fontSize: 14, color: Colors.black87)),
              const Spacer(),
              if (username == currentUsername)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') _deletePost(post['id'], index);
                    if (value == 'edit') _editPost(post, index);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.45)),
          if (postImageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 220,
              color: const Color(0xFFF5ECD7),
              child: CachedNetworkImage(
                  imageUrl: postImageUrl, fit: BoxFit.contain),
            ),
          ],
          if (hasLinkedItem) ...[
            const SizedBox(height: 10),
            _buildLinkedItemCard(post),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => likePost(index),
                child: Row(
                  children: [
                    Icon(
                      post['is_liked'] == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 20,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 5),
                    Text('$likes',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostCommentsScreen(post: post),
                    ),
                  ).then((_) => loadData());
                },
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble,
                        size: 18, color: Color(0xFF5B7FA6)),
                    const SizedBox(width: 5),
                    Text('$comments',
                        style: const TextStyle(
                            color: Color(0xFF5B7FA6), fontSize: 13)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => toggleSavePost(index),
                child: Icon(
                  post['is_saved'] == true
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(String imageUrl, {double size = 42}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) =>
                    const Icon(Icons.person, color: Colors.white54, size: 22),
                placeholder: (c, u) => Shimmer.fromColors(
                  baseColor: const Color(0xFF1A2F55),
                  highlightColor: const Color(0xFF2A4A7F),
                  child:
                      Container(width: size, height: size, color: Colors.white),
                ),
              )
            : Container(
                color: const Color(0xFF4A6FA5),
                child:
                    const Icon(Icons.person, color: Colors.white, size: 22),
              ),
      ),
    );
  }
}