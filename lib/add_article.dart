import 'dart:io';

import 'package:enginet/core/session_manager.dart';
import 'package:enginet/points_helper.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

class AddArticleScreen extends StatefulWidget {
 final Map<String, dynamic>? article;
  const AddArticleScreen({super.key,this.article });

  @override
  State<AddArticleScreen> createState() => _AddArticleScreenState();
}

class _AddArticleScreenState extends State<AddArticleScreen> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool get isEditMode => widget.article != null;

  String? _selectedCategory;
  File? _selectedImage;
  File? _selectedPdf;
  bool _isLoading = false;

  final List<String> _categories = [
    'Programming',
    'Civil Engineering',
    'Mechanical Engineering',
    'Electrical Engineering',
    'Mathematics',
    'Physics',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  @override
void initState() {
  super.initState();

  if (isEditMode) {
    _titleController.text = widget.article!['title'] ?? '';
    _contentController.text = widget.article!['content'] ?? '';
    _selectedCategory = widget.article!['category'];
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => _selectedPdf = File(result.files.single.path!));
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;
    final username = await SessionManager.getUsername() ?? 'user';
    final fileExt = path.extension(_selectedImage!.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$username$fileExt';
    final filePath = 'article-images/$fileName';
    await _supabase.storage.from('articles').upload(
          filePath,
          _selectedImage!,
          fileOptions: const FileOptions(upsert: true),
        );
    return _supabase.storage.from('articles').getPublicUrl(filePath);
  }

  Future<String?> _uploadPdf() async {
    if (_selectedPdf == null) return null;
    final username = await SessionManager.getUsername() ?? 'user';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$username.pdf';
    final filePath = 'article-pdfs/$fileName';
    await _supabase.storage.from('articles').upload(
          filePath,
          _selectedPdf!,
          fileOptions: const FileOptions(upsert: true),
        );
    return _supabase.storage.from('articles').getPublicUrl(filePath);
  }

  Future<void> _submitArticle() async {
  final title = _titleController.text.trim();
  final content = _contentController.text.trim();

  if (title.isEmpty || content.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill title and content')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final imageUrl = await _uploadImage();
    final pdfUrl = await _uploadPdf();

    if (isEditMode) {
      await _supabase.from('articles').update({
        'title': title,
        'content': content,
        'category': _selectedCategory,
        if (imageUrl != null) 'image_url': imageUrl,
        if (pdfUrl != null) 'pdf_url': pdfUrl,
      }).eq('id', widget.article!['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article updated!')),
      );
      Navigator.pop(context, true);
      return;
    }

    final username = await SessionManager.getUsername();

    await _supabase.from('articles').insert({
      'title': title,
      'content': content,
      'author_name': username?.toString().trim(),
      'image_url': imageUrl,
      'category': _selectedCategory,
      'pdf_url': pdfUrl,
    });

    final email = await SessionManager.getEmail();
    final userData = await _supabase
        .from('users')
        .select('id')
        .eq('email', email!)
        .single();

    await addPoints(userData['id'], 5);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Article published!')),
    );
    Navigator.pop(context, true);
  } catch (e) {
    debugPrint('Error submitting article: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditMode ? 'Failed to update article' : 'Failed to publish article',
        ),
      ),
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
  isEditMode ? 'Edit Article' : 'New Article',
  style: GoogleFonts.agbalumo(
    color: const Color(0xFFE3C39D),
    fontSize: 22,
  ),
),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitArticle,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3C39D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
    isEditMode ? 'Update' : 'Publish',
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
            _label('Title *'),
            const SizedBox(height: 8),
            _field(controller: _titleController, hint: 'Article title', maxLines: 1),

            const SizedBox(height: 16),
            _label('Category'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFD8C09A),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  hint: const Text('Select category', style: TextStyle(color: Colors.black38)),
                  isExpanded: true,
                  dropdownColor: const Color(0xFFD8C09A),
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
              ),
            ),

            const SizedBox(height: 16),
            _label('Content *'),
            const SizedBox(height: 8),
            _field(controller: _contentController, hint: 'Write your article...', maxLines: 10),

            const SizedBox(height: 16),
            _label('PDF File (optional)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickPdf,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8C09A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.black54),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedPdf == null ? 'Choose PDF file' : 'PDF file selected ✓',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            _label('Cover Image (optional)'),
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
                        child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 42, color: Colors.black54),
                          SizedBox(height: 8),
                          Text('Tap to choose image', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
              ),
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _selectedImage = null),
                child: const Text('Remove image', style: TextStyle(color: Colors.redAccent)),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.agbalumo(color: const Color(0xFF6C94C6), fontSize: 16),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD8C09A),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38),
        ),
      ),
    );
  }
}