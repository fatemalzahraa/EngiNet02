import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enginet/core/session_manager.dart';
import 'dart:convert';
import 'package:enginet/core/app_colors.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Her mesaj artık: role, content, ve opsiyonel cards listesi içeriyor
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  String _appContext = "";
  bool _contextLoaded = false;

  // Tüm platform içerikleri (kart gösterimi için)
  List<Map<String, dynamic>> _allCourses = [];
  List<Map<String, dynamic>> _allBooks = [];

  // ✅ Groq is now called via backend — no API key in Flutter
  static const String _backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://enginet02.onrender.com',
  );

  @override
  void initState() {
    super.initState();
    _loadAppContext();
  }

  // ── JWT'den user_id çıkar ───────────────────────────────
  int? _extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];
      final mod = payload.length % 4;
      if (mod != 0) payload += '=' * (4 - mod);
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = utf8.decode(base64.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      // JWT'de genellikle 'sub' veya 'user_id' olur
      final id = map['user_id'] ?? map['sub'];
      if (id == null) return null;
      return int.tryParse(id.toString());
    } catch (_) {
      return null;
    }
  }

  // ── Platform içeriğini Supabase'den çek ─────────────────
  Future<void> _loadAppContext() async {
    try {
      final supabase = Supabase.instance.client;

      final courses = await supabase
          .from('courses')
          .select('id, title, category, description, rating')
          .order('rating', ascending: false)
          .limit(20);

      final books = await supabase
          .from('books')
          .select('id, title, category, description, likes')
          .order('likes', ascending: false)
          .limit(20);

      final articles = await supabase
          .from('articles')
          .select('title, category')
          .order('rating', ascending: false)
          .limit(20);

      _allCourses = List<Map<String, dynamic>>.from(courses);
      _allBooks = List<Map<String, dynamic>>.from(books);

      final sb = StringBuffer();

      sb.writeln("=== Available Courses ===");
      for (final c in courses) {
        sb.writeln(
          "• ${c['title']} [${c['category'] ?? 'General'}]: ${c['description'] ?? ''}",
        );
      }

      sb.writeln("\n=== Available Books ===");
      for (final b in books) {
        sb.writeln(
          "• ${b['title']} [${b['category'] ?? 'General'}]: ${b['description'] ?? ''}",
        );
      }

      sb.writeln("\n=== Available Articles ===");
      for (final a in articles) {
        sb.writeln("• ${a['title']} [${a['category'] ?? 'General'}]");
      }

      // Eski mesaj geçmişini yükle
      await _loadChatHistory();

      setState(() {
        _appContext = sb.toString();
        _contextLoaded = true;
      });
    } catch (e) {
      debugPrint("Error loading context: $e");
      setState(() => _contextLoaded = true);
    }
  }

  // ── Supabase'den eski sohbet geçmişini yükle ────────────
  Future<void> _loadChatHistory() async {
    try {
      final token = await SessionManager.getToken();
      if (token == null) return;
      final userId = _extractUserIdFromToken(token);
      if (userId == null) return;

      final supabase = Supabase.instance.client;
      final history = await supabase
          .from('ai_chat_history')
          .select('role, content')
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(50);

      setState(() {
        _messages.clear();
        for (final row in history) {
          _messages.add({
            "role": row['role'] as String,
            "content": row['content'] as String,
            "cards": <Map<String, dynamic>>[],
          });
        }
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint("Error loading chat history: $e");
    }
  }

  // ── Mesajı Supabase'e kaydet ─────────────────────────────
  Future<void> _saveMsgToSupabase(String role, String content) async {
    try {
      final token = await SessionManager.getToken();
      if (token == null) return;
      final userId = _extractUserIdFromToken(token);
      if (userId == null) return;

      await Supabase.instance.client.from('ai_chat_history').insert({
        'user_id': userId,
        'role': role,
        'content': content,
      });
    } catch (e) {
      debugPrint("Error saving message: $e");
    }
  }

  // ── AI cevabından bahsedilen kurs/kitapları çıkar ────────
  List<Map<String, dynamic>> _extractMentionedCards(String reply) {
    final cards = <Map<String, dynamic>>[];
    final replyLower = reply.toLowerCase();

    for (final course in _allCourses) {
      final title = (course['title'] as String? ?? '').toLowerCase();
      if (title.isNotEmpty && replyLower.contains(title)) {
        cards.add({...course, 'type': 'course'});
        if (cards.length >= 3) break;
      }
    }

    for (final book in _allBooks) {
      final title = (book['title'] as String? ?? '').toLowerCase();
      if (title.isNotEmpty && replyLower.contains(title)) {
        cards.add({...book, 'type': 'book'});
        if (cards.length >= 5) break;
      }
    }

    return cards;
  }

  String get _systemPrompt =>
      """
You are EngiNet AI, a smart assistant for an engineering education platform.

PLATFORM CONTENT:
$_appContext

YOUR CAPABILITIES:
1. Answer engineering and programming questions
2. Recommend courses, books, and articles from the platform based on user needs
3. Explain technical concepts clearly
4. Help with math, physics, and CS topics
5. Support Arabic and English (respond in the same language as the user)

RECOMMENDATION RULES:
- When recommending, mention specific titles from the platform content above (use EXACT titles)
- Explain WHY each recommendation fits the user's need
- Be concise but helpful

Always be friendly, professional, and accurate.
""";

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"role": "user", "content": text, "cards": []});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    _saveMsgToSupabase("user", text);

    try {
      final token = await SessionManager.getToken();

      final conversationMessages = _messages
          .where((m) => m["role"] != "error")
          .map(
            (m) => {
              "role": m["role"] as String,
              "content": m["content"] as String,
            },
          )
          .toList();

      // ✅ استدعاء الـ backend بدل Groq مباشرة
      final response = await http.post(
        Uri.parse("$_backendUrl/ai/chat"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "messages": conversationMessages,
          "system_prompt": _systemPrompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data["reply"].toString();

        final cards = _extractMentionedCards(reply);

        setState(() {
          _messages.add({
            "role": "assistant",
            "content": reply,
            "cards": cards,
          });
          _isLoading = false;
        });

        _saveMsgToSupabase("assistant", reply);
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _messages.add({
            "role": "error",
            "content": "❌ ${error['detail'] ?? 'Unexpected error'}",
            "cards": [],
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "error",
          "content": "❌ Connection error. Check your internet.",
          "cards": [],
        });
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Sohbeti temizle (Supabase'den de sil) ───────────────
  Future<void> _clearChat() async {
    try {
      final token = await SessionManager.getToken();
      if (token != null) {
        final userId = _extractUserIdFromToken(token);
        if (userId != null) {
          await Supabase.instance.client
              .from('ai_chat_history')
              .delete()
              .eq('user_id', userId);
        }
      }
    } catch (e) {
      debugPrint("Error clearing history: $e");
    }
    setState(() => _messages.clear());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_contextLoaded)
              const LinearProgressIndicator(
                backgroundColor: AppColors.cardBg,
                color: AppColors.accent,
              ),
            const Divider(color: Colors.white12),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isLoading) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "EngiNet AI",
                style: GoogleFonts.agbalumo(
                  fontSize: 22,
                  color: AppColors.accent,
                ),
              ),
              Text(
                _contextLoaded
                    ? "Powered by Groq • Platform-aware"
                    : "Loading platform content...",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _clearChat,
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              tooltip: "Clear chat",
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 20),
            Text(
              "Hello! I'm EngiNet AI",
              style: GoogleFonts.agbalumo(
                color: AppColors.accent,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "I know all courses, books & articles\non this platform. Ask me anything!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            _buildSuggestedQuestion(
              "What courses do you recommend for a Flutter beginner?",
            ),
            _buildSuggestedQuestion("اقترح لي كتب برمجة للمبتدئين"),
            _buildSuggestedQuestion(
              "Explain the difference between OOP and functional programming",
            ),
            _buildSuggestedQuestion(
              "ما هي أفضل مقالات الذكاء الاصطناعي في المنصة؟",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestion(String question) {
    return GestureDetector(
      onTap: () {
        _controller.text = question;
        _sendMessage();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4A6FA5)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lightbulb_outline,
              color: AppColors.accent,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isUser = msg["role"] == "user";
    final isError = msg["role"] == "error";
    final cards = ((msg["cards"] as List?)?.cast<Map<String, dynamic>>()) ?? <Map<String, dynamic>>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isError
                        ? const Color(0xFF5C1A1A)
                        : isUser
                        ? const Color(0xFF4A6FA5)
                        : AppColors.cardBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    msg["content"] as String? ?? '',
                    style: TextStyle(
                      color: isError ? Colors.red[300] : Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.accent,
                  child: Icon(Icons.person, color: Colors.black, size: 18),
                ),
              ],
            ],
          ),

          // ── Kurs/Kitap Kartları ──────────────────────────
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 42),
                itemCount: cards.length,
                itemBuilder: (context, i) => _buildContentCard(cards[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Kurs veya Kitap Kartı ────────────────────────────────
  Widget _buildContentCard(Map<String, dynamic> item) {
    final isCourse = item['type'] == 'course';
    final title = item['title'] as String? ?? '';
    final category = item['category'] as String? ?? 'General';
    final description = item['description'] as String? ?? '';

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCourse
              ? const Color(0xFF4A6FA5)
              : AppColors.accent.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCourse ? Icons.play_circle_outline : Icons.menu_book,
                color: isCourse ? const Color(0xFF6C94C6) : AppColors.accent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isCourse ? "Course" : "Book",
                  style: TextStyle(
                    color: isCourse
                        ? const Color(0xFF6C94C6)
                        : AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotAnimation(delay: 0),
                SizedBox(width: 4),
                _DotAnimation(delay: 200),
                SizedBox(width: 4),
                _DotAnimation(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D2240),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF4A6FA5)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: "Ask about courses, books, or any topic...",
                  hintStyle: TextStyle(color: Colors.white38),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
                ),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Dot Animation
// ══════════════════════════════════════════════════════════

class _DotAnimation extends StatefulWidget {
  final int delay;
  const _DotAnimation({required this.delay});

  @override
  State<_DotAnimation> createState() => _DotAnimationState();
}

class _DotAnimationState extends State<_DotAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF6C94C6),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
