import 'dart:convert';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:enginet/core/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentQuestionsScreen extends StatefulWidget {
  const StudentQuestionsScreen({super.key});

  @override
  State<StudentQuestionsScreen> createState() => _StudentQuestionsScreenState();
}

class _StudentQuestionsScreenState extends State<StudentQuestionsScreen> {
  final _universityController = TextEditingController();
  final _specialtyController = TextEditingController();

  String _studyYear = '1st';
  String _level = 'Beginner';
  String _preferredLanguage = 'English';
  bool _isLoading = false;

  final Set<String> _selectedInterests = {'Flutter', 'Web Dev'};

  final List<String> _years = ['1st', '2nd', '3rd', '4th', '5th'];
  final List<String> _levels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> _languages = ['English', 'Arabic', 'Turkish'];
  final List<String> _interests = [
    'Flutter',
    'AI',
    'Web Dev',
    'Data Science',
    'Cyber Security',
    'Civil Eng',
    'Electrical Eng',
    'Mechanical Eng',
  ];

  @override
  void dispose() {
    _universityController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
  final university = _universityController.text.trim();
  final specialty = _specialtyController.text.trim();

  if (university.isEmpty || specialty.isEmpty || _selectedInterests.isEmpty) {
    _showSnackBar('Please fill all required fields', isError: true);
    return;
  }

  setState(() => _isLoading = true);

  try {
    final supabase = Supabase.instance.client;
    final email = await SessionManager.getEmail();

    final user = await supabase
        .from('users')
        .select('id')
        .eq('email', email ?? '')
        .maybeSingle();

    if (user == null) {
      _showSnackBar('User not found', isError: true);
      return;
    }

    await supabase.from('student_profiles').upsert({
      'user_id': user['id'],
      'university': university,
      'specialty': specialty,
      'study_year': _studyYear,
      'level': _level,
      'interests': _selectedInterests.join(','),
      'preferred_language': _preferredLanguage,
    }, onConflict: 'user_id');

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  } catch (e) {
    debugPrint('Student profile error: $e');
    _showSnackBar('Error: $e', isError: true);
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

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.robotoCondensed(
          color: Colors.white54,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.robotoCondensed(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.black45),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionChip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
    bool withCheck = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withOpacity(0.16)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.white.withOpacity(0.13),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && withCheck) ...[
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF87E0CB),
                size: 18,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: GoogleFonts.robotoCondensed(
                color: selected ? AppColors.accent : Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressBars() {
    return Row(
      children: List.generate(4, (index) {
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
            decoration: BoxDecoration(
              color: index < 2
                  ? AppColors.accent
                  : Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue =
        _universityController.text.trim().isNotEmpty &&
        _specialtyController.text.trim().isNotEmpty &&
        _selectedInterests.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
          child: StatefulBuilder(
            builder: (context, localSetState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student info',
                    style: GoogleFonts.robotoCondensed(
                      color: AppColors.accent,
                      fontSize: 43,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Personalize your experience',
                    style: GoogleFonts.robotoCondensed(
                      color: Colors.white54,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _progressBars(),
                  const SizedBox(height: 36),

                  _sectionTitle('Academic'),
                  _textField(
                    controller: _universityController,
                    hint: 'GIBTÜ',
                    icon: Icons.school_outlined,
                  ),
                  const SizedBox(height: 16),
                  _textField(
                    controller: _specialtyController,
                    hint: 'Software Engineering',
                    icon: Icons.build_outlined,
                  ),

                  const SizedBox(height: 32),
                  _sectionTitle('Year of study'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _years.map((year) {
                      return _optionChip(
                        text: year,
                        selected: _studyYear == year,
                        onTap: () => setState(() => _studyYear = year),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle('Level'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _levels.map((level) {
                      return _optionChip(
                        text: level,
                        selected: _level == level,
                        onTap: () => setState(() => _level = level),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle('Language'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _languages.map((lang) {
                      return _optionChip(
                        text: lang,
                        selected: _preferredLanguage == lang,
                        withCheck: true,
                        onTap: () => setState(() => _preferredLanguage = lang),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle('Interests'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: _interests.map((interest) {
                      final selected = _selectedInterests.contains(interest);
                      return _optionChip(
                        text: interest,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedInterests.remove(interest);
                            } else {
                              _selectedInterests.add(interest);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 54),

                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _saveProfile,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: canContinue
                              ? AppColors.accent
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Continue  →',
                                  style: GoogleFonts.robotoCondensed(
                                    color: canContinue
                                        ? const Color(0xFF56627B)
                                        : Colors.white24,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
