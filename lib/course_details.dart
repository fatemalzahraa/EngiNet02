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
import 'package:enginet/engineer_profile.dart';
import 'package:enginet/points_helper.dart';
import 'package:enginet/core/app_colors.dart';

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
  Map<int, int> _watchedSeconds = {};

  bool isLoading = true;
  bool _courseStarted = false;
  int commentsCount = 0;
  Map<String, dynamic>? _currentUser;
  bool isLiked = false;
  int selectedRating = 0;
  bool _isProcessingLike = false;
  bool _isProcessingRating = false;
  List<Map<String, dynamic>> comments = [];
  int _totalDurationSeconds = 0;
  bool _isCalculatingDuration = false;

  String get _durationLabel {
    final totalSeconds = _totalDurationSeconds;
    if (totalSeconds < 60) return '${totalSeconds}s';
    final totalMinutes = totalSeconds ~/ 60;
    if (totalMinutes < 60) return '${totalMinutes}m';
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

void _resumeCourse() {
  if (lessons.isEmpty) return;
  
  int targetIndex = 0;
  for (int i = 0; i < lessons.length; i++) {
    final lessonId = lessons[i]['id'] as int? ?? 0;
    if (_progress[lessonId] != true) {
      targetIndex = i;
      break;
    }
    targetIndex = lessons.length - 1;
  }
  _openLesson(targetIndex);
}
  // ── Completion reward ────────────────────────────────────────────────────
  Future<void> _giveCompletionReward() async {
    if (_currentUser == null || course == null) return;
    if (_currentUser!['role'] != 'student') return;

    try {
      final existing = await supabase
          .from('course_completions')
          .select()
          .eq('user_id', _currentUser!['id'])
          .eq('course_id', int.parse(widget.courseId))
          .maybeSingle();

      if (existing != null) return;

      await supabase.from('course_completions').insert({
        'user_id': _currentUser!['id'],
        'course_id': int.parse(widget.courseId),
      });

      await addPoints(_currentUser!['id'], 10);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 You earned 10 points for completing the course!'),
        ),
      );
    } catch (e) {
      debugPrint('❌ completion reward error: $e');
    }
  }

  // ── Open instructor profile ───────────────────────────────────────────────
  Future<void> _openInstructorProfile() async {
    final instructorUsername = course?['instructor_name']?.toString() ?? '';
    if (instructorUsername.isEmpty) return;

    try {
      final owner = await supabase
          .from('users')
          .select('id')
          .eq('username', instructorUsername)
          .maybeSingle();

      if (owner == null || owner['id'] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User profile not found')));
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EngineerProfileScreen(targetUserId: owner['id']),
        ),
      );
    } catch (e) {
      debugPrint('❌ open instructor profile error: $e');
    }
  }

  // ── Load all ─────────────────────────────────────────────────────────────
Future<void> _loadAll() async {
  _currentUser = await _fetchCurrentUser();
  
  // Önce course ve progress'i sırayla yükle
  await loadCourse();
  await _loadProgress();
  
  // Geri kalanlar paralel çalışabilir
  await Future.wait([
    _loadComments(),
    _checkLike(),
    _loadMyRating(),
  ]);
}

  // _deleteCourse() metodunun üstüne ekle:
