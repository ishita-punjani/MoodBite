import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/supabase_providers.dart';
import '../../models/dish.dart';
import '../../models/mood.dart';
import '../../models/restaurant.dart';
import '../../models/zone.dart';

/// A dish search hit, with the name of the restaurant that serves it.
class DishSearchResult {
  const DishSearchResult(this.dish, this.restaurantName);

  final Dish dish;
  final String restaurantName;
}

/// Name and category of a restaurant's first dish, used to pick its picture.
class CoverDish {
  const CoverDish(this.name, this.category);

  final String name;
  final String category;
}

class CatalogueRepository {
  const CatalogueRepository(this._client);

  final SupabaseClient _client;

  static const minQueryLength = 2;
  static const _searchLimit = 25;

  Future<List<Mood>> fetchMoods() async {
    final rows = await _client.from('moods').select(Mood.columns).timeout(networkTimeout);
    return rows.map(Mood.fromJson).toList();
  }

  Future<List<Zone>> fetchZones() async {
    final rows = await _client
        .from('zones')
        .select(Zone.columns)
        .order('name')
        .timeout(networkTimeout);
    return sortZonesByName(rows.map(Zone.fromJson));
  }

  Future<List<Restaurant>> fetchRestaurants() async {
    final rows = await _client
        .from('restaurants')
        .select(Restaurant.columnsWithPrices)
        .order('name')
        .timeout(networkTimeout);
    return rows.map(Restaurant.fromJson).toList();
  }

  Future<Restaurant?> fetchRestaurant(String id) async {
    final row = await _client
        .from('restaurants')
        .select(Restaurant.columnsWithPrices)
        .eq('id', id)
        .maybeSingle()
        .timeout(networkTimeout);
    return row == null ? null : Restaurant.fromJson(row);
  }

  Future<List<Dish>> fetchMenu(String restaurantId) async {
    final rows = await _client
        .from('dishes')
        .select(Dish.columns)
        .eq('restaurant_id', restaurantId)
        .order('category')
        .order('name')
        .timeout(networkTimeout);
    return rows.map(Dish.fromJson).toList();
  }

  /// The first dish (lowest id) of every restaurant, keyed by restaurant id.
  Future<Map<String, CoverDish>> fetchCoverDishes() async {
    final rows = await _client
        .from('dishes')
        .select('restaurant_id, name, category')
        .order('id')
        .timeout(networkTimeout);
    final covers = <String, CoverDish>{};
    for (final row in rows) {
      covers.putIfAbsent(
        row['restaurant_id'] as String,
        () => CoverDish(row['name'] as String, row['category'] as String),
      );
    }
    return covers;
  }

  Future<List<Restaurant>> searchRestaurants(String query) async {
    final term = sanitizeSearch(query);
    if (term.length < minQueryLength) return const [];
    final rows = await _client
        .from('restaurants')
        .select(Restaurant.columnsWithPrices)
        .or('name.ilike.%$term%,area.ilike.%$term%')
        .order('name')
        .limit(_searchLimit)
        .timeout(networkTimeout);
    return rows.map(Restaurant.fromJson).toList();
  }

  Future<List<DishSearchResult>> searchDishes(String query) async {
    final term = sanitizeSearch(query);
    if (term.length < minQueryLength) return const [];
    final rows = await _client
        .from('dishes')
        .select('${Dish.columns}, restaurants(name)')
        .or('name.ilike.%$term%,description.ilike.%$term%')
        .order('name')
        .limit(_searchLimit)
        .timeout(networkTimeout);
    return rows.map((row) {
      final restaurant = row['restaurants'] as Map<String, dynamic>?;
      return DishSearchResult(Dish.fromJson(row), restaurant?['name'] as String? ?? '');
    }).toList();
  }

  /// Keeps letters (with their combining marks, e.g. Devanagari vowel signs),
  /// digits, spaces and a few safe characters, so the query cannot break
  /// PostgREST filter syntax (commas, brackets, wildcards).
  static String sanitizeSearch(String query) => query
      .replaceAll(RegExp(r"[^\p{L}\p{M}\p{N} '&.-]", unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final catalogueRepositoryProvider = Provider<CatalogueRepository>(
  (ref) => CatalogueRepository(ref.watch(supabaseClientProvider)),
);

final moodsProvider = FutureProvider<List<Mood>>(
  (ref) => ref.watch(catalogueRepositoryProvider).fetchMoods(),
);

final zonesProvider = FutureProvider<List<Zone>>(
  (ref) => ref.watch(catalogueRepositoryProvider).fetchZones(),
);

final restaurantsProvider = FutureProvider.autoDispose<List<Restaurant>>(
  (ref) => ref.watch(catalogueRepositoryProvider).fetchRestaurants(),
);

final coverDishesProvider = FutureProvider<Map<String, CoverDish>>(
  (ref) => ref.watch(catalogueRepositoryProvider).fetchCoverDishes(),
);

final restaurantProvider =FutureProvider.autoDispose.family<Restaurant?, String>(
  (ref, id) => ref.watch(catalogueRepositoryProvider).fetchRestaurant(id),
);

final menuProvider = FutureProvider.autoDispose.family<List<Dish>, String>(
  (ref, restaurantId) => ref.watch(catalogueRepositoryProvider).fetchMenu(restaurantId),
);
