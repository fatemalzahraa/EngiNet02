import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'course_details.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:enginet/core/constants.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final supabase = Supabase.instance.client;

  List<dynamic> allCourses = [];
  List<dynamic> filteredCourses = [];
  List<dynamic> recommendedCourses = [];
  bool isLoading = true;
  bool isLoadingRecommended = true;
  bool showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCourses();
    loadRecommendedCourses();
  }

  Future<void> loadCourses() async {
    try {
      final data = await supabase
          .from('courses')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        allCourses = data;
        filteredCourses = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint("Error: $e");
    }
  }

  Future<void> loadRecommendedCourses() async {
  try {
    final token = await SessionManager.getToken();
    debugPrint("TOKEN: $token");

    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/recommendations'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    debugPrint("REC STATUS: ${res.statusCode}");
debugPrint("REC BODY: ${res.body}");

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    if (!mounted) return;
    setState(() {
      recommendedCourses = data['courses'] ?? [];
      isLoadingRecommended = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() => isLoadingRecommended = false);
    debugPrint("Error loading recommended courses: $e");
  }
}

  void filterCourses(String value) {
    setState(() {
      filteredCourses = allCourses.where((c) {
        return c['title']
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
            // ─── HEADER ───
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    icon: const Icon(Icons.search,
                        color: Colors.white, size: 28),
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

            // ─── SEARCH BAR ───
            if (showSearch)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: filterCourses,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search courses...",
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

            // ─── CONTENT ───
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C94C6)))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await loadCourses();
                        await loadRecommendedCourses();
                      },
                      child: ListView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // ─── Recommended Courses Section ───
                          if (recommendedCourses.isNotEmpty ||
                              isLoadingRecommended) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 4, bottom: 12),
                              child: Text(
                                "Recommended Courses",
                                style: GoogleFonts.agbalumo(
                                  fontSize: 22,
                                  color: const Color(0xFF6C94C6),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 180,
                              child: isLoadingRecommended
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                          color: Color(0xFF6C94C6)))
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount:
                                          recommendedCourses.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final item =
                                            recommendedCourses[index];
                                        return _buildRecommendedCourseCard(
                                            item);
                                      },
                                    ),
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 12),
                              child: Text(
                                "All Courses",
                                style: GoogleFonts.agbalumo(
                                  fontSize: 22,
                                  color: const Color(0xFF6C94C6),
                                ),
                              ),
                            ),
                          ],

                          // ─── All Courses List ───
                          if (filteredCourses.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text("No courses found",
                                    style:
                                        TextStyle(color: Colors.white)),
                              ),
                            )
                          else
                            ...filteredCourses
                                .map((item) => _buildCourseCard(item))
                                .toList(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedCourseCard(dynamic item) {
    final title = item['title']?.toString() ?? '';
    final imageUrl = item['image_url']?.toString() ?? '';
    final courseId = item['id']?.toString() ?? '';
    final rating =
        double.tryParse(item['rating']?.toString() ?? '0') ?? 0.0;

    return GestureDetector(
      onTap: () async {
        if (courseId.isEmpty) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CourseDetailScreen(courseId: courseId),
          ),
        );
        await loadCourses();
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF4A6FA5),
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
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Container(
                        height: 110,
                        color: const Color(0xFF7D93B0),
                        child: const Icon(Icons.play_circle,
                            size: 40, color: Colors.white54),
                      ),
                      placeholder: (c, u) => Shimmer.fromColors(
                        baseColor: const Color(0xFF1A2F55),
                        highlightColor: const Color(0xFF2A4A7F),
                        child: Container(
                            height: 110, color: Colors.white),
                      ),
                    )
                  : Container(
                      height: 110,
                      color: const Color(0xFF2A4A6F),
                      child: const Icon(Icons.play_circle,
                          size: 40, color: Colors.white54),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
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

  Widget _buildCourseCard(dynamic item) {
    final title = item['title'] ?? '';
    final imageUrl = item['image_url'] ?? '';
    final instructorName = item['instructor_name'] ?? '';
    final instructorImage = item['instructor_image'] ?? '';
    final rating = (item['rating'] ?? 0.0).toDouble();

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CourseDetailScreen(courseId: item['id'].toString()),
          ),
        );
        await loadCourses();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF4A6FA5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 130,
                      height: 130,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Container(
                        width: 130,
                        height: 130,
                        color: const Color(0xFF7D93B0),
                        child: const Icon(Icons.play_circle,
                            size: 50, color: Colors.white54),
                      ),
                      placeholder: (c, u) => Shimmer.fromColors(
                        baseColor: const Color(0xFF1A2F55),
                        highlightColor: const Color(0xFF2A4A7F),
                        child: Container(
                            width: 130,
                            height: 130,
                            color: Colors.white),
                      ),
                    )
                  : Container(
                      width: 130,
                      height: 130,
                      color: const Color(0xFF2A4A6F),
                      child: const Icon(Icons.play_circle,
                          size: 50, color: Colors.white54),
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
                              ? const Icon(Icons.person,
                                  size: 14, color: Colors.white)
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
                        const Icon(Icons.star,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
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