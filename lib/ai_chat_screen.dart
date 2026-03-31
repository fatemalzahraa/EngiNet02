import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  static const String _apiKey = "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";

  static const String _systemPrompt = """
أنت مساعد ذكاء اصطناعي متخصص في مجال الهندسة والبرمجة لمنصة EngiNet.
مهمتك مساعدة الطلاب والمهندسين في:
- الأسئلة الهندسية والتقنية
- شرح مفاهيم البرمجة
- تحليل الكود وإيجاد الأخطاء
- اقتراح الكورسات والمصادر التعليمية
- الإجابة على أسئلة الرياضيات والفيزياء

أجب دائماً بشكل واضح ومفيد. يمكنك الإجابة بالعربية أو الإنجليزية حسب لغة السؤال.
""";

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final apiMessages = _messages
          .where((m) => m["role"] != "error")
          .map((m) => {
                "role": m["role"] == "assistant" ? "model" : "user",
                "parts": [{"text": m["content"]!}]
              })
          .toList();

      // أضف الـ system prompt كأول رسالة
      apiMessages.insert(0, {
        "role": "user",
        "parts": [{"text": _systemPrompt}]
      });

      final response = await http.post(
  Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
  headers: {
    "Content-Type": "application/json",
    "Authorization": "Bearer $_apiKey"
  },
  body: jsonEncode({
    "model": "llama-3.3-70b-versatile",
    "max_tokens": 1024,
    "messages": [
      {"role": "system", "content": _systemPrompt},
      ..._messages
          .where((m) => m["role"] != "error")
          .map((m) => {"role": m["role"]!, "content": m["content"]!}),
    ],
  }),
);

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  final reply = data["choices"][0]["message"]["content"].toString();
  setState(() {
    _messages.add({"role": "assistant", "content": reply});
    _isLoading = false;
  });
} else {
  final error = jsonDecode(response.body);
  setState(() {
    _messages.add({
      "role": "error",
      "content": "❌ خطأ: ${error['error']?['message'] ?? 'حدث خطأ غير متوقع'}"
    });
    _isLoading = false;
  });
}
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "error",
          "content": "❌ تعذّر الاتصال. تحقق من الإنترنت."
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

  void _clearChat() => setState(() => _messages.clear());

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
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
                  color: const Color(0xFFE3C39D),
                ),
              ),
              const Text(
                "Powered by Gemini",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _clearChat,
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 20),
          Text(
            "مرحباً! أنا EngiNet AI",
            style: GoogleFonts.agbalumo(
              color: const Color(0xFFE3C39D),
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "اسألني عن الهندسة، البرمجة،\nالكورسات، أو أي شيء تقني!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 30),
          _buildSuggestedQuestion("ما هي أفضل لغة برمجة للمبتدئين؟"),
          _buildSuggestedQuestion("اشرح لي مفهوم OOP ببساطة"),
          _buildSuggestedQuestion("كيف أتعلم Flutter من الصفر؟"),
        ],
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
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4A6FA5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                color: Color(0xFFE3C39D), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg) {
    final isUser = msg["role"] == "user";
    final isError = msg["role"] == "error";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
                ),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFF5C1A1A)
                    : isUser
                        ? const Color(0xFF4A6FA5)
                        : const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: !isUser && !isError
                    ? Border.all(color: const Color(0xFF2A4A6F))
                    : null,
              ),
              child: Text(
                msg["content"] ?? '',
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
              backgroundColor: Color(0xFFE3C39D),
              child: Icon(Icons.person, color: Colors.black, size: 18),
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
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
              ),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: const Color(0xFF2A4A6F)),
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
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF4A6FA5)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: "اسألني أي شيء...",
                  hintStyle: TextStyle(color: Colors.white38),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C94C6), Color(0xFF4A6FA5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

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