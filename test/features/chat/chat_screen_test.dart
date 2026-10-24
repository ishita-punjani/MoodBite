import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/constants/copy.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/core/validators.dart';
import 'package:moodbite/features/auth/session_controller.dart';
import 'package:moodbite/features/browse/catalogue_repository.dart';
import 'package:moodbite/features/cart/cart_controller.dart';
import 'package:moodbite/features/chat/chat_screen.dart';
import 'package:moodbite/features/home/home_controllers.dart';
import 'package:moodbite/features/home/recommendation_repository.dart';
import 'package:moodbite/models/diet.dart';
import 'package:moodbite/models/dish_recommendation.dart';
import 'package:moodbite/models/geo_point.dart';
import 'package:moodbite/models/profile.dart';
import 'package:moodbite/models/recommendation_result.dart';
import 'package:moodbite/models/zone.dart';

import '../../support/fake_recommendation_gateway.dart';

const _bandra = Zone(id: 'z13', name: 'Bandra West', centre: GeoPoint(19.0596, 72.8295));

class _FakeSession extends ChangeNotifier implements SessionController {
  @override
  final Profile? profile = const Profile(id: 'u1', fullName: 'Priya Sharma');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SeededZone extends DeliveryZoneController {
  @override
  Zone? build() => _bandra;
}

class _SeededFilters extends RecommendationFiltersController {
  @override
  RecommendationFilters build() => const RecommendationFilters(maxPriceInr: 300, diet: Diet.veg);
}

/// Scripted repository: each call to [chat] returns or throws the next item.
class _FakeRepository implements RecommendationRepository {
  _FakeRepository(this.script);

  final List<Object> script;
  final List<ChatRequest> requests = [];
  Completer<RecommendationResult>? hold;

  @override
  Future<RecommendationResult> chat(ChatRequest request) async {
    requests.add(
      ChatRequest(
        messages: List.of(request.messages),
        location: request.location,
        maxPriceInr: request.maxPriceInr,
        diet: request.diet,
      ),
    );
    final held = hold;
    if (held != null) return held.future;
    final next = script.removeAt(0);
    if (next is Exception) throw next;
    return next as RecommendationResult;
  }

  @override
  Future<RecommendationResult> recommend(RecommendationRequest request) => throw UnimplementedError();
}

RecommendationResult _result({
  RecommendationSource source = RecommendationSource.ai,
  String reply = 'Warm and comforting ideas for you.',
  int picks = 2,
  String? moodId = 'stressed',
}) => RecommendationResult(
  source: source,
  moodId: moodId,
  reply: reply,
  picks: [
    for (var i = 1; i <= picks; i++)
      DishRecommendation.fromJson(dishRow('d$i', restaurant: 'r$i', reason: 'Reason $i')),
  ],
);

Widget _app(_FakeRepository repo, {bool withZone = true, bool seededFilters = false}) => ProviderScope(
  overrides: [
    sessionControllerProvider.overrideWithValue(_FakeSession()),
    recommendationRepositoryProvider.overrideWithValue(repo),
    zonesProvider.overrideWith((ref) async => [_bandra]),
    if (withZone) deliveryZoneProvider.overrideWith(_SeededZone.new),
    if (seededFilters) recommendationFiltersProvider.overrideWith(_SeededFilters.new),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const ChatScreen()),
);

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _tapSend(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Send'));
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(ChatScreen)));

void main() {
  group('empty state', () {
    testWidgets('shows the empty message, the four suggestion chips and the hint', (tester) async {
      await _pump(tester, _app(_FakeRepository([])));
      expect(find.text('Ask me about food'), findsOneWidget);
      for (final text in AppCopy.chatSuggestions) {
        expect(find.widgetWithText(ActionChip, text), findsOneWidget);
      }
      expect(find.text("Tell me how you feel or what you're craving"), findsOneWidget);
      expect(find.text('Delivering to Bandra West · Veg'), findsNothing);
      expect(find.text('Delivering to Bandra West · Any'), findsOneWidget);
    });
  });

  group('send and receive', () {
    testWidgets('a message goes out with the area and the Mood-tab filters and the reply shows dish cards', (
      tester,
    ) async {
      final repo = _FakeRepository([_result()]);
      await _pump(tester, _app(repo, seededFilters: true));
      await _type(tester, '  I am stressed, something warm  ');
      await _tapSend(tester);

      expect(find.text('I am stressed, something warm'), findsOneWidget);
      expect(find.text('Warm and comforting ideas for you.'), findsOneWidget);
      expect(find.text('Dish d1'), findsOneWidget);
      expect(find.text('Dish d2'), findsOneWidget);
      expect(find.text('Reason 1'), findsOneWidget);
      expect(find.text('AI reply'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Add'), findsNWidgets(2));
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

      final request = repo.requests.single;
      expect(request.messages.map((m) => (m.isUser, m.text)), [(true, 'I am stressed, something warm')]);
      expect(request.location, _bandra.centre);
      expect(request.maxPriceInr, 300);
      expect(request.diet, Diet.veg);
      expect(find.text('Delivering to Bandra West · Veg · up to ₹300'), findsOneWidget);
    });

    testWidgets('a suggestion chip sends its text', (tester) async {
      final repo = _FakeRepository([_result()]);
      await _pump(tester, _app(repo));
      await tester.tap(find.widgetWithText(ActionChip, 'Surprise me'));
      await tester.pumpAndSettle();
      expect(repo.requests.single.messages.single.text, 'Surprise me');
      expect(find.widgetWithText(ActionChip, 'Surprise me'), findsNothing);
    });

    testWidgets('the second turn sends the conversation so far (user and assistant messages)', (tester) async {
      final repo = _FakeRepository([_result(reply: 'First'), _result(reply: 'Second')]);
      await _pump(tester, _app(repo));
      await _type(tester, 'one');
      await _tapSend(tester);
      await _type(tester, 'two');
      await _tapSend(tester);
      expect(repo.requests.last.messages.map((m) => m.text), ['one', 'First', 'two']);
    });

    testWidgets('at most five dish cards are shown', (tester) async {
      final repo = _FakeRepository([_result(picks: 7)]);
      await _pump(tester, _app(repo));
      await _type(tester, 'hungry');
      await _tapSend(tester);
      expect(find.byType(OutlinedButton), findsNWidgets(5));
    });

    testWidgets('a reply without dishes (a food question) shows only the bubble', (tester) async {
      final repo = _FakeRepository([_result(reply: 'What are you in the mood for?', picks: 0, moodId: null)]);
      await _pump(tester, _app(repo));
      await _type(tester, 'hello');
      await _tapSend(tester);
      expect(find.text('What are you in the mood for?'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Add'), findsNothing);
    });
  });

  group('fallback badge', () {
    testWidgets('a keyword-fallback answer is badged Quick reply, an AI one AI reply', (tester) async {
      final repo = _FakeRepository([_result(source: RecommendationSource.quick)]);
      await _pump(tester, _app(repo));
      await _type(tester, 'something warm');
      await _tapSend(tester);
      expect(find.text('Quick reply'), findsOneWidget);
      expect(find.text('AI reply'), findsNothing);
    });
  });

  group('waiting', () {
    testWidgets('shows a typing indicator with a loading quip and disables sending until the answer arrives', (
      tester,
    ) async {
      final repo = _FakeRepository([])..hold = Completer<RecommendationResult>();
      await _pump(tester, _app(repo));
      await _type(tester, 'something warm');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && AppCopy.loadingQuips.contains(w.data)), findsOneWidget);
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      repo.hold!.complete(_result());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNotNull);
      expect(repo.requests, hasLength(1));
    });
  });

  group('errors', () {
    testWidgets('a failure shows a friendly message with Retry, never the raw error, and Retry resends once', (
      tester,
    ) async {
      final repo = _FakeRepository([Exception('boom: secret detail'), _result()]);
      await _pump(tester, _app(repo));
      await _type(tester, 'something warm');
      await _tapSend(tester);

      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
      expect(find.text('something warm'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Please try again.'), findsNothing);
      expect(find.text('something warm'), findsOneWidget); // not duplicated
      expect(find.text('Dish d1'), findsOneWidget);
      expect(repo.requests, hasLength(2));
      expect(repo.requests.last.messages.map((m) => m.text), ['something warm']);
    });

    testWidgets('a timeout is explained in words', (tester) async {
      final repo = _FakeRepository([TimeoutException('slow')]);
      await _pump(tester, _app(repo));
      await _type(tester, 'something warm');
      await _tapSend(tester);
      expect(find.textContaining('taking too long'), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('an empty or blank message shows an inline error and sends nothing', (tester) async {
      final repo = _FakeRepository([]);
      await _pump(tester, _app(repo));
      await _tapSend(tester);
      expect(find.text("Tell me how you feel or what you're craving"), findsNWidgets(2)); // hint + error
      await _type(tester, '     ');
      await _tapSend(tester);
      expect(repo.requests, isEmpty);
    });

    testWidgets('the field stops at 300 characters and a counter appears near the limit', (tester) async {
      final repo = _FakeRepository([]);
      await _pump(tester, _app(repo));
      await _type(tester, 'a' * 100);
      expect(find.text('100/300'), findsNothing);
      await _type(tester, 'a' * 260);
      expect(find.text('260/300'), findsOneWidget);
      await _type(tester, 'a' * 400);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text.length, 300);
    });

    test('the validator trims, requires text and caps at 300', () {
      expect(Validators.chatMessage(null), isNotNull);
      expect(Validators.chatMessage('   '), isNotNull);
      expect(Validators.chatMessage('  hi  '), isNull);
      expect(Validators.chatMessage('a' * 300), isNull);
      expect(Validators.chatMessage('a' * 301), 'Keep it under 300 characters');
      expect(Validators.chatMessage('  ${'a' * 300}  '), isNull);
    });
  });

  group('no delivery area', () {
    testWidgets('shows the inline prompt, holds the message, and sends it after an area is chosen', (tester) async {
      final repo = _FakeRepository([_result()]);
      await _pump(tester, _app(repo, withZone: false));
      expect(find.text('Choose your delivery area so I can find dishes near you.'), findsOneWidget);

      await _type(tester, 'something warm');
      await _tapSend(tester);
      expect(repo.requests, isEmpty);
      expect(find.text('Choose your delivery area and I will send your message.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'something warm');

      await tester.tap(find.widgetWithText(FilledButton, 'Choose area'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bandra West'));
      await tester.pumpAndSettle();

      expect(repo.requests.single.location, _bandra.centre);
      expect(repo.requests.single.messages.single.text, 'something warm');
      expect(find.text('Choose your delivery area and I will send your message.'), findsNothing);
      expect(find.text('Dish d1'), findsOneWidget);
    });
  });

  group('add to cart', () {
    testWidgets('Add puts the dish in the cart with the mood id the function detected', (tester) async {
      final repo = _FakeRepository([_result(moodId: 'stressed')]);
      await _pump(tester, _app(repo));
      await _type(tester, 'something warm');
      await _tapSend(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add').first);
      await tester.pumpAndSettle();

      final cart = _container(tester).read(cartProvider);
      expect(cart.lines.single.dish.id, 'd1');
      expect(cart.lines.single.moodId, 'stressed');
      expect(cart.moodId, 'stressed');
    });

    testWidgets('a reply with no detected mood adds with no mood', (tester) async {
      final repo = _FakeRepository([_result(moodId: null)]);
      await _pump(tester, _app(repo));
      await _type(tester, 'pizza');
      await _tapSend(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add').first);
      await tester.pumpAndSettle();
      expect(_container(tester).read(cartProvider).moodId, isNull);
    });
  });
}
