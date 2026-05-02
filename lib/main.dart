import 'package:enginet/ai_chat_screen.dart';
import 'package:enginet/index.dart';
import 'package:enginet/notifications_screen.dart';
import 'package:enginet/questions_screen.dart';
import 'package:enginet/screens/login_screen.dart';
import 'package:enginet/screens/signup_screen.dart';
import 'package:enginet/splash_screen.dart';
import 'package:flutter/material.dart';
import 'reset_password_screen.dart';
import 'student_profile.dart';
import 'engineer_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:enginet/add_article.dart';
import 'package:enginet/add_book.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://ksfrsnbfdzgtkxhswobs.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    _supabaseAnonKey.isEmpty
        ? const MissingSupabaseConfigApp()
        : const MyApp(),
  );
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
        '/ai-chat': (context) => const AIChatScreen(),
        '/questions': (context) => const QuestionsScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/add-book': (context) => const AddBookScreen(),
        '/add-article': (context) => const AddArticleScreen(),
      },
    );
  }
}

class MissingSupabaseConfigApp extends StatelessWidget {
  const MissingSupabaseConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF071739),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  color: Color(0xFFE3C39D),
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Supabase configuration is missing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE3C39D),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Run the app with --dart-define=SUPABASE_ANON_KEY=your_key'
                  '\n'
                  'and optionally --dart-define=SUPABASE_URL=your_url',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
