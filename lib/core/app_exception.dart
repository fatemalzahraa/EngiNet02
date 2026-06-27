class AppException implements Exception {
  final String message;
  final String? details;

  const AppException(this.message, {this.details});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException() : super('No internet connection');
}

class AuthException extends AppException {
  const AuthException(String message) : super(message);
}

class ServerException extends AppException {
  const ServerException(String message) : super(message);
}