Future<void> _showEditDialog() async {
  if (course == null) return;
  final titleCtrl = TextEditingController(text: course!['title'] ?? '');
  final descCtrl = TextEditingController(text: course!['description'] ?? '');
  String? selectedCat = course!['category'];

  final categories = [
    'Programming', 'Civil Engineering', 'Mechanical Engineering',
    'Electrical Engineering', 'Mathematics', 'Physics', 'Other',
  ];

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A2F55),
      title: const Text('Edit Course', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Description',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setLocal) => DropdownButtonFormField<String>(
                value: categories.contains(selectedCat) ? selectedCat : null,
                dropdownColor: const Color(0xFF1A2F55),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Category',
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                items: categories.map((c) =>
                  DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setLocal(() => selectedCat = val),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () async {
            final token = await SessionManager.getToken();
            if (token == null) return;
            try {
              final res = await http.put(
                Uri.parse('${AppConstants.baseUrl}/courses/${widget.courseId}'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  if (selectedCat != null) 'category': selectedCat,
                }),
              );
              if (res.statusCode == 200) {
                Navigator.pop(ctx);
                await loadCourse();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Course updated')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Update failed: ${res.body}')),
                  );
                }
              }
            } catch (e) {
              debugPrint('❌ update error: $e');
            }
          },
          child: const Text('Save', style: TextStyle(color: Color(0xFFD4AF37))),
        ),
      ],
    ),
  );

  titleCtrl.dispose();
  descCtrl.dispose();
}

  // ── Delete course ─────────────────────────────────────────────────────────
  Future<void> _confirmDeleteCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure you want to delete this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) await _deleteCourse();
  }

  Future<void> _deleteCourse() async {
    try {
      final courseId = int.parse(widget.courseId);

      final lessonRows = await supabase
          .from('lessons')
          .select('id')
          .eq('course_id', courseId);

      final lessonIds = (lessonRows as List)
          .map((e) => e['id'] as int)
          .toList();

      if (lessonIds.isNotEmpty) {
        await supabase
            .from('lesson_progress')
            .delete()
            .inFilter('lesson_id', lessonIds);
      }

      await supabase.from('lessons').delete().eq('course_id', courseId);
      await supabase.from('student_courses').delete().eq('course_id', courseId);
      await supabase.from('course_ratings').delete().eq('course_id', courseId);
      await supabase.from('course_comments').delete().eq('course_id', courseId);
      await supabase.from('courses').delete().eq('id', courseId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course deleted successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ deleteCourse error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  // ── Current user ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _fetchCurrentUser() async {
    final email = await SessionManager.getEmail();
    if (email == null) return null;
    return await supabase
        .from('users')
        .select('id, username, profile_image, role')
        .eq('email', email)
        .maybeSingle();
  }

  // ── Like ─────────────────────────────────────────────────────────────────
Future<void> _checkLike() async {
  final token = await SessionManager.getToken();
  if (token == null) return;
  
  try {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/courses/${widget.courseId}/my-like'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (mounted) setState(() => isLiked = data['is_liked'] == true);
    }
  } catch (e) {
    debugPrint('❌ checkLike error: $e');
  }
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
      await supabase
          .from('courses')
          .update({'likes': course!['likes']})
          .eq('id', int.parse(widget.courseId));
    } catch (e) {
      setState(() {
        isLiked = wasLiked;
        course!['likes'] = currentLikes;
      });
    } finally {
      _isProcessingLike = false;
    }
  }

  // ── Rating ────────────────────────────────────────────────────────────────
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
        await supabase.from('course_ratings').upsert({
          'user_id': _currentUser!['id'],
          'course_id': int.parse(widget.courseId),
          'rating': selectedRating,
        }, onConflict: 'user_id,course_id');
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

      await supabase
          .from('courses')
          .update({'rating': avg.toStringAsFixed(1)})
          .eq('id', int.parse(widget.courseId));

      if (mounted) setState(() => course!['rating'] = avg.toStringAsFixed(1));
    } finally {
      _isProcessingRating = false;
    }
  }

  // ── Comments ─────────────────────────────────────────────────────────────
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

  // ── Lesson progress ───────────────────────────────────────────────────────
  Future<void> _saveLessonProgress(
    int lessonId, {
    required bool completed,
    required int watchedSeconds,
  }) async {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) return;
    if (!mounted) return;

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

  // ── Load course ───────────────────────────────────────────────────────────
