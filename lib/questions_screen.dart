import 'dart:convert';

import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final response =
          await http.get(Uri.parse('${AppConstants.baseUrl}/questions'));

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

  void _openQuestion(Map q) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnswerScreen(question: q)),
    ).then((_) => _fetchQuestions());
  }

  void _openAskDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D2240),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Ask a Question",
                style: GoogleFonts.agbalumo(
                    color: const Color(0xFFE3C39D), fontSize: 22)),
            const SizedBox(height: 16),
            _buildField(titleCtrl, "Title"),
            const SizedBox(height: 10),
            _buildField(contentCtrl, "Details", maxLines: 4),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B6382),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
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

                    final response = await http.post(
                      Uri.parse('${AppConstants.baseUrl}/questions'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode({
                        "title": titleCtrl.text.trim(),
                        "content": contentCtrl.text.trim(),
                        "category": "",
                      }),
                    );

                    if (response.statusCode >= 400) {
                      throw Exception(response.body);
                    }

                    if (!mounted) return;
                    Navigator.pop(ctx);
                    await _fetchQuestions();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("✅ Question posted!")));
                  } catch (e) {
                    debugPrint("Error posting question: $e");
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("❌ Error: $e")));
                  }
                },
                child: const Text("Post",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
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
          borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            contentPadding: const EdgeInsets.all(14),
            border: InputBorder.none),
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
                  Text("Questions",
                      style: GoogleFonts.agbalumo(
                          color: const Color(0xFF6C94C6),
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Icon(Icons.search, color: Colors.white54),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFE3C39D)))
                  : RefreshIndicator(
                      onRefresh: _fetchQuestions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _questions.length,
                        itemBuilder: (_, i) {
                          final q = _questions[i];
                          final profile = q['profiles'];
                          final username = q['username']?.toString() ??
                              profile?['username']?.toString() ??
                              '';
                          final profileImage =
                              q['profile_image']?.toString() ??
                                  profile?['profile_image']?.toString() ??
                                  '';

                          return GestureDetector(
                            onTap: () => _openQuestion(q),
                            child: Container(
                              margin:
                                  const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3C39D),
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundImage:
                                            profileImage.isNotEmpty
                                                ? NetworkImage(
                                                    profileImage)
                                                : null,
                                        backgroundColor:
                                            const Color(0xFF4B6382),
                                        child: profileImage.isEmpty
                                            ? const Icon(Icons.person,
                                                color: Colors.white,
                                                size: 18)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(username,
                                          style:
                                              GoogleFonts.robotoCondensed(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 15,
                                                  color: const Color(
                                                      0xFF071739))),
                                      const Spacer(),
                                      Text(
                                        _timeAgo(q['created_at']
                                            ?.toString()),
                                        style: const TextStyle(
                                            color: Color(0xFF4A4A4A),
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(q["title"]?.toString() ?? "",
                                      style: GoogleFonts.robotoCondensed(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              const Color(0xFF071739))),
                                  const SizedBox(height: 6),
                                  Text(q["content"]?.toString() ?? "",
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFF071739),
                                          fontSize: 13)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.favorite_border,
                                          color: Color(0xFF071739),
                                          size: 18),
                                      const SizedBox(width: 4),
                                      Text("${q["likes"] ?? 0}",
                                          style: const TextStyle(
                                              color: Color(0xFF071739))),
                                      const SizedBox(width: 16),
                                      const Icon(
                                          Icons.chat_bubble_outline,
                                          color: Color(0xFF071739),
                                          size: 18),
                                      const Spacer(),
                                      const Icon(Icons.bookmark_border,
                                          color: Color(0xFF071739),
                                          size: 20),
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
