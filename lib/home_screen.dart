import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:enginet/engineer_profile.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  void _editPost(dynamic post, int index) {
  final controller = TextEditingController(text: post['content']);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Post'),
      content: TextField(
        controller: controller,
        maxLines: 4,
      ),
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

            setState(() {
              posts[index]['content'] = controller.text;
            });

            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> _deletePost(int postId, int index) async {
  try {
    await _supabase.from('posts').delete().eq('id', postId);

    setState(() {
      posts.removeAt(index);
    });
  } catch (e) {
    debugPrint('Delete error: $e');
  }
}
  Future<void> loadData() async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL']!;
      final supabaseKey = dotenv.env['SUPABASE_ANON_KEY']!;
      currentUsername = await SessionManager.getUsername();
      _page = 0;

      final results = await Future.wait([
        http.get(Uri.parse('${AppConstants.baseUrl}/users/engineers')),
        http.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/posts'
            '?select=*'
            '&order=created_at.desc'
            '&limit=$_limit'
            '&offset=0',
          ),
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
          },
        ),
      ]);

      final engineersData = results[0].statusCode == 200
          ? jsonDecode(results[0].body) as List<dynamic>
          : <dynamic>[];

      final postsData = results[1].statusCode == 200
          ? jsonDecode(results[1].body) as List<dynamic>
          : <dynamic>[];

      if (!mounted) return;
      setState(() {
        engineers = engineersData;
        posts = postsData;
        _hasMore = postsData.length == _limit;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL']!;
      final supabaseKey = dotenv.env['SUPABASE_ANON_KEY']!;
      _page++;

      final res = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/posts'
          '?select=*'
          '&order=created_at.desc'
          '&limit=$_limit'
          '&offset=${_page * _limit}',
        ),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
        },
      );

      if (res.statusCode == 200) {
        final newPosts = jsonDecode(res.body) as List<dynamic>;
        if (!mounted) return;
        setState(() {
          posts.addAll(newPosts);
          _hasMore = newPosts.length == _limit;
        });
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> likePost(int index) async {
    final post = posts[index];
    final postId = post['id'];

    setState(() => posts[index] = {...post, 'likes': (post['likes'] ?? 0) + 1});

    try {
      final token = await SessionManager.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => posts[index] = post);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to like posts')),
        );
        return;
      }

      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/posts/$postId/like'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200 && mounted) {
        setState(() => posts[index] = post);
      }
    } catch (e) {
      if (mounted) setState(() => posts[index] = post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: isLoading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Engineer',
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
                Text('posts',
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
                children: [
                  Text('Engineer',
                      style: GoogleFonts.agbalumo(
                          color: const Color(0xFF6C94C6), fontSize: 24)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 165,
                    child: engineers.isEmpty
                        ? const Center(
                            child: Text('No engineers',
                                style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: engineers.length,
                            itemBuilder: (context, i) =>
                                _buildEngineerCard(engineers[i]),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text('posts',
                      style: GoogleFonts.agbalumo(
                          color: const Color(0xFF6C94C6), fontSize: 24)),
                  const SizedBox(height: 12),
                  if (posts.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No posts yet',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  else
                    ...List.generate(
                        posts.length, (i) => _buildPostCard(i, posts[i])),
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
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8))),
              ],
            ),
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

    return GestureDetector(
      onTap: () {
        if (userId != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EngineerProfileScreen(targetUserId: userId),
              ));
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
                border: Border.all(color: const Color(0xFFE3C39D), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
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
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 88, 16, 15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD8C09A), width: 2),
                ),
                child: const Icon(Icons.add, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(int index, dynamic post) {
    final content = post['content']?.toString() ?? '';
    final username = post['username']?.toString() ?? '';
    final profileImage = post['profile_image']?.toString() ?? '';
    final likes = post['likes'] ?? 0;
    final comments = post['comments_count'] ?? post['comments'] ?? 0;
    final postImageUrl = post['image_url']?.toString() ?? '';
    final linkedCourse = post['linked_course'] ?? post['courses'];

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
          if (value == 'delete') {
            _deletePost(post['id'], index);
          } else if (value == 'edit') {
            _editPost(post, index);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: postImageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => const SizedBox.shrink(),
                placeholder: (c, u) => Shimmer.fromColors(
                  baseColor: const Color(0xFF1A2F55),
                  highlightColor: const Color(0xFF2A4A7F),
                  child: Container(height: 200, color: Colors.white),
                ),
              ),
            ),
          ],
          if (linkedCourse != null) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFF5ECD7),
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: linkedCourse['image_url'] != null &&
                            linkedCourse['image_url'].toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: linkedCourse['image_url'].toString(),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => const Icon(
                                Icons.play_circle,
                                size: 40,
                                color: Colors.grey),
                            placeholder: (c, u) => Shimmer.fromColors(
                              baseColor: const Color(0xFF1A2F55),
                              highlightColor: const Color(0xFF2A4A7F),
                              child: Container(
                                  width: 52, height: 52, color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.play_circle,
                            size: 40, color: Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      linkedCourse['title']?.toString() ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => likePost(index),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_border,
                        size: 20, color: Colors.black54),
                    const SizedBox(width: 5),
                    Text('$likes',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 18, color: Color(0xFF5B7FA6)),
                  const SizedBox(width: 5),
                  Text('$comments',
                      style: const TextStyle(
                          color: Color(0xFF5B7FA6), fontSize: 13)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.bookmark_border,
                  size: 22, color: Colors.black54),
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
        border: Border.all(color: const Color(0xFFE3C39D), width: 1.5),
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
                  child: Container(width: size, height: size, color: Colors.white),
                ),
              )
            : Container(
                color: const Color(0xFF4A6FA5),
                child: const Icon(Icons.person, color: Colors.white, size: 22),
              ),
      ),
    );
  }
}