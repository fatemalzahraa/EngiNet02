import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/engineer_profile.dart';
import 'package:enginet/core/app_colors.dart';
import 'package:enginet/features/questions/widgets/answer_section.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}
StreamSubscription<List<Map<String, dynamic>>>? _questionsSub;
class _QuestionsScreenState extends State<QuestionsScreen> {
  List _questions = [];
  bool _isLoading = true;
  int? _currentUserId;
  File? selectedMedia;
  String? selectedMediaName;
  String? selectedMediaType;
  Timer? _timer;
  String _searchQuery = '';

 @override
void initState() {
   super.initState();
  _fetchQuestions();
  _loadCurrentUser();

  _timer = Timer.periodic(const Duration(minutes: 1), (_) {
    if (mounted) setState(() {});
  });
}
@override
void dispose() {
  _questionsSub?.cancel();
  _timer?.cancel();
  super.dispose();
}

void _startQuestionsRealtime() {
  _questionsSub?.cancel();
  _questionsSub = null;
}

  Future<void> _loadCurrentUser() async {
  final email = await SessionManager.getEmail();
  if (email == null) return;
  final user = await Supabase.instance.client
      .from('users')
      .select('id')
      .eq('email', email)
      .maybeSingle();
  if (!mounted) return;
  setState(() {
    _currentUserId = user?['id'];
  });
}

  Future<void> _openUserProfile(String username) async {
    if (username.isEmpty) return;

    try {
      final owner = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (owner == null || owner['id'] == null) return;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EngineerProfileScreen(targetUserId: owner['id']),
        ),
      );
    } catch (e) {
      debugPrint('❌ open profile error: $e');
    }
  }

  Future<void> _fetchQuestions() async {
    
    try {
      final token = await SessionManager.getToken();

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/questions'),
        headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch questions');
      }

      final data = jsonDecode(response.body) as List<dynamic>;

      if (!mounted) return;
      setState(() {
        _questions = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint("Error fetching questions: $e");
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedMedia = File(result.files.single.path!);
        selectedMediaName = result.files.single.name;
        selectedMediaType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedMedia = File(result.files.single.path!);
        selectedMediaName = result.files.single.name;
        selectedMediaType = 'video';
      });
    }
  }

Future<void> _likeQuestion(Map q) async {
  final token = await SessionManager.getToken();
  if (token == null || token.isEmpty) return;

  final index = _questions.indexWhere((item) => item['id'] == q['id']);
  if (index == -1) return;

  final currentLiked = q['is_liked'] == true;
  final currentLikes = (q['likes'] ?? 0) as int;

  // Anında güncelle
  setState(() {
    final updated = Map<String, dynamic>.from(_questions[index]);
    updated['is_liked'] = !currentLiked;
    updated['likes'] = currentLiked ? currentLikes - 1 : currentLikes + 1;
    _questions[index] = updated;
  });

  try {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/questions/${q['id']}/like'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        final i = _questions.indexWhere((item) => item['id'] == q['id']);
        if (i != -1) {
          final updated = Map<String, dynamic>.from(_questions[i]);
          updated['is_liked'] = data['liked'];
          updated['likes'] = data['likes'];
          _questions[i] = updated;
        }
      });
    } else {
      // Hata → geri al
      if (!mounted) return;
      setState(() {
        final i = _questions.indexWhere((item) => item['id'] == q['id']);
        if (i != -1) {
          final updated = Map<String, dynamic>.from(_questions[i]);
          updated['is_liked'] = currentLiked;
          updated['likes'] = currentLikes;
          _questions[i] = updated;
        }
      });
    }
  } catch (e) {
    debugPrint("LIKE ERROR: $e");
    if (!mounted) return;
    setState(() {
      final i = _questions.indexWhere((item) => item['id'] == q['id']);
      if (i != -1) {
        final updated = Map<String, dynamic>.from(_questions[i]);
        updated['is_liked'] = currentLiked;
        updated['likes'] = currentLikes;
        _questions[i] = updated;
      }
    });
  }
}
  Future<void> _saveQuestion(Map q) async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) return;

    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/questions/${q['id']}/save'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.statusCode == 200 ? 'Question saved' : 'Could not save question',
        ),
      ),
    );
  }

  Future<void> _deleteQuestion(Map q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Question"),
        content: const Text("Are you sure you want to delete this question?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await SessionManager.getToken();
      if (token == null || token.isEmpty) return;

      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/questions/${q['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          _questions.removeWhere((item) => item['id'] == q['id']);
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Question deleted")));
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      debugPrint("DELETE QUESTION ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }

void _openQuestion(Map q) {
  final questionId = q['id'];
  
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AnswerScreen(question: q)),
  ).then((newAnswerCount) async {
    // AnswerScreen'den dönen cevap sayısını hemen güncelle
    if (newAnswerCount != null) {
      setState(() {
        final i = _questions.indexWhere((item) => item['id'] == questionId);
        if (i != -1) {
          final updated = Map<String, dynamic>.from(_questions[i]);
          updated['answers_count'] = newAnswerCount;
          _questions[i] = updated;
        }
      });
    }
    // Sonra backend'den de yenile
    await _fetchQuestions();
  });
}

  void _openAskDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    selectedMedia = null;
    selectedMediaName = null;
    selectedMediaType = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D2240),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, modalSetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Ask a Question",
                  style: GoogleFonts.agbalumo(
                    color: AppColors.accent,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 16),
                _buildField(titleCtrl, "Title"),
                const SizedBox(height: 10),
                _buildField(contentCtrl, "Description", maxLines: 4),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _mediaButton(
                        icon: Icons.image,
                        label: 'Image',
                        onTap: () async {
                          await _pickImage();
                          modalSetState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _mediaButton(
                        icon: Icons.videocam,
                        label: 'Video',
                        onTap: () async {
                          await _pickVideo();
                          modalSetState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                if (selectedMediaName != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedMediaName!,
                          style: const TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          selectedMedia = null;
                          selectedMediaName = null;
                          selectedMediaType = null;
                          modalSetState(() {});
                        },
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty ||
                          contentCtrl.text.trim().isEmpty) {
                        return;
                      }

                      try {
                        final token = await SessionManager.getToken();
                        if (token == null || token.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please login first")),
                          );
                          return;
                        }

                        final request = http.MultipartRequest(
                          'POST',
                          Uri.parse('${AppConstants.baseUrl}/questions'),
                        );

                        request.headers['Authorization'] = 'Bearer $token';
                        request.fields['title'] = titleCtrl.text.trim();
                        request.fields['content'] = contentCtrl.text.trim();
                        request.fields['category'] = '';

                        if (selectedMedia != null) {
                          final isImage = selectedMediaType == 'image';

                          request.files.add(
                            await http.MultipartFile.fromPath(
                              'media',
                              selectedMedia!.path,
                              filename: selectedMediaName,
                              contentType: MediaType(
                                isImage ? 'image' : 'video',
                                isImage ? 'jpeg' : 'mp4',
                              ),
                            ),
                          );
                        }

                        final response = await request.send();
                        final body = await response.stream.bytesToString();

                        debugPrint(
                          'POST QUESTION STATUS: ${response.statusCode}',
                        );
                        debugPrint('POST QUESTION BODY: $body');

                       if (response.statusCode >= 400) {
  throw Exception(body);
}

if (!mounted) return;
Navigator.pop(ctx);
await _fetchQuestions();  // bunu koru
if (mounted) setState(() {}); // bunu ekle

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("✅ Question posted!")),
                        );
                      } catch (e) {
                        debugPrint("Error posting question: $e");
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
                      }
                    },
                    child: const Text(
                      "Post",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          contentPadding: const EdgeInsets.all(14),
          border: InputBorder.none,
        ),
      ),
    );
  }

