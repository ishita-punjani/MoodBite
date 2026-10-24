import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/supabase_providers.dart';
import '../../models/address.dart';
import '../../models/geo_point.dart';

class AddressRepository {
  const AddressRepository(this._client);

  final SupabaseClient _client;

  Future<List<Address>> fetchMine() async {
    final rows = await _client
        .from('addresses')
        .select(Address.columns)
        .order('created_at', ascending: false)
        .timeout(networkTimeout);
    return rows.map(Address.fromJson).toList();
  }

  /// The database sets `zone_id` and rejects points outside Mumbai.
  Future<Address> add({required String label, required String line1, required GeoPoint location}) async {
    final row = await _client
        .from('addresses')
        .insert({'label': label, 'line1': line1, 'lat': location.lat, 'lng': location.lng})
        .select(Address.columns)
        .single()
        .timeout(networkTimeout);
    return Address.fromJson(row);
  }
}

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ref.watch(supabaseClientProvider)),
);

final addressesProvider = FutureProvider.autoDispose<List<Address>>(
  (ref) => ref.watch(addressRepositoryProvider).fetchMine(),
);
