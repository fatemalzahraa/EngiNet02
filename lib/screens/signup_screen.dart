import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;



class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _userController = TextEditingController();

  String _selectedRole = 'student'; 

  Future<void> signUp() async {
    if (!passwordConfirmed()) {
      showErrorDialog('Passwords do not match');
      return;
    }

    final username = _userController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final response = await http.post(
        Uri.parse('https://enginet02-1.onrender.com/register'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'role': _selectedRole.toLowerCase(),
        }),
      );
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
  Navigator.pushReplacementNamed(context, '/login');

      } else {
        try {
    final data = jsonDecode(response.body);
    final detail = data['detail'];
    showErrorDialog(detail?.toString() ?? 'Registration failed');
  } catch (_) {
    showErrorDialog('Registration failed');
  }
      }
    } catch (e) {
      if (!mounted) return;
      showErrorDialog('Something went wrong: $e');
    }
  }

  bool passwordConfirmed() =>
      _passwordController.text.trim() == _confirmPasswordController.text.trim();

  void openLoginScreen() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _userController.dispose();
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
                Image.asset('images/enginet_logo.png', height: 150),
                const SizedBox(height: 20),
                Text('Sign Up',
                    style: GoogleFonts.robotoCondensed(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFA68868))),
                Text('Welcome To EngiNet!',
                    style: GoogleFonts.robotoCondensed(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFA68868))),
                const SizedBox(height: 50),

                // Username
                inputField(_userController, 'User Name'),

                const SizedBox(height: 20),
                // Email
                inputField(_emailController, 'Email'),

                const SizedBox(height: 20),
                // Password
                inputField(_passwordController, 'Password', obscureText: true),

                const SizedBox(height: 20),
                // Confirm Password
                inputField(_confirmPasswordController, 'Confirm Password',
                    obscureText: true),

                const SizedBox(height: 20),
                // Role dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    items: ['student', 'engineer']
                        .map((role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedRole = val!;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFE3C39D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(34),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Sign Up button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: GestureDetector(
                    onTap: signUp,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B6382),
                        borderRadius: BorderRadius.circular(34),
                      ),
                      child: Center(
                        child: Text('Sign Up',
                            style: GoogleFonts.robotoCondensed(
                                color: const Color(0xFFCDD5D8),
                                fontWeight: FontWeight.bold,
                                fontSize: 24)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already a member?  ",
                        style: GoogleFonts.robotoCondensed(
                            color: const Color(0xFFA68868),
                            fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: openLoginScreen,
                      child: Text('Sign In Now',
                          style: GoogleFonts.robotoCondensed(
                              color: const Color(0xFFCDD5D8),
                              fontWeight: FontWeight.bold)),
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

  Widget inputField(TextEditingController controller, String hintText,
      {bool obscureText = false}) {
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
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
            ),
          ),
        ),
      ),
    );
  }
}
