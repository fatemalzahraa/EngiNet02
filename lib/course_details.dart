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
import 'course_comments_screen.dart';

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
  int commentsCount = 0;
  Map<String, dynamic>? _currentUser;
bool isLiked = false;
int selectedRating = 0;
bool _isProcessingLike = false;
bool _isProcessingRating = false;
final TextEditingController _commentController = TextEditingController();
List<Map<String, dynamic>> comments = [];
int _totalDurationSeconds = 0;
bool _isCalculatingDuration = false;

String get _durationLabel {
  final totalSeconds = _totalDurationSeconds;

  if (totalSeconds < 60) {
    return '${totalSeconds}s';
  }

  final totalMinutes = totalSeconds ~/ 60;

  if (totalMinutes < 60) {
    return '${totalMinutes}m';
  }

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (minutes == 0) return '${hours}h';

  return '${hours}h ${minutes}m';
}

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
  _currentUser = await _fetchCurrentUser();
  await Future.wait([
    loadCourse(),
    _loadProgress(),
    _loadComments(),
    _checkLike(),
    _loadMyRating(),
  ]);
}

Future<Map<String, dynamic>?> _fetchCurrentUser() async {
  final email = await SessionManager.getEmail();
  if (email == null) return null;

  return await supabase
      .from('users')
      .select('id, username, profile_image')
      .eq('email', email)
      .maybeSingle();
}

Future<void> _checkLike() async {
  if (_currentUser == null) return;

  final res = await supabase
      .from('course_likes')
      .select()
      .eq('user_id', _currentUser!['id'])
      .eq('course_id', int.parse(widget.courseId))
      .maybeSingle();

  if (mounted) setState(() => isLiked = res != null);
}

Future<void> _toggleLike() async {
  if (_currentUser == null || course == null || _isProcessingLike) return;

  _isProcessingLike = true;
  final wasLiked = isLiked;
  final currentLikes = course!['likes'] ?? 0;

  setState(() {
    isLiked = !wasLiked;
    course!['likes'] = wasLiked ? currentLikes - 1 : currentLikes + 1;
  });

  try {
    if (wasLiked) {
      await supabase
          .from('course_likes')
          .delete()
          .eq('user_id', _currentUser!['id'])
          .eq('course_id', int.parse(widget.courseId));
    } else {
      await supabase.from('course_likes').insert({
        'user_id': _currentUser!['id'],
        'course_id': int.parse(widget.courseId),
      });
    }

    await supabase.from('courses').update({
      'likes': course!['likes'],
    }).eq('id', int.parse(widget.courseId));
  } catch (e) {
    setState(() {
      isLiked = wasLiked;
      course!['likes'] = currentLikes;
    });
  } finally {
    _isProcessingLike = false;
  }
}

Future<void> _loadMyRating() async {
  if (_currentUser == null) return;

  final res = await supabase
      .from('course_ratings')
      .select('rating')
      .eq('user_id', _currentUser!['id'])
      .eq('course_id', int.parse(widget.courseId))
      .maybeSingle();

  if (mounted) setState(() => selectedRating = res?['rating'] ?? 0);
}

Future<void> _rateCourse(int ratingValue) async {
  if (_currentUser == null || course == null || _isProcessingRating) return;

  _isProcessingRating = true;

  setState(() {
    selectedRating = selectedRating == ratingValue ? 0 : ratingValue;
  });

  try {
    if (selectedRating == 0) {
      await supabase
          .from('course_ratings')
          .delete()
          .eq('user_id', _currentUser!['id'])
          .eq('course_id', int.parse(widget.courseId));
    } else {
      await supabase.from('course_ratings').upsert(
        {
          'user_id': _currentUser!['id'],
          'course_id': int.parse(widget.courseId),
          'rating': selectedRating,
        },
        onConflict: 'user_id,course_id',
      );
    }

    final allRatings = await supabase
        .from('course_ratings')
        .select('rating')
        .eq('course_id', int.parse(widget.courseId));

    double avg = 0.0;
    final list = allRatings as List;
    if (list.isNotEmpty) {
      final sum = list.fold<int>(0, (p, r) => p + (r['rating'] as int));
      avg = sum / list.length;
    }

    await supabase.from('courses').update({
      'rating': avg.toStringAsFixed(1),
    }).eq('id', int.parse(widget.courseId));

    if (mounted) setState(() => course!['rating'] = avg.toStringAsFixed(1));
  } finally {
    _isProcessingRating = false;
  }
}

Future<void> _loadComments() async {
  final res = await supabase
      .from('course_comments')
      .select()
      .eq('course_id', int.parse(widget.courseId))
      .order('created_at', ascending: true);

  if (mounted) {
    setState(() {
      comments = List<Map<String, dynamic>>.from(res as List);
      commentsCount = comments.length;
    });
  }
}

