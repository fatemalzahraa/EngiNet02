import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'article_detail.dart';

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  final supabase = Supabase.instance.client;

  List<dynamic> allArticles = [];
  List<dynamic> filteredArticles = [];
  bool isLoading = true;
  bool showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadArticles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadArticles() async {
    try {
      final data = await supabase
          .from('articles')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        allArticles = data;
        filteredArticles = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint("Error loading articles: $e");
    }
  }

  void filterArticles(String value) {
    setState(() {
      filteredArticles = allArticles.where((a) {
        return (a['title'] ?? '')
            .toString()
            .toLowerCase()
            .contains(value.toLowerCase());
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    icon: const Icon(Icons.search,
                        color: Colors.white, size: 28),
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
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white54),
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
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C94C6)))
                  : filteredArticles.isEmpty
                      ? const Center(
                          child: Text("No articles found",
                              style: TextStyle(color: Colors.white)))
                      : RefreshIndicator(
                          onRefresh: loadArticles,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            itemCount: filteredArticles.length,
                            itemBuilder: (context, index) {
                              final item = filteredArticles[index];
                              return _buildArticleCard(item);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(dynamic item) {
    final title = item['title']?.toString() ?? '';
    final imageUrl = item['image_url']?.toString() ?? '';
    final authorName = item['author_name']?.toString() ?? '';
    final authorImage = item['author_image']?.toString() ?? '';
    final rating =
        double.tryParse(item['rating']?.toString() ?? '0') ?? 0.0;

    // ✅ يدعم UUID (String) وأيضاً int
    final articleId = item['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (articleId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ArticleDetailScreen(articleId: articleId),
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
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
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
                                ? const Icon(Icons.person,
                                    color: Colors.white)
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
                          const Icon(Icons.star,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
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