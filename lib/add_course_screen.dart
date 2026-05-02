import 'dart:convert';
import 'dart:io';

import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

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

  Future<int> getVideoDurationSeconds(String path) async {
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    final seconds = controller.value.duration.inSeconds;
    await controller.dispose();
    return seconds;
  }

  Future<void> pickCourseImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null && result.files.single.path != null) {
      setState(() {
        courseImage = File(result.files.single.path!);
        courseImageName = result.files.single.name;
      });
    }
  }

  Future<void> pickVideo(int index) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);

    if (result != null && result.files.single.path != null) {
      setState(() {
        videos[index].videoFile = File(result.files.single.path!);
        videos[index].videoName = result.files.single.name;
      });
    }
  }

  void addVideoField() {
    setState(() => videos.add(VideoInput()));
  }

  void removeVideoField(int index) {
    if (videos.length == 1) return;

    setState(() {
      videos[index].titleController.dispose();
      videos.removeAt(index);
    });
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

      final token = await SessionManager.getToken();
      if (token == null || token.isEmpty) {
        showMessage('Please login first');
        return;
      }

      final durations = <int>[];
      for (final video in videos) {
        final seconds = await getVideoDurationSeconds(video.videoFile!.path);
        durations.add(seconds);
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/courses/create-with-videos'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['instructor_name'] = engineer['username']?.toString() ?? '';
      request.fields['instructor_image'] =
          engineer['profile_image']?.toString() ?? '';

      request.fields['video_titles_json'] = jsonEncode(
        videos.map((v) => v.titleController.text.trim()).toList(),
      );

      request.fields['video_durations_json'] = jsonEncode(durations);

      request.files.add(
        await http.MultipartFile.fromPath(
          'course_image',
          courseImage!.path,
          filename: courseImageName ?? 'course_image.jpg',
        ),
      );

      for (int i = 0; i < videos.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'videos',
            videos[i].videoFile!.path,
            filename: videos[i].videoName ?? 'video_$i.mp4',
          ),
        );
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();

      debugPrint('ADD COURSE STATUS: ${response.statusCode}');
      debugPrint('ADD COURSE BODY: $body');

      if (response.statusCode != 200) {
        throw Exception(body);
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