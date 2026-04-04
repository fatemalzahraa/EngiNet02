import 'dart:convert';

import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class EngineerProfileScreen extends StatefulWidget {
  const EngineerProfileScreen({super.key});

  @override
  State<EngineerProfileScreen> createState() => _EngineerProfileScreenState();
}

class _EngineerProfileScreenState extends State<EngineerProfileScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? user;
  List<dynamic> posts = [];
  List<dynamic> books = [];
  List<dynamic> articles = [];
  bool isLoading = true;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final token = await SessionManager.getToken();
      final username = await SessionManager.getUsername();
      if (token == null || token.isEmpty || username == null || username.isEmpty) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final profileResponse = await http.get(
        Uri.parse('${AppConstants.baseUrl}/profile/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (profileResponse.statusCode != 200) {
        throw Exception('Failed to load profile');
      }

      final userRes = jsonDecode(profileResponse.body) as Map<String, dynamic>;

      // ✅ جلب الكتب
      final booksRes = await supabase
          .from('books')
          .select()
          .order('created_at', ascending: false);

      // ✅ جلب المقالات
      final articlesRes = await supabase
          .from('articles')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        user = userRes;
        books = booksRes;
        articles = articlesRes;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void showEditDialog() {
    final bioController = TextEditingController(text: user?['bio'] ?? '');
    final imageController =
        TextEditingController(text: user?['profile_image'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF071739),
        title: Text("Edit Profile",
            style: GoogleFonts.agbalumo(color: const Color(0xFFE3C39D))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(bioController, "Bio", maxLines: 3),
            const SizedBox(height: 12),
            _dialogField(imageController, "Profile Image URL"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final token = await SessionManager.getToken();
              final username = await SessionManager.getUsername();
              if (token == null || token.isEmpty || username == null || username.isEmpty) {
                return;
              }

              await http.put(
                Uri.parse('${AppConstants.baseUrl}/profile/me'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'bio': bioController.text,
                  'profile_image': imageController.text,
                }),
              );

              if (!mounted) return;
              Navigator.pop(context);
              loadProfile();
            },
            child: Text("Save",
                style: GoogleFonts.agbalumo(color: const Color(0xFFE3C39D))),
          ),
        ],
      ),
    );
  }

  // ===== باقي الكود بدون تغيير =====

  Widget _dialogField(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE3C39D),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF071739),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6C94C6))),
      );
    }

    final username = user?['username'] ?? '';
    final bio = user?['bio'] ?? '';
    final profileImage = user?['profile_image'] ?? '';
    final points = user?['points'] ?? 0;
    final university = user?['university'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3C39D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.black, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    username,
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFFE3C39D),
                      fontSize: 22,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: showEditDialog,
                    child:
                        const Icon(Icons.edit, color: Color(0xFFE3C39D)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: profileImage.isNotEmpty
                        ? NetworkImage(profileImage)
                        : null,
                    backgroundColor: const Color(0xFF4A6FA5),
                    child: profileImage.isEmpty
                        ? const Icon(Icons.person,
                            size: 50, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Follower",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const Text("125",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Points",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Text("$points",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "$username\n$university\n$bio",
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            Row(
              children: [
                _tab("Posts", 0),
                _tab("Books", 1),
                _tab("Articles", 2),
              ],
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: selectedTab == 0
                  ? _buildPostsList()
                  : selectedTab == 1
                      ? _buildBooksList()
                      : _buildArticlesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFFE3C39D)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.agbalumo(
                  color: isSelected
                      ? const Color(0xFFE3C39D)
                      : Colors.white54,
                  fontSize: 16,
                )),
          ),
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    if (posts.isEmpty) {
      return const Center(
          child: Text("No posts", style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final profileImage = user?['profile_image'] ?? '';
        final username = user?['username'] ?? '';
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: profileImage.isNotEmpty
                        ? NetworkImage(profileImage)
                        : null,
                    backgroundColor: const Color(0xFF4A6FA5),
                  ),
                  const SizedBox(width: 8),
                  Text(username,
                      style: GoogleFonts.agbalumo(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post['content'] ?? '',
                style:
                    const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.favorite_border, size: 18),
                  const SizedBox(width: 4),
                  Text('${post['likes_count'] ?? 0}'),
                  const SizedBox(width: 12),
                  const Icon(Icons.chat_bubble_outline,
                      size: 18, color: Color(0xFF5B7FA6)),
                  const SizedBox(width: 4),
                  Text('${post['comments_count'] ?? 0}'),
                  const Spacer(),
                  const Icon(Icons.bookmark_border, size: 20),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBooksList() {
    if (books.isEmpty) {
      return const Center(
          child: Text("No books", style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD8C09A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: book['image_url'] != null &&
                    book['image_url'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(book['image_url'],
                        width: 50,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.book, size: 40)),
                  )
                : const Icon(Icons.book, size: 40),
            title: Text(book['title'] ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(book['author'] ?? '',
                style: const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }

  Widget _buildArticlesList() {
    if (articles.isEmpty) {
      return const Center(
          child:
              Text("No articles", style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD8C09A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: article['image_url'] != null &&
                    article['image_url'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(article['image_url'],
                        width: 50,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.article, size: 40)),
                  )
                : const Icon(Icons.article, size: 40),
            title: Text(article['title'] ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(article['author_name'] ?? '',
                style: const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}
