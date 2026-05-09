import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enginet/post_comments_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SavedPostsScreen extends StatelessWidget {
  final List posts;

  const SavedPostsScreen({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE3C39D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Posts',
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 24,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final imageUrl = post['image_url']?.toString() ?? '';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostCommentsScreen(post: post),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD8C09A),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['username'] ?? '',
                    style: GoogleFonts.agbalumo(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post['content'] ?? '',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  if (imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        height: 220,
                        color: const Color(0xFFF5ECD7),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}