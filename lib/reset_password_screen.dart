import 'package:enginet/core/constants.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

/// Three-step reset flow:
///  Step 1 — enter email → POST /forgot-password → OTP sent
///  Step 2 — enter OTP code → POST /verify-otp
///  Step 3 — enter new password → POST /reset-password
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  int _step = 1; // 1 = email, 2 = OTP, 3 = new password
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  // ── Step 1: Send Link ────────────────────────────────────
  Future<void> _sendResetLink() async {
  final email = _emailCtrl.text.trim();

  if (email.isEmpty) {
    _showSnack('Please enter your email', error: true);
    return;
  }

  setState(() => _isLoading = true);

  try {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/forgot-password?email=$email'),
    );

    if (res.statusCode == 200) {
      setState(() => _step = 2);
     _showSnack('A reset code has been sent to your email');
    } else {
  debugPrint('Reset error status: ${res.statusCode}');
  debugPrint('Reset error body: ${res.body}');

  final body = jsonDecode(res.body);
  _showSnack(body['detail'] ?? body['message'] ?? 'Something went wrong', error: true);
}
  } catch (e) {
    _showSnack('Connection error', error: true);
  } finally {
    setState(() => _isLoading = false);
  }
}

// ── Step 2: Verify OTP ─────────────────────────
Future<void> _verifyOTP() async {
  final code = _codeCtrl.text.trim();

  if (code.length != 6) {
    _showSnack('Enter the 6-digit code', error: true);
    return;
  }

  setState(() => _isLoading = true);

  try {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': _emailCtrl.text.trim(),
        'code': code,
      }),
    );

    if (res.statusCode == 200) {
      setState(() => _step = 3);
    } else {
      final body = jsonDecode(res.body);
      _showSnack(body['detail'] ?? 'Invalid code', error: true);
    }
  } catch (e) {
    _showSnack('Connection error', error: true);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}


// ── Step 3: Reset Password ─────────────────────
Future<void> _resetPassword() async {
  final newPass = _newPassCtrl.text.trim();
  final confirm = _confirmPassCtrl.text.trim();

  if (newPass.isEmpty || confirm.isEmpty) {
    _showSnack('Fill all fields', error: true);
    return;
  }

  if (newPass != confirm) {
    _showSnack('Passwords do not match', error: true);
    return;
  }

  if (newPass.length < 6) {
    _showSnack('Minimum 6 characters', error: true);
    return;
  }

  setState(() => _isLoading = true);

  try {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': _emailCtrl.text.trim(),
        'code': _codeCtrl.text.trim(),
        'new_password': newPass,
      }),
    );

    if (res.statusCode == 200) {
      _showSnack('Password updated successfully!');
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      final body = jsonDecode(res.body);
      _showSnack(body['detail'] ?? 'Something went wrong', error: true);
    }
  } catch (e) {
    _showSnack('Connection error', error: true);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
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
                Image.asset('images/enginet_logo.png', height: 120),
                const SizedBox(height: 20),
                Text('Reset Password',
                    style: GoogleFonts.robotoCondensed(
                        fontSize: 36, fontWeight: FontWeight.bold,
                        color: const Color(0xFFA68868))),
                const SizedBox(height: 8),
                // Step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _step == i + 1 ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _step >= i + 1
                          ? const Color(0xFFE3C39D)
                          : const Color(0xFF4B6382),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
                const SizedBox(height: 32),

                if (_step == 1) ..._buildStep1(),
                if (_step == 2) ..._buildStep2(),
                if (_step == 3) ..._buildStep3(),
               

                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
                  child: Text('Back to Sign In',
                      style: GoogleFonts.robotoCondensed(
                          color: const Color(0xFFCDD5D8),
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1() => [
    Text('Enter your email to receive a reset code',
        textAlign: TextAlign.center,
        style: GoogleFonts.robotoCondensed(fontSize: 16, color: const Color(0xFFA68868))),
    const SizedBox(height: 24),
    _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 20),
    _actionButton('Send Reset Code', _sendResetLink),
  ];

List<Widget> _buildStep2() => [
  Text('Enter the 6-digit code sent to\n${_emailCtrl.text.trim()}'),
  const SizedBox(height: 24),
  _field(_codeCtrl, '6-Digit Code', keyboardType: TextInputType.number),
  const SizedBox(height: 20),
  _actionButton('Verify Code', _verifyOTP),
];
List<Widget> _buildStep3() => [
  _field(_newPassCtrl, 'New Password', obscureText: true),
  const SizedBox(height: 12),
  _field(_confirmPassCtrl, 'Confirm Password', obscureText: true),
  const SizedBox(height: 20),
  _actionButton('Update Password', _resetPassword),
];


  Widget _field(TextEditingController ctrl, String hint,
      {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFE3C39D), borderRadius: BorderRadius.circular(34)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: ctrl,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(border: InputBorder.none, hintText: hint),
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
            color: const Color(0xFF4B6382), borderRadius: BorderRadius.circular(34)),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(label,
                  style: GoogleFonts.robotoCondensed(
                      color: const Color(0xFFCDD5D8),
                      fontWeight: FontWeight.bold, fontSize: 22)),
        ),
      ),
    );
  }
}