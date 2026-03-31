import 'package:enginet/article.dart';
import 'package:enginet/book.dart';
import 'package:enginet/course.dart';
import 'package:enginet/engineer_profile.dart';
import 'package:enginet/student_profile.dart';
import 'package:enginet/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class IndexPage extends StatefulWidget {
  final String title;

  const IndexPage({super.key, required this.title});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  int _currentIndex = 0;
  bool _isBottomNav = true;
  String _role = 'student';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role') ?? 'student';
    });
  }

  Widget get _profileScreen =>
      _role == 'engineer' ? const EngineerProfileScreen() : const StudentProfileScreen();

  void _changeItem(int value) {
    if (value == 2) {
      _showAddOptions();
    } else {
      setState(() {
        _isBottomNav = true;
        _currentIndex = value;
      });
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.question_answer),
                title: const Text('Soru sor'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Kitab Ekle'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('Makale Ekle'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Kurs Ekle'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> get _pages => [
        const HomeScreen(),
        _profileScreen,
        const BookScreen(),
        const ArticleScreen(),
        const CourseScreen(),
      ];

  List<Widget> get _pagesNav => [
        const HomeScreen(),
        const BookScreen(),
        const SizedBox(),
        const ArticleScreen(),
        _profileScreen,
      ];

  void _onItemTapped(int index) {
    setState(() {
      _isBottomNav = false;
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        title: Text(
          widget.title,
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFFE3C39D)),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _isBottomNav ? _pagesNav : _pages,
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFFE3C39D),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFFA68868)),
                child: Column(
                  children: [
                    Image.asset('images/user1.png', width: 100, height: 100),
                    const SizedBox(height: 10),
                    const Text('User Name'),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                selected: _currentIndex == 0,
                onTap: () {
                  _onItemTapped(0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_box_rounded),
                title: const Text('Profile'),
                selected: _currentIndex == 1,
                onTap: () {
                  _onItemTapped(1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Kitaplar'),
                selected: _currentIndex == 2,
                onTap: () {
                  _onItemTapped(2);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.article_rounded),
                title: const Text('Makaleler'),
                selected: _currentIndex == 3,
                onTap: () {
                  _onItemTapped(3);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_collection_rounded),
                title: const Text('Kurslar'),
                selected: _currentIndex == 4,
                onTap: () {
                  _onItemTapped(4);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ConvexAppBar(
        initialActiveIndex: _currentIndex,
        onTap: _changeItem,
        backgroundColor: const Color(0xFF3C4F71),
        items: const [
          TabItem(icon: Icon(Icons.home), title: 'Home'),
          TabItem(icon: Icon(Icons.book), title: 'Book'),
          TabItem(icon: Icon(Icons.add), title: ''),
          TabItem(icon: Icon(Icons.article), title: 'Article'),
          TabItem(icon: Icon(Icons.account_circle), title: 'Profile'),
        ],
      ),
    );
  }
}