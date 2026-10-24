import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../models/profile.dart';
import '../profile/profile_repository.dart';
import 'auth_repository.dart';

enum SessionStatus { signedOut, loading, needsProfile, ready, error }

/// Tracks sign-in state plus whether the profile is complete. The router
/// listens to it to decide which screen to show.
class SessionController extends ChangeNotifier {
  SessionController(this._auth, this._profiles) {
    _subscription = _auth.authStateChanges.listen(_onAuthChange);
    if (_auth.currentUser != null) {
      unawaited(loadProfile());
    } else {
      _status = SessionStatus.signedOut;
    }
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  late final StreamSubscription<AuthState> _subscription;

  SessionStatus _status = SessionStatus.loading;
  Profile? _profile;
  String? _errorMessage;

  SessionStatus get status => _status;
  Profile? get profile => _profile;
  String? get errorMessage => _errorMessage;

  void _onAuthChange(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
        unawaited(loadProfile());
      case AuthChangeEvent.signedOut:
        _profile = null;
        _set(SessionStatus.signedOut);
      default:
        break;
    }
  }

  Future<void> loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      _set(SessionStatus.signedOut);
      return;
    }
    _set(SessionStatus.loading);
    try {
      _profile = await _profiles.fetchMine(user.id);
      _set(_profile!.isComplete ? SessionStatus.ready : SessionStatus.needsProfile);
    } catch (e) {
      _errorMessage = friendlyError(e);
      _set(SessionStatus.error);
    }
  }

  /// Called after the profile form saves successfully.
  void updateProfile(Profile profile) {
    _profile = profile;
    _set(profile.isComplete ? SessionStatus.ready : SessionStatus.needsProfile);
  }

  void _set(SessionStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final sessionControllerProvider = Provider<SessionController>((ref) {
  final controller = SessionController(
    ref.watch(authRepositoryProvider),
    ref.watch(profileRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
