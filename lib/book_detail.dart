import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Map<String, dynamic>? book;
  bool isLoading = true;
  bool isBookmarked = false;
  final String baseUrl = "http://10.0.2.2:8000";

  @override
  void initState() {
    super.initState();
    loadBook();
  }

  Future<void> loadBook() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/books/${widget.bookId}"));
      if (response.statusCode == 200) {
        setState(() {
          book = Map<String, dynamic>.from(json.decode(response.body));
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("❌ Cannot open URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF071739),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C94C6))),
      );
    }

    if (book == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF071739),
        appBar: AppBar(backgroundColor: const Color(0xFF071739)),
        body: const Center(
          child: Text("Book not found", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final title = book!['title']?.toString() ?? '';
    final author = book!['author']?.toString() ?? '';
    final imageUrl = book!['image_url']?.toString() ?? '';
    final fileUrl = book!['file_url']?.toString() ?? '';
    final description = book!['description']?.toString() ?? '';
    final rating = double.tryParse(book!['rating']?.toString() ?? '4.5') ?? 4.5;
    final likes = book!['likes'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3C39D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Book details",
                    style: GoogleFonts.agbalumo(
                      fontSize: 28,
                      color: const Color(0xFFE3C39D),
                    ),
                  ),
                ],
              ),
            ),

            // CARD 
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Container(
                    width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8C09A),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF3E8),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                         
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: NetworkImage(
                                    "https://i.pravatar.cc/150?img=1"),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                author,
                                style: GoogleFonts.agbalumo(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          //
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      height: 200,
                                      width: 160,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(
                                        height: 200,
                                        width: 160,
                                        color: const Color(0xFFE0D5C5),
                                        child: const Icon(Icons.book,
                                            size: 60, color: Colors.brown),
                                      ),
                                    )
                                  : Container(
                                      height: 200,
                                      width: 160,
                                      color: const Color(0xFFE0D5C5),
                                      child: const Icon(Icons.book,
                                          size: 60, color: Colors.brown),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // 
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < rating.floor()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // 
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Read و Download
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => openUrl(fileUrl),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C94C6),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.menu_book,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Read",
                                          style: GoogleFonts.agbalumo(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => openUrl(fileUrl),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C94C6),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.download,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Download",
                                          style: GoogleFonts.agbalumo(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          //  Bookmark
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
                              const SizedBox(width: 8),
                              const Icon(Icons.chat_bubble,
                                  color: Color(0xFF5B7FA6), size: 18),
                              const SizedBox(width: 4),
                              Text(
                                "$likes",
                                style:
                                    const TextStyle(color: Colors.black87),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(
                                    () => isBookmarked = !isBookmarked),
                                child: Icon(
                                  isBookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: const Color(0xFF071739),
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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