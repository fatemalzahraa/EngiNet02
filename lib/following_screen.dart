import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/session_manager.dart';

import 'engineer_profile.dart';


class FollowingScreen extends StatefulWidget {
  final List<dynamic> following;

  const FollowingScreen({super.key, required this.following});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();

}

class _FollowingScreenState extends State<FollowingScreen> {
  final supabase = Supabase.instance.client;

  late List<dynamic> followingList;

  @override
  void initState() {
    super.initState();
    followingList = List.from(widget.following);
  }

  Future<void> unfollowUser(int targetId, int index) async {
    final email = await SessionManager.getEmail();
    if (email == null) return;

    final user = await supabase
        .from('users')
        .select('id')
        .eq('email', email)
        .single();

    final currentUserId = user['id'];

    await supabase
        .from('follows')
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', targetId);

    setState(() {
      followingList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
    appBar: AppBar(
  backgroundColor: const Color(0xFF071739),
  elevation: 0,
  automaticallyImplyLeading: false, 

  title: Stack(
    alignment: Alignment.center,
    children: [
     
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFE3C39D),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFF071739),
              ),
            ),
          ),
        ),
      ),

      
      const Text(
        'Following',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),
      body: followingList.isEmpty
          ? const Center(
              child: Text(
                'No following yet',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              itemCount: followingList.length,
              itemBuilder: (context, index) {
                final user = followingList[index]['users'];

                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2F55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage:
                            (user['profile_image'] ?? '').isNotEmpty
                                ? CachedNetworkImageProvider(
                                    user['profile_image'])
                                : null,
                        backgroundColor: const Color(0xFF4A6FA5),
                        child: (user['profile_image'] ?? '').isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),

                      /// 🔥 اسم المهندس
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EngineerProfileScreen(
                                  targetUserId: user['id'],
                                ),
                              ),
                            );
                          },
                          child: Text(
                            user['username'] ?? '',
                            style: const TextStyle(
                              color: Color(0xFFE3C39D), // 🔥 اللون
                              fontSize: 18, // 🔥 تكبير الخط
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      /// 🔥 زر إلغاء المتابعة
                      ElevatedButton(
                        onPressed: () =>
                            unfollowUser(user['id'], index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE3C39D),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Unfollow'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}