Future<void> loadCourse() async {
  try {
    final token = await SessionManager.getToken();
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/courses/${widget.courseId}'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        course = Map<String, dynamic>.from(data);
        lessons = List<dynamic>.from(data['lessons'] ?? []);
        commentsCount = data['comments_count'] ?? 0;
        // isLoading burada false YAPMA
      });
    }
  } catch (e) {
    debugPrint('❌ Error loading course: $e');
  }
}

Future<void> _loadProgress() async {
  try {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => isLoading = false); // <-- buraya
      return;
    }

    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/profile/lesson-progress/${widget.courseId}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        _progress = {};
        _watchedSeconds = {};

        data.forEach((k, v) {
          final lessonId = int.parse(k);
          if (v is Map) {
            _progress[lessonId] = v['completed'] == true || v['completed'] == 1;
            _watchedSeconds[lessonId] = int.tryParse(v['watched_seconds'].toString()) ?? 0;
          } else {
            _progress[lessonId] = v == true || v == 1 || v.toString() == '1';
            _watchedSeconds[lessonId] = 0;
          }
        });

        _courseStarted = _progress.values.any((v) => v) ||
            _watchedSeconds.values.any((s) => s > 0);
        
        isLoading = false; // <-- buraya taşındı
      });
    }
  } catch (e) {
    debugPrint('❌ Error loading progress: $e');
    if (mounted) setState(() => isLoading = false); // <-- catch'e de ekle
  }
}

  // ── Start course ──────────────────────────────────────────────────────────
 Future<void> _startCourse() async {
  try {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/courses/${widget.courseId}/start'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Start failed: ${res.body}')));
      return;
    }

    setState(() => _courseStarted = true);

    if (lessons.isNotEmpty) {
      // İlk tamamlanmamış dersi bul
      int targetIndex = 0;
      for (int i = 0; i < lessons.length; i++) {
        final lessonId = lessons[i]['id'] as int? ?? 0;
        if (_progress[lessonId] != true) {
          targetIndex = i;
          break;
        }
        // Hepsi tamamlandıysa son dersi aç
        targetIndex = lessons.length - 1;
      }
      _openLesson(targetIndex);
    }
  } catch (e) {
    debugPrint('❌ Error starting course: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error starting course: $e')));
  }
}

  // ── Progress helpers ──────────────────────────────────────────────────────
  int get _completedCount => _progress.values.where((v) => v).length;

  double get _progressPercent {
    if (lessons.isEmpty) return 0;
    return (_completedCount / lessons.length) * 100;
  }

  bool _canOpenLesson(int index) {
    if (index == 0) return true;
    final previousLessonId = lessons[index - 1]['id'] as int? ?? 0;
    return _progress[previousLessonId] == true;
  }

  // ── Open lesson ───────────────────────────────────────────────────────────
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

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonVideoPlayerScreen(
          title: title,
          videoUrl: videoUrl,
          startAtSeconds: _watchedSeconds[lessonId] ?? 0,
        ),
      ),
    );

    if (result == null) return;

    final completed = result['completed'] == true;
    final watchedSeconds =
        int.tryParse(result['watched_seconds'].toString()) ?? 0;

    await _saveLessonProgress(
      lessonId,
      completed: completed,
      watchedSeconds: watchedSeconds,
    );

    setState(() {
      _watchedSeconds[lessonId] = watchedSeconds;

      if (completed) {
        _progress[lessonId] = true;
        _courseStarted = true;
      }
    });

    if (completed) {
      final completedLessons = _progress.values.where((v) => v).length;

      if (completedLessons >= lessons.length) {
        await _giveCompletionReward();
      }

      final nextIndex = index + 1;
      if (mounted && nextIndex < lessons.length) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _openLesson(nextIndex);
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C94C6)),
        ),
      );
    }

    if (course == null) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Text(
            'Course not found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final title = course!['title']?.toString() ?? '';
    final imageUrl = course!['image_url']?.toString() ?? '';
    final instructorName = course!['instructor_name']?.toString() ?? '';
    final instructorImage = course!['instructor_image']?.toString() ?? '';
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
                        errorWidget: (c, u, e) => const Icon(
                          Icons.play_circle,
                          size: 80,
                          color: Colors.white54,
                        ),
                        placeholder: (c, u) => Shimmer.fromColors(
                          baseColor: const Color(0xFF1A2F55),
                          highlightColor: const Color(0xFF2A4A7F),
                          child: Container(height: 250, color: Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.play_circle,
                        size: 80,
                        color: Colors.white54,
                      ),
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
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
              ),
              if (_currentUser != null &&
    (_currentUser!['username'] == course!['instructor_name'] ||
        _currentUser!['role'] == 'admin'))
  Positioned(
    top: 40,
    right: 64, // <-- edit butonu için yer aç
    child: GestureDetector(
      onTap: _showEditDialog,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFF4A6FA5),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    ),
  ),
