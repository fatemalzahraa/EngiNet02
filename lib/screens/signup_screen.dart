import 'dart:convert';

import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'student';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // ---- Validation ----
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("Please fill all fields", isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar("Passwords do not match", isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar("Password must be at least 6 characters", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final registerResponse = await http.post(
        Uri.parse('${AppConstants.baseUrl}/register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'role': _selectedRole,
        }),
      );

      final registerData =
          jsonDecode(registerResponse.body) as Map<String, dynamic>;

      if (registerResponse.statusCode >= 400) {
        _showSnackBar(
          (registerData['detail'] ?? 'Registration failed. Try again.')
              .toString(),
          isError: true,
        );
        return;
      }

      final loginResponse = await http.post(
        Uri.parse('${AppConstants.baseUrl}/token'),
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email,
          'password': password,
        },
      );

      final loginData = jsonDecode(loginResponse.body) as Map<String, dynamic>;

      if (loginResponse.statusCode != 200) {
        _showSnackBar(
          'Account created, but automatic login failed. Please sign in.',
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      await SessionManager.saveSession(
        token: loginData['access_token']?.toString() ?? '',
        role: loginData['role']?.toString() ?? _selectedRole,
        username: loginData['username']?.toString() ?? username,
        email: email,
      );

      if (!mounted) return;
      _showSnackBar("Account created successfully! ✅");
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint("Signup error: $e");
      _showSnackBar("Unable to connect to server. Try again.", isError: true);
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
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ---- Logo ----
                Image.asset('images/enginet_logo.png', height: 100),
                const SizedBox(height: 16),

                Text(
                  'Create Account',
                  style: GoogleFonts.agbalumo(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE3C39D),
                  ),
                ),
                Text(
                  'Join the EngiNet community',
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 15,
                    color: const Color(0xFFA68868),
                  ),
                ),
                const SizedBox(height: 32),

                // ---- Username ----
                _buildField(
                  controller: _usernameController,
                  hint: 'Username',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 14),

                // ---- Email ----
                _buildField(
                  controller: _emailController,
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                // ---- Password ----
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
                const SizedBox(height: 14),

                // ---- Confirm Password ----
                _buildField(
                  controller: _confirmPasswordController,
                  hint: 'Confirm Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 20),

                // ---- Role Selector ----
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3C39D),
                    borderRadius: BorderRadius.circular(34),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: Colors.black45),
                      const SizedBox(width: 10),
                      Text(
                        'I am a:',
                        style: GoogleFonts.robotoCondensed(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            dropdownColor: const Color(0xFFE3C39D),
                            style: GoogleFonts.robotoCondensed(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'student',
                                child: Text('Student'),
                              ),
                              DropdownMenuItem(
                                value: 'engineer',
                                child: Text('Engineer'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedRole = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ---- Signup Button ----
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _isLoading ? null : _signup,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B6382),
                        borderRadius: BorderRadius.circular(34),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)
                            : Text(
                                'Create Account',
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
                const SizedBox(height: 20),

                // ---- Login Link ----
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: GoogleFonts.robotoCondensed(
                          color: Colors.white54, fontSize: 15),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.robotoCondensed(
                          color: const Color(0xFFE3C39D),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
        color: const Color(0xFFE3C39D),
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
