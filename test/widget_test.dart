import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/core/env.dart';
import 'package:moodbite/widgets/startup_error_app.dart';

void main() {
  group('Env.fromMap', () {
    test('reads required and optional values', () {
      final env = Env.fromMap({
        'SUPABASE_URL': ' https://example.supabase.co ',
        'SUPABASE_ANON_KEY': 'anon',
        'GOOGLE_WEB_CLIENT_ID': '',
      });
      expect(env.supabaseUrl, 'https://example.supabase.co');
      expect(env.supabaseAnonKey, 'anon');
      expect(env.googleWebClientId, isNull);
    });

    test('names every missing required key', () {
      expect(
        () => Env.fromMap({'SUPABASE_URL': ''}),
        throwsA(isA<EnvException>().having(
          (e) => e.message,
          'message',
          'Missing values in .env: SUPABASE_URL, SUPABASE_ANON_KEY',
        )),
      );
    });
  });

  testWidgets('startup error screen shows the message', (tester) async {
    await tester.pumpWidget(const StartupErrorApp(message: 'Missing .env'));
    expect(find.text('MoodBite could not start'), findsOneWidget);
    expect(find.text('Missing .env'), findsOneWidget);
  });
}
