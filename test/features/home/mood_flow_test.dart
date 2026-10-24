import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodbite/core/router.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/auth/session_controller.dart';
import 'package:moodbite/features/browse/catalogue_repository.dart';
import 'package:moodbite/features/home/home_controllers.dart';
import 'package:moodbite/features/home/home_screen.dart';
import 'package:moodbite/features/home/recommendation_repository.dart';
import 'package:moodbite/features/home/recommendations_screen.dart';
import 'package:moodbite/models/diet.dart';
import 'package:moodbite/models/geo_point.dart';
import 'package:moodbite/models/mood.dart';
import 'package:moodbite/models/profile.dart';
import 'package:moodbite/models/zone.dart';
import 'package:moodbite/widgets/brand.dart';
import 'package:moodbite/widgets/quantity_stepper.dart';

import '../../support/fake_recommendation_gateway.dart';

class FakeSession extends ChangeNotifier implements SessionController {
  FakeSession(this.profile);

  @override
  final Profile? profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SeededZone extends DeliveryZoneController {
  @override
  Zone? build() => const Zone(id: 'z13', name: 'Bandra West', centre: GeoPoint(19.0596, 72.8295));
}

const _moods = [Mood(id: 'happy', label: 'Happy', emoji: '😄')];

const _twoMoods = [
  Mood(id: 'happy', label: 'Happy', emoji: '😄'),
  Mood(id: 'sad', label: 'Sad', emoji: '😢'),
];

Widget wrapRouter({String? name, List<Mood> moods = _moods}) => ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWithValue(FakeSession(Profile(id: 'u1', fullName: name))),
        moodsProvider.overrideWith((ref) async => moods),
        deliveryZoneProvider.overrideWith(SeededZone.new),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.recommendations,
            builder: (context, state) => Scaffold(body: Text('results for ${state.uri.queryParameters['mood']}')),
          ),
        ]),
      ),
    );

