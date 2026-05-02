import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:enginet/following_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:enginet/book_detail.dart';
import 'package:enginet/saved_books_screen.dart';
import 'package:enginet/article_detail.dart';
import 'package:enginet/course_details.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? user;
  List<dynamic> myCourses = [];
  bool isLoading = true;
  int selectedTab = 0;
  final ImagePicker _picker = ImagePicker();
  int followingCount = 0;
  List<dynamic> followingEngineers = [];
  List<dynamic> savedBooks = [];
  List<dynamic> savedArticles = [];

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  // ─── Pick & upload profile image ─────────────────────────────────────────
  Future<String?> _pickAndUploadProfileImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile == null) return null;

    final file = File(pickedFile.path);
    final username = await SessionManager.getUsername() ?? 'user';
    final fileExt = path.extension(file.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$username$fileExt';
    final filePath = 'profile-images/$fileName';

    await _supabase.storage.from('profiles').upload(
          filePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage.from('profiles').getPublicUrl(filePath);
  }

  // ─── Load profile ─────────────────────────────────────────────────────────
  Future<void> loadProfile() async {
    try {
      final email = await SessionManager.getEmail();
      if (email == null || email.isEmpty) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final userRes = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .single();

      final userId = userRes['id'];

      final followingRes = await _supabase
          .from('follows')
          .select(
              'following_id, users!follows_following_id_fkey(id, username, profile_image, role, bio)')
          .eq('follower_id', userId);

      final savedRes = await _supabase
          .from('bookmarks')
          .select('books(*)')
          .eq('user_id', userId);

      final savedArticlesRes = await _supabase
          .from('article_bookmarks')
          .select('articles(*)')
          .eq('user_id', userId);

      final engineersOnly = (followingRes as List)
          .where((f) => f['users'] != null && f['users']['role'] == 'engineer')
          .toList();

      final startedCoursesRes = await _supabase
          .from('student_courses')
          .select('courses(*)')
          .eq('user_id', userId);

      final uniqueCourses = <dynamic>[];

      for (final row in startedCoursesRes) {
        final course = row['courses'];
        if (course == null) continue;

        final courseId = course['id'];

        final lessonsRes = await _supabase
            .from('lessons')
            .select('id')
            .eq('course_id', courseId);

        final lessonIds = (lessonsRes as List).map((e) => e['id']).toList();

        int completedCount = 0;

        if (lessonIds.isNotEmpty) {
          final progressRes = await _supabase
              .from('lesson_progress')
              .select('id')
              .eq('user_id', userId)
              .eq('is_completed', true)
              .inFilter('lesson_id', lessonIds);

          completedCount = (progressRes as List).length;
        }

        final totalLessons = lessonIds.length;
        final progressPercent = totalLessons == 0
            ? 0
            : ((completedCount / totalLessons) * 100).round();

        uniqueCourses.add({
          ...course,
          'progress_percent': progressPercent,
          'is_finished': totalLessons > 0 && completedCount == totalLessons,
        });
      }

      if (!mounted) return;
      setState(() {
        user = userRes;
        myCourses = uniqueCourses;
        isLoading = false;
        followingCount = engineersOnly.length;
        followingEngineers = engineersOnly;
        savedBooks = (savedRes as List)
            .map((e) => e['books'])
            .where((e) => e != null)
            .toList();
        savedArticles = (savedArticlesRes as List)
            .map((e) => e['articles'])
            .where((e) => e != null)
            .toList();
      });
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ─── Edit dialog ──────────────────────────────────────────────────────────
  void showEditDialog() {
    final bioController = TextEditingController(text: user?['bio'] ?? '');
    String? tempSelectedImageUrl;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF071739),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.agbalumo(color: const Color(0xFFE3C39D)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(bioController, 'Bio', maxLines: 3),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final imageUrl = await _pickAndUploadProfileImage();
                if (imageUrl == null) return;
                tempSelectedImageUrl = imageUrl;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Image selected. Press Save to update.'),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3C39D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.image, color: Colors.black54),
                    SizedBox(width: 10),
                    Text('Choose profile image',
                        style: TextStyle(color: Colors.black87)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final email = await SessionManager.getEmail();
              if (email == null) return;

              final updateData = {'bio': bioController.text};
              if (tempSelectedImageUrl != null) {
                updateData['profile_image'] = tempSelectedImageUrl!;
              }

              await _supabase
                  .from('users')
                  .update(updateData)
                  .eq('email', email);

              if (!mounted) return;
              Navigator.pop(dialogContext);
              loadProfile();
            },
            child: Text('Save',
                style:
                    GoogleFonts.agbalumo(color: const Color(0xFFE3C39D))),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFE3C39D),
          borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration:
            InputDecoration(border: InputBorder.none, hintText: hint),
      ),
    );
  }

  // ─── Section header ───────────────────────────────────────────────────────
  Widget _sectionHeader({required String title, VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE3C39D),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'See more >',
              style: TextStyle(
                color: Color(0xFFE3C39D),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Horizontal book list ─────────────────────────────────────────────────
  Widget _horizontalList(List books) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    BookDetailScreen(bookId: book['id'].toString()),
              ),
            ),
            child: Container(
              width: 125,
              margin: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8C09A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: (book['image_url'] ?? '').toString().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: book['image_url'],
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.book, size: 50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE3C39D),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Horizontal article list ──────────────────────────────────────────────
  Widget _horizontalArticleList(List articles) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArticleDetailScreen(
                    articleId: article['id'].toString()),
              ),
            ),
            child: Container(
              width: 125,
              margin: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8C09A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: (article['image_url'] ?? '')
                              .toString()
                              .isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: article['image_url'],
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.article, size: 50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE3C39D),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Saved tab ────────────────────────────────────────────────────────────
  Widget _buildSavedBooks() {
    if (savedBooks.isEmpty && savedArticles.isEmpty) {
      return const Center(
        child: Text('No saved items',
            style: TextStyle(color: Colors.white54)),
      );
    }

    final firstThreeBooks = savedBooks.take(3).toList();
    final firstThreeArticles = savedArticles.take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(
          title: 'Books',
          onTap: savedBooks.length > 3
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SavedBooksScreen(books: savedBooks),
                    ),
                  )
              : null,
        ),
        const SizedBox(height: 16),
        savedBooks.isEmpty
            ? const Text('No saved books yet',
                style: TextStyle(color: Colors.white54))
            : _horizontalList(firstThreeBooks),
        const SizedBox(height: 30),
        _sectionHeader(title: 'Articles'),
        const SizedBox(height: 16),
        savedArticles.isEmpty
            ? const Text('No saved articles yet',
                style: TextStyle(color: Colors.white54))
            : _horizontalArticleList(firstThreeArticles),
        const SizedBox(height: 30),
        _sectionHeader(title: 'Questions'),
        const SizedBox(height: 12),
        const Text('No saved questions yet',
            style: TextStyle(color: Colors.white54)),
      ],
    );
  }

  // ─── Courses tab ──────────────────────────────────────────────────────────
  Widget _buildCoursesList() {
    if (myCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.school_outlined, color: Colors.white24, size: 60),
            SizedBox(height: 16),
            Text('No courses started yet',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 8),
            Text('Start watching lessons to track your progress',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myCourses.length,
      itemBuilder: (context, index) {
        final course = myCourses[index];
        final imageUrl = course['image_url'] ?? '';
        final title = course['title'] ?? '';
        final instructor = course['instructor_name'] ?? '';
        final instructorImage = course['instructor_image'] ?? '';
        final rating = (course['rating'] ?? 0.0).toDouble();
        final progressPercent = course['progress_percent'] ?? 0;
        final isFinished = course['is_finished'] == true;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(
                courseId: course['id'].toString(),
              ),
            ),
          ).then((_) => loadProfile()),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD8C09A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // ── Course thumbnail ─────────────────────────────
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 90,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Shimmer.fromColors(
                            baseColor: const Color(0xFF1A2F55),
                            highlightColor: const Color(0xFF2A4A7F),
                            child: Container(
                                width: 90,
                                height: 80,
                                color: Colors.white),
                          ),
                          errorWidget: (c, u, e) => Container(
                            width: 90,
                            height: 80,
                            color: const Color(0xFF4A6FA5),
                            child: const Icon(Icons.play_circle,
                                color: Colors.white54),
                          ),
                        )
                      : Container(
                          width: 90,
                          height: 80,
                          color: const Color(0xFF4A6FA5),
                          child: const Icon(Icons.play_circle,
                              color: Colors.white54),
                        ),
                ),

                // ── Course info ──────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
  children: [
    Expanded(
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const SizedBox(width: 8),
    isFinished
        ? Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          )
        : Text(
            '$progressPercent%',
            style: const TextStyle(
              color: Color(0xFF4A6FA5),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
  ],
),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: instructorImage.isNotEmpty
                                  ? NetworkImage(instructorImage)
                                  : null,
                              backgroundColor: const Color(0xFF4A6FA5),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                instructor,
                                style: GoogleFonts.agbalumo(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.star,
                                color: Colors.orange, size: 14),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12),
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
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF071739),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6C94C6))),
      );
    }

    final username = user?['username'] ?? '';
    final bio = user?['bio'] ?? '';
    final profileImage = user?['profile_image'] ?? '';
    final points = user?['points'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────
            Container(
              color: const Color(0xFF8B6F47),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: Color(0xFFE3C39D),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.black, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    username,
                    style: GoogleFonts.agbalumo(
                        color: const Color(0xFFE3C39D), fontSize: 22),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: showEditDialog,
                    child:
                        const Icon(Icons.edit, color: Color(0xFFE3C39D)),
                  ),
                ],
              ),
            ),

            // ── Avatar ───────────────────────────────────────────
            Transform.translate(
              offset: const Offset(0, -50),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: profileImage.isNotEmpty
                        ? NetworkImage(profileImage)
                        : null,
                    backgroundColor: const Color(0xFF4A6FA5),
                    child: profileImage.isEmpty
                        ? const Icon(Icons.person,
                            size: 55, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    username,
                    style: GoogleFonts.agbalumo(
                        color: const Color(0xFFE3C39D), fontSize: 22),
                  ),
                ],
              ),
            ),

            // ── Stats row ────────────────────────────────────────
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowingScreen(
                              following: followingEngineers),
                        ),
                      ),
                      child: _statColumn('Following', '$followingCount'),
                    ),
                    _statColumn('Points', '$points'),
                  ],
                ),
              ),
            ),

            // ── Bio ──────────────────────────────────────────────
            if (bio.isNotEmpty)
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bio — $bio',
                      style: GoogleFonts.agbalumo(
                          color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),

            const Divider(color: Colors.white24),

            // ── Tabs ─────────────────────────────────────────────
            Row(children: [
              _tab('My Courses', 0),
              _tab('Questions', 1),
              _tab('Saved', 2),
            ]),
            const Divider(color: Colors.white24, height: 1),

            // ── Tab content ──────────────────────────────────────
            Expanded(
              child: selectedTab == 0
                  ? _buildCoursesList()
                  : selectedTab == 2
                      ? _buildSavedBooks()
                      : const Center(
                          child: Text('Coming soon…',
                              style: TextStyle(color: Colors.white54)),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Small helpers ────────────────────────────────────────────────────────
  Widget _statColumn(String label, String value) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ],
      );

  Widget _tab(String label, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFFE3C39D)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.agbalumo(
                color: isSelected
                    ? const Color(0xFFE3C39D)
                    : Colors.white54,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}