import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/supabase_providers.dart';
import '../../models/diet.dart';
import '../../models/dish_recommendation.dart';
import '../../models/geo_point.dart';
import '../../models/recommendation_result.dart';
import 'recommendation_logic.dart';

/// Inputs for one mood recommendation request. Value equality so it can key a
/// Riverpod family provider.
class RecommendationRequest {
  const RecommendationRequest({
    required this.moodId,
    required this.location,
    this.maxPriceInr,
    this.diet = Diet.any,
  });

  final String moodId;
  final GeoPoint location;
  final int? maxPriceInr;
  final Diet diet;

  @override
  bool operator ==(Object other) =>
      other is RecommendationRequest &&
      other.moodId == moodId &&
      other.location == location &&
      other.maxPriceInr == maxPriceInr &&
      other.diet == diet;

  @override
  int get hashCode => Object.hash(moodId, location, maxPriceInr, diet);
}

/// Inputs for one chat turn. The server only reads the last [maxMessages].
class ChatRequest {
  const ChatRequest({
    required this.messages,
    required this.location,
    this.maxPriceInr,
    this.diet = Diet.any,
  });

  static const maxMessages = 6;

  final List<ChatMessage> messages;
  final GeoPoint location;
  final int? maxPriceInr;
  final Diet diet;
}

/// The two network paths, behind an interface so tests use a fake.
abstract class RecommendationGateway {
  /// Calls the `recommend` Edge Function and returns its decoded JSON body.
  Future<Object?> invokeRecommend(Map<String, dynamic> body, {required Duration timeout});

  /// Calls the `recommend_dishes` RPC directly (SQL scoring).
  Future<List<dynamic>> rpcRecommendDishes(Map<String, dynamic> params);
}

class SupabaseRecommendationGateway implements RecommendationGateway {
  const SupabaseRecommendationGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> invokeRecommend(Map<String, dynamic> body, {required Duration timeout}) async {
    final response = await _client.functions.invoke('recommend', body: body).timeout(timeout);
    return response.data;
  }

  @override
  Future<List<dynamic>> rpcRecommendDishes(Map<String, dynamic> params) =>
      _client.rpc<List<dynamic>>('recommend_dishes', params: params).timeout(networkTimeout);
}

/// Mood recommendations and food chat. Mood mode never fails just because the
/// Edge Function is unreachable: it falls back to the SQL scoring RPC.
class RecommendationRepository {
  const RecommendationRepository(this._gateway);

  final RecommendationGateway _gateway;

  static const _candidateCount = 20;

  /// Two Gemini attempts of 8 s each can happen on the server.
  static const moodTimeout = Duration(seconds: 20);
  static const chatTimeout = Duration(seconds: 40);

  Future<RecommendationResult> recommend(RecommendationRequest request) async {
    try {
      final data = await _gateway.invokeRecommend({
        'mode': 'mood',
        'mood_id': request.moodId,
        'lat': request.location.lat,
        'lng': request.location.lng,
        'max_price': request.maxPriceInr,
        'diet': request.diet.wireValue,
      }, timeout: moodTimeout);
      return _checked(RecommendationResult.fromJson(data as Map<String, dynamic>), request.diet, request.maxPriceInr);
    } catch (_) {
      return _direct(request);
    }
  }

  /// One chat turn. Errors are thrown (there is no direct-RPC equivalent of
  /// free text); the caller shows a friendly message.
  Future<RecommendationResult> chat(ChatRequest request) async {
    final recent = request.messages.length > ChatRequest.maxMessages
        ? request.messages.sublist(request.messages.length - ChatRequest.maxMessages)
        : request.messages;
    final data = await _gateway.invokeRecommend({
      'mode': 'chat',
      'messages': [for (final message in recent) message.toJson()],
      'lat': request.location.lat,
      'lng': request.location.lng,
      'max_price': request.maxPriceInr,
      'diet': request.diet.wireValue,
    }, timeout: chatTimeout);
    return _checked(RecommendationResult.fromJson(data as Map<String, dynamic>), request.diet, request.maxPriceInr);
  }

  /// A response that breaks the user's own filters is rejected, never shown.
  RecommendationResult _checked(RecommendationResult result, Diet diet, int? maxPriceInr) {
    final broken = result.picks.any(
      (pick) => !diet.allows(pick.isVeg) || (maxPriceInr != null && pick.priceInr > maxPriceInr),
    );
    if (broken) throw const FormatException('Response breaks the filters');
    return result;
  }

  Future<RecommendationResult> _direct(RecommendationRequest request) async {
    final rows = await _gateway.rpcRecommendDishes({
      'p_mood_id': request.moodId,
      'p_lat': request.location.lat,
      'p_lng': request.location.lng,
      'p_max_price': request.maxPriceInr,
      'p_diet': request.diet.wireValue,
      'p_use_embeddings': true,
      'p_limit': _candidateCount,
    });
    final ranked = rows
        .map((row) => DishRecommendation.fromJson(row as Map<String, dynamic>))
        .toList();
    return RecommendationResult(
      source: RecommendationSource.quick,
      moodId: request.moodId,
      picks: selectDiverse(ranked),
    );
  }
}

final recommendationGatewayProvider = Provider<RecommendationGateway>(
  (ref) => SupabaseRecommendationGateway(ref.watch(supabaseClientProvider)),
);

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepository(ref.watch(recommendationGatewayProvider)),
);

final recommendationsProvider = FutureProvider.autoDispose
    .family<RecommendationResult, RecommendationRequest>(
  (ref, request) => ref.watch(recommendationRepositoryProvider).recommend(request),
);
