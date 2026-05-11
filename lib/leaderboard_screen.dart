import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  int selectedTab = 0; // 0 engineers, 1 students

  List engineers = [];
  List students = [];

  @override
  void initState() {
    super.initState();
    loadLeaderboard();
  }

  Future<void> loadLeaderboard() async {
    try {
      final res = await supabase
          .from('users')
          .select('id, username, profile_image, role, points')
          .order('points', ascending: false)
          .limit(100);

      if (!mounted) return;

      setState(() {
        engineers = (res as List)
            .where((u) => u['role'] == 'engineer')
            .toList();

        students = res
            .where((u) => u['role'] == 'student')
            .toList();

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Leaderboard error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Widget _tab(String title, int index) {
    final isSelected = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedTab = index);
        },
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.agbalumo(
                color: isSelected
                    ? const Color(0xFFE3C39D)
                    : Colors.grey,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: 90,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE3C39D)
                    : Colors.grey,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user, int index) {
    final username = user['username']?.toString() ?? 'User';
    final image = user['profile_image']?.toString() ?? '';
    final points = user['points'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3C39D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(
            '#${index + 1}',
            style: const TextStyle(
              color: Color(0xFF071739),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 24,
            backgroundImage:
                image.isNotEmpty ? NetworkImage(image) : null,
            backgroundColor: const Color(0xFF4A6FA5),
            child: image.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username,
              style: GoogleFonts.agbalumo(
                color: const Color(0xFF071739),
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF071739),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$points pts',
              style: const TextStyle(
                color: Color(0xFFE3C39D),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final list = selectedTab == 0 ? engineers : students;

    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: Text(
            'No users yet',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(
        list.length,
        (index) => _buildUserCard(list[index], index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE3C39D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Leaderboard',
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 24,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE3C39D)),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  Image.asset(
                    'images/enginet_logo.png',
                    height: 100,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'EngiNet Leaderboard',
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFFE3C39D),
                      fontSize: 26,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Row(
                    children: [
                      _tab('Engineers', 0),
                      _tab('Students', 1),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _buildList(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}