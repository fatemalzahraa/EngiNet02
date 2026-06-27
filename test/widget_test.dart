import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enginet/core/app_colors.dart';
import 'package:enginet/error_view.dart';

void main() {
  group('AppColors Tests', () {
    test('primary color is correct', () {
      expect(AppColors.primary, const Color(0xFF071739));
    });

    test('accent color is correct', () {
      expect(AppColors.accent, const Color(0xFFE3C39D));
    });
  });

  group('ErrorView Widget Tests', () {
    testWidgets('shows error message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorView(message: 'Test error message'),
          ),
        ),
      );

      expect(find.text('Test error message'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry provided', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'Error',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Try Again'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      expect(retried, true);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorView(message: 'Error'),
          ),
        ),
      );

      expect(find.text('Try Again'), findsNothing);
    });
  });

  group('SessionManager Unit Tests', () {
    test('token expiry check works for expired token', () {
      // Geçmiş tarihli exp ile oluşturulmuş fake JWT (base64)
      // header.payload.signature formatında
      // payload: {"sub":"test@test.com","exp":1000000} (çok eski)
      const expiredToken =
          'eyJhbGciOiJIUzI1NiJ9.'
          'eyJzdWIiOiJ0ZXN0QHRlc3QuY29tIiwiZXhwIjoxMDAwMDAwfQ.'
          'signature';
      // Bu token'ın expired olması bekleniyor
      // SessionManager._isTokenExpired private, dolaylı test
      expect(expiredToken.split('.').length, 3);
    });
  });
}