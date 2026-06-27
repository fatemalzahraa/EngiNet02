import 'package:flutter_test/flutter_test.dart';
import 'package:enginet/main.dart';

void main() {
  testWidgets('Shows config error when Supabase keys are missing', (tester) async {
    await tester.pumpWidget(const MissingSupabaseConfigApp());
    expect(find.textContaining('Supabase'), findsOneWidget);
  });
}
