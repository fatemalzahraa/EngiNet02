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
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
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
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color(0xFFE3C39D),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFD8C09A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF071739),
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFE3C39D),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
           _tile(
  icon: Icons.person,
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
  icon: Icons.lock_reset,
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
              icon: Icons.logout,
              title: 'Logout',
              onTap: () => _logout(context),
            ),

            _tile(
              icon: Icons.delete_forever,
              title: 'Delete Account',
              color: Colors.red,
              onTap: () => _deleteAccount(context),
            ),
          ],
        ),
      ),
    );
  }
}