Future<void> _addComment() async {
  if (_currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login first')),
    );
    return;
  }

  final text = _commentController.text.trim();
  if (text.isEmpty) return;

  try {
    await supabase.from('course_comments').insert({
      'course_id': int.parse(widget.courseId),
      'comment_user_id': _currentUser!['id'],
      'username': _currentUser!['username'],
      'profile_image': _currentUser!['profile_image'],
      'content': text,
    });

    _commentController.clear();
    await _loadComments();

  } catch (e) {
    debugPrint("❌ ERROR COMMENT: $e");
  }
}
Future<void> _loadCommentsCount() async {
  try {
    final res = await supabase
        .from('course_comments')
        .select('id')
        .eq('course_id', int.parse(widget.courseId));

    if (!mounted) return;
    setState(() => commentsCount = (res as List).length);
  } catch (e) {
    debugPrint('❌ Error loading course comments count: $e');
  }
}
  Future<void> _saveLessonProgress(
  int lessonId, {
  required bool completed,
  required int watchedSeconds,
}) async {
  final token = await SessionManager.getToken();
  if (token == null || token.isEmpty) return;

  final res = await http.post(
    Uri.parse(
      '${AppConstants.baseUrl}/profile/lesson-progress'
      '?lesson_id=$lessonId'
      '&is_completed=$completed'
      '&watched_seconds=$watchedSeconds',
    ),
    headers: {'Authorization': 'Bearer $token'},
  );

  debugPrint('STATUS = ${res.statusCode}');
  debugPrint('BODY = ${res.body}');

  if (res.statusCode == 200 && completed) {
    setState(() {
      _progress[lessonId] = true;
      _courseStarted = true;
    });
  }
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
        _calculateVideosDuration(List<dynamic>.from(lessonsRes));
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading course: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }
  Future<void> _calculateVideosDuration(List<dynamic> courseLessons) async {
  if (_isCalculatingDuration) return;
  _isCalculatingDuration = true;

  int totalSeconds = 0;

  for (final lesson in courseLessons) {
    final videoUrl = lesson['video_url']?.toString() ?? '';
    if (videoUrl.isEmpty) continue;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();

      totalSeconds += controller.value.duration.inSeconds;

      await controller.dispose();
    } catch (e) {
      debugPrint('❌ Duration error: $e');
    }
  }

  if (!mounted) return;

  setState(() {
    _totalDurationSeconds = totalSeconds;
    _isCalculatingDuration = false;
  });
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
          _progress = data.map((k, v) {
  final completed = v == true || v == 1 || v.toString() == '1';
  return MapEntry(int.parse(k), completed);
});
          _courseStarted = _progress.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading progress: $e');
    }
  }

  Future<void> _saveLessonCompleted(int lessonId) async {
  final token = await SessionManager.getToken();

  if (token == null || token.isEmpty) return;

  final res = await http.post(
    Uri.parse(
      '${AppConstants.baseUrl}/profile/lesson-progress'
      '?lesson_id=$lessonId&is_completed=true',
    ),
    headers: {'Authorization': 'Bearer $token'},
  );

  debugPrint('STATUS = ${res.statusCode}');
  debugPrint('BODY = ${res.body}');

  if (res.statusCode == 200) {
    if (!mounted) return;

    setState(() {
      _progress[lessonId] = true;
      _courseStarted = true;
    });
  }
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
    await _saveLessonProgress(
  lessonId,
  completed: true,
  watchedSeconds: 0,
);

    final nextIndex = index + 1;
    if (mounted && nextIndex < lessons.length) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _openLesson(nextIndex);
      });
    }
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
        radius: 22,
        backgroundImage:
            instructorImage.isNotEmpty ? NetworkImage(instructorImage) : null,
        backgroundColor: const Color(0xFF2A4A6F),
        child: instructorImage.isEmpty
            ? const Icon(Icons.person, size: 20, color: Colors.white)
            : null,
      ),
      const SizedBox(width: 8),

      Expanded(
        child: Text(
          instructorName,
          style: GoogleFonts.agbalumo(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),

      const SizedBox(width: 8),
      const Icon(Icons.ondemand_video, color: Color(0xFF2C3E50), size: 19),
      const SizedBox(width: 3),
      Text(
        _durationLabel,
        style: GoogleFonts.agbalumo(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(width: 8),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          return GestureDetector(
            onTap: () => _rateCourse(index + 1),
            child: Icon(
              index < selectedRating ? Icons.star : Icons.star_border,
              color: Colors.orange,
              size: 17,
            ),
          );
        }),
      ),
      const SizedBox(width: 3),
      Text(
        rating.toStringAsFixed(1),
        style: GoogleFonts.agbalumo(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(width: 8),
      GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseCommentsScreen(
          courseId: widget.courseId,
        ),
      ),
    );
  },
  child: const Icon(
    Icons.chat_bubble,
    color: Color(0xFF2E1B73),
    size: 18,
  ),
),
      const SizedBox(width: 3),
      Text(
        '$commentsCount',
        style: GoogleFonts.agbalumo(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 
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
          Container(
  width: 24,
  height: 24,
  decoration: BoxDecoration(
    color: isCompleted ? const Color(0xFF4CAF50) : Colors.transparent,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: Colors.white54),
  ),
  child: isCompleted
      ? const Icon(Icons.check, color: Colors.white, size: 18)
      : null,
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
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Color(0xFFE3C39D)),
    onPressed: () => Navigator.pop(context),
  ),
  title: Text(
    'Comments',
    style: GoogleFonts.agbalumo(color: const Color(0xFFE3C39D)),
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