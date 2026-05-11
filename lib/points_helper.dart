import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<void> addPoints(int userId, int points) async {
  try {
    final user = await supabase
        .from('users')
        .select('points')
        .eq('id', userId)
        .single();

    final currentPoints = (user['points'] ?? 0) as int;

    await supabase.from('users').update({
      'points': currentPoints + points,
    }).eq('id', userId);
  } catch (e) {
    print('❌ addPoints error: $e');
  }
}