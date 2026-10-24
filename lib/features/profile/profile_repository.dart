import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/supabase_providers.dart';
import '../../models/profile.dart';

class ProfileRepository {
  const ProfileRepository(this._client);

  final SupabaseClient _client;

  /// The signed-in user's profile, or an empty one if the row does not exist yet.
  Future<Profile> fetchMine(String userId) async {
    final row = await _client
        .from('profiles')
        .select(Profile.columns)
        .eq('id', userId)
        .maybeSingle()
        .timeout(networkTimeout);
    return row == null ? Profile(id: userId) : Profile.fromJson(row);
  }

  Future<Profile> save({
    required String userId,
    required String fullName,
    required String phone,
    required bool? isVeg,
    required int? defaultMaxPrice,
  }) async {
    final row = await _client
        .from('profiles')
        .upsert({
          'id': userId,
          'full_name': fullName,
          'phone': phone,
          'is_veg': isVeg,
          'default_max_price': defaultMaxPrice,
        })
        .select(Profile.columns)
        .single()
        .timeout(networkTimeout);
    return Profile.fromJson(row);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);
