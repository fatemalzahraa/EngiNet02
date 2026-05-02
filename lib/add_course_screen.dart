import 'dart:io';

import 'package:enginet/core/session_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final supabase = Supabase.instance.client;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  File? courseImage;
  String? courseImageName;

  bool isSaving = false;

  List<VideoInput> videos = [VideoInput()];

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    for (final v in videos) {
      v.titleController.dispose();
    }
    super.dispose();
  }

  Future<void> pickCourseImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        courseImage = File(result.files.single.path!);
        courseImageName = result.files.single.name;
      });
    }
  }

  Future<void> pickVideo(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        videos[index].videoFile = File(result.files.single.path!);
        videos[index].videoName = result.files.single.name;
      });
    }
  }

  void addVideoField() {
    setState(() {
      videos.add(VideoInput());
    });
  }

  void removeVideoField(int index) {
    if (videos.length == 1) return;

    setState(() {
      videos[index].titleController.dispose();
      videos.removeAt(index);
    });
  }

  Future<String> uploadFile({
    required String bucket,
    required File file,
    required String fileName,
  }) async {
    final safeName = fileName.replaceAll(' ', '_');
    final path = '${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await supabase.storage.from(bucket).upload(path, file);

    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  Future<Map<String, dynamic>> getCurrentEngineerData() async {
    final username = await SessionManager.getUsername();

    if (username == null || username.isEmpty) {
      throw Exception('User not logged in');
    }

    final userData = await supabase
        .from('users')
        .select('username, profile_image')
        .eq('username', username)
        .maybeSingle();

    return {
      'username': userData?['username'] ?? username,
      'profile_image': userData?['profile_image'] ?? '',
    };
  }

  Future<void> saveCourse() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      showMessage('Please enter course title');
      return;
    }

    if (description.isEmpty) {
      showMessage('Please enter course description');
      return;
    }

    if (courseImage == null) {
      showMessage('Please choose course image');
      return;
    }

    for (int i = 0; i < videos.length; i++) {
      if (videos[i].titleController.text.trim().isEmpty) {
        showMessage('Please enter title for video ${i + 1}');
        return;
      }

      if (videos[i].videoFile == null) {
        showMessage('Please choose video ${i + 1}');
        return;
      }
    }

    setState(() => isSaving = true);

    try {
      final engineer = await getCurrentEngineerData();

      final imageUrl = await uploadFile(
        bucket: 'course-images',
        file: courseImage!,
        fileName: courseImageName ?? 'course_image.jpg',
      );

      final course = await supabase
          .from('courses')
          .insert({
            'title': title,
            'description': description,
            'image_url': imageUrl,
            'instructor_name': engineer['username'],
            'instructor_image': engineer['profile_image'],
            'duration_hours': videos.length,
            'rating': 0.0,
          })
          .select('id')
          .single();

      final courseId = course['id'];

      for (int i = 0; i < videos.length; i++) {
        final video = videos[i];

        final videoUrl = await uploadFile(
          bucket: 'course-videos',
          file: video.videoFile!,
          fileName: video.videoName ?? 'video_$i.mp4',
        );

        await supabase.from('lessons').insert({
          'course_id': courseId,
          'title': video.titleController.text.trim(),
          'video_url': videoUrl,
          'order_index': i + 1,
        });
      }

      if (!mounted) return;

      showMessage('Course added successfully');

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Add course error: $e');
      showMessage('Error adding course');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF1E3A5F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
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
                  const SizedBox(width: 12),
                  Text(
                    'Add Course',
                    style: GoogleFonts.agbalumo(
                      fontSize: 30,
                      color: const Color(0xFF6C94C6),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Course title'),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Course description'),
                    ),

                    const SizedBox(height: 14),

                    GestureDetector(
                      onTap: pickCourseImage,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A6FA5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.image, color: Color(0xFFE3C39D)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                courseImageName ?? 'Choose course image',
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Text(
                          'Videos',
                          style: GoogleFonts.agbalumo(
                            fontSize: 24,
                            color: const Color(0xFF6C94C6),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: addVideoField,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE3C39D),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.black),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    ...List.generate(
                      videos.length,
                      (index) => buildVideoCard(index),
                    ),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: isSaving ? null : saveCourse,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3C39D),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  'Save Course',
                                  style: GoogleFonts.agbalumo(
                                    color: Colors.black,
                                    fontSize: 18,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildVideoCard(int index) {
    final video = videos[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4A6FA5).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Video ${index + 1}',
                style: const TextStyle(
                  color: Color(0xFFE3C39D),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (videos.length > 1)
                GestureDetector(
                  onTap: () => removeVideoField(index),
                  child: const Icon(Icons.delete, color: Colors.white70),
                ),
            ],
          ),

          const SizedBox(height: 12),

          TextField(
            controller: video.titleController,
            style: const TextStyle(color: Colors.white),
            decoration: inputDecoration('Video title'),
          ),

          const SizedBox(height: 12),

          GestureDetector(
            onTap: () => pickVideo(index),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.video_library,
                    color: Color(0xFFE3C39D),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      video.videoName ?? 'Choose video from device',
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
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
}

class VideoInput {
  final TextEditingController titleController = TextEditingController();
  File? videoFile;
  String? videoName;
}