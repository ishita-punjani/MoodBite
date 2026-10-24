import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/supabase_providers.dart';
import '../../models/order.dart';
import '../cart/cart_controller.dart';

class OrderRepository {
  const OrderRepository(this._client);

  final SupabaseClient _client;

  /// Places the order through the `place_order` RPC, which re-checks the
  /// Mumbai zone, the quantities and the prices on the server.
  /// [moodId] is recorded as recommendation feedback; `null` when the user
  /// browsed instead of using a mood. Returns the new order id.
  Future<String> placeOrder({
    required String addressId,
    required String restaurantId,
    required List<CartLine> lines,
    String? moodId,
  }) async {
    final id = await _client.rpc('place_order', params: {
      'p_address_id': addressId,
      'p_restaurant_id': restaurantId,
      'p_items': [
        for (final line in lines) {'dish_id': line.dish.id, 'qty': line.quantity},
      ],
      'p_mood_id': moodId,
    }).timeout(networkTimeout);
    return id as String;
  }

  Future<List<Order>> fetchMine() async {
    final rows = await _client
        .from('orders')
        .select(Order.columns)
        .order('placed_at', ascending: false)
        .timeout(networkTimeout);
    return rows.map(Order.fromJson).toList();
  }

  Future<Order?> fetchOne(String id) async {
    final row = await _client
        .from('orders')
        .select(Order.columns)
        .eq('id', id)
        .maybeSingle()
        .timeout(networkTimeout);
    return row == null ? null : Order.fromJson(row);
  }
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(supabaseClientProvider)),
);

final ordersProvider = FutureProvider.autoDispose<List<Order>>(
  (ref) => ref.watch(orderRepositoryProvider).fetchMine(),
);

final orderProvider = FutureProvider.autoDispose.family<Order?, String>(
  (ref, id) => ref.watch(orderRepositoryProvider).fetchOne(id),
);
