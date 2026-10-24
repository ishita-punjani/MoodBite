import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every network call goes through this so a slow network never hangs a screen.
const networkTimeout = Duration(seconds: 15);

/// Messages raised on purpose by our SQL functions (`raise exception ...`).
/// They are already user-friendly, so they are shown as-is.
const _friendlyServerMessages = {
  'We deliver only in Mumbai',
  'Enter a price between 1 and 5000',
  'Choose a delivery address',
  'Your cart is empty',
  'Please sign in to place an order',
  'This restaurant is not taking orders right now',
  'Too many items in one order',
  'Each dish can appear only once in an order',
  'Quantity must be between 1 and 10, and all items must be from this restaurant',
};

/// Google sign-in cannot run: no web client ID in `.env`, or Google returned
/// no ID token.
class GoogleSignInUnavailable implements Exception {
  const GoogleSignInUnavailable();
}

/// Converts any error into a short message that is safe to show on screen.
/// Raw exception text is never shown to the user.
String friendlyError(Object error) {
  if (error is TimeoutException) {
    return 'This is taking too long. Check your connection and try again.';
  }
  if (error is SocketException || error is HttpException) {
    return 'No internet connection. Check your network and try again.';
  }
  if (error is AuthException) return _authMessage(error);
  if (error is GoogleSignInUnavailable) return _googleUnavailable;
  if (error is GoogleSignInException) return _googleMessage(error);
  if (error is PostgrestException) {
    if (_friendlyServerMessages.contains(error.message)) return error.message;
    return 'Something went wrong on our side. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}

const _googleUnavailable = 'Google sign-in is not available right now. Use your email instead.';

String _googleMessage(GoogleSignInException error) => switch (error.code) {
      GoogleSignInExceptionCode.interrupted => 'Google sign-in was interrupted. Please try again.',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError ||
      GoogleSignInExceptionCode.uiUnavailable =>
        _googleUnavailable,
      _ => 'Could not sign in with Google. Please try again.',
    };

String _authMessage(AuthException error) {
  final code = error.code ?? '';
  if (code == 'otp_expired' || code == 'invalid_credentials') {
    return 'That code is wrong or has expired. Check it or request a new one.';
  }
  if (error.statusCode == '429' || code.contains('rate_limit')) {
    return 'Too many attempts. Please wait a minute and try again.';
  }
  if (code == 'email_address_invalid') return 'Enter a valid email address';
  if (code == 'provider_disabled') return _googleUnavailable;
  if (code == 'signup_disabled' || code == 'otp_disabled') {
    return 'Email sign-in is not available right now.';
  }
  return 'Could not sign you in. Please try again.';
}
