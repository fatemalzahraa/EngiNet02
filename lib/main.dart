
import 'package:enginet/index.dart';
import 'package:enginet/screens/login_screen.dart';
import 'package:enginet/screens/signup_screen.dart';
import 'package:enginet/splash_screen.dart';
import 'package:flutter/material.dart';
import 'reset_password_screen.dart';
import 'student_profile.dart';
import 'engineer_profile.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const SignupScreen(),
        '/home': (context) => const IndexPage(title: 'Enginet'),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/student-profile': (context) => const StudentProfileScreen(),
        '/engineer-profile': (context) => const EngineerProfileScreen(),
      },
    );
  }
}
