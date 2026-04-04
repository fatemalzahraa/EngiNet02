import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArticleDetailScreen extends StatefulWidget {
  final String articleId; // ✅ UUID بدل int
  const ArticleDetailScreen({super.key, required this.articleId});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? article;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadArticle();
  }

  Future<void> loadArticle() async {
    try {
      // ✅ جلب المقال من Supabase
      final res = await supabase
          .from('articles')
          .select()
          .eq('id', widget.articleId)
          .single();

      if (!mounted) return;
      setState(() {
        article = res;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
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

    if (article == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF071739),
        appBar: AppBar(backgroundColor: const Color(0xFF071739)),
        body: const Center(
          child: Text("Article not found",
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final title = article!['title']?.toString() ?? '';
    final content = article!['content']?.toString() ?? '';
    final imageUrl = article!['image_url']?.toString() ?? '';
    final authorName = article!['author_name']?.toString() ?? '';
    final authorImage = article!['author_image']?.toString() ?? '';
    final rating =
        double.tryParse(article!['rating']?.toString() ?? '0') ?? 0.0;
    final commentsCount = article!['comments_count'] ?? 0; // ✅ من Supabase

    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            // زر Back
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3C39D),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),

            // CARD
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7D93B0),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الكاتب
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: authorImage.isNotEmpty
                                      ? NetworkImage(authorImage)
                                      : null,
                                  backgroundColor: const Color(0xFF6C94C6),
                                  child: authorImage.isEmpty
                                      ? const Icon(Icons.person,
                                          color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  authorName,
                                  style: GoogleFonts.agbalumo(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // صورة المقال
                          if (imageUrl.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  imageUrl,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    height: 200,
                                    color: const Color(0xFFDDE3EA),
                                    child: const Icon(Icons.article,
                                        size: 60, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),

                          // العنوان والتقييم
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ...List.generate(
                                      5,
                                      (i) => Icon(
                                        i < rating.floor()
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.orange,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.chat_bubble,
                                        color: Color(0xFF5B7FA6), size: 18),
                                    const SizedBox(width: 4),
                                    // ✅ عدد التعليقات من Supabase
                                    Text("$commentsCount",
                                        style: const TextStyle(
                                            color: Colors.black87)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // المحتوى
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              content,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.6,
                              ),
                            ),
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
}