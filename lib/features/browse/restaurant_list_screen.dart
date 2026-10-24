import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/copy.dart';
import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/geo_point.dart';
import '../../models/restaurant.dart';
import '../../widgets/brand.dart';
import '../../widgets/dish_image.dart';
import '../../widgets/dish_tile.dart';
import '../../widgets/price_line.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../home/area_picker.dart';
import '../home/home_controllers.dart';
import 'catalogue_repository.dart';
import 'restaurant_sort.dart';

/// Restaurants tab: search at the top (restaurants and dishes), otherwise
/// every restaurant, nearest to the chosen delivery area first.
class RestaurantListScreen extends ConsumerStatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  ConsumerState<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends ConsumerState<RestaurantListScreen> {
  static const _debounce = Duration(milliseconds: 400);

  final _query = TextEditingController();
  Timer? _timer;
  int _requestId = 0;
  bool _loading = false;
  String? _error;
  String _searched = '';
  List<Restaurant> _restaurants = const [];
  List<DishSearchResult> _dishes = const [];

  bool get _searching => _searched.isNotEmpty || _loading || _error != null;

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _timer?.cancel();
    _timer = Timer(_debounce, _search);
  }

  void _useSuggestion(String text) {
    _timer?.cancel();
    _query.text = text;
    _query.selection = TextSelection.collapsed(offset: text.length);
    _search();
  }

  Future<void> _search() async {
    final term = CatalogueRepository.sanitizeSearch(_query.text);
    final id = ++_requestId;
    if (term.length < CatalogueRepository.minQueryLength) {
      setState(() {
        _searched = '';
        _loading = false;
        _error = null;
        _restaurants = const [];
        _dishes = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(catalogueRepositoryProvider);
      final results = await Future.wait([repo.searchRestaurants(term), repo.searchDishes(term)]);
      if (!mounted || id != _requestId) return;
      setState(() {
        _searched = term;
        _restaurants = results[0] as List<Restaurant>;
        _dishes = results[1] as List<DishSearchResult>;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zone = ref.watch(deliveryZoneProvider);
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('Restaurants'), actions: const [ProfileAvatarButton()]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Dish or restaurant, e.g. biryani',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _query.clear();
                          _search();
                        },
                      ),
              ),
              onChanged: (text) {
                setState(() {}); // shows or hides the clear button
                _onChanged(text);
              },
              onSubmitted: (_) {
                _timer?.cancel();
                _search();
              },
            ),
          ),
          _SuggestionChips(onSelected: _useSuggestion),
          Expanded(child: _searching ? _searchBody(zone?.centre) : _BrowseList(zone: zone?.centre)),
        ],
      ),
    );
  }

  Widget _searchBody(GeoPoint? from) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _search);
    if (_restaurants.isEmpty && _dishes.isEmpty) {
      return EmptyView(emoji: '🤷', title: 'No matches for "$_searched"', message: 'Try a different word.');
    }
    final textTheme = Theme.of(context).textTheme;
    final sorted = sortRestaurants(_restaurants, from);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        if (sorted.isNotEmpty) ...[
          _SectionTitle('Restaurants (${sorted.length})', textTheme),
          for (final entry in sorted) RestaurantCard(entry: entry),
        ],
        if (_dishes.isNotEmpty) ...[
          _SectionTitle('Dishes (${_dishes.length})', textTheme),
          for (final hit in _dishes)
            DishTile(
              name: hit.dish.name,
              description: hit.dish.description,
              priceInr: hit.dish.priceInr,
              isVeg: hit.dish.isVeg,
              category: hit.dish.category,
              caption: hit.restaurantName,
              onTap: () => context.push(AppRoutes.restaurant(hit.dish.restaurantId)),
            ),
        ],
      ],
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kMinTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: AppCopy.searchSuggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final text = AppCopy.searchSuggestions[index];
          return ActionChip(label: Text(text), onPressed: () => onSelected(text));
        },
      ),
    );
  }
}

class _BrowseList extends ConsumerWidget {
  const _BrowseList({required this.zone});

  final GeoPoint? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(restaurantsProvider);
    return restaurants.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(restaurantsProvider)),
      data: (list) {
        if (list.isEmpty) return const EmptyView(emoji: '🏪', title: 'No restaurants yet');
        final entries = sortRestaurants(list, zone);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(restaurantsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            itemCount: entries.length + 1,
            itemBuilder: (context, index) =>
                index == 0 ? _ListHeader(sortedByDistance: zone != null) : RestaurantCard(entry: entries[index - 1]),
          ),
        );
      },
    );
  }
}

class _ListHeader extends ConsumerWidget {
  const _ListHeader({required this.sortedByDistance});

  final bool sortedByDistance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final zone = ref.watch(deliveryZoneProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            onPressed: () => showAreaPicker(context),
            icon: const Icon(Icons.place, size: 18),
            label: Text(
              sortedByDistance
                  ? 'Nearest to ${zone?.name ?? 'your area'} first'
                  : 'Choose your area to sort by distance',
            ),
          ),
          Text(AppCopy.priceLegend, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// One restaurant: picture (its first dish), name, cuisine, area, distance and price line.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.entry});

  final RestaurantEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final restaurant = entry.restaurant;
    final distance = entry.distanceLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Card(
        child: InkWell(
          onTap: () => context.push(AppRoutes.restaurant(restaurant.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RestaurantImage(restaurantId: restaurant.id, width: 88, height: 88),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant.name, style: textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        restaurant.cuisines.join(', '),
                        style: textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        distance == null ? restaurant.area : '${restaurant.area} · $distance away',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      PriceLine(restaurant),
                      if (!restaurant.isOpen)
                        Text('Closed', style: textTheme.bodySmall?.copyWith(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.textTheme);

  final String text;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
        child: Text(text, style: textTheme.titleMedium),
      );
}
