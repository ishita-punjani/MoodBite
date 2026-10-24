import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/features/home/recommendation_repository.dart';
import 'package:moodbite/models/diet.dart';
import 'package:moodbite/models/geo_point.dart';
import 'package:moodbite/models/recommendation_result.dart';

import '../../support/fake_recommendation_gateway.dart';

const _bandra = GeoPoint(19.0596, 72.8295);

RecommendationRequest request({Diet diet = Diet.any, int? price}) =>
    RecommendationRequest(moodId: 'happy', location: _bandra, diet: diet, maxPriceInr: price);

ChatRequest chatRequest(String text, {Diet diet = Diet.any}) =>
    ChatRequest(messages: [ChatMessage(isUser: true, text: text)], location: _bandra, diet: diet);

void main() {
  group('Diet', () {
    test('profile mapping: Non-veg means non-veg only, not "no filter"', () {
      expect(Diet.fromProfile(null), Diet.any);
      expect(Diet.fromProfile(true), Diet.veg);
      expect(Diet.fromProfile(false), Diet.nonVeg);
    });

    test('allows', () {
      expect(Diet.any.allows(true) && Diet.any.allows(false), isTrue);
      expect(Diet.veg.allows(true), isTrue);
      expect(Diet.veg.allows(false), isFalse);
      expect(Diet.nonVeg.allows(false), isTrue);
      expect(Diet.nonVeg.allows(true), isFalse);
    });
  });

  group('mood mode', () {
    test('an AI answer is parsed, with reasons, and flagged as an AI pick', () async {
      final gateway = FakeRecommendationGateway(
        edge: edgeBody('gemini', [
          dishRow('d1', reason: 'Warm and comforting'),
          dishRow('d2', restaurant: 'r2', reason: 'Light'),
        ]),
      );
      final result = await RecommendationRepository(gateway).recommend(request());
      expect(result.source, RecommendationSource.ai);
      expect(result.picks.map((p) => p.dishId), ['d1', 'd2']);
      expect(result.picks.first.reason, 'Warm and comforting');
      expect(gateway.rpcParams, isEmpty);
    });

    test('a server-side fallback answer is a Quick pick', () async {
      final gateway = FakeRecommendationGateway(edge: edgeBody('fallback', [dishRow('d1')]));
      final result = await RecommendationRepository(gateway).recommend(request());
      expect(result.source, RecommendationSource.quick);
      expect(result.source.badgeLabel, 'Quick pick');
      expect(RecommendationSource.ai.badgeLabel, 'AI pick');
    });

    test('sends diet, price and location to the function, and nothing about the user', () async {
      final gateway = FakeRecommendationGateway(edge: edgeBody('gemini', [dishRow('d1', isVeg: false)]));
      await RecommendationRepository(gateway).recommend(request(diet: Diet.nonVeg, price: 300));
      expect(gateway.edgeBodies.single, {
        'mode': 'mood',
        'mood_id': 'happy',
        'lat': _bandra.lat,
        'lng': _bandra.lng,
        'max_price': 300,
        'diet': 'nonveg',
      });
      expect(gateway.lastTimeout, RecommendationRepository.moodTimeout);
    });

    test('an unreachable function falls back to the direct RPC (Quick pick, diverse, p_diet sent)', () async {
      final gateway = FakeRecommendationGateway(
        edge: TimeoutException('down'),
        rpcRows: [for (var i = 0; i < 8; i++) dishRow('d$i', isVeg: false, restaurant: 'r${i % 6}')],
      );
      final result = await RecommendationRepository(gateway).recommend(request(diet: Diet.nonVeg));
      expect(result.source, RecommendationSource.quick);
      expect(result.picks, hasLength(5));
      expect(result.picks.map((p) => p.restaurantId).toSet(), hasLength(5));
      expect(gateway.rpcParams.single['p_diet'], 'nonveg');
      expect(gateway.rpcParams.single['p_limit'], 20);
    });

    test('garbage from the function (bad shape, unknown source) falls back to the RPC', () async {
      final bodies = <Object?>[
        null,
        'oops',
        {'source': 'martian', 'picks': []},
        {'source': 'gemini'},
        {'source': 'gemini', 'picks': [1]},
      ];
      for (final bad in bodies) {
        final gateway = FakeRecommendationGateway(edge: bad, rpcRows: [dishRow('d1')]);
        final result = await RecommendationRepository(gateway).recommend(request());
        expect(result.source, RecommendationSource.quick, reason: '$bad');
        expect(result.picks.single.dishId, 'd1');
      }
    });

    test('a response that breaks the diet or price filter is rejected, never shown', () async {
      final wrongDiet = FakeRecommendationGateway(
        edge: edgeBody('gemini', [dishRow('d1', isVeg: true), dishRow('d2', isVeg: false, restaurant: 'r2')]),
        rpcRows: [dishRow('d9', isVeg: false)],
      );
      final a = await RecommendationRepository(wrongDiet).recommend(request(diet: Diet.nonVeg));
      expect(a.picks.map((p) => p.dishId), ['d9']);

      final tooPricey = FakeRecommendationGateway(
        edge: edgeBody('gemini', [dishRow('d1', price: 500)]),
        rpcRows: [dishRow('d9', price: 100)],
      );
      final b = await RecommendationRepository(tooPricey).recommend(request(price: 200));
      expect(b.picks.map((p) => p.dishId), ['d9']);
    });

    test('direct RPC diet filtering: a non-veg request never returns a veg dish', () async {
      final gateway = FakeRecommendationGateway(
        edge: Exception('down'),
        rpcRows: [for (var i = 0; i < 10; i++) dishRow('d$i', isVeg: i.isEven, restaurant: 'r$i')],
      );
      final result = await RecommendationRepository(gateway).recommend(request(diet: Diet.nonVeg));
      expect(result.picks, isNotEmpty);
      expect(result.picks.every((p) => !p.isVeg), isTrue);
    });

    test('if both paths fail the error reaches the caller', () async {
      expect(RecommendationRepository(_ThrowingGateway()).recommend(request()), throwsA(isA<StateError>()));
    });
  });

  group('chat mode', () {
    final messages = [for (var i = 0; i < 9; i++) ChatMessage(isUser: i.isEven, text: 'm$i')];

    test('sends only the last 6 messages, roles mapped, plus filters', () async {
      final gateway = FakeRecommendationGateway(edge: edgeBody('gemini', [dishRow('d1')], reply: 'Try this!'));
      await RecommendationRepository(gateway).chat(
        ChatRequest(messages: messages, location: _bandra, diet: Diet.veg, maxPriceInr: 250),
      );
      final body = gateway.edgeBodies.single;
      final sent = body['messages'] as List;
      expect(body['mode'], 'chat');
      expect(sent.map((m) => (m as Map)['text']), ['m3', 'm4', 'm5', 'm6', 'm7', 'm8']);
      expect(sent.first, {'role': 'assistant', 'text': 'm3'});
      expect(body['diet'], 'veg');
      expect(body['max_price'], 250);
      expect(gateway.lastTimeout, RecommendationRepository.chatTimeout);
    });

    test('parses reply, picks, mood and source', () async {
      final gateway = FakeRecommendationGateway(
        edge: edgeBody('gemini', [dishRow('d1', reason: 'Cosy')], reply: 'Try this!', moodId: 'tired'),
      );
      final result = await RecommendationRepository(gateway).chat(chatRequest('tired'));
      expect(result.reply, 'Try this!');
      expect(result.moodId, 'tired');
      expect(result.source, RecommendationSource.ai);
      expect(result.picks.single.reason, 'Cosy');
    });

    test('a question with no picks is valid', () async {
      final gateway =
          FakeRecommendationGateway(edge: edgeBody('fallback', const [], reply: 'What are you craving?', moodId: null));
      final result = await RecommendationRepository(gateway).chat(chatRequest('hmm'));
      expect(result.picks, isEmpty);
      expect(result.moodId, isNull);
      expect(result.reply, 'What are you craving?');
    });

    test('a pick that breaks the UI diet is rejected, and errors are thrown (no silent fallback)', () async {
      final wrong = FakeRecommendationGateway(edge: edgeBody('gemini', [dishRow('d1', isVeg: false)], reply: 'x'));
      expect(
        RecommendationRepository(wrong).chat(chatRequest('hi', diet: Diet.veg)),
        throwsA(isA<FormatException>()),
      );
      final down = FakeRecommendationGateway(edge: TimeoutException('down'));
      expect(RecommendationRepository(down).chat(chatRequest('hi')), throwsA(isA<TimeoutException>()));
    });
  });
}

class _ThrowingGateway implements RecommendationGateway {
  @override
  Future<Object?> invokeRecommend(Map<String, dynamic> body, {required Duration timeout}) async =>
      throw StateError('edge down');

  @override
  Future<List<dynamic>> rpcRecommendDishes(Map<String, dynamic> params) async => throw StateError('rpc down');
}
