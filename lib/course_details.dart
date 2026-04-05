import 'dart:convert';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? course;
  List<dynamic> lessons = [];

  // Fixed: lesson progress persisted via API — key: lesson_id, value: bool
  Map<int, bool> _progress = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([loadCourse(), _loadProgress()]);
  }

  Future<void> loadCourse() async {
    try {
      final courseRes = await supabase
          .from('courses')
          .select()
          .eq('id', widget.courseId)
          .single();

      final lessonsRes = await supabase
          .from('lessons')
          .select()
          .eq('course_id', widget.courseId)
          .order('order_index', ascending: true);

      if (!mounted) return;
      setState(() {
        course = courseRes;
        lessons = List<dynamic>.from(lessonsRes);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading course: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // Fixed: load real progress from backend
  Future<void> _loadProgress() async {
    try {
      final token = await SessionManager.getToken();
      if (token == null || token.isEmpty) return;

      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/profile/lesson-progress/${widget.courseId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          _progress = data.map((k, v) => MapEntry(int.parse(k), v as bool));
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading progress: $e');
    }
  }

  // Fixed: save lesson completion to backend
  Future<void> _toggleLesson(int lessonId, bool completed) async {
    setState(() => _progress[lessonId] = completed);

    try {
      final token = await SessionManager.getToken();
      if (token == null || token.isEmpty) return;

      await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/profile/lesson-progress'
          '?lesson_id=$lessonId&is_completed=$completed',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      debugPrint('❌ Error saving progress: $e');
      // Revert optimistic update on failure
      if (mounted) setState(() => _progress[lessonId] = !completed);
    }
  }

  int get _completedCount => _progress.values.where((v) => v).length;

  Future<void> openVideo(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Cannot open URL: $e');
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

    if (course == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF071739),
        body: Center(child: Text('Course not found', style: TextStyle(color: Colors.white))),
      );
    }

    final title = course!['title']?.toString() ?? '';
    final imageUrl = course!['image_url']?.toString() ?? '';
    final instructorName = course!['instructor_name']?.toString() ?? '';
    final instructorImage = course!['instructor_image']?.toString() ?? '';
    final durationHours = course!['duration_hours'] ?? 0;
    final rating = double.tryParse(course!['rating']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: Column(
        children: [
          // ── Header Image ──────────────────────────────────
          Stack(
            children: [
              Container(
                height: 250,
                width: double.infinity,
                color: const Color(0xFF1a237e),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        height: 250, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.play_circle,
                            size: 80, color: Colors.white54))
                    : const Icon(Icons.play_circle, size: 80, color: Colors.white54),
              ),
              Positioned(
                top: 40,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                        color: Color(0xFFE3C39D), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),

          // ── Content ───────────────────────────────────────
          Expanded(
            child: Container(
              color: const Color(0xFF4A6FA5).withValues(alpha: 0.5),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (lessons.isNotEmpty) {
                              openVideo(lessons[0]['video_url']?.toString() ?? '');
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                color: const Color(0xFF2C3E50),
                                borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                const Icon(Icons.play_arrow, color: Color(0xFFE3C39D), size: 20),
                                const SizedBox(width: 4),
                                Text('Start',
                                    style: GoogleFonts.agbalumo(
                                        color: const Color(0xFFE3C39D), fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ],
                    ),
                  ),

                  // Instructor + stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage:
                              instructorImage.isNotEmpty ? NetworkImage(instructorImage) : null,
                          backgroundColor: const Color(0xFF2A4A6F),
                          child: instructorImage.isEmpty
                              ? const Icon(Icons.person, size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(instructorName,
                            style: GoogleFonts.agbalumo(color: Colors.white, fontSize: 13)),
                        const SizedBox(width: 12),
                        const Icon(Icons.play_circle_outline, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text('$durationHours hrs',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 12),
                        const Icon(Icons.star, color: Colors.orange, size: 16),
                        Text(rating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const Spacer(),
                        // Progress indicator
                        Text(
                          '$_completedCount / ${lessons.length}',
                          style: const TextStyle(color: Color(0xFFE3C39D), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Progress bar
                  if (lessons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: LinearProgressIndicator(
                        value: _completedCount / lessons.length,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Color(0xFFE3C39D)),
                      ),
                    ),

                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),

                  // Lessons list
                  Expanded(
                    child: lessons.isEmpty
                        ? const Center(
                            child: Text('No lessons yet',
                                style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            itemCount: lessons.length,
                            itemBuilder: (context, index) =>
                                _buildLessonItem(index, lessons[index]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonItem(int index, dynamic lesson) {
    final lessonId = lesson['id'] as int? ?? 0;
    final title = lesson['title']?.toString() ?? '';
    final videoUrl = lesson['video_url']?.toString() ?? '';
    final isCompleted = _progress[lessonId] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF3A5A8A).withValues(alpha: 0.4),
        border: const Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF4CAF50) : const Color(0xFFE3C39D),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text('${index + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => openVideo(videoUrl),
              child: Text(title,
                  style: TextStyle(
                      color: isCompleted ? Colors.white54 : Colors.white, fontSize: 14)),
            ),
          ),
          // Fixed: checkbox now saves to backend
          Checkbox(
            value: isCompleted,
            onChanged: (v) => _toggleLesson(lessonId, v ?? false),
            activeColor: const Color(0xFF6C94C6),
            checkColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}