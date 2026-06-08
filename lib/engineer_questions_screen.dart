import 'dart:convert';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:enginet/core/app_colors.dart';

class EngineerQuestionsScreen extends StatefulWidget {
  const EngineerQuestionsScreen({super.key});

  @override
  State<EngineerQuestionsScreen> createState() =>
      _EngineerQuestionsScreenState();
}

class _EngineerQuestionsScreenState extends State<EngineerQuestionsScreen> {
  final _universityController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _experienceController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _isLoading = false;

  final List<String> _skills = [
    'Flutter',
    'AI',
    'Cyber Security',
    'Backend',
    'Frontend',
    'Data Science',
    'Civil Engineering',
    'Electrical Engineering',
    'Mechanical Engineering',
  ];

  final Set<String> _selectedSkills = {};

  @override
  void dispose() {
    _universityController.dispose();
    _specialtyController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final university = _universityController.text.trim();
    final specialty = _specialtyController.text.trim();
    final experience = int.tryParse(_experienceController.text.trim()) ?? 0;

    if (university.isEmpty || specialty.isEmpty || _selectedSkills.isEmpty) {
      _showSnackBar('Please fill all required fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await SessionManager.getToken();

      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/engineer-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'university': university,
          'specialty': specialty,
          'experience_years': experience,
          'skills': _selectedSkills.join(','),
          'bio': _bioController.text.trim(),
          'location': _locationController.text.trim(),
          'linkedin': _linkedinController.text.trim(),
          'github': _githubController.text.trim(),
          'website': _websiteController.text.trim(),
        }),
      );

      if (res.statusCode >= 400) {
        debugPrint(res.body);
        _showSnackBar('Failed to save profile', isError: true);
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint('Engineer profile error: $e');
      _showSnackBar('Unable to connect to server', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.black54),
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Engineer Info',
                style: GoogleFonts.agbalumo(
                  fontSize: 36,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us about your field and skills',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 28),

              _field(
                controller: _universityController,
                hint: 'University',
                icon: Icons.school,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _specialtyController,
                hint: 'Engineering Field / Specialty',
                icon: Icons.engineering,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _experienceController,
                hint: 'Experience Years',
                icon: Icons.work_history,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _locationController,
                hint: 'Location',
                icon: Icons.location_on,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _bioController,
                hint: 'Short Bio',
                icon: Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _linkedinController,
                hint: 'LinkedIn',
                icon: Icons.link,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _githubController,
                hint: 'GitHub',
                icon: Icons.code,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _websiteController,
                hint: 'Website',
                icon: Icons.web,
              ),
              const SizedBox(height: 24),

              const Text(
                'Choose your skills',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _skills.map((skill) {
                  final selected = _selectedSkills.contains(skill);

                  return ChoiceChip(
                    label: Text(skill),
                    selected: selected,
                    selectedColor: AppColors.accent,
                    backgroundColor: Colors.white24,
                    labelStyle: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                    ),
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _selectedSkills.remove(skill);
                        } else {
                          _selectedSkills.add(skill);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _isLoading ? null : _saveProfile,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(34),
                    ),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
