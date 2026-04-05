import 'dart:convert';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  Map<String, dynamic>? user;

  // Fixed: only courses this student has progress in
  List<dynamic> myCourses = [];

  bool isLoading = true;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final token = await SessionManager.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final headers = {'Authorization': 'Bearer $token'};

      // Parallel requests
      final results = await Future.wait([
        http.get(Uri.parse('${AppConstants.baseUrl}/profile/me'), headers: headers),
        // Fixed: use /profile/my-courses instead of fetching all courses
        http.get(Uri.parse('${AppConstants.baseUrl}/profile/my-courses'), headers: headers),
      ]);

      final profileRes = results[0];
      final coursesRes = results[1];

      if (profileRes.statusCode != 200) throw Exception('Failed to load profile');

      final userRes = jsonDecode(profileRes.body) as Map<String, dynamic>;
      final coursesData = coursesRes.statusCode == 200
          ? jsonDecode(coursesRes.body) as List<dynamic>
          : <dynamic>[];

      if (!mounted) return;
      setState(() {
        user = userRes;
        myCourses = coursesData;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void showEditDialog() {
    final bioController = TextEditingController(text: user?['bio'] ?? '');
    final imageController = TextEditingController(text: user?['profile_image'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF071739),
        title: Text('Edit Profile',
            style: GoogleFonts.agbalumo(color: const Color(0xFFE3C39D))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(bioController, 'Bio', maxLines: 3),
            const SizedBox(height: 12),
            _dialogField(imageController, 'Profile Image URL'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              try {
                final token = await SessionManager.getToken();
                if (token == null || token.isEmpty) return;
                await http.put(
                  Uri.parse('${AppConstants.baseUrl}/profile/me'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'bio': bioController.text,
                    'profile_image': imageController.text,
                  }),
                );
                if (!mounted) return;
                Navigator.pop(context);
                loadProfile();
              } catch (e) {
                debugPrint('❌ Error updating profile: $e');
              }
            },
            child: Text('Save',
                style: GoogleFonts.agbalumo(color: const Color(0xFFE3C39D))),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFE3C39D), borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF071739),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C94C6))),
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
            // Header
            Container(
              color: const Color(0xFF8B6F47),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(
                          color: Color(0xFFE3C39D), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back, color: Colors.black, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(username,
                      style: GoogleFonts.agbalumo(
                          color: const Color(0xFFE3C39D), fontSize: 22)),
                  const Spacer(),
                  GestureDetector(
                    onTap: showEditDialog,
                    child: const Icon(Icons.edit, color: Color(0xFFE3C39D)),
                  ),
                ],
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -50),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundImage:
                        profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                    backgroundColor: const Color(0xFF4A6FA5),
                    child: profileImage.isEmpty
                        ? const Icon(Icons.person, size: 55, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(username,
                      style: GoogleFonts.agbalumo(
                          color: const Color(0xFFE3C39D), fontSize: 22)),
                ],
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statColumn('Courses', '${myCourses.length}'),
                    _statColumn('Points', '$points'),
                  ],
                ),
              ),
            ),

            if (bio.isNotEmpty)
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Bio — $bio',
                        style: GoogleFonts.agbalumo(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ),

            const Divider(color: Colors.white24),

            Row(children: [
              _tab('My Courses', 0),
              _tab('Questions', 1),
              _tab('Saved', 2),
            ]),
            const Divider(color: Colors.white24, height: 1),

            Expanded(
              child: selectedTab == 0
                  ? _buildCoursesList()
                  : const Center(
                      child: Text('Coming soon…', style: TextStyle(color: Colors.white54))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
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
                  color: isSelected ? const Color(0xFFE3C39D) : Colors.transparent, width: 2),
            ),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.agbalumo(
                    color: isSelected ? const Color(0xFFE3C39D) : Colors.white54, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildCoursesList() {
    if (myCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_outlined, color: Colors.white24, size: 60),
            const SizedBox(height: 16),
            const Text('No courses started yet',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Start watching lessons to track your progress',
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: const Color(0xFFD8C09A), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        width: 90, height: 80, fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                            width: 90, height: 80,
                            color: const Color(0xFF4A6FA5),
                            child: const Icon(Icons.play_circle, color: Colors.white54)))
                    : Container(
                        width: 90, height: 80,
                        color: const Color(0xFF4A6FA5),
                        child: const Icon(Icons.play_circle, color: Colors.white54)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
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
                          Text(instructor, style: GoogleFonts.agbalumo(fontSize: 12)),
                          const Spacer(),
                          const Icon(Icons.star, color: Colors.orange, size: 14),
                          Text(rating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}