String _timeAgo(String? dateStr) {
  if (dateStr == null) return '';
  
  // Sonunda Z yoksa ekle — Supabase UTC döndürür ama Z koymaz
  final normalized = dateStr.endsWith('Z') ? dateStr : '${dateStr}Z';
  final date = DateTime.tryParse(normalized);
  if (date == null) return '';

  final diff = DateTime.now().toUtc().difference(date.toUtc());

  if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "${diff.inHours}h ago";
  return "${diff.inDays}d ago";
}

  Widget _questionMedia(Map q) {
    final mediaUrl = q['media_url']?.toString() ?? '';
    final mediaType = q['media_type']?.toString() ?? '';

    if (mediaUrl.isEmpty) return const SizedBox.shrink();

    if (mediaType == 'image') {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: mediaUrl,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (mediaType == 'video') {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.play_circle, color: AppColors.accent, size: 55),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  List get _filteredQuestions {
    if (_searchQuery.trim().isEmpty) return _questions;

    final query = _searchQuery.trim().toLowerCase();

    return _questions.where((q) {
      final title = q["title"]?.toString().toLowerCase() ?? "";
      final content = q["content"]?.toString().toLowerCase() ?? "";
      final username = q["username"]?.toString().toLowerCase() ?? "";

      return title.contains(query) ||
          content.contains(query) ||
          username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredQuestions = _filteredQuestions;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.accent),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    "Questions",
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFF6C94C6),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search for a question...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchQuestions,
                      child: filteredQuestions.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(24),
                              children: const [
                                SizedBox(height: 160),
                                Center(
                                  child: Text(
                                    "No questions found",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredQuestions.length,
                              itemBuilder: (_, i) {
                                final q = filteredQuestions[i];
                                final username =
                                    q['username']?.toString() ?? '';
                                final profileImage =
                                    q['profile_image']?.toString() ?? '';

                                return GestureDetector(
                                  onTap: () => _openQuestion(q),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () =>
                                              _openUserProfile(username),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundImage:
                                                    profileImage.isNotEmpty
                                                    ? NetworkImage(profileImage)
                                                    : null,
                                                backgroundColor:
                                                    AppColors.cardBg,
                                                child: profileImage.isEmpty
                                                    ? const Icon(
                                                        Icons.person,
                                                        color: Colors.white,
                                                        size: 18,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                username,
                                                style:
                                                    GoogleFonts.robotoCondensed(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                      color: AppColors.primary,
                                                    ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                _timeAgo(
                                                  q['created_at']?.toString(),
                                                ),
                                                style: const TextStyle(
                                                  color: Color(0xFF4A4A4A),
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (_currentUserId != null && q['user_id'] == _currentUserId)
                                                GestureDetector(
                                                  onTap: () =>
                                                      _deleteQuestion(q),
                                                  child: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                    size: 18,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          q["title"]?.toString() ?? "",
                                          style: GoogleFonts.robotoCondensed(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          q["content"]?.toString() ?? "",
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        _questionMedia(q),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => _likeQuestion(q),
                                              child: Icon(
                                                (q['is_liked'] == true ||
                                                        q['is_liked'] == 1)
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${q["likes"] ?? 0}",
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            GestureDetector(
                                              onTap: () => _openQuestion(q),
                                              child: const Icon(
                                                Icons.chat_bubble,
                                                color: Color(0xFF5B7FA6),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${q["answers_count"] ?? 0}",
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () => _saveQuestion(q),
                                              child: Icon(
                                                (q['is_saved'] == true ||
                                                        q['is_saved'] == 1)
                                                    ? Icons.bookmark
                                                    : Icons.bookmark_border,
                                                color: AppColors.primary,
                                                size: 28,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAskDialog,
        backgroundColor: AppColors.cardBg,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

