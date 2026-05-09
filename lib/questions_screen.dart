import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
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

  String _searchQuery = '';

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

    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/questions/${q['id']}/like'),
      headers: {'Authorization': 'Bearer $token'},
    );

    debugPrint('LIKE STATUS: ${res.statusCode}');
    debugPrint('LIKE BODY: ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      setState(() {
        _questions[index]['is_liked'] = data['liked'];
        _questions[index]['likes'] = data['likes'];
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
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.red),
          ),
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
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      if (!mounted) return;

      setState(() {
        _questions.removeWhere((item) => item['id'] == q['id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Question deleted")),
      );
    } else {
      throw Exception(response.body);
    }
  } catch (e) {
    debugPrint("DELETE QUESTION ERROR: $e");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ Error: $e")),
    );
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

                        debugPrint(
                            'POST QUESTION STATUS: ${response.statusCode}');
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
            child: Icon(
              Icons.play_circle,
              color: Color(0xFFE3C39D),
              size: 55,
            ),
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
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFFE3C39D),
                    ),
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
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search for a question...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white54),
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
                      child: CircularProgressIndicator(
                        color: Color(0xFFE3C39D),
                      ),
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
                                      color: const Color(0xFFE3C39D),
                                      borderRadius: BorderRadius.circular(16),
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
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: const Color(0xFF071739),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _timeAgo(q['created_at']
                                                  ?.toString()),
                                              style: const TextStyle(
                                                color: Color(0xFF4A4A4A),
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _deleteQuestion(q),
                                              child: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 18,
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
  final FocusNode _answerFocusNode = FocusNode();

  bool _isPosting = false;

  String? replyingToAnswerId;
  String? replyingToUsername;

  @override
  void initState() {
    super.initState();
    _fetchAnswers();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _answerFocusNode.dispose();
    super.dispose();
  }

  String? _parentIdOf(Map a) {
    final value = a['parent_answer_id'] ??
        a['parent_comment_id'] ??
        a['parent_id'] ??
        a['reply_to_answer_id'] ??
        a['reply_id'];

    if (value == null) return null;

    final text = value.toString();
    if (text.isEmpty || text == 'null') return null;

    return text;
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
      debugPrint("ANSWERS DATA: $data");

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
      final bodyData = {
        "content": _ctrl.text.trim(),
        "parent_answer_id": replyingToAnswerId,
      };

      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/questions/${widget.question['id']}/answers',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode >= 400) {
        throw Exception(response.body);
      }

      _ctrl.clear();

      if (!mounted) return;
      setState(() {
        replyingToAnswerId = null;
        replyingToUsername = null;
      });

      await _fetchAnswers();
    } catch (e) {
      debugPrint("Error posting answer: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Map<String, Map<String, dynamic>> get _answersMap {
    return {
      for (final a in _answers) a['id'].toString(): Map<String, dynamic>.from(a),
    };
  }

  Widget _buildParentAnswerPreview(Map<String, dynamic> a) {
    final parentId = _parentIdOf(a);
    if (parentId == null) return const SizedBox.shrink();

    final parent = _answersMap[parentId];
    final parentProfile = parent?['profiles'];

    final parentUsername = parent?['username']?.toString() ??
        parentProfile?['username']?.toString() ??
        '';

    final parentContent = parent?['content']?.toString() ?? '';

    if (parentUsername.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF6C94C6).withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parentUsername,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF5B7FA6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            parentContent.length > 60
                ? '${parentContent.substring(0, 60)}...'
                : parentContent,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswer(Map<String, dynamic> a, bool isReply) {
  final aProfile = a['profiles'];

  final aUsername = a['username']?.toString() ??
      aProfile?['username']?.toString() ??
      'User';

  final aProfileImage = a['profile_image']?.toString() ??
      aProfile?['profile_image']?.toString() ??
      '';

  return Padding(
   padding: EdgeInsets.only(
    bottom: 6,
    left: isReply ? 60 : 0,  
    top: isReply ? 0 : 4,
  ),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
  color: isReply
      ? const Color(0xFFCFA882)
      : const Color(0xFFA17E5A),
  borderRadius: BorderRadius.circular(12),
  border: isReply
      ? const Border(
          left: BorderSide(
            color: Color(0xFF6C94C6),
            width: 5, 
          ),
        )
      : null,
),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 13 : 16,
            backgroundImage: aProfileImage.isNotEmpty
                ? NetworkImage(aProfileImage)
                : null,
            backgroundColor: const Color(0xFF6C94C6),
            child: aProfileImage.isEmpty
                ? Icon(Icons.person,
                    size: isReply ? 13 : 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aUsername,
                  style: GoogleFonts.robotoCondensed(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (isReply) _buildParentAnswerPreview(a),
                Text(
                  a['content']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (!isReply)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        replyingToAnswerId = a['id'].toString();
                        replyingToUsername = aUsername;
                      });
                      FocusScope.of(context).requestFocus(_answerFocusNode);
                    },
                    child: const Text(
                      'Reply',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE3C39D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  List<Widget> _buildAnswersTree() {
  final parentAnswers =
      _answers.where((a) => _parentIdOf(a) == null).toList();

  final widgets = <Widget>[];

  for (final parent in parentAnswers) {
    final parentMap = Map<String, dynamic>.from(parent);
    widgets.add(_buildAnswer(parentMap, false));

    final replies = _answers.where((a) {
      return _parentIdOf(a) == parentMap['id'].toString();
    }).toList();

    for (final reply in replies) {
      widgets.add(_buildAnswer(Map<String, dynamic>.from(reply), true));
    }
  }

  return widgets;
}
  @override
  Widget build(BuildContext context) {
    final profile = widget.question['profiles'];

    final questionUsername = widget.question['username']?.toString() ??
        profile?['username']?.toString() ??
        '';

    final questionProfileImage = widget.question['profile_image']?.toString() ??
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
        title: Text(
          "Answers",
          style: GoogleFonts.agbalumo(
            color: const Color(0xFFE3C39D),
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
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
                      backgroundImage: questionProfileImage.isNotEmpty
                          ? NetworkImage(questionProfileImage)
                          : null,
                      backgroundColor: const Color(0xFF4B6382),
                      child: questionProfileImage.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      questionUsername,
                      style: GoogleFonts.robotoCondensed(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF071739),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.question["title"]?.toString() ?? "",
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF071739),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.question["content"]?.toString() ?? "",
                  style: const TextStyle(color: Color(0xFF071739)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      color: Color(0xFF071739),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${widget.question["likes"] ?? 0}",
                      style: const TextStyle(color: Color(0xFF071739)),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFF071739),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${_answers.length}",
                      style: const TextStyle(color: Color(0xFF071739)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Answers (${_answers.length})",
                style: GoogleFonts.agbalumo(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
          ),

          Expanded(
            child: _answers.isEmpty
                ? const Center(
                    child: Text(
                      "No answers yet",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _buildAnswersTree(),
                  ),
          ),

          if (replyingToUsername != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3C39D),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Replying to $replyingToUsername",
                      style: const TextStyle(
                        color: Color(0xFF071739),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        replyingToAnswerId = null;
                        replyingToUsername = null;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF071739),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: const Color(0xFF0D2240),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _answerFocusNode,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: replyingToUsername == null
                            ? "Write your answer..."
                            : "Write your reply...",
                        hintStyle: const TextStyle(color: Colors.white38),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: InputBorder.none,
                      ),
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
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF6C94C6),
                          Color(0xFF4A6FA5),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: _isPosting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
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
