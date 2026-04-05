import 'package:enginet/article.dart';
import 'package:enginet/book.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:enginet/course.dart';
import 'package:enginet/engineer_profile.dart';
import 'package:enginet/student_profile.dart';
import 'package:enginet/home_screen.dart';
import 'package:enginet/core/constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class IndexPage extends StatefulWidget {
  final String title;
  const IndexPage({super.key, required this.title});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  int _currentIndex = 0;
  String _role = 'student';
  String _username = '';
  String _profileImage = '';
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final token = await SessionManager.getToken();
      final role = await SessionManager.getRole();
      final username = await SessionManager.getUsername();
      String profileImage = '';

      if (token != null && token.isNotEmpty) {
        final response = await http.get(
          Uri.parse('${AppConstants.baseUrl}/profile/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final profile = jsonDecode(response.body) as Map<String, dynamic>;
          profileImage = profile['profile_image']?.toString() ?? '';
        }
      }

      if (!mounted) return;
      setState(() {
        _role = role ?? 'student';
        _username = username ?? '';
        _profileImage = profileImage;
        _profileLoaded = true;
      });
    } catch (e) {
      debugPrint('❌ Error loading role: $e');
      if (!mounted) return;
      setState(() => _profileLoaded = true);
    }
  }

  Widget get _profileScreen =>
      _role == 'engineer' ? const EngineerProfileScreen() : const StudentProfileScreen();

  // Pages indexed 0-4 matching _currentIndex
  // 0=Home, 1=Books, 2=Courses, 3=Articles, 4=Profile
  List<Widget> get _pages => [
        const HomeScreen(),
        const BookScreen(),
        const CourseScreen(),
        const ArticleScreen(),
        _profileScreen,
      ];

  // Fixed: correct mapping from ConvexAppBar index to _pages index
  // ConvexAppBar: 0=Home, 1=Books, 2=Add(modal), 3=Articles, 4=Profile
  void _changeBottomNav(int value) {
    if (value == 2) {
      _showAddOptions();
      return;
    }
    // Map nav index → page index
    const pageMap = {0: 0, 1: 1, 3: 3, 4: 4};
    setState(() => _currentIndex = pageMap[value] ?? 0);
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2240),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Content',
                style:
                    GoogleFonts.agbalumo(color: const Color(0xFFE3C39D), fontSize: 20)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.question_answer, color: Colors.white),
              title: const Text('Ask a Question', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/questions');
              },
            ),
            ListTile(
              leading: const Icon(Icons.book, color: Colors.white),
              title: const Text('Add Book', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.note_add, color: Colors.white),
              title: const Text('Add Article', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.white),
              title: const Text('Add Course', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _onDrawerItemTapped(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context);
  }

  Future<void> _logout() async {
    await SessionManager.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        centerTitle: true,
        title: Text(widget.title,
            style: GoogleFonts.agbalumo(
                color: const Color(0xFFE3C39D), fontSize: 40, fontWeight: FontWeight.bold)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFFE3C39D)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Color(0xFFE3C39D)),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),

      body: IndexedStack(index: _currentIndex, children: _pages),

      drawer: Drawer(
        child: Container(
          color: const Color(0xFFE3C39D),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFFA68868)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundImage:
                          _profileImage.isNotEmpty ? NetworkImage(_profileImage) : null,
                      backgroundColor: const Color(0xFF4A6FA5),
                      child: _profileImage.isEmpty
                          ? const Icon(Icons.person, size: 45, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(_username.isNotEmpty ? _username : 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                selected: _currentIndex == 0,
                onTap: () => _onDrawerItemTapped(0),
              ),
              ListTile(
                leading: const Icon(Icons.account_box_rounded),
                title: const Text('Profile'),
                selected: _currentIndex == 4,
                onTap: () => _onDrawerItemTapped(4),
              ),
              ListTile(
                leading: const Icon(Icons.question_answer),
                title: const Text('Questions'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/questions');
                },
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Books'),
                selected: _currentIndex == 1,
                onTap: () => _onDrawerItemTapped(1),
              ),
              ListTile(
                leading: const Icon(Icons.article_rounded),
                title: const Text('Articles'),
                selected: _currentIndex == 3,
                onTap: () => _onDrawerItemTapped(3),
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Courses'),
                selected: _currentIndex == 2,
                onTap: () => _onDrawerItemTapped(2),
              ),
              ListTile(
                leading: const Icon(Icons.smart_toy),
                title: const Text('AI Chat'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/ai-chat');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),

      // Fixed: correct nav items order matches _changeBottomNav mapping
      bottomNavigationBar: ConvexAppBar(
        initialActiveIndex: 0,
        onTap: _changeBottomNav,
        backgroundColor: const Color(0xFF3C4F71),
        items: const [
          TabItem(icon: Icon(Icons.home), title: 'Home'),        // → page 0
          TabItem(icon: Icon(Icons.book), title: 'Books'),       // → page 1
          TabItem(icon: Icon(Icons.add), title: ''),             // → modal
          TabItem(icon: Icon(Icons.article), title: 'Articles'), // → page 3
          TabItem(icon: Icon(Icons.account_circle), title: 'Profile'), // → page 4
        ],
      ),
    );
  }
}