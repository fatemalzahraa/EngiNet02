import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'app_exception.dart';

class ApiService {
  static Future<T> call<T>(Future<T> Function() fn) async {
    try {
      return await fn().timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const AppException('Request timed out. Try again.');
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    return call(() => http.get(uri, headers: headers));
  }

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return call(() => http.post(uri, headers: headers, body: body));
  }
}