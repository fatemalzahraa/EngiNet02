import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart' show Shimmer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'book_detail.dart';
import 'package:enginet/core/session_manager.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final supabase = Supabase.instance.client;
  String? currentUsername;

  List<dynamic> allBooks = [];
  List<dynamic> filteredBooks = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUser();
    loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _loadUser() async {
  currentUsername = await SessionManager.getUsername();
  if (mounted) setState(() {});
}

  Future<void> _deleteBook(String id) async {
  await supabase.from('books').delete().eq('id', id);
  loadBooks();
}

void _editBook(dynamic book) {
  final titleController =
      TextEditingController(text: book['title'] ?? '');
  final descController =
      TextEditingController(text: book['description'] ?? '');

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
            await supabase.from('books').update({
              'title': titleController.text.trim(),
              'description': descController.text.trim(),
            }).eq('id', book['id']);

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
      final data = await supabase
          .from('books')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        allBooks = data;
        filteredBooks = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint("Error loading books: $e");
    }
  }

  void filterBooks(String value) {
    setState(() {
      filteredBooks = allBooks.where((book) {
        return (book['title'] ?? '')
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
              padding: const EdgeInsets.all(16),
              child: Text(
                "Books",
                style: GoogleFonts.agbalumo(
                  fontSize: 40,
                  color: const Color(0xFF6C94C6),
                ),
              ),
            ),
            Padding(
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
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C94C6)))
                  : filteredBooks.isEmpty
                      ? const Center(
                          child: Text("No books found",
                              style: TextStyle(color: Colors.white)))
                      : RefreshIndicator(
                          onRefresh: loadBooks,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredBooks.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.55,
                            ),
                            itemBuilder: (context, index) {
                              final book = filteredBooks[index];
                              final imageUrl =
                                  book['image_url']?.toString() ?? '';
                              final title =
                                  book['title']?.toString() ?? '';
                             final likes = book['likes'] ?? 0;
                             final isOwner = book['author_username']?.toString() == currentUsername;
                              

                              // ✅ آمن مع UUID و int
                              final bookId =
                                  book['id']?.toString() ?? '';

                              return GestureDetector(
                                onTap: () {
                                  if (bookId.isEmpty) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BookDetailScreen(
                                              bookId: bookId),
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
      // 🔴 الصورة + زر ⋮ فوقها
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
          icon: const Icon(Icons.more_vert, color: Colors.black),
          onSelected: (value) {
            if (value == 'delete') {
              _deleteBook(bookId);
            } else if (value == 'edit') {
              _editBook(book);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    ],
  ),
),

      const SizedBox(height: 8),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}