import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/constants/copy.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/auth/session_controller.dart';
import 'package:moodbite/features/browse/catalogue_repository.dart';
import 'package:moodbite/features/browse/restaurant_list_screen.dart';
import 'package:moodbite/features/browse/restaurant_sort.dart';
import 'package:moodbite/features/home/home_controllers.dart';
import 'package:moodbite/models/dish.dart';
import 'package:moodbite/models/geo_point.dart';
import 'package:moodbite/models/profile.dart';
import 'package:moodbite/models/restaurant.dart';
import 'package:moodbite/models/zone.dart';

class _Session extends ChangeNotifier implements SessionController {
  @override
  Profile? get profile => const Profile(id: 'u1', fullName: 'Priya Sharma');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Restaurant restaurant(
  String id,
  String name,
  GeoPoint at, {
  int level = 2,
  bool open = true,
  int? minPrice,
  int? maxPrice,
}) =>
    Restaurant(
      id: id,
      name: name,
      area: 'Area $id',
      address: 'Somewhere',
      location: at,
      cuisines: const ['Cafe', 'Italian'],
      priceLevel: level,
      isOpen: open,
      minDishPrice: minPrice,
      maxDishPrice: maxPrice,
    );

// Distances from Bandra West (19.0596, 72.8295): Near is about 1 km away, Mid about 12 km, Far about 30 km.
final near = restaurant('r1', 'Zed Near Cafe', const GeoPoint(19.0680, 72.8300));
final mid = restaurant('r2', 'Mid Kitchen', const GeoPoint(18.9600, 72.8100), level: 3, minPrice: 120, maxPrice: 380);
final far = restaurant('r3', 'Alpha Far Bistro', const GeoPoint(19.2300, 72.9700), level: 1);
const bandra = GeoPoint(19.0596, 72.8295);

class FakeCatalogue implements CatalogueRepository {
  final searches = <String>[];

  @override
  Future<List<Restaurant>> searchRestaurants(String query) async {
    searches.add(query);
    return [far, near];
  }

  @override
  Future<List<DishSearchResult>> searchDishes(String query) async => [
        DishSearchResult(
          const Dish(
            id: 'd1',
            restaurantId: 'r1',
            name: 'Margherita Pizza',
            description: 'Classic',
            priceInr: 320,
            isVeg: true,
            category: 'pizza_pasta',
          ),
          'Zed Near Cafe',
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SeededZone extends DeliveryZoneController {
  @override
  Zone? build() => const Zone(id: 'z13', name: 'Bandra West', centre: bandra);
}

Widget host({bool withZone = true, FakeCatalogue? catalogue}) => ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWithValue(_Session()),
        restaurantsProvider.overrideWith((ref) async => [far, mid, near]),
        coverDishesProvider.overrideWith((ref) async => const {}),
        catalogueRepositoryProvider.overrideWithValue(catalogue ?? FakeCatalogue()),
        if (withZone) deliveryZoneProvider.overrideWith(_SeededZone.new),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const RestaurantListScreen()),
    );

void main() {
  group('sortRestaurants', () {
    test('nearest first when the area is known', () {
      final sorted = sortRestaurants([far, mid, near], bandra);
      expect(sorted.map((e) => e.restaurant.id), ['r1', 'r2', 'r3']);
      expect(sorted.first.distanceKm, lessThan(2));
      expect(sorted.first.distanceLabel, matches(RegExp(r'^\d+\.\d km$')));
    });

    test('A to Z (not reverse) with no distance when no area is chosen', () {
      final sorted = sortRestaurants([near, mid, far], null);
      expect(sorted.map((e) => e.restaurant.name), ['Alpha Far Bistro', 'Mid Kitchen', 'Zed Near Cafe']);
      expect(sorted.every((e) => e.distanceKm == null && e.distanceLabel == null), isTrue);
    });
  });

  group('Restaurants tab', () {
    testWidgets('lists restaurants nearest first with distance, price level and the legend', (tester) async {
    final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final names = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList();
      expect(names.indexOf('Zed Near Cafe'), lessThan(names.indexOf('Mid Kitchen')));
      expect(names.indexOf('Mid Kitchen'), lessThan(names.indexOf('Alpha Far Bistro')));
      expect(find.textContaining('km away'), findsWidgets);
      expect(find.text('Nearest to Bandra West first'), findsOneWidget);
      expect(find.text(AppCopy.priceLegend), findsOneWidget);
      expect(find.text('₹₹₹ · Dishes from ₹120 to ₹380'), findsOneWidget);
      expect(find.text('₹₹'), findsOneWidget); // level only: no dishes loaded
      expect(find.text('Cafe, Italian'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Price level 3 of 4, dishes from 120 to 380 rupees')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Price level 2 of 4')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('without a chosen area it asks for one and sorts A to Z', (tester) async {
      await tester.pumpWidget(host(withZone: false));
      await tester.pumpAndSettle();
      expect(find.text('Choose your area to sort by distance'), findsOneWidget);
      expect(find.textContaining('km away'), findsNothing);
      final names = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList();
      expect(names.indexOf('Alpha Far Bistro'), lessThan(names.indexOf('Zed Near Cafe')));
    });

    testWidgets('the search field has a label and a hint, and suggestion chips are shown', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Dish or restaurant, e.g. biryani'), findsOneWidget);
      for (final suggestion in AppCopy.searchSuggestions.take(3)) {
        expect(find.widgetWithText(ActionChip, suggestion), findsOneWidget);
      }
    });

    testWidgets('tapping a suggestion fills the search and shows restaurants and dishes', (tester) async {
      final catalogue = FakeCatalogue();
      await tester.pumpWidget(host(catalogue: catalogue));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Pizza'));
      await tester.pumpAndSettle();
      expect(catalogue.searches, ['Pizza']);
      expect(find.widgetWithText(TextField, 'Pizza'), findsOneWidget);
      expect(find.text('Restaurants (2)'), findsOneWidget);
      expect(find.text('Dishes (1)'), findsOneWidget);
      expect(find.text('Margherita Pizza'), findsOneWidget);
      // Search results are also nearest first.
      final names = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList();
      expect(names.indexOf('Zed Near Cafe'), lessThan(names.indexOf('Alpha Far Bistro')));
    });

    testWidgets('clearing the search goes back to the full list', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Pizza'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Mid Kitchen'), findsOneWidget);
      expect(find.text('Restaurants (2)'), findsNothing);
    });

    testWidgets('the legend reads in the agreed wording', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('₹ budget, ₹₹ moderate, ₹₹₹ premium, ₹₹₹₹ luxury'), findsOneWidget);
    });

    testWidgets('missing price data shows nothing for that part and no error', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWithValue(_Session()),
          restaurantsProvider.overrideWith((ref) async => [
                restaurant('r5', 'Dishes Only', bandra, level: 0, minPrice: 90, maxPrice: 90),
                restaurant('r6', 'Nothing Known', bandra, level: 0),
              ]),
          coverDishesProvider.overrideWith((ref) async => const {}),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RestaurantListScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Dishes at ₹90'), findsOneWidget);
      expect(find.textContaining('Dishes from'), findsNothing);
      expect(find.text('Nothing Known'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a closed restaurant is marked Closed', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWithValue(_Session()),
          restaurantsProvider.overrideWith((ref) async => [restaurant('r9', 'Night Owl', bandra, open: false)]),
          coverDishesProvider.overrideWith((ref) async => const {}),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RestaurantListScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Closed'), findsOneWidget);
    });
  });
}
