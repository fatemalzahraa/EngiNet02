import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'article_detail.dart';

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  List<dynamic> allArticles = [];
  List<dynamic> filteredArticles = [];
  bool isLoading = true;
  bool showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  final String baseUrl = "https://enginet02-1.onrender.com";

  @override
  void initState() {
    super.initState();
    loadArticles();
  }

  Future<void> loadArticles() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/articles/"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          allArticles = data;
          filteredArticles = data;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error: $e");
    }
  }

  void filterArticles(String value) {
    setState(() {
      filteredArticles = allArticles.where((a) {
        return a['title'].toString().toLowerCase().contains(value.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Articles",
                    style: GoogleFonts.agbalumo(
                      fontSize: 36,
                      color: const Color(0xFF6C94C6),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        showSearch = !showSearch;
                        if (!showSearch) {
                          _searchController.clear();
                          filteredArticles = allArticles;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            if (showSearch)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: filterArticles,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search articles...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1E3A5F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6C94C6)))
                  : filteredArticles.isEmpty
                      ? const Center(
                          child: Text("No articles found",
                              style: TextStyle(color: Colors.white)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredArticles.length,
                          itemBuilder: (context, index) {
                            final item = filteredArticles[index];
                            return _buildArticleCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(dynamic item) {
    final title = item['title'] ?? '';
    final imageUrl = item['image_url'] ?? '';
    final authorName = item['author_name'] ?? '';
    final authorImage = item['author_image'] ?? '';
    final rating = (item['rating'] ?? 0.0).toDouble();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(
              articleId: (item['id'] as num).toInt(),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: const Color(0xFF2A4A6F),
                        child: const Icon(Icons.article,
                            size: 60, color: Colors.white54),
                      ),
                    )
                  : Container(
                      height: 200,
                      color: const Color(0xFF2A4A6F),
                      child: const Icon(Icons.article,
                          size: 60, color: Colors.white54),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: authorImage.isNotEmpty
                                ? NetworkImage(authorImage)
                                : null,
                            backgroundColor: const Color(0xFF2A4A6F),
                            child: authorImage.isEmpty
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            authorName,
                            style: GoogleFonts.agbalumo(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.download,
                              color: Color(0xFF6C94C6), size: 24),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}