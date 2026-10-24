import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/errors.dart';

/// Native Google account chooser, returning the ID token Supabase needs.
/// Behind an interface so the sign-in flow can be tested without Google.
abstract class GoogleIdTokenProvider {
  /// The ID token for the account the user picks, or `null` if they cancelled.
  /// Throws [GoogleSignInUnavailable] when Google sign-in is not configured.
  Future<String?> fetchIdToken();

  Future<void> signOut();
}

/// Uses `google_sign_in` 7.x: one `initialize` with the **Web** client ID as
/// `serverClientId` (not the Android client ID), then `authenticate`.
class GoogleSignInTokenProvider implements GoogleIdTokenProvider {
  GoogleSignInTokenProvider(this._serverClientId);

  final String? _serverClientId;
  Future<void>? _initialized;

  Future<void> _initialize() async {
    final pending = _initialized ??= GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    try {
      await pending;
    } catch (_) {
      _initialized = null;
      rethrow;
    }
  }

  @override
  Future<String?> fetchIdToken() async {
    if (_serverClientId == null) throw const GoogleSignInUnavailable();
    await _initialize();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const GoogleSignInUnavailable();
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (_initialized == null) return;
    await GoogleSignIn.instance.signOut();
  }
}

/// The Web client ID from `.env` (`GOOGLE_WEB_CLIENT_ID`); set in `main()`.
final googleWebClientIdProvider = Provider<String?>((ref) => null);

final googleIdTokenProvider = Provider<GoogleIdTokenProvider>(
  (ref) => GoogleSignInTokenProvider(ref.watch(googleWebClientIdProvider)),
);
