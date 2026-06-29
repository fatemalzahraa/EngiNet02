import 'package:path/path.dart' as path;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:enginet/core/app_colors.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _supabase = Supabase.instance.client;
  final _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Linked item state
  List<dynamic> _courses = [];
  List<dynamic> _books = [];
  List<dynamic> _articles = [];

  int? _selectedCourseId;
  int? _selectedBookId;
  int? _selectedArticleId;

  bool _isLoading = false;
  bool _loadingItems = true;

  File? _selectedImage;

  // Which type is selected
  String _linkedType = 'none'; // 'none' | 'course' | 'book' | 'article'

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final courses = await _supabase
          .from('courses')
          .select('id, title')
          .order('title', ascending: true);

      final books = await _supabase
          .from('books')
          .select('id, title')
          .order('title', ascending: true);

      final articles = await _supabase
          .from('articles')
          .select('id, title')
          .order('title', ascending: true);

      if (!mounted) return;
      setState(() {
        _courses = courses;
        _books = books;
        _articles = articles;
        _loadingItems = false;
      });
    } catch (e) {
      debugPrint('Error loading items: $e');
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile == null) return;
      setState(() => _selectedImage = File(pickedFile.path));
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to pick image')));
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

      return _supabase.storage.from('posts').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please write something')));
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
            'linked_course_id':
                _linkedType == 'course' ? _selectedCourseId : null,
            'linked_book_id':
                _linkedType == 'book' ? _selectedBookId : null,
            'linked_article_id':
                _linkedType == 'article' ? _selectedArticleId : null,
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
                    'message':
                        '${currentUser['username']} shared a new post.',
                    'is_read': 0,
                    'post_id': postId,
                  })
              .toList();
          await _supabase.from('notifications').insert(notifications);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Post published!')));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error posting: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to publish post')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.arrow_back, color: Colors.black, size: 18),
          ),
        ),
        title: Text(
          'New Post',
          style: GoogleFonts.agbalumo(color: AppColors.accent, fontSize: 22),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : Text('Publish',
                      style: GoogleFonts.agbalumo(fontSize: 14)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Content ──
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFD8C09A),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _contentController,
                maxLines: 6,
                style:
                    const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'What\'s on your mind?',
                  hintStyle: TextStyle(color: Colors.black38),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Image ──
            Text(
              'Image (optional)',
              style: GoogleFonts.agbalumo(
                  color: const Color(0xFF6C94C6), fontSize: 16),
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
                        child: Image.file(_selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 40, color: Colors.black54),
                          SizedBox(height: 8),
                          Text('Tap to choose image',
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
              ),
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _selectedImage = null),
                child: const Text('Remove image',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],

            const SizedBox(height: 16),

            // ── Link type selector ──
            Text(
              'Link a Course / Book / Article (optional)',
              style: GoogleFonts.agbalumo(
                  color: const Color(0xFF6C94C6), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip('None', 'none'),
                const SizedBox(width: 8),
                _typeChip('Course', 'course'),
                const SizedBox(width: 8),
                _typeChip('Book', 'book'),
                const SizedBox(width: 8),
                _typeChip('Article', 'article'),
              ],
            ),
            const SizedBox(height: 12),

            // ── Dropdown based on type ──
            if (_linkedType != 'none')
              _loadingItems
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C94C6)))
                  : _buildDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String label, String value) {
    final isSelected = _linkedType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _linkedType = value;
        _selectedCourseId = null;
        _selectedBookId = null;
        _selectedArticleId = null;
      }),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : const Color(0xFF1A2F55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    List<dynamic> items;
    int? selectedId;
    void Function(int?) onChanged;
    IconData icon;

    switch (_linkedType) {
      case 'course':
        items = _courses;
        selectedId = _selectedCourseId;
        onChanged = (val) => setState(() => _selectedCourseId = val);
        icon = Icons.play_circle;
        break;
      case 'book':
        items = _books;
        selectedId = _selectedBookId;
        onChanged = (val) => setState(() => _selectedBookId = val);
        icon = Icons.menu_book;
        break;
      case 'article':
        items = _articles;
        selectedId = _selectedArticleId;
        onChanged = (val) => setState(() => _selectedArticleId = val);
        icon = Icons.article;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD8C09A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedId,
          isExpanded: true,
          dropdownColor: const Color(0xFFD8C09A),
          hint: Row(
            children: [
              Icon(icon, size: 18, color: Colors.black45),
              const SizedBox(width: 8),
              const Text('Select...',
                  style: TextStyle(color: Colors.black45)),
            ],
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child:
                  Text('None', style: TextStyle(color: Colors.black54)),
            ),
            ...items.map(
              (item) => DropdownMenuItem<int?>(
                value: item['id'] as int?,
                child: Text(
                  item['title']?.toString() ?? '',
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}