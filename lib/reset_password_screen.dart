import 'package:enginet/core/constants.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool isLoading = false;

  
  Future<void> resetPassword() async {
    final email = _emailController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final response = await http.post(
      Uri.parse("${AppConstants.baseUrl}/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "new_password": newPassword,
      }),
    );

    setState(() => isLoading = false);

    if (!mounted) return;

    if (response.statusCode == 200) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("✅ Password updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      final data = jsonDecode(response.body);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("❌ ${data['detail'] ?? 'Something went wrong'}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
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
                    color: const Color(0xFFA68868),
                  ),
                ),
                Text(
                  'Enter your new password',
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 18,
                    color: const Color(0xFFA68868),
                  ),
                ),
                const SizedBox(height: 40),

                // Email
                _buildField(_emailController, 'Email',
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),

                // New Password
                _buildField(_newPasswordController, 'New Password',
                    obscureText: true),
                const SizedBox(height: 16),

                // Confirm Password
                _buildField(_confirmPasswordController, 'Confirm Password',
                    obscureText: true),
                const SizedBox(height: 24),

                // زر Reset
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: GestureDetector(
                    onTap: isLoading ? null : resetPassword,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B6382),
                        borderRadius: BorderRadius.circular(34),
                      ),
                      child: Center(
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(
                                'Reset Password',
                                style: GoogleFonts.robotoCondensed(
                                  color: const Color(0xFFCDD5D8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // رجوع للـ Login
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushReplacementNamed('/login'),
                  child: Text(
                    "Back to Sign In",
                    style: GoogleFonts.robotoCondensed(
                      color: const Color(0xFFCDD5D8),
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

  Widget _buildField(TextEditingController controller, String hint,
      {bool obscureText = false,
      TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE3C39D),
          borderRadius: BorderRadius.circular(34),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
            ),
          ),
        ),
      ),
    );
  }
}