import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/constants.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final supabase = Supabase.instance.client;

  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final bioCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final universityCtrl = TextEditingController();
  final specialtyCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final linkedinCtrl = TextEditingController();
  final githubCtrl = TextEditingController();
  final websiteCtrl = TextEditingController();
  final skillsCtrl = TextEditingController();

  bool showEmail = false;
  bool isLoading = true;
  bool isSaving = false;

  String profileImage = '';
  File? selectedImageFile;

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final email = await SessionManager.getEmail();

      final user = await supabase
          .from('users')
          .select()
          .eq('email', email!)
          .single();

      usernameCtrl.text = user['username'] ?? '';
      emailCtrl.text = user['email'] ?? '';
      bioCtrl.text = user['bio'] ?? '';
      phoneCtrl.text = user['phone'] ?? '';
      universityCtrl.text = user['university'] ?? '';
      specialtyCtrl.text = user['specialty'] ?? '';
      locationCtrl.text = user['location'] ?? '';
      linkedinCtrl.text = user['linkedin'] ?? '';
      githubCtrl.text = user['github'] ?? '';
      websiteCtrl.text = user['website'] ?? '';
      skillsCtrl.text = user['skills'] ?? '';

      showEmail = user['show_email'] ?? false;

      profileImage = user['profile_image'] ?? '';

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD USER ERROR: $e');
    }
  }

  Future<void> pickImage() async {
  final pickedFile = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
  );

  if (pickedFile == null) return;

  setState(() {
    selectedImageFile = File(pickedFile.path);
    profileImage = pickedFile.path;
  });
}
  Future<void> saveProfile() async {
  try {
    setState(() => isSaving = true);

    final token = await SessionManager.getToken();
  if (token == null || token.isEmpty) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please login again')),
  );

  setState(() => isSaving = false);
  return;
}

    final newEmail = emailCtrl.text.trim();

if (!newEmail.contains('@') || !newEmail.contains('.')) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Enter a valid email')),
  );

  setState(() => isSaving = false);
  return;
}

    bool validUrl(String value) {
      if (value.trim().isEmpty) return true;
      return value.startsWith('http://') || value.startsWith('https://');
    }

    if (!validUrl(linkedinCtrl.text) ||
        !validUrl(githubCtrl.text) ||
        !validUrl(websiteCtrl.text)) {
          if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Links must start with http:// or https://'),
        ),
      );
      setState(() => isSaving = false);
      return;
    }

    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${AppConstants.baseUrl}/profile/update'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    request.fields['username'] = usernameCtrl.text.trim();
    request.fields['email'] = emailCtrl.text.trim();
    request.fields['bio'] = bioCtrl.text.trim();
    request.fields['phone'] = phoneCtrl.text.trim();
    request.fields['university'] = universityCtrl.text.trim();
    request.fields['specialty'] = specialtyCtrl.text.trim();
    request.fields['location'] = locationCtrl.text.trim();
    request.fields['linkedin'] = linkedinCtrl.text.trim();
    request.fields['github'] = githubCtrl.text.trim();
    request.fields['website'] = websiteCtrl.text.trim();
    request.fields['skills'] = skillsCtrl.text.trim();
    request.fields['show_email'] = showEmail.toString();

    if (selectedImageFile != null) {
      final ext = path.extension(selectedImageFile!.path).toLowerCase();
      final subtype = ext == '.png' ? 'png' : 'jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          selectedImageFile!.path,
          contentType: MediaType('image', subtype),
        ),
      );
    }

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode >= 400) {
      throw Exception(responseBody);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );

    Navigator.pop(context, true);
  } catch (e) {
    debugPrint('SAVE PROFILE ERROR: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    if (mounted) setState(() => isSaving = false);
  }
}

  Widget field(
    TextEditingController ctrl,
    String hint,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFD8C09A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFE3C39D),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: pickImage,
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: const Color(0xFFD8C09A),
                    backgroundImage: selectedImageFile != null
    ? FileImage(selectedImageFile!)
    : profileImage.isNotEmpty
        ? CachedNetworkImageProvider(profileImage)
        : null,
                      child: profileImage.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 55,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Tap to change photo',
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFFE3C39D),
                    ),
                  ),

                  const SizedBox(height: 24),

                  field(usernameCtrl, 'Username'),
                  field(emailCtrl, 'Email'),
                  field(phoneCtrl, 'Phone'),
                  field(bioCtrl, 'Bio'),
                  field(universityCtrl, 'University'),
                  field(specialtyCtrl, 'Specialty'),
                  field(locationCtrl, 'Location'),
                  field(linkedinCtrl, 'LinkedIn'),
                  field(githubCtrl, 'GitHub'),
                  field(websiteCtrl, 'Website'),
                  field(skillsCtrl, 'Skills'),

                  SwitchListTile(
                    value: showEmail,
                    activeThumbColor: const Color(0xFFE3C39D),
                    title: const Text(
                      'Show Email',
                      style: TextStyle(color: Colors.white),
                    ),
                    onChanged: (v) {
                      setState(() {
                        showEmail = v;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          isSaving ? null : saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFE3C39D),
                      ),
                      child: isSaving
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}