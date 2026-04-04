import 'dart:convert';

import 'package:enginet/core/constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

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

  Future<void> loadData() async {
    try {
      final engineersResponse =
          await http.get(Uri.parse('${AppConstants.baseUrl}/users/engineers'));
      final postsResponse =
          await http.get(Uri.parse('${AppConstants.baseUrl}/posts/'));

      final engineersRes = engineersResponse.statusCode == 200
          ? jsonDecode(engineersResponse.body) as List<dynamic>
          : <dynamic>[];
      final postsRes = postsResponse.statusCode == 200
          ? jsonDecode(postsResponse.body) as List<dynamic>
          : <dynamic>[];

      if (!mounted) return;
      setState(() {
        engineers = engineersRes;
        posts = postsRes;
        isLoading = false;
      });

      if (engineersResponse.statusCode != 200) {
        debugPrint('Engineers endpoint failed: ${engineersResponse.statusCode}');
      }
      if (postsResponse.statusCode != 200) {
        debugPrint('Posts endpoint failed: ${postsResponse.statusCode}');
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> likePost(dynamic post) async {
    // Keeping UI read-only until the backend auth flow is fully unified.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF6C94C6)))
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ---- Engineers ----
                  Text(
                    "Engineers",
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFF6C94C6),
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: engineers.isEmpty
                        ? const Center(
                            child: Text("No engineers",
                                style:
                                    TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: engineers.length,
                            itemBuilder: (context, index) {
                              return _buildEngineerCard(
                                  engineers[index]);
                            },
                          ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Posts ----
                  Text(
                    "Posts",
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFF6C94C6),
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (posts.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text("No posts yet",
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  else
                    ...posts
                        .map((post) => _buildPostCard(post))
                        .toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildEngineerCard(dynamic eng) {
    final name = eng['username']?.toString() ?? '';
    final image = eng['profile_image']?.toString() ?? '';

    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8C09A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFE3C39D), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: image.isNotEmpty
                      ? Image.network(image,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey))
                      : const Icon(Icons.person,
                          size: 50, color: Colors.grey),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.agbalumo(
                color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(dynamic post) {
    final profile = post['profiles'];
    final linkedCourse = post['linked_course'] ?? post['courses'];

    final content = post['content']?.toString() ?? '';
    final username = post['username']?.toString() ??
        profile?['username']?.toString() ??
        '';
    final profileImage = post['profile_image']?.toString() ??
        profile?['profile_image']?.toString() ??
        '';
    final likes = post['likes'] ?? 0;
    final postImageUrl = post['image_url']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD8C09A),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header ----
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: profileImage.isNotEmpty
                    ? NetworkImage(profileImage)
                    : null,
                backgroundColor: const Color(0xFF4A6FA5),
                child: profileImage.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                username,
                style: GoogleFonts.agbalumo(
                    fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ---- Content ----
          Text(
            content,
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.4),
          ),

          // ---- Post Image ----
          if (postImageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                postImageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              ),
            ),
          ],

          // ---- Linked Course ----
          if (linkedCourse != null) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5ECD7),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: linkedCourse['image_url'] != null &&
                            linkedCourse['image_url']
                                .toString()
                                .isNotEmpty
                        ? Image.network(
                            linkedCourse['image_url'].toString(),
                            width: 50,
                            height: 50,
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

          const SizedBox(height: 10),

          // ---- Actions ----
          Row(
            children: [
              GestureDetector(
                onTap: () => likePost(post),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_border,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text("$likes",
                        style:
                            const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline,
                  size: 18, color: Color(0xFF5B7FA6)),
              const Spacer(),
              const Icon(Icons.bookmark_border,
                  size: 20, color: Colors.black54),
            ],
          ),
        ],
      ),
    );
  }
}
