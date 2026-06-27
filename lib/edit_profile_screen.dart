import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/constants.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:enginet/core/app_colors.dart';

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

      if (email == null) return;

      final user = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (user == null) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final studentProfile = await supabase
          .from('student_profiles')
          .select()
          .eq('user_id', user['id'])
          .maybeSingle();

      usernameCtrl.text = user['username'] ?? '';
      emailCtrl.text = user['email'] ?? '';
      bioCtrl.text = user['bio'] ?? '';
      phoneCtrl.text = user['phone'] ?? '';
      universityCtrl.text =
          studentProfile?['university'] ?? user['university'] ?? '';
      specialtyCtrl.text =
          studentProfile?['specialty'] ?? user['specialty'] ?? '';
      locationCtrl.text = user['location'] ?? '';
      linkedinCtrl.text = user['linkedin'] ?? '';
      githubCtrl.text = user['github'] ?? '';
      websiteCtrl.text = user['website'] ?? '';
      skillsCtrl.text = user['skills'] ?? '';

      showEmail = user['show_email'] ?? false;
      profileImage = user['profile_image'] ?? '';

      if (!mounted) return;

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('LOAD USER ERROR: $e');

      if (!mounted) return;
      setState(() => isLoading = false);
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

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login again')));

        setState(() => isSaving = false);
        return;
      }

      final newEmail = emailCtrl.text.trim();

      if (!newEmail.contains('@') || !newEmail.contains('.')) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter a valid email')));

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
        SnackBar(
          backgroundColor: AppColors.accent,
          content: Text(
            'Profile updated successfully',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('SAVE PROFILE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error: $e', style: GoogleFonts.poppins()),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget field(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),

        gradient: LinearGradient(
          colors: [const Color(0xFFD8C09A), const Color(0xFFE6D0AF)],
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: TextField(
        controller: ctrl,

        style: GoogleFonts.poppins(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),

        decoration: InputDecoration(
          border: InputBorder.none,

          hintText: hint,

          hintStyle: GoogleFonts.poppins(
            color: AppColors.primary.withOpacity(0.55),
          ),

          prefixIcon: Icon(icon, color: AppColors.primary),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        title: Text(
          'Edit Profile',
          style: GoogleFonts.agbalumo(color: AppColors.accent, fontSize: 28),
        ),

        iconTheme: const IconThemeData(color: AppColors.accent),
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    Color(0xFF0B2A5B),
                    Color(0xFF132F5C),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),

              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),

                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    GestureDetector(
                      onTap: pickImage,

                      child: Stack(
                        alignment: Alignment.bottomRight,

                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),

                            child: CircleAvatar(
                              radius: 62,
                              backgroundColor: const Color(0xFFD8C09A),

                              backgroundImage: selectedImageFile != null
                                  ? FileImage(selectedImageFile!)
                                  : profileImage.isNotEmpty
                                  ? CachedNetworkImageProvider(profileImage)
                                  : null,

                              child: profileImage.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 62,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.all(10),

                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),

                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Tap to change photo',
                      style: GoogleFonts.poppins(
                        color: AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 36),

                    field(usernameCtrl, 'Username', Icons.person_rounded),

                    field(emailCtrl, 'Email', Icons.email_rounded),

                    field(phoneCtrl, 'Phone', Icons.phone_rounded),

                    field(bioCtrl, 'Bio', Icons.edit_note_rounded),

                    field(universityCtrl, 'University', Icons.school_rounded),

                    field(
                      specialtyCtrl,
                      'Specialty',
                      Icons.workspace_premium_rounded,
                    ),

                    field(locationCtrl, 'Location', Icons.location_on_rounded),

                    field(linkedinCtrl, 'LinkedIn', Icons.link_rounded),

                    field(githubCtrl, 'GitHub', Icons.code_rounded),

                    field(websiteCtrl, 'Website', Icons.language_rounded),

                    field(skillsCtrl, 'Skills', Icons.psychology_rounded),

                    Container(
                      margin: const EdgeInsets.only(top: 8),

                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: SwitchListTile(
                        value: showEmail,

                        activeColor: AppColors.accent,

                        title: Text(
                          'Show Email',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        onChanged: (v) {
                          setState(() {
                            showEmail = v;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 58,

                      child: ElevatedButton(
                        onPressed: isSaving ? null : saveProfile,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),

                          elevation: 8,
                        ),

                        child: isSaving
                            ? const CircularProgressIndicator(
                                color: AppColors.primary,
                              )
                            : Text(
                                'Save Changes',
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
