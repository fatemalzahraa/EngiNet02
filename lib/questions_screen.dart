import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = "https://enginet02.onrender.com";

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List _questions = [];
  bool _isLoading = true;
  String _token = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    await _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final res = await http.get(Uri.parse("$baseUrl/questions"));
    if (res.statusCode == 200) {
      setState(() {
        _questions = jsonDecode(res.body);
        _isLoading = false;
      });
    }
  }

  void _openQuestion(Map q) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnswerScreen(question: q, token: _token)),
    );
  }

  void _openAskDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D2240),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20),
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
                  if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;
                  final res = await http.post(
                    Uri.parse("$baseUrl/questions"),
                    headers: {
                      "Content-Type": "application/json",
                      "Authorization": "Bearer $_token"
                    },
                    body: jsonEncode({
                      "title": titleCtrl.text,
                      "content": contentCtrl.text,
                      "category": ""
                    }),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (res.statusCode == 200) {
                    _fetchQuestions();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ Question posted!")));
                  }
                },
                child: const Text("Post", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
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
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE3C39D)))
                  : RefreshIndicator(
                      onRefresh: _fetchQuestions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _questions.length,
                        itemBuilder: (_, i) {
                          final q = _questions[i];
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
                                      const CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Color(0xFF4B6382),
                                        child: Icon(Icons.person, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(q["username"] ?? "",
                                          style: GoogleFonts.robotoCondensed(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: const Color(0xFF071739))),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(q["title"] ?? "",
                                      style: GoogleFonts.robotoCondensed(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF071739))),
                                  const SizedBox(height: 6),
                                  Text(q["content"] ?? "",
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFF071739), fontSize: 13)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.favorite_border,
                                          color: Color(0xFF071739), size: 18),
                                      const SizedBox(width: 4),
                                      Text("${q["likes"] ?? 0}",
                                          style: const TextStyle(color: Color(0xFF071739))),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.chat_bubble_outline,
                                          color: Color(0xFF071739), size: 18),
                                      const SizedBox(width: 4),
                                      const Text("0",
                                          style: TextStyle(color: Color(0xFF071739))),
                                      const Spacer(),
                                      const Icon(Icons.bookmark_border,
                                          color: Color(0xFF071739), size: 20),
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
  final String token;
  const AnswerScreen({super.key, required this.question, required this.token});

  @override
  State<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends State<AnswerScreen> {
  List _answers = [];
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAnswers();
  }

  Future<void> _fetchAnswers() async {
    final res = await http.get(
        Uri.parse("$baseUrl/questions/${widget.question['id']}/answers"));
    if (res.statusCode == 200) {
      setState(() => _answers = jsonDecode(res.body));
    }
  }

  Future<void> _postAnswer() async {
    if (_ctrl.text.isEmpty) return;
    final res = await http.post(
      Uri.parse("$baseUrl/questions/${widget.question['id']}/answers"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${widget.token}"
      },
      body: jsonEncode({"content": _ctrl.text}),
    );
    if (res.statusCode == 200) {
      _ctrl.clear();
      _fetchAnswers();
    }
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
        title: Text("Answer",
            style: GoogleFonts.agbalumo(
                color: const Color(0xFFE3C39D), fontSize: 24)),
      ),
      body: Column(
        children: [
          // السؤال
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
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF4B6382),
                      child: Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(widget.question["username"] ?? "",
                        style: GoogleFonts.robotoCondensed(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF071739))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(widget.question["title"] ?? "",
                    style: GoogleFonts.robotoCondensed(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF071739))),
                const SizedBox(height: 6),
                Text(widget.question["content"] ?? "",
                    style: const TextStyle(color: Color(0xFF071739))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.favorite_border,
                        color: Color(0xFF071739), size: 18),
                    const SizedBox(width: 4),
                    Text("${widget.question["likes"] ?? 0}",
                        style: const TextStyle(color: Color(0xFF071739))),
                    const SizedBox(width: 16),
                    const Icon(Icons.chat_bubble_outline,
                        color: Color(0xFF071739), size: 18),
                    const SizedBox(width: 4),
                    Text("${_answers.length}",
                        style: const TextStyle(color: Color(0xFF071739))),
                    const Spacer(),
                    const Icon(Icons.bookmark_border,
                        color: Color(0xFF071739), size: 20),
                  ],
                ),
              ],
            ),
          ),
          // الأجوبة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Answers",
                  style: GoogleFonts.agbalumo(
                      color: Colors.white, fontSize: 20)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _answers.length,
              itemBuilder: (_, i) {
                final a = _answers[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFA68868),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a["username"] ?? "",
                          style: GoogleFonts.robotoCondensed(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF071739))),
                      const SizedBox(height: 6),
                      Text(a["content"] ?? "",
                          style: const TextStyle(color: Color(0xFF071739))),
                    ],
                  ),
                );
              },
            ),
          ),
          // كتابة جواب
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
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
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