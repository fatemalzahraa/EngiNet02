import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/app_colors.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _sendResetEmail() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      _showSnack('Please enter your email', error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.resetPasswordForEmail(email);
      setState(() => _emailSent = true);
    } on AuthException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Connection error. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('images/enginet_logo.png', height: 120),
                const SizedBox(height: 20),
                Text(
                  'Reset Password',
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textAccent,
                  ),
                ),
                const SizedBox(height: 32),

                if (!_emailSent) ...[
                  Text(
                    'Enter your email and we\'ll send you a reset link.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 15,
                      color: AppColors.textAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(34),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Email',
                        hintStyle: TextStyle(color: Colors.black45),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.black45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _sendResetEmail,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(34),
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : Text(
                                  'Send Reset Link',
                                  style: GoogleFonts.robotoCondensed(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 80,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Check your email!',
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a password reset link to\n${_emailCtrl.text.trim()}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 15,
                      color: AppColors.textAccent,
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushReplacementNamed('/login'),
                  child: Text(
                    'Back to Sign In',
                    style: GoogleFonts.robotoCondensed(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}