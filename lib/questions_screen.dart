import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:http_parser/http_parser.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List _questions = [];
  bool _isLoading = true;
  File? selectedMedia;
  String? selectedMediaName;
  String? selectedMediaType;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
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

  final wasLiked =
      q['is_liked'] == true || q['is_liked'] == 1;

  final oldLikes = int.tryParse(q['likes'].toString()) ?? 0;

  setState(() {
    _questions[index]['is_liked'] = !wasLiked;
    _questions[index]['likes'] =
        wasLiked ? (oldLikes > 0 ? oldLikes - 1 : 0) : oldLikes + 1;
  });

  try {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/questions/${q['id']}/like'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  } catch (e) {
    setState(() {
      _questions[index]['is_liked'] = wasLiked;
      _questions[index]['likes'] = oldLikes;
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
        content: Text(res.statusCode == 200
            ? 'Question saved'
            : 'Could not save question'),
      ),
    );
  }

  void _openQuestion(Map q) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnswerScreen(question: q)),
    ).then((_) => _fetchQuestions());
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
                    color: const Color(0xFFE3C39D),
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
                      backgroundColor: const Color(0xFF4B6382),
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
                            const SnackBar(
                              content: Text("Please login first"),
                            ),
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

                        debugPrint('POST QUESTION STATUS: ${response.statusCode}');
                        debugPrint('POST QUESTION BODY: $body');

                        if (response.statusCode >= 400) {
                          throw Exception(body);
                        }

                        if (!mounted) return;
                        Navigator.pop(ctx);
                        await _fetchQuestions();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("✅ Question posted!")),
                        );
                      } catch (e) {
                        debugPrint("Error posting question: $e");
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("❌ Error: $e")),
                        );
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
          color: const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE3C39D), size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
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
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
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
            color: const Color(0xFF071739),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.play_circle, color: Color(0xFFE3C39D), size: 55),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    "Questions",
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFF6C94C6),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.search, color: Colors.white54),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE3C39D),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchQuestions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _questions.length,
                        itemBuilder: (_, i) {
                          final q = _questions[i];
                          final username = q['username']?.toString() ?? '';
                          final profileImage =
                              q['profile_image']?.toString() ?? '';

                          return GestureDetector(
                            onTap: () => _openQuestion(q),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3C39D),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundImage:
                                            profileImage.isNotEmpty
                                                ? NetworkImage(profileImage)
                                                : null,
                                        backgroundColor:
                                            const Color(0xFF4B6382),
                                        child: profileImage.isEmpty
                                            ? const Icon(Icons.person,
                                                color: Colors.white, size: 18)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        username,
                                        style: GoogleFonts.robotoCondensed(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: const Color(0xFF071739),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _timeAgo(q['created_at']?.toString()),
                                        style: const TextStyle(
                                          color: Color(0xFF4A4A4A),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    q["title"]?.toString() ?? "",
                                    style: GoogleFonts.robotoCondensed(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF071739),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    q["content"]?.toString() ?? "",
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF071739),
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
        (q['is_liked'] == true || q['is_liked'] == 1)
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
        (q['is_saved'] == true || q['is_saved'] == 1)
            ? Icons.bookmark
            : Icons.bookmark_border,
        color: const Color(0xFF071739),
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
        backgroundColor: const Color(0xFF4B6382),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}


// ===================== ANSWER SCREEN =====================
class AnswerScreen extends StatefulWidget {
  final Map question;
  const AnswerScreen({super.key, required this.question});

  @override
  State<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends State<AnswerScreen> {
  List _answers = [];
  final _ctrl = TextEditingController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _fetchAnswers();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAnswers() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/questions/${widget.question['id']}/answers',
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch answers');
      }

      final data = jsonDecode(response.body) as List<dynamic>;

      if (!mounted) return;
      setState(() => _answers = data);
    } catch (e) {
      debugPrint("Error fetching answers: $e");
    }
  }

  Future<void> _postAnswer() async {
    if (_ctrl.text.trim().isEmpty || _isPosting) return;

    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first")),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/questions/${widget.question['id']}/answers',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"content": _ctrl.text.trim()}),
      );

      if (response.statusCode >= 400) {
        throw Exception(response.body);
      }

      _ctrl.clear();
      await _fetchAnswers();
    } catch (e) {
      debugPrint("Error posting answer: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: $e")));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.question['profiles'];
    final questionUsername = widget.question['username']?.toString() ??
        profile?['username']?.toString() ??
        '';
    final questionProfileImage =
        widget.question['profile_image']?.toString() ??
            profile?['profile_image']?.toString() ??
            '';

    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE3C39D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Answers",
            style: GoogleFonts.agbalumo(
                color: const Color(0xFFE3C39D), fontSize: 24)),
      ),
      body: Column(
        children: [
          // ---- السؤال ----
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFE3C39D),
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: questionProfileImage.isNotEmpty
                          ? NetworkImage(questionProfileImage)
                          : null,
                      backgroundColor: const Color(0xFF4B6382),
                      child: questionProfileImage.isEmpty
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(questionUsername,
                        style: GoogleFonts.robotoCondensed(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF071739))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(widget.question["title"]?.toString() ?? "",
                    style: GoogleFonts.robotoCondensed(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF071739))),
                const SizedBox(height: 6),
                Text(widget.question["content"]?.toString() ?? "",
                    style:
                        const TextStyle(color: Color(0xFF071739))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.favorite_border,
                        color: Color(0xFF071739), size: 18),
                    const SizedBox(width: 4),
                    Text("${widget.question["likes"] ?? 0}",
                        style:
                            const TextStyle(color: Color(0xFF071739))),
                    const SizedBox(width: 16),
                    const Icon(Icons.chat_bubble_outline,
                        color: Color(0xFF071739), size: 18),
                    const SizedBox(width: 4),
                    Text("${_answers.length}",
                        style:
                            const TextStyle(color: Color(0xFF071739))),
                  ],
                ),
              ],
            ),
          ),

          // ---- عنوان الأجوبة ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Answers (${_answers.length})",
                  style: GoogleFonts.agbalumo(
                      color: Colors.white, fontSize: 20)),
            ),
          ),

          // ---- قائمة الأجوبة ----
          Expanded(
            child: _answers.isEmpty
                ? const Center(
                    child: Text("No answers yet",
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _answers.length,
                    itemBuilder: (_, i) {
                      final a = _answers[i];
                      final aProfile = a['profiles'];
                      final aUsername = a['username']?.toString() ??
                          aProfile?['username']?.toString() ??
                          '';
                      final aProfileImage =
                          a['profile_image']?.toString() ??
                              aProfile?['profile_image']?.toString() ??
                              '';
                      final isAccepted = a['is_accepted'] == true ||
                          a['is_accepted'] == 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: isAccepted
                                ? const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.3)
                                : const Color(0xFFA68868),
                            borderRadius: BorderRadius.circular(12),
                            border: isAccepted
                                ? Border.all(
                                    color: Colors.green, width: 2)
                                : null),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundImage:
                                      aProfileImage.isNotEmpty
                                          ? NetworkImage(aProfileImage)
                                          : null,
                                  backgroundColor:
                                      const Color(0xFF4B6382),
                                  child: aProfileImage.isEmpty
                                      ? const Icon(Icons.person,
                                          size: 15, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(aUsername,
                                    style: GoogleFonts.robotoCondensed(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF071739))),
                                const Spacer(),
                                if (isAccepted)
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(a["content"]?.toString() ?? "",
                                style: const TextStyle(
                                    color: Color(0xFF071739))),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ---- كتابة جواب ----
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: const Color(0xFF0D2240),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                          hintText: "Write your answer...",
                          hintStyle: TextStyle(color: Colors.white38),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: InputBorder.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _postAnswer,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Color(0xFF6C94C6),
                        Color(0xFF4A6FA5)
                      ]),
                      shape: BoxShape.circle,
                    ),
                    child: _isPosting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
