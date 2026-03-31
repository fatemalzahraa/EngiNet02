import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'book_detail.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  List<dynamic> allBooks = [];
  List<dynamic> filteredBooks = [];
  bool isLoading = true;

  final String baseUrl = "http://10.0.2.2:8000";

  @override
  void initState() {
    super.initState();
    loadBooks();
  }

  Future<void> loadBooks() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/books/"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          allBooks = data;
          filteredBooks = data;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        debugPrint("Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error loading books: $e");
    }
  }

  void filterBooks(String value) {
    setState(() {
      filteredBooks = allBooks.where((book) {
        return book['title']
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
                        color: Color(0xFF6C94C6),
                      ),
                    )
                  : filteredBooks.isEmpty
                      ? const Center(
                          child: Text(
                            "No books found",
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : GridView.builder(
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
                            final imageUrl = book['image_url'] ?? '';
                            final title = book['title'] ?? '';
                            final likes = book['likes'] ?? 0;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookDetailScreen(
                                      bookId: (book['id'] as num).toInt(),
                                    ),
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
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                        child: Image.network(
                                          imageUrl.isNotEmpty
                                              ? imageUrl
                                              : 'https://via.placeholder.com/150',
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return const Icon(Icons.book,
                                                size: 60);
                                          },
                                        ),
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
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8),
                                      child: Text("⭐ $likes"),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}