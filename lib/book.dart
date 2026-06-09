import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart' show Shimmer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'book_detail.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:enginet/core/app_colors.dart';
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _loadUser();
    loadBooks();
    loadRecommendedBooks();
  }

  @override
void dispose() {
  _debounce?.cancel();
  _searchController.dispose();
  super.dispose();
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
      content: const Text(
        "Are you sure you want to delete this book?",
      ),
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

  if (confirm == true) {
    _deleteBook(id);
  }
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
    final descController = TextEditingController(
      text: book['description'] ?? '',
    );

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

    debugPrint("Books response: $response");
    debugPrint("Books count: ${response.length}");
    
    // ← هذا الجزء ناقص عندك!
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

 Future<void> loadRecommendedBooks() async {
  debugPrint("=== loadRecommendedBooks started ==="); 
  if (mounted) setState(() => isLoadingRecommended = true);
  
  try {
    final response = await supabase
        .from('books')
        .select()
        .order('likes', ascending: false)
        .limit(10);
        debugPrint("=== recommended count: ${response.length} ==="); 

    final result = List<Map<String, dynamic>>.from(response);

    if (!mounted) return;
    setState(() {
      recommendedBooks = result;
      isLoadingRecommended = false;
    });
  } catch (e) {
    debugPrint("=== recommended ERROR: $e ==="); 
    debugPrint("Error loading recommended books: $e");
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
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

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

              // Recommended Books Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    "Recommended Books",
                    style: GoogleFonts.agbalumo(
                      fontSize: 22,
                      color: const Color(0xFF6C94C6),
                    ),
                  ),
                ),
              ),

              // ✅ بعد
SliverToBoxAdapter(
  child: SizedBox(
    height: 220,
    child: isLoadingRecommended
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C94C6)),
          )
        : recommendedBooks.isEmpty
        ? const Center(
            child: Text("No recommendations yet",
                style: TextStyle(color: Colors.white)),
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
                      builder: (context) => BookDetailScreen(bookId: bookId),
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
                      // ← ارتفاع صريح بدل Expanded
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
                                height: 160, // ← صريح
                                errorWidget: (c, u, e) =>
                                    const SizedBox(
                                      height: 160,
                                      child: Icon(Icons.book, size: 40),
                                    ),
                                placeholder: (c, u) => Shimmer.fromColors(
                                  baseColor: const Color(0xFFCCB89A),
                                  highlightColor: const Color(0xFFE8D8C0),
                                  child: Container(
                                    width: 130,
                                    height: 160,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const SizedBox(
                                height: 160,
                                child: Icon(Icons.book, size: 40),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
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
        Icon(
          Icons.menu_book_rounded,
          size: 80,
          color: Colors.white54,
        ),
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
          style: TextStyle(
            color: Colors.white70,
          ),
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
                    delegate: SliverChildBuilderDelegate((context, index) {
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
                              builder: (context) =>
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
                                            placeholder: (context, url) => Container(
  color: Colors.grey.shade300,
  child: const Center(
    child: CircularProgressIndicator(),
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
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color: Colors.black,
                                          ),
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
                                  horizontal: 8,
                                ),
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                    }, childCount: filteredBooks.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedBookCard(dynamic book) {
    final imageUrl = book['image_url']?.toString() ?? '';
    final title = book['title']?.toString() ?? '';
    final bookId = book['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (bookId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailScreen(bookId: bookId),
          ),
        );
      },
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFD8C6AF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (c, u, e) =>
                            const Icon(Icons.book, size: 40),
                        placeholder: (c, u) => Shimmer.fromColors(
                          baseColor: const Color(0xFFCCB89A),
                          highlightColor: const Color(0xFFE8D8C0),
                          child: Container(color: Colors.white),
                        ),
                      )
                    : const Icon(Icons.book, size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
  }
}
