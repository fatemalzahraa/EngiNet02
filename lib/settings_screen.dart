import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/reset_password_screen.dart';
import 'package:enginet/edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await SessionManager.clearSession();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF132F5C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Account',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete your account?',
          style: GoogleFonts.poppins(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.white70,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;

      final email = await SessionManager.getEmail();

      if (email == null) return;

      final userRes = await supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .single();

      final userId = userRes['id'];

      await supabase.from('saved_posts').delete().eq('user_id', userId);
      await supabase.from('bookmarks').delete().eq('user_id', userId);
      await supabase.from('article_bookmarks').delete().eq('user_id', userId);
      await supabase.from('likes').delete().eq('user_id', userId);
      await supabase.from('comments').delete().eq('comment_user_id', userId);
      await supabase.from('comments').delete().eq('user_id', userId);
      await supabase.from('answers').delete().eq('user_id', userId);
      await supabase.from('questions').delete().eq('user_id', userId);
      await supabase.from('student_courses').delete().eq('user_id', userId);
      await supabase.from('lesson_progress').delete().eq('user_id', userId);
      await supabase.from('notifications').delete().eq('user_id', userId);
      await supabase.from('follows').delete().eq('follower_id', userId);
      await supabase.from('follows').delete().eq('following_id', userId);

      await supabase.from('users').delete().eq('id', userId);

      await SessionManager.clearSession();

      if (!context.mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    } catch (e) {
      debugPrint('DELETE ACCOUNT ERROR: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Error: $e',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color(0xFFE3C39D),
  }) {
    final bool isDanger = color == Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD8C09A),
            const Color(0xFFE6D0AF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDanger
                        ? Colors.red.withOpacity(0.12)
                        : const Color(0xFF071739).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: isDanger
                        ? Colors.red
                        : const Color(0xFF071739),
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF071739),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: const Color(0xFF071739).withOpacity(0.65),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        title: Text(
          'Settings',
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 30,
          ),
        ),

        iconTheme: const IconThemeData(
          color: Color(0xFFE3C39D),
        ),
      ),

      body: Container(
        width: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF071739),
              Color(0xFF0B2A5B),
              Color(0xFF132F5C),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),

            child: Column(
              children: [
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(22),

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE3C39D).withOpacity(0.12),

                    border: Border.all(
                      color: const Color(0xFFE3C39D).withOpacity(0.30),
                      width: 1.5,
                    ),
                  ),

                  child: const Icon(
                    Icons.settings_rounded,
                    color: Color(0xFFE3C39D),
                    size: 60,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Manage Your Account',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Customize your profile, password and preferences',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                _tile(
                  icon: Icons.person_rounded,
                  title: 'Edit Profile',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),

                _tile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Reset Password',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ResetPasswordScreen(),
                      ),
                    );
                  },
                ),

                _tile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  onTap: () => _logout(context),
                ),

                const Spacer(),

                _tile(
                  icon: Icons.delete_forever_rounded,
                  title: 'Delete Account',
                  color: Colors.red,
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}