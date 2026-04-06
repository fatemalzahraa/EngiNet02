import 'dart:convert';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// ─── Supabase config ───────────────────────────────────────────────
// ضع هذه القيم في ملف AppConstants أو هنا مباشرة
const String _supabaseUrl = 'https://ksfrsnbfdzgtkxhswobs.supabase.co';
const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzZnJzbmJmZHpndGt4aHN3b2JzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5Nzk3ODgsImV4cCI6MjA5MDU1NTc4OH0.igEzAcb8dF1G25IpzCrMNg8q_K6hdoj9mHPZMVeA7Bs';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> engineers = [];
  List<dynamic> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ─── Load engineers from your backend + posts from Supabase ───────
  Future<void> loadData() async {
    try {
      final results = await Future.wait([
        // Engineers من backend الحالي
        http.get(Uri.parse('${AppConstants.baseUrl}/users/engineers')),
        // Posts من Supabase مباشرة مع join على جدول profiles
        http.get(
          Uri.parse(
            '$_supabaseUrl/rest/v1/posts'
            '?select=*,profiles(username,profile_image)'
            '&order=created_at.desc',
          ),
          headers: {
            'apikey': _supabaseAnonKey,
            'Authorization': 'Bearer $_supabaseAnonKey',
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
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ─── Like post (authenticated) ────────────────────────────────────
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

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C94C6)))
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Engineers ──────────────────────────────────────
                  Text('Engineer',
                      style: GoogleFonts.agbalumo(
                          color: const Color(0xFF6C94C6), fontSize: 24)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
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

                  // ── Posts ──────────────────────────────────────────
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
                ],
              ),
            ),
    );
  }

  // ─── Engineer Card (تصميم الصورة الجديد) ─────────────────────────
  Widget _buildEngineerCard(dynamic eng) {
    final name = eng['username']?.toString() ?? '';
    final image = eng['profile_image']?.toString() ?? '';

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // ── الصورة بتصميم مستطيل ───────────────────────────
              Container(
                width: 110,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8C09A),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: const Color(0xFFE3C39D).withOpacity(0.6),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: image.isNotEmpty
                      ? Image.network(
                          image,
                          width: 110,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(Icons.person,
                              size: 50, color: Colors.white54),
                        )
                      : const Icon(Icons.person,
                          size: 50, color: Colors.white54),
                ),
              ),

              // ── زر + أحمر في الزاوية ───────────────────────────
              Positioned(
                bottom: 6,
                right: 4,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF071739), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.agbalumo(
                color: Colors.white, fontSize: 13, height: 1.2),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Post Card ────────────────────────────────────────────────────
  Widget _buildPostCard(int index, dynamic post) {
    // Supabase join: profiles nested object
    final profile = post['profiles'];

    final content = post['content']?.toString() ?? '';
    final username = post['username']?.toString() ??
        profile?['username']?.toString() ??
        '';
    final profileImage = post['profile_image']?.toString() ??
        profile?['profile_image']?.toString() ??
        '';
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
          // ── Header: avatar + username ──────────────────────────
          Row(
            children: [
              _buildProfileAvatar(profileImage, size: 42),
              const SizedBox(width: 10),
              Text(username,
                  style: GoogleFonts.agbalumo(
                      fontSize: 14, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),

          // ── Content ────────────────────────────────────────────
          Text(content,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.45)),

          // ── Post Image ─────────────────────────────────────────
          if (postImageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                postImageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              ),
            ),
          ],

          // ── Linked Course ──────────────────────────────────────
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
                        ? Image.network(
                            linkedCourse['image_url'].toString(),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                                Icons.play_circle,
                                size: 40,
                                color: Colors.grey),
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

          // ── Actions: like, comment, bookmark ──────────────────
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

  // ─── Profile Avatar (مع fallback لعدم وجود صورة) ─────────────────
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
            ? Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.person,
                    color: Colors.white54, size: 22),
              )
            : Container(
                color: const Color(0xFF4A6FA5),
                child: const Icon(Icons.person,
                    color: Colors.white, size: 22),
              ),
      ),
    );
  }
}