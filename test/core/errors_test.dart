import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moodbite/core/errors.dart';
import 'package:moodbite/features/browse/catalogue_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('friendlyError', () {
    test('network problems', () {
      expect(friendlyError(TimeoutException('x')), contains('taking too long'));
      expect(friendlyError(const SocketException('x')), contains('No internet'));
    });

    test('auth errors never leak raw text', () {
      expect(friendlyError(const AuthException('Token has expired or is invalid', code: 'otp_expired')),
          contains('wrong or has expired'));
      expect(friendlyError(const AuthException('rate', statusCode: '429')), contains('Too many attempts'));
      expect(friendlyError(const AuthException('internal stack trace')), 'Could not sign you in. Please try again.');
    });

    test('Google sign-in errors map to friendly messages', () {
      const unavailable = 'Google sign-in is not available right now. Use your email instead.';
      expect(friendlyError(const GoogleSignInUnavailable()), unavailable);
      expect(
        friendlyError(const GoogleSignInException(code: GoogleSignInExceptionCode.clientConfigurationError)),
        unavailable,
      );
      expect(
        friendlyError(const GoogleSignInException(code: GoogleSignInExceptionCode.providerConfigurationError)),
        unavailable,
      );
      expect(
        friendlyError(const GoogleSignInException(code: GoogleSignInExceptionCode.interrupted)),
        'Google sign-in was interrupted. Please try again.',
      );
      expect(
        friendlyError(const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError, description: 'x')),
        'Could not sign in with Google. Please try again.',
      );
      expect(friendlyError(const AuthException('off', code: 'provider_disabled')), unavailable);
    });

    test('our own SQL messages pass through, others are hidden', () {
      expect(friendlyError(const PostgrestException(message: 'We deliver only in Mumbai', code: 'P0001')),
          'We deliver only in Mumbai');
      expect(friendlyError(const PostgrestException(message: 'relation "x" does not exist', code: '42P01')),
          'Something went wrong on our side. Please try again.');
      expect(friendlyError(StateError('boom')), 'Something went wrong. Please try again.');
    });
  });

  group('sanitizeSearch', () {
    test('removes characters that would break PostgREST filters', () {
      expect(CatalogueRepository.sanitizeSearch('  pav,bhaji (cheese)* % '), 'pav bhaji cheese');
      expect(CatalogueRepository.sanitizeSearch("Jaffer Bhai's"), "Jaffer Bhai's");
      expect(CatalogueRepository.sanitizeSearch('Britannia & Co.'), 'Britannia & Co.');
      expect(CatalogueRepository.sanitizeSearch('बिरयानी'), 'बिरयानी');
    });
  });
}