if (_currentUser != null &&
    (_currentUser!['username'] == course!['instructor_name'] ||
        _currentUser!['role'] == 'admin'))
  Positioned(
    top: 40,
    right: 16,
    child: GestureDetector(
      onTap: _confirmDeleteCourse,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.delete, color: Colors.white),
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
                          onTap: _courseStarted ? _resumeCourse : _startCourse,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _courseStarted
                                      ? Icons.percent
                                      : Icons.play_arrow,
                                  color: AppColors.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _courseStarted
                                      ? 'Progress ${_progressPercent.toStringAsFixed(0)}%'
                                      : 'Start',
                                  style: GoogleFonts.agbalumo(
                                    color: AppColors.accent,
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
                    child: GestureDetector(
                      onTap: _openInstructorProfile,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: instructorImage.isNotEmpty
                                ? NetworkImage(instructorImage)
                                : null,
                            backgroundColor: const Color(0xFF2A4A6F),
                            child: instructorImage.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.white,
                                  )
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
                          const Icon(
                            Icons.ondemand_video,
                            color: Color(0xFF2C3E50),
                            size: 19,
                          ),
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
                                  index < selectedRating
                                      ? Icons.star
                                      : Icons.star_border,
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
                            onTap: _toggleLike,
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isLiked ? Colors.red : Colors.black,
                                  size: 18,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${course!['likes'] ?? 0}',
                                  style: GoogleFonts.agbalumo(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
                  ),
                  if (lessons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: LinearProgressIndicator(
                        value: _completedCount / lessons.length,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: lessons.isEmpty
                        ? const Center(
                            child: Text(
                              'No lessons yet',
                              style: TextStyle(color: Colors.white54),
                            ),
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
                  ? AppColors.accent
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

// ══════════════════════════════════════════════════════════════
// Lesson Video Player
// ══════════════════════════════════════════════════════════════

class LessonVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String videoUrl;

  final int startAtSeconds;

  const LessonVideoPlayerScreen({
    super.key,
    required this.title,
    required this.videoUrl,
    this.startAtSeconds = 0,
  });

  @override
  State<LessonVideoPlayerScreen> createState() =>
      _LessonVideoPlayerScreenState();
}

class _LessonVideoPlayerScreenState extends State<LessonVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) async {
        if (!mounted) return;

        if (widget.startAtSeconds > 0) {
          await _controller.seekTo(Duration(seconds: widget.startAtSeconds));
        }

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
      Navigator.pop(context, {
        'completed': true,
        'watched_seconds': duration.inSeconds,
      });
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
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.accent),
          onPressed: () {
            final seconds = _controller.value.isInitialized
                ? _controller.value.position.inSeconds
                : 0;

            Navigator.pop(context, {
              'completed': false,
              'watched_seconds': seconds,
            });
          },
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.agbalumo(color: AppColors.accent),
          overflow: TextOverflow.ellipsis,
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
                        playedColor: AppColors.accent,
                        bufferedColor: Colors.white54,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Center(
                      child: IconButton(
                        iconSize: 64,
                        color: AppColors.accent,
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
