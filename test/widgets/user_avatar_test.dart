import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodbite/core/router.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/auth/session_controller.dart';
import 'package:moodbite/models/profile.dart';
import 'package:moodbite/widgets/user_avatar.dart';

class FakeSession extends ChangeNotifier implements SessionController {
  FakeSession(this.profile);

  @override
  final Profile? profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('initialsFor', () {
    test('first and last word, upper case', () {
      expect(initialsFor('Priya Sharma'), 'PS');
      expect(initialsFor('  priya   kumari  sharma '), 'PS');
    });

    test('a single name gives one letter', () => expect(initialsFor('priya'), 'P'));

    test('empty or missing name gives no initials', () {
      expect(initialsFor(null), '');
      expect(initialsFor('   '), '');
    });

    test('does not crash on Devanagari names', () => expect(initialsFor('प्रिया शर्मा'), isNotEmpty));
  });

  group('avatarColorFor', () {
    test('is stable for the same name, ignoring case and spaces at the ends', () {
      expect(avatarColorFor('Priya Sharma'), avatarColorFor('  priya sharma '));
    });

    test('always comes from the palette', () {
      for (final name in ['A', 'Priya', 'Rohan Mehta', 'D\'Souza', '']) {
        expect(AppColors.avatarPalette, contains(avatarColorFor(name)));
      }
    });

    test('different names are not all the same colour', () {
      final colours = {for (final n in ['Aarav', 'Bina', 'Chirag', 'Divya', 'Esha', 'Farhan']) avatarColorFor(n)};
      expect(colours.length, greaterThan(1));
    });
  });

  testWidgets('UserAvatar shows the initials with a screen-reader label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const Scaffold(body: UserAvatar(name: 'Priya Sharma'))));
    expect(find.text('PS'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile picture, initials PS'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('UserAvatar without a name shows a person icon', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const Scaffold(body: UserAvatar(name: null))));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('the app bar avatar button is 48dp, shows the initials and opens the profile', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(appBar: AppBar(title: const Text('Tab'), actions: const [ProfileAvatarButton()])),
      ),
      GoRoute(path: AppRoutes.profile, builder: (context, state) => const Scaffold(body: Text('profile page'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionControllerProvider.overrideWithValue(FakeSession(const Profile(id: 'u1', fullName: 'Ishaan Patel')))],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('IP'), findsOneWidget);
    final size = tester.getSize(find.ancestor(of: find.byType(UserAvatar), matching: find.byType(SizedBox)).first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(ProfileAvatarButton));
    await tester.pumpAndSettle();
    expect(find.text('profile page'), findsOneWidget);
  });
}
