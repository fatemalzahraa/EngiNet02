import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> engineers = [];
  List<dynamic> posts = [];
  bool isLoading = true;
  final String baseUrl = "https://enginet02-1.onrender.com";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> loadData() async {
    final token = await getToken();
    try {
      final usersRes = await http.get(
        Uri.parse("$baseUrl/users/engineers"),
        headers: token != null ? {"Authorization": "Bearer $token"} : {},
      );
      final postsRes = await http.get(
        Uri.parse("$baseUrl/posts/"),
        headers: token != null ? {"Authorization": "Bearer $token"} : {},
      );

      if (!mounted) return;
      setState(() {
        if (usersRes.statusCode == 200) engineers = json.decode(usersRes.body);
        if (postsRes.statusCode == 200) posts = json.decode(postsRes.body);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C94C6)))
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Engineers Section
                  Text(
                    "Engineer",
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFF6C94C6),
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Engineers Row
                  SizedBox(
                    height: 150,
                    child: engineers.isEmpty
                        ? const Center(
                            child: Text("No engineers",
                                style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: engineers.length,
                            itemBuilder: (context, index) {
                              final eng = engineers[index];
                              return _buildEngineerCard(eng);
                            },
                          ),
                  ),

                  const SizedBox(height: 20),

                  // Posts Section
                  Text(
                    "posts",
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFF6C94C6),
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Posts List
                  ...posts.map((post) => _buildPostCard(post)).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildEngineerCard(dynamic eng) {
    final name = eng['username'] ?? '';
    final image = eng['profile_image'] ?? '';

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
                  border: Border.all(color: const Color(0xFFE3C39D), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: image.isNotEmpty
                      ? Image.network(image,
                          width: 100, height: 100, fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                              Icons.person, size: 50, color: Colors.grey))
                      : const Icon(Icons.person, size: 50, color: Colors.grey),
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
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.agbalumo(color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(dynamic post) {
    final content = post['content'] ?? '';
    final username = post['username'] ?? '';
    final profileImage = post['profile_image'] ?? '';
    final likes = post['likes'] ?? 0;
    final linkedCourse = post['linked_course'];

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
          // المستخدم
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
                style: GoogleFonts.agbalumo(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // المحتوى
          Text(
            content,
            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
          ),

          // الكورس المرتبط
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
                            linkedCourse['image_url'].isNotEmpty
                        ? Image.network(
                            linkedCourse['image_url'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                                Icons.play_circle, size: 40, color: Colors.grey),
                          )
                        : const Icon(Icons.play_circle, size: 40, color: Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      linkedCourse['title'] ?? '',
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

          // الإعجابات والتعليقات
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await http.post(
                      Uri.parse("$baseUrl/posts/${post['id']}/like"));
                  loadData();
                },
                child: Row(
                  children: [
                    const Icon(Icons.favorite_border,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text("$likes",
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline,
                  size: 18, color: Color(0xFF5B7FA6)),
              const SizedBox(width: 4),
              const Text("10", style: TextStyle(color: Colors.black54)),
              const Spacer(),
              const Icon(Icons.bookmark_border, size: 20, color: Colors.black54),
            ],
          ),
        ],
      ),
    );
  }
}