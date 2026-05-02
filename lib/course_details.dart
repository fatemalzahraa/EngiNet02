import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

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
  Map<int, bool> _progress = {};

  bool isLoading = true;
  bool _courseStarted = false;

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
          _courseStarted = _progress.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading progress: $e');
    }
  }

  Future<void> _saveLessonCompleted(int lessonId) async {
  final token = await SessionManager.getToken();
  print("TOKEN = $token");

  if (token == null || token.isEmpty) {
    print("❌ NO TOKEN");
    return;
  }

  final res = await http.post(
    Uri.parse(
      '${AppConstants.baseUrl}/profile/lesson-progress'
      '?lesson_id=$lessonId&is_completed=true',
    ),
    headers: {'Authorization': 'Bearer $token'},
  );

  print("STATUS = ${res.statusCode}");
  print("BODY = ${res.body}");
}

  Future<void> _startCourse() async {
  try {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/courses/${widget.courseId}/start'),
      headers: {'Authorization': 'Bearer $token'},
    );

    debugPrint('START COURSE STATUS: ${res.statusCode}');
    debugPrint('START COURSE BODY: ${res.body}');

    if (res.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Start failed: ${res.body}')),
      );
      return;
    }

    setState(() => _courseStarted = true);

    if (lessons.isNotEmpty) {
      _openLesson(0);
    }
  } catch (e) {
    debugPrint('❌ Error starting course: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error starting course: $e')),
    );
  }
}

  int get _completedCount => _progress.values.where((v) => v).length;

  double get _progressPercent {
    if (lessons.isEmpty) return 0;
    return (_completedCount / lessons.length) * 100;
  }

  bool _canOpenLesson(int index) {
    if (index == 0) return true;

    final previousLesson = lessons[index - 1];
    final previousLessonId = previousLesson['id'] as int? ?? 0;

    return _progress[previousLessonId] == true;
  }

  Future<void> _openLesson(int index) async {
    if (!_canOpenLesson(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish the previous video first')),
      );
      return;
    }

    final lesson = lessons[index];
    final lessonId = lesson['id'] as int? ?? 0;
    final videoUrl = lesson['video_url']?.toString() ?? '';
    final title = lesson['title']?.toString() ?? '';

    if (videoUrl.isEmpty) return;

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonVideoPlayerScreen(
          title: title,
          videoUrl: videoUrl,
        ),
      ),
    );

    if (completed == true) {
      await _saveLessonCompleted(lessonId);
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
        body: Center(
          child: Text('Course not found', style: TextStyle(color: Colors.white)),
        ),
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
          Stack(
            children: [
              Container(
                height: 250,
                width: double.infinity,
                color: const Color(0xFF1a237e),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (c, u, e) =>
                            const Icon(Icons.play_circle, size: 80, color: Colors.white54),
                        placeholder: (c, u) => Shimmer.fromColors(
                          baseColor: const Color(0xFF1A2F55),
                          highlightColor: const Color(0xFF2A4A7F),
                          child: Container(height: 250, color: Colors.white),
                        ),
                      )
                    : const Icon(Icons.play_circle, size: 80, color: Colors.white54),
              ),
              Positioned(
                top: 40,
                left: 16,
                child: GestureDetector(
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
              ),
            ],
          ),

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
                          onTap: _courseStarted ? null : _startCourse,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _courseStarted ? Icons.percent : Icons.play_arrow,
                                  color: const Color(0xFFE3C39D),
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _courseStarted
                                      ? 'Progress ${_progressPercent.toStringAsFixed(0)}%'
                                      : 'Start',
                                  style: GoogleFonts.agbalumo(
                                    color: const Color(0xFFE3C39D),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                        Text(
                          instructorName,
                          style: GoogleFonts.agbalumo(color: Colors.white, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.play_circle_outline, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$durationHours hrs',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.star, color: Colors.orange, size: 16),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          '$_completedCount / ${lessons.length}',
                          style: const TextStyle(color: Color(0xFFE3C39D), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  if (lessons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: LinearProgressIndicator(
                        value: _completedCount / lessons.length,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE3C39D)),
                      ),
                    ),

                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),

                  Expanded(
                    child: lessons.isEmpty
                        ? const Center(
                            child: Text('No lessons yet', style: TextStyle(color: Colors.white54)),
                          )
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
    final isCompleted = _progress[lessonId] ?? false;
    final canOpen = _canOpenLesson(index);

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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFF4CAF50)
                  : canOpen
                      ? const Color(0xFFE3C39D)
                      : Colors.grey,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : canOpen
                      ? Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.lock, color: Colors.white, size: 17),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _openLesson(index),
              child: Text(
                title,
                style: TextStyle(
                  color: isCompleted
                      ? Colors.white54
                      : canOpen
                          ? Colors.white
                          : Colors.white38,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Checkbox(
            value: isCompleted,
            onChanged: null,
            activeColor: const Color(0xFF6C94C6),
            checkColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class LessonVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String videoUrl;

  const LessonVideoPlayerScreen({
    super.key,
    required this.title,
    required this.videoUrl,
  });

  @override
  State<LessonVideoPlayerScreen> createState() => _LessonVideoPlayerScreenState();
}

class _LessonVideoPlayerScreenState extends State<LessonVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _isInitialized = true);
        _controller.play();
      });

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (!_controller.value.isInitialized || _completed) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    if (duration.inSeconds > 0 &&
        position.inSeconds >= duration.inSeconds - 1) {
      _completed = true;
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        iconTheme: const IconThemeData(color: Color(0xFFE3C39D)),
        title: Text(
          widget.title,
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 18,
          ),
        ),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFFE3C39D),
                        bufferedColor: Colors.white54,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Center(
                      child: IconButton(
                        iconSize: 64,
                        color: const Color(0xFFE3C39D),
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                        ),
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Color(0xFF6C94C6)),
      ),
    );
  }
}