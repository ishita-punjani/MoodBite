import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/supabase_providers.dart';
import 'google_sign_in_service.dart';

class AuthRepository {
  const AuthRepository(this._auth, this._google);

  final GoTrueClient _auth;
  final GoogleIdTokenProvider _google;

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Emails a 6-digit code. Creates the account on first sign-in.
  Future<void> sendEmailOtp(String email) => _auth
      .signInWithOtp(email: email.trim(), shouldCreateUser: true)
      .timeout(networkTimeout);

  Future<void> verifyEmailOtp({required String email, required String code}) =>
      _auth
          .verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.email)
          .timeout(networkTimeout);

  /// Google account chooser, then Supabase `signInWithIdToken`. Returns false
  /// if the user closed the chooser. The session arrives through
  /// [authStateChanges], like the email flow.
  Future<bool> signInWithGoogle() async {
    final idToken = await _google.fetchIdToken();
    if (idToken == null) return false;
    await _auth
        .signInWithIdToken(provider: OAuthProvider.google, idToken: idToken)
        .timeout(networkTimeout);
    return true;
  }

  Future<void> signOut() async {
    await _auth.signOut().timeout(networkTimeout);
    try {
      await _google.signOut();
    } catch (_) {
      // The app session is already closed; a Google-side failure only means
      // the account chooser may remember the last account.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider).auth, ref.watch(googleIdTokenProvider)),
);
