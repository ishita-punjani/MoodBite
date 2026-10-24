import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thrown when `.env` is missing or lacks a required value.
/// The message only ever contains variable NAMES, never values.
class EnvException implements Exception {
  const EnvException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client-safe configuration read from `.env` at runtime.
class Env {
  const Env({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.googleWebClientId,
  });

  static const requiredKeys = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Web OAuth client ID for Google sign-in. Optional: without it the Google
  /// button explains it is unavailable and email OTP keeps working.
  final String? googleWebClientId;

  /// Builds config from a key/value map. Throws [EnvException] naming any
  /// missing required keys.
  factory Env.fromMap(Map<String, String> values) {
    String? read(String key) {
      final value = values[key]?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    final missing = requiredKeys.where((key) => read(key) == null).toList();
    if (missing.isNotEmpty) {
      throw EnvException('Missing values in .env: ${missing.join(', ')}');
    }
    return Env(
      supabaseUrl: read('SUPABASE_URL')!,
      supabaseAnonKey: read('SUPABASE_ANON_KEY')!,
      googleWebClientId: read('GOOGLE_WEB_CLIENT_ID'),
    );
  }

  /// Loads the bundled `.env` asset.
  static Future<Env> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      throw const EnvException(
        'Could not load .env. Copy .env.example to .env and fill in the values.',
      );
    }
    return Env.fromMap(dotenv.env);
  }
}
