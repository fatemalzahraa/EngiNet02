import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

 Future<void> _login() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();


  if (email.isEmpty || password.isEmpty) {
    _showSnackBar('Please fill all fields', isError: true);
    return;
  }

  setState(() => _isLoading = true);

  try {
    debugPrint('Calling signInWithPassword...');
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    debugPrint('Response received: user=${response.user?.id}');

    final user = response.user;
    final session = response.session;

    if (user == null || session == null) {
      debugPrint('User or session is null');
      _showSnackBar('Login failed. Check your credentials.', isError: true);
      return;
    }

    final userData = await _supabase
        .from('users')
        .select('role, username')
        .eq('email', email)
        .maybeSingle();


    final role = userData?['role']?.toString() ?? 'student';
    final username = userData?['username']?.toString() ?? '';

    await SessionManager.saveSession(
      token: session.accessToken,
      role: role,
      username: username,
      email: email,
    );

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  } on AuthException catch (e) {
    debugPrint('AuthException: ${e.message} / ${e.statusCode}');
    _showSnackBar(e.message, isError: true);
  } catch (e) {
    debugPrint('Login error: $e');
    _showSnackBar('Unable to connect. Try again.', isError: true);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
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
                  'EngiNet',
                  style: GoogleFonts.agbalumo(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 16,
                    color: AppColors.textAccent,
                  ),
                ),
                const SizedBox(height: 40),
                _buildField(
                  controller: _emailController,
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _passwordController,
                  hint: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/reset-password-link'),
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.robotoCondensed(
                        color: const Color(0xFF6C94C6),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _isLoading ? null : _login,
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
                                'Sign In',
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.robotoCondensed(
                        color: Colors.white54,
                        fontSize: 15,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/register'),
                      child: Text(
                        'Sign Up',
                        style: GoogleFonts.robotoCondensed(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(34),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45),
          prefixIcon: Icon(icon, color: Colors.black45),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}