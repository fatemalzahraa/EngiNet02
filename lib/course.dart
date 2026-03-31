import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'course_details.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  List<dynamic> allCourses = [];
  List<dynamic> filteredCourses = [];
  bool isLoading = true;
  bool showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final String baseUrl = "https://enginet02-1.onrender.com";

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> loadCourses() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/courses/"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          allCourses = data;
          filteredCourses = data;
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

  void filterCourses(String value) {
    setState(() {
      filteredCourses = allCourses.where((c) {
        return c['title'].toString().toLowerCase().contains(value.toLowerCase());
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
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Course",
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
                          filteredCourses = allCourses;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            // SEARCH BAR
            if (showSearch)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: filterCourses,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search courses...",
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

            // COURSES LIST
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C94C6)))
                  : filteredCourses.isEmpty
                      ? const Center(child: Text("No courses found", style: TextStyle(color: Colors.white)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredCourses.length,
                          itemBuilder: (context, index) {
                          final item = filteredCourses[index];
return _buildCourseCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildCourseCard(dynamic item) {
    final title = item['title'] ?? '';
    final imageUrl = item['image_url'] ?? '';
    final instructorName = item['instructor_name'] ?? '';
    final instructorImage = item['instructor_image'] ?? '';
    final rating = (item['rating'] ?? 0.0).toDouble();

    return GestureDetector(
      onTap: () {
        var materialPageRoute = MaterialPageRoute(
           builder: (context) => CourseDetailScreen(courseId: (item['id'] as num).toInt()),
          );
        Navigator.push(
          context,
          materialPageRoute,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF4A6FA5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // صورة الكورس
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 130,
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: 130,
                        height: 130,
                        color: const Color(0xFF7D93B0),
                        child: const Icon(Icons.play_circle, size: 50, color: Colors.white54),
                      ),
                    )
                  : Container(
                      width: 130,
                      height: 130,
                      color: const Color(0xFF2A4A6F),
                      child: const Icon(Icons.play_circle, size: 50, color: Colors.white54),
                    ),
            ),

         
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: instructorImage.isNotEmpty
                              ? NetworkImage(instructorImage)
                              : null,
                          backgroundColor: const Color(0xFF2A4A6F),
                          child: instructorImage.isEmpty
                              ? const Icon(Icons.person, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            instructorName,
                            style: GoogleFonts.agbalumo(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
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
}