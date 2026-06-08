import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'article_detail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:enginet/core/app_colors.dart';

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  final supabase = Supabase.instance.client;
  String? currentUsername;

  List<dynamic> allArticles = [];
  List<dynamic> filteredArticles = [];
  List<dynamic> recommendedArticles = [];
  bool isLoading = true;
  bool isLoadingRecommended = true;
  bool showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    loadArticles();
    loadRecommendedArticles();
  }

  Future<void> _loadCurrentUser() async {
    currentUsername = await SessionManager.getUsername();
    if (mounted) setState(() {});
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

  Future<void> loadRecommendedArticles() async {
    try {
      List<dynamic> result = [];

      final email = await SessionManager.getEmail();
      if (email != null) {
        final userRow = await supabase
            .from('users')
            .select('id')
            .eq('email', email)
            .single();

        final userId = userRow['id'] as int;

        final userInteractions = await supabase
            .from('user_interactions')
            .select('content_id')
            .eq('content_type', 'article')
            .eq('user_id', userId)
            .limit(5);

        if (userInteractions.isNotEmpty) {
          final interactedIds = userInteractions
              .map((e) => e['content_id'])
              .toList();

          final categories = await supabase
              .from('articles')
              .select('category')
              .inFilter('id', interactedIds);

          final catList = categories
              .map((e) => e['category']?.toString())
              .where((c) => c != null)
              .toSet()
              .toList();

          if (catList.isNotEmpty) {
            result = await supabase
                .from('articles')
                .select()
                .inFilter('category', catList)
                .not('id', 'in', '(${interactedIds.join(',')})')
                .order('rating', ascending: false)
                .limit(10);
          }
        }
      }

      // Fallback → popular
      if (result.isEmpty) {
        result = await supabase
            .from('articles')
            .select()
            .order('rating', ascending: false)
            .limit(10);
      }

      if (!mounted) return;
      setState(() {
        recommendedArticles = result;
        isLoadingRecommended = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingRecommended = false);
      debugPrint("Error loading recommended articles: $e");
    }
  }

  void filterArticles(String value) {
    setState(() {
      filteredArticles = allArticles.where((a) {
        return (a['title'] ?? '').toString().toLowerCase().contains(
          value.toLowerCase(),
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
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
                    icon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 28,
                    ),
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
                    fillColor: AppColors.cardBg,
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
                        color: Color(0xFF6C94C6),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await loadArticles();
                        await loadRecommendedArticles();
                      },
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // ─── Recommended Articles Section ───
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, top: 4),
                            child: Text(
                              "Recommended Articles",
                              style: GoogleFonts.agbalumo(
                                fontSize: 22,
                                color: const Color(0xFF6C94C6),
                              ),
                            ),
                          ),

                          SizedBox(
                            height: 220,
                            child: isLoadingRecommended
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF6C94C6),
                                    ),
                                  )
                                : recommendedArticles.isEmpty
                                ? const Center(
                                    child: Text(
                                      "No recommendations yet",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: recommendedArticles.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final item = recommendedArticles[index];
                                      return _buildRecommendedArticleCard(item);
                                    },
                                  ),
                          ),

                          const SizedBox(height: 20),

                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              "All Articles",
                              style: GoogleFonts.agbalumo(
                                fontSize: 22,
                                color: const Color(0xFF6C94C6),
                              ),
                            ),
                          ),
                          // ─── All Articles ───
                          if (filteredArticles.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  "No articles found",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                          else
                            ...filteredArticles.map(
                              (item) => _buildArticleCard(item),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedArticleCard(dynamic item) {
    final title = item['title']?.toString() ?? '';
    final imageUrl = item['image_url']?.toString() ?? '';
    final articleId = item['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (articleId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(articleId: articleId),
          ),
        );
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
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
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Container(
                        height: 120,
                        color: const Color(0xFF2A4A6F),
                        child: const Icon(
                          Icons.article,
                          size: 40,
                          color: Colors.white54,
                        ),
                      ),
                      placeholder: (c, u) => Shimmer.fromColors(
                        baseColor: const Color(0xFF1A2F55),
                        highlightColor: const Color(0xFF2A4A7F),
                        child: Container(height: 120, color: Colors.white),
                      ),
                    )
                  : Container(
                      height: 120,
                      color: const Color(0xFF2A4A6F),
                      child: const Icon(
                        Icons.article,
                        size: 40,
                        color: Colors.white54,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
    final rating = double.tryParse(item['rating']?.toString() ?? '0') ?? 0.0;
    final articleId = item['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (articleId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(articleId: articleId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
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
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Container(
                        height: 200,
                        color: const Color(0xFF2A4A6F),
                        child: const Icon(
                          Icons.article,
                          size: 60,
                          color: Colors.white54,
                        ),
                      ),
                      placeholder: (c, u) => Shimmer.fromColors(
                        baseColor: const Color(0xFF1A2F55),
                        highlightColor: const Color(0xFF2A4A7F),
                        child: Container(height: 200, color: Colors.white),
                      ),
                    )
                  : Container(
                      height: 200,
                      color: const Color(0xFF2A4A6F),
                      child: const Icon(
                        Icons.article,
                        size: 60,
                        color: Colors.white54,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
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
                      ),
                    ],
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
                          const Icon(
                            Icons.star,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
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
