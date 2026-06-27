import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart' show Shimmer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'book_detail.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:enginet/core/app_colors.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final supabase = Supabase.instance.client;
  String? currentUsername;
  Timer? _debounce;

  List<Map<String, dynamic>> allBooks = [];
  List<Map<String, dynamic>> filteredBooks = [];
  List<Map<String, dynamic>> recommendedBooks = [];
  bool isLoading = true;
  bool isLoadingRecommended = true;
  final TextEditingController _searchController = TextEditingController();

  // ── API base URL — .env veya const ile yönet ──────────────────
  static const String _apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://enginet02.onrender.com',
  );

  @override
  void initState() {
    super.initState();
    _loadUser();
    _wakeUpBackend();
    loadBooks();
    loadRecommendedBooks();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _wakeUpBackend() async {
  try {
    await http.get(Uri.parse('$_apiBase/health')).timeout(
      const Duration(seconds: 60),
    );
  } catch (_) {}
}

  Future<void> _loadUser() async {
    currentUsername = await SessionManager.getUsername();
    if (mounted) setState(() {});
  }

  Future<void> _showDeleteDialog(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Book"),
        content: const Text("Are you sure you want to delete this book?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) _deleteBook(id);
  }

  Future<void> _deleteBook(String id) async {
    try {
      await supabase.from('books').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book deleted successfully')),
      );
      loadBooks();
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  void _editBook(dynamic book) {
    final titleController = TextEditingController(text: book['title'] ?? '');
    final descController = TextEditingController(text: book['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController),
            const SizedBox(height: 10),
            TextField(controller: descController, maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await supabase
                  .from('books')
                  .update({
                    'title': titleController.text.trim(),
                    'description': descController.text.trim(),
                  })
                  .eq('id', book['id']);
              Navigator.pop(context);
              loadBooks();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> loadBooks() async {
    try {
      final response = await supabase
          .from('books')
          .select()
          .order('created_at', ascending: false);

      final data = List<Map<String, dynamic>>.from(response);
      if (!mounted) return;
      setState(() {
        allBooks = data;
        filteredBooks = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading books: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  /// Kişiselleştirilmiş öneriler — hybrid engine (/recommendations)
  /// Token yoksa veya hata olursa popularity fallback'e düşer.
  Future<void> loadRecommendedBooks() async {
    if (mounted) setState(() => isLoadingRecommended = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      debugPrint('TOKEN_FIRST50 = ${session?.accessToken?.substring(0, 50)}');
final token = session?.accessToken;

      // Token yoksa → Supabase'den popüler kitapları çek (cold-start fallback)
      if (token == null || token.isEmpty) {
        await _loadPopularFallback();
        return;
      }

      final uri = Uri.parse('$_apiBase/recommendations?limit=10');
      debugPrint('API_BASE_URL = $_apiBase');
      debugPrint('REQUEST_URL = $uri');

      final response = await http
          .get(uri, headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          })
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Endpoint hem "books" hem strategy döndürür.
        // strategy == "popular" → zaten popular liste geliyor, aynı şekilde göster.
        final raw = body['books'] as List<dynamic>? ?? [];
        final books = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        setState(() {
          recommendedBooks = books;
          isLoadingRecommended = false;
        });

        debugPrint(
          '=== recommended: ${books.length} books, '
          'strategy=${body['strategy']}, '
          'signals=${body['signals_used']} ===',
        );
      } else {
        debugPrint('Recommendations API error: ${response.statusCode}');
        await _loadPopularFallback();
      }
    } on TimeoutException {
      debugPrint('Recommendations timeout — falling back to popular');
      await _loadPopularFallback();
    } catch (e) {
      debugPrint('loadRecommendedBooks error: $e');
      await _loadPopularFallback();
    }
  }

  /// Popularity fallback — direkt Supabase (token gerekmez)
  Future<void> _loadPopularFallback() async {
    try {
      final response = await supabase
          .from('books')
          .select('id, title, image_url, likes, category')
          .order('likes', ascending: false)
          .limit(10);

      final result = List<Map<String, dynamic>>.from(response);
      if (!mounted) return;
      setState(() {
        recommendedBooks = result;
        isLoadingRecommended = false;
      });
    } catch (e) {
      debugPrint('Popular fallback error: $e');
      if (!mounted) return;
      setState(() => isLoadingRecommended = false);
    }
  }

  Future<void> saveSearch(String query) async {
    if (query.trim().length < 2) return;
    try {
      final email = await SessionManager.getEmail();
      if (email == null) return;
      final user = await supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .single();
      await supabase.from('search_history').insert({
        'user_id': user['id'],
        'query': query.trim(),
      });
    } catch (e) {
      debugPrint("Search save error: $e");
    }
  }

  void filterBooks(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      saveSearch(value);
      if (!mounted) return;
      setState(() {
        filteredBooks = allBooks.where((book) {
          final title = (book['title'] ?? '').toString().toLowerCase();
          final author = (book['author'] ?? '').toString().toLowerCase();
          final category = (book['category'] ?? '').toString().toLowerCase();
          final search = value.toLowerCase();
          return title.contains(search) ||
              author.contains(search) ||
              category.contains(search);
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await loadBooks();
            await loadRecommendedBooks();
          },
          child: CustomScrollView(
            slivers: [
              // ─── Header ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Books",
                    style: GoogleFonts.agbalumo(
                      fontSize: 40,
                      color: const Color(0xFF6C94C6),
                    ),
                  ),
                ),
              ),

              // ─── Search ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: filterBooks,
                    decoration: InputDecoration(
                      hintText: "Search books...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ─── Recommended Books ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "Recommended Books",
                    style: GoogleFonts.agbalumo(
                      fontSize: 22,
                      color: const Color(0xFF6C94C6),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: isLoadingRecommended
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6C94C6),
                          ),
                        )
                      : recommendedBooks.isEmpty
                          ? const Center(
                              child: Text(
                                "No recommendations yet",
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: recommendedBooks.length,
                              itemBuilder: (context, index) {
                                final book = recommendedBooks[index];
                                final imageUrl = book['image_url']?.toString() ?? '';
                                final title = book['title']?.toString() ?? '';
                                final bookId = book['id']?.toString() ?? '';

                                return GestureDetector(
                                  onTap: () {
                                    if (bookId.isEmpty) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            BookDetailScreen(bookId: bookId),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 130,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD8C6AF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16),
                                          ),
                                          child: imageUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: imageUrl,
                                                  fit: BoxFit.cover,
                                                  width: 130,
                                                  height: 160,
                                                  errorWidget: (c, u, e) =>
                                                      const SizedBox(
                                                        height: 160,
                                                        child: Icon(
                                                          Icons.book,
                                                          size: 40,
                                                        ),
                                                      ),
                                                  placeholder: (c, u) =>
                                                      Shimmer.fromColors(
                                                    baseColor:
                                                        const Color(0xFFCCB89A),
                                                    highlightColor:
                                                        const Color(0xFFE8D8C0),
                                                    child: Container(
                                                      width: 130,
                                                      height: 160,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : const SizedBox(
                                                  height: 160,
                                                  child: Icon(
                                                    Icons.book,
                                                    size: 40,
                                                  ),
                                                ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 6,
                                          ),
                                          child: Text(
                                            title,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),

              // ─── All Books Grid ───
              if (isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C94C6),
                      ),
                    ),
                  ),
                )
              else if (filteredBooks.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 80, color: Colors.white54),
                        SizedBox(height: 16),
                        Text(
                          "No books found",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Try searching with another keyword",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.55,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final book = filteredBooks[index];
                        final imageUrl = book['image_url']?.toString() ?? '';
                        final title = book['title']?.toString() ?? '';
                        final likes = book['likes'] ?? 0;
                        final isOwner =
                            book['author_username']?.toString() ==
                            currentUsername;
                        final bookId = book['id']?.toString() ?? '';

                        return GestureDetector(
                          onTap: () {
                            if (bookId.isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    BookDetailScreen(bookId: bookId),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFD8C6AF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                        child: imageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                placeholder: (context, url) =>
                                                    Container(
                                                  color: Colors.grey.shade300,
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                ),
                                                imageUrl: imageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              )
                                            : const Icon(Icons.book, size: 60),
                                      ),
                                      if (isOwner)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert,
                                                color: Colors.black),
                                            onSelected: (value) {
                                              if (value == 'delete') {
                                                _showDeleteDialog(bookId);
                                              } else if (value == 'edit') {
                                                _editBook(book);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text("⭐ $likes"),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filteredBooks.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}