Widget wrap(Widget child, {bool? isVeg, RecommendationGateway? gateway, List<Mood> moods = _moods}) => ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWithValue(FakeSession(Profile(id: 'u1', isVeg: isVeg))),
        moodsProvider.overrideWith((ref) async => moods),
        deliveryZoneProvider.overrideWith(SeededZone.new),
        if (gateway != null) recommendationRepositoryProvider.overrideWithValue(RecommendationRepository(gateway)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

void main() {
  group('Mood tab layout', () {
    testWidgets('greeting, headline, delivery row, filters row and a tinted mood card with a subtitle', (tester) async {
      await tester.pumpWidget(wrapRouter(name: 'Priya Sharma'));
      await tester.pumpAndSettle();
      final greeting = RegExp(r'^Good (morning|afternoon|evening), Priya$');
      expect(find.byWidgetPredicate((w) => w is Text && greeting.hasMatch(w.data ?? '')), findsOneWidget);
      expect(find.text('How are you feeling?'), findsOneWidget);
      expect(find.text('Delivering to Bandra West'), findsOneWidget);
      expect(find.text('Any'), findsOneWidget);
      expect(find.text('Max price'), findsOneWidget);
      expect(find.text('e.g. 300'), findsOneWidget);
      expect(find.text('Happy'), findsOneWidget);
      expect(find.text('Fun, colourful food to share'), findsOneWidget);
      final card = tester.widget<Material>(find.ancestor(of: find.text('Happy'), matching: find.byType(Material)).first);
      expect(card.color, AppColors.moodTint('happy'));
    });

    testWidgets('mood cards, the area row and the diet control have 48dp touch targets and labels', (tester) async {
    final semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrapRouter(moods: _twoMoods));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Happy mood. Fun, colourful food to share')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Sad mood. Sweet treats and a hug on a plate')), findsOneWidget);
      final areaRow = find.ancestor(of: find.text('Delivering to Bandra West'), matching: find.byType(InkWell)).first;
      expect(tester.getSize(areaRow).height, greaterThanOrEqualTo(48));
      final sadCard = find.ancestor(of: find.text('Sad'), matching: find.byType(InkWell)).first;
      expect(tester.getSize(sadCard).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.byType(SegmentedButton<Diet>)).height, greaterThanOrEqualTo(48));
      semantics.dispose();
    });

    testWidgets('two moods sit side by side in a 2-column grid', (tester) async {
      await tester.pumpWidget(wrapRouter(moods: _twoMoods));
      await tester.pumpAndSettle();
      final happy = tester.getTopLeft(find.text('Happy'));
      final sad = tester.getTopLeft(find.text('Sad'));
      expect(sad.dy, happy.dy);
      expect(sad.dx, greaterThan(happy.dx));
    });

    testWidgets('tapping a mood opens its results directly', (tester) async {
      await tester.pumpWidget(wrapRouter());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Happy'));
      await tester.pumpAndSettle();
      expect(find.text('results for happy'), findsOneWidget);
    });

    testWidgets('an invalid budget shows the message and does not open results', (tester) async {
      await tester.pumpWidget(wrapRouter());
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Max price'), '9999');
      await tester.tap(find.text('Happy'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a price between 1 and 5000'), findsOneWidget);
      expect(find.text('results for happy'), findsNothing);
    });

    testWidgets('the app bar has the logo, the title and the profile avatar (no My orders icon)', (tester) async {
      await tester.pumpWidget(wrapRouter(name: 'Priya Sharma'));
      await tester.pumpAndSettle();
      expect(find.byType(BrandLogo), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('MoodBite')), findsOneWidget);
      expect(find.text('PS'), findsOneWidget);
      expect(find.byTooltip('My orders'), findsNothing);
    });
  });

  group('Mood tab diet control', () {
    testWidgets('defaults from the profile: Non-veg is selected for a non-veg profile', (tester) async {
      await tester.pumpWidget(wrap(const HomeScreen(), isVeg: false));
      await tester.pumpAndSettle();
      final control = tester.widget<SegmentedButton<Diet>>(find.byType(SegmentedButton<Diet>));
      expect(control.selected, {Diet.nonVeg});
      expect(find.text('Any'), findsOneWidget);
      expect(find.text('Veg'), findsOneWidget);
      expect(find.text('Non-veg'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('no preference defaults to Any and tapping changes the filter', (tester) async {
      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      expect(container.read(recommendationFiltersProvider).diet, Diet.any);
      await tester.tap(find.text('Veg'));
      await tester.pumpAndSettle();
      expect(container.read(recommendationFiltersProvider).diet, Diet.veg);
    });
  });

  group('Recommendations screen', () {
    testWidgets('an AI answer shows the AI pick badge and the AI reason', (tester) async {
      final gateway = FakeRecommendationGateway(
        edge: edgeBody('gemini', [dishRow('d1', reason: 'Warm and comforting')]),
      );
      await tester.pumpWidget(wrap(const RecommendationsScreen(moodId: 'happy'), gateway: gateway));
      await tester.pumpAndSettle();
      expect(find.text('AI pick'), findsOneWidget);
      expect(find.text('Warm and comforting'), findsOneWidget);
    });

    testWidgets('an unreachable function falls back to the RPC: Quick pick with the template reason',
        (tester) async {
      final gateway = FakeRecommendationGateway(edge: TimeoutException('down'), rpcRows: [dishRow('d1')]);
      await tester.pumpWidget(wrap(const RecommendationsScreen(moodId: 'happy'), gateway: gateway));
      await tester.pumpAndSettle();
      expect(find.text('Quick pick'), findsOneWidget);
      expect(find.textContaining('A good match for feeling happy'), findsOneWidget);
    });

    testWidgets('a result card is dish-first: name, restaurant and distance, price, reason, badge, Add', (tester) async {
    final semantics = tester.ensureSemantics();
      final gateway = FakeRecommendationGateway(
        edge: edgeBody('gemini', [dishRow('d1', reason: 'Warm and comforting', price: 180)]),
      );
      await tester.pumpWidget(wrap(const RecommendationsScreen(moodId: 'happy'), gateway: gateway));
      await tester.pumpAndSettle();
      expect(find.text('Dish d1'), findsOneWidget);
      expect(find.text('Resto r1 · 1.2 km'), findsOneWidget);
      expect(find.text('₹180'), findsOneWidget);
      expect(find.text('Warm and comforting'), findsOneWidget);
      expect(find.text('AI pick'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Vegetarian')), findsOneWidget);
      final add = find.widgetWithText(OutlinedButton, 'Add');
      expect(add, findsOneWidget);
      expect(tester.getSize(add).height, greaterThanOrEqualTo(48));
      // With no photo bundled the card shows the labelled emoji placeholder.
      expect(find.text('🍛'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Add turns into a quantity stepper', (tester) async {
      final gateway = FakeRecommendationGateway(edge: edgeBody('gemini', [dishRow('d1')]));
      await tester.pumpWidget(wrap(const RecommendationsScreen(moodId: 'happy'), gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.byType(QuantityStepper), findsOneWidget);
    });

    testWidgets('there is a way to try another mood: chips for the moods and a button', (tester) async {
      final gateway = FakeRecommendationGateway(edge: edgeBody('gemini', [dishRow('d1')]));
      await tester.pumpWidget(wrap(const RecommendationsScreen(moodId: 'happy'), gateway: gateway, moods: _twoMoods));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Sad'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Happy')).selected, isTrue);
      await tester.scrollUntilVisible(find.text('Try another mood'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('Try another mood'), findsOneWidget);
    });

    testWidgets('the empty state also offers another mood', (tester) async {
      final gateway = FakeRecommendationGateway(edge: edgeBody('fallback', const []));
      await tester.pumpWidget(wrap(const RecommendationsScreen(moodId: 'happy'), gateway: gateway));
      await tester.pumpAndSettle();
      expect(find.text('Try another mood'), findsOneWidget);
    });

    testWidgets('no dishes shows the friendly empty state', (tester) async {
      final gateway = FakeRecommendationGateway(edge: edgeBody('fallback', const []));
      await tester.pumpWidget(wrap(const RecommendationsScreen(moodId: 'happy'), gateway: gateway));
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches right now'), findsOneWidget);
    });
  });
}
