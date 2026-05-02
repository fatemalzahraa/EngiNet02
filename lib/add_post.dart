import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/session_manager.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _supabase = Supabase.instance.client;
  final _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _courses = [];
  int? _selectedCourseId;
  String _selectedCategory = 'bilgi';
  bool _isLoading = false;
  bool _loadingCourses = true;

  File? _selectedImage;

  final List<String> _categories = ['bilgi', 'soru', 'ipucu', 'egitim', 'duyuru'];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await _supabase
          .from('courses')
          .select('id, title')
          .order('title', ascending: true);

      if (!mounted) return;
      setState(() {
        _courses = courses;
        _loadingCourses = false;
      });
    } catch (e) {
      debugPrint('Error loading courses: $e');
      if (!mounted) return;
      setState(() => _loadingCourses = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final username = await SessionManager.getUsername() ?? 'user';
      final fileExt = path.extension(_selectedImage!.path);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$username$fileExt';
      final filePath = 'post-images/$fileName';

      await _supabase.storage.from('posts').upload(
            filePath,
            _selectedImage!,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl =
          _supabase.storage.from('posts').getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  Future<void> _submitPost() async {
     if (_contentController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please write something')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final email = await SessionManager.getEmail();
    final username = await SessionManager.getUsername();
    final imageUrl = await _uploadImage();

  final insertedPost = await _supabase
    .from('posts')
    .insert({
      'username': username,
      'content': _contentController.text.trim(),
      'image_url': imageUrl,
      'linked_course_id': _selectedCourseId,
      'category': _selectedCategory,
      'likes': 0,
    })
    .select('id')
    .single();

final postId = insertedPost['id'];

    final currentUser = await _supabase
        .from('users')
        .select('id, username, role')
        .eq('email', email ?? '')
        .single();

    if (currentUser['role'] == 'engineer') {
      final followers = await _supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', currentUser['id']);
if (followers.isNotEmpty) {
  final notifications = (followers as List)
      .map((f) => {
            'user_id': f['follower_id'],
            'message': '${currentUser['username']} shared a new post.',
            'is_read': 0,
            'post_id': postId,
          })
      .toList();

  await _supabase.from('notifications').insert(notifications);
}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post published!')),
    );
    Navigator.pop(context, true);
  } catch (e) {
    debugPrint('Error posting: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to publish post')),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFE3C39D),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 18),
          ),
        ),
        title: Text(
          'New Post',
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3C39D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      'Publish',
                      style: GoogleFonts.agbalumo(fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFD8C09A),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _contentController,
                maxLines: 6,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'What\'s on your mind?',
                  hintStyle: TextStyle(color: Colors.black38),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Image (optional)',
              style: GoogleFonts.agbalumo(
                color: const Color(0xFF6C94C6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8C09A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 40, color: Colors.black54),
                          SizedBox(height: 8),
                          Text(
                            'Tap to choose image',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
              ),
            ),

            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                  });
                },
                child: const Text(
                  'Remove image',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Text(
              'Category',
              style: GoogleFonts.agbalumo(
                color: const Color(0xFF6C94C6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE3C39D)
                          : const Color(0xFF1A2F55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE3C39D),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Text(
              'Link a Course (optional)',
              style: GoogleFonts.agbalumo(
                color: const Color(0xFF6C94C6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _loadingCourses
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6C94C6),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8C09A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedCourseId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFFD8C09A),
                        hint: const Text(
                          'Select a course',
                          style: TextStyle(color: Colors.black45),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'None',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          ..._courses.map(
                            (course) => DropdownMenuItem<int?>(
                              value: course['id'] as int?,
                              child: Text(
                                course['title']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedCourseId = val),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}