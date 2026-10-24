import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/core/errors.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/auth/auth_repository.dart';
import 'package:moodbite/features/auth/sign_in_screen.dart';
import 'package:moodbite/features/auth/verify_otp_screen.dart';
import 'package:moodbite/features/profile/profile_form_screen.dart';
import 'package:moodbite/features/profile/profile_repository.dart';
import 'package:moodbite/widgets/brand.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signed-out auth that records calls and never touches the network.
class FakeAuthRepository implements AuthRepository {
  final sentTo = <String>[];
  int googleCalls = 0;

  /// Behaviour of the Google button; defaults to a successful sign-in.
  Future<bool> Function() onGoogle = () async => true;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> sendEmailOtp(String email) async => sentTo.add(email);

  @override
  Future<void> verifyEmailOtp({required String email, required String code}) async {}

  @override
  Future<bool> signInWithGoogle() {
    googleCalls++;
    return onGoogle();
  }

  @override
  Future<void> signOut() async {}
}

class UnusedProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget wrap(Widget child, FakeAuthRepository auth) => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(UnusedProfileRepository()),
      ],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

void main() {
  testWidgets('sign-in: empty and invalid email show messages and send nothing', (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(wrap(const SignInScreen(), auth));

    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('Enter your email address'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(auth.sentTo, isEmpty);
  });

  testWidgets('sign-in: the MoodBite logo is shown above the form', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const SignInScreen(), FakeAuthRepository()));
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.bySemanticsLabel('MoodBite logo'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('profile form: the avatar shows initials of the typed name, a person icon when empty', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const ProfileFormScreen(isOnboarding: true), FakeAuthRepository()));
    expect(find.byIcon(Icons.person), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'ishaan patel');
    await tester.pump();
    expect(find.text('IP'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('sign-in: field has a label and a hint', (tester) async {
    await tester.pumpWidget(wrap(const SignInScreen(), FakeAuthRepository()));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('you@example.com'), findsOneWidget);
  });

  testWidgets('verify: short code is rejected and resend starts on cooldown', (tester) async {
    await tester.pumpWidget(wrap(const VerifyOtpScreen(email: 'a@b.com'), FakeAuthRepository()));
    expect(find.text('Resend code in 30s'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('Verify and continue'));
    await tester.pump();
    expect(find.text('Enter the 6-digit code'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Resend code'), findsOneWidget);
  });

  testWidgets('profile form: required fields and phone format are validated', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const ProfileFormScreen(isOnboarding: true), FakeAuthRepository()));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter your mobile number'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), '12345');
    await tester.enterText(find.widgetWithText(TextFormField, 'Usual max price per dish (optional)'), '9999');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
    expect(find.text('Enter a price between 1 and 5000'), findsOneWidget);
  });

  test('fake auth never completes a sign-in', () async {
    final auth = FakeAuthRepository();
    await auth.sendEmailOtp('x@y.com');
    expect(auth.sentTo, ['x@y.com']);
    expect(await auth.authStateChanges.isEmpty, isTrue);
    unawaited(auth.signOut());
  });

  group('Google sign-in button', () {
    testWidgets('is shown next to the email form and calls the repository', (tester) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(wrap(const SignInScreen(), auth));
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(auth.googleCalls, 1);
      expect(auth.sentTo, isEmpty);
    });

    testWidgets('shows a loading state and blocks both sign-in buttons while it runs', (tester) async {
      final auth = FakeAuthRepository();
      final pending = Completer<bool>();
      auth.onGoogle = () => pending.future;
      await tester.pumpWidget(wrap(const SignInScreen(), auth));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Continue with Google'));
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(auth.googleCalls, 1);
      expect(auth.sentTo, isEmpty);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('closing the account chooser shows no error', (tester) async {
      final auth = FakeAuthRepository()..onGoogle = () async => false;
      await tester.pumpWidget(wrap(const SignInScreen(), auth));
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Google sign-in'), findsNothing);
      expect(find.textContaining('Could not'), findsNothing);
    });

    testWidgets('a Google failure shows a friendly message and email still works', (tester) async {
      final auth = FakeAuthRepository()..onGoogle = () async => throw const GoogleSignInUnavailable();
      await tester.pumpWidget(wrap(const SignInScreen(), auth));
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Google sign-in is not available right now. Use your email instead.'), findsOneWidget);
      expect(find.textContaining('GoogleSignInUnavailable'), findsNothing);

      await tester.enterText(find.byType(TextFormField), 'priya@example.com');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(auth.sentTo, ['priya@example.com']);
    });

    testWidgets('an unexpected error never shows raw exception text', (tester) async {
      final auth = FakeAuthRepository()..onGoogle = () async => throw StateError('boom 12345');
      await tester.pumpWidget(wrap(const SignInScreen(), auth));
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });
  });
}
