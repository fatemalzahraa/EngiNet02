import 'dart:convert';
import 'dart:io';
import 'package:enginet/core/constants.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class QuestionsRepository {
  Future<List> fetchQuestions() async {
    final token = await SessionManager.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/questions'),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) throw Exception('Failed to fetch questions');
    return jsonDecode(response.body) as List;
  }

  Future<List> fetchAnswers(dynamic questionId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/questions/$questionId/answers'),
    );
    if (response.statusCode != 200) throw Exception('Failed to fetch answers');
    return jsonDecode(response.body) as List;
  }

  Future<Map<String, dynamic>> likeQuestion(dynamic questionId) async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/questions/$questionId/like'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  Future<void> saveQuestion(dynamic questionId) async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    await http.post(
      Uri.parse('${AppConstants.baseUrl}/questions/$questionId/save'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> deleteQuestion(dynamic questionId) async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/questions/$questionId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<void> postQuestion({
    required String title,
    required String content,
    File? media,
    String? mediaName,
    String? mediaType,
  }) async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.baseUrl}/questions'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['content'] = content;
    request.fields['category'] = '';
    if (media != null) {
      final isImage = mediaType == 'image';
      request.files.add(await http.MultipartFile.fromPath(
        'media', media.path,
        filename: mediaName,
        contentType: MediaType(isImage ? 'image' : 'video', isImage ? 'jpeg' : 'mp4'),
      ));
    }
    final response = await request.send();
    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      throw Exception(body);
    }
  }

  Future<void> postAnswer({
    required dynamic questionId,
    required String content,
    String? parentAnswerId,
  }) async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/questions/$questionId/answers'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'content': content, 'parent_answer_id': parentAnswerId}),
    );
    if (response.statusCode >= 400) throw Exception(response.body);
  }

  Future<void> editAnswer(dynamic answerId, String content, dynamic parentAnswerId) async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    final res = await http.put(
      Uri.parse('${AppConstants.baseUrl}/questions/answers/$answerId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'content': content, 'parent_answer_id': parentAnswerId}),
    );
    if (res.statusCode >= 400) throw Exception(res.body);
  }

  Future<void> deleteAnswer(dynamic answerId) async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/questions/answers/$answerId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 400) throw Exception(res.body);
  }
}
