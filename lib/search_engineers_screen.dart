import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/engineer_profile.dart';
import 'package:enginet/core/session_manager.dart';

class SearchEngineersScreen extends StatefulWidget {
  const SearchEngineersScreen({super.key});

  @override
  State<SearchEngineersScreen> createState() =>
      _SearchEngineersScreenState();
}

class _SearchEngineersScreenState
    extends State<SearchEngineersScreen> {
  final supabase = Supabase.instance.client;

  List engineers = [];
  List filtered = [];

  bool isLoading = true;

  int? currentUserId;

  @override
  void initState() {
    super.initState();
    loadEngineers();
  }

  Future<void> loadEngineers() async {
    try {
      final email = await SessionManager.getEmail();

      if (email != null) {
        final me = await supabase
            .from('users')
            .select('id')
            .eq('email', email)
            .maybeSingle();

        currentUserId = me?['id'];
      }

      final res = await supabase
          .from('users')
          .select()
          .eq('role', 'engineer')
          .order('username');

      engineers = List<Map<String, dynamic>>.from(res);

      filtered = engineers
          .where((e) => e['id'] != currentUserId)
          .toList();

      if (!mounted) return;

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('SEARCH ENGINEERS ERROR: $e');

      if (!mounted) return;

      setState(() => isLoading = false);
    }
  }

  void search(String text) {
    final q = text.toLowerCase();

    setState(() {
      filtered = engineers.where((e) {
        final username =
            e['username']?.toString().toLowerCase() ?? '';

        return username.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),

      appBar: AppBar(
  backgroundColor: const Color(0xFF071739),

  iconTheme: const IconThemeData(
    color: Color(0xFFE3C39D),
  ),

  title: Text(
    'Search Engineers',
    style: GoogleFonts.agbalumo(
      color: const Color(0xFFE3C39D),
    ),
  ),
),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle:
                    const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white54,
                ),
                filled: true,
                fillColor: const Color(0xFF1E3A5F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final eng = filtered[i];

                      final image =
                          eng['profile_image']?.toString() ?? '';

                      return ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EngineerProfileScreen(
                                targetUserId: eng['id'],
                              ),
                            ),
                          );
                        },

                        leading: CircleAvatar(
                          backgroundImage: image.isNotEmpty
                              ? CachedNetworkImageProvider(image)
                              : null,
                          child: image.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),

                        title: Text(
                          eng['username'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),

                        subtitle: Text(
                          eng['specialty'] ?? '',
                          style: const TextStyle(
                            color: Colors.white54,
                          ),
                        ),

                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white54,
                          size: 16,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}