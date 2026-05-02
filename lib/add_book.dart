import 'dart:io';

import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:file_picker/file_picker.dart';

class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final _bookUrlController = TextEditingController();
  File? _selectedBookFile;

  bool _isLoading = false;
  File? _selectedImage;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    super.dispose();  
    _bookUrlController.dispose();
  }
  Future<void> _pickBookFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (result == null || result.files.single.path == null) return;

  setState(() {
    _selectedBookFile = File(result.files.single.path!);
  });
}
Future<String?> _uploadBookFile() async {
  if (_selectedBookFile == null) return null;

  final username = await SessionManager.getUsername() ?? 'user';
  final fileName =
      '${DateTime.now().millisecondsSinceEpoch}_$username.pdf';

  final filePath = 'book-files/$fileName';

  await _supabase.storage.from('books').upload(
        filePath,
        _selectedBookFile!,
        fileOptions: const FileOptions(upsert: true),
      );

  return _supabase.storage.from('books').getPublicUrl(filePath);
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

    final username = await SessionManager.getUsername() ?? 'user';
    final fileExt = path.extension(_selectedImage!.path);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$username$fileExt';

    final filePath = 'book-images/$fileName';

    await _supabase.storage.from('books').upload(
          filePath,
          _selectedImage!,
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage.from('books').getPublicUrl(filePath);
  }

  Future<void> _submitBook() async {
    final username = await SessionManager.getUsername();
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    final description = _descriptionController.text.trim();
    final bookUrl = _bookUrlController.text.trim();
    

    if (bookUrl.isEmpty && _selectedBookFile == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please add a book link or PDF file')),
  );
  return;
}

    setState(() => _isLoading = true);

    try {
      final imageUrl = await _uploadImage();
      final uploadedBookUrl = await _uploadBookFile();
      final finalBookUrl = uploadedBookUrl ?? bookUrl;
      final username = await SessionManager.getUsername();

      await _supabase.from('books').insert({
        'title': title,
        'author': author,
        'description': description.isEmpty ? null : description,
        'image_url': imageUrl,
        'author_username': username,
        'book_url': finalBookUrl,
        'author_username': username,
});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book added!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error adding book: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add book')),
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
          'New Book',
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3C39D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
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
                      'Save',
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
            _label('Book Title'),
            const SizedBox(height: 8),
            _field(
              controller: _titleController,
              hint: 'Book title',
              maxLines: 1,
            ),

            const SizedBox(height: 16),

    

            

            _label('Description (optional)'),
            const SizedBox(height: 8),
            _field(
              controller: _descriptionController,
              hint: 'Short description...',
              maxLines: 4,
            ),
            const SizedBox(height: 16),

_label('Book Link or PDF File'),
const SizedBox(height: 8),

_field(
  controller: _bookUrlController,
  hint: 'https://example.com/book.pdf',
  maxLines: 1,
),

const SizedBox(height: 8),

GestureDetector(
  onTap: _pickBookFile,
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
            _selectedBookFile == null
                ? 'Choose PDF file'
                : 'PDF file selected',
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
                height: 190,
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
                          Icon(Icons.add_photo_alternate,
                              size: 42, color: Colors.black54),
                          SizedBox(height: 8),
                          Text(
                            'Tap to choose cover image',
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
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.agbalumo(
        color: const Color(0xFF6C94C6),
        fontSize: 16,
      ),
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