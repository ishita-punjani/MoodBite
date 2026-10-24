import 'dish_recommendation.dart';

/// Where a recommendation came from. Shown as an "AI pick" / "Quick pick" badge.
enum RecommendationSource {
  /// Gemini chose and explained the dishes.
  ai,

  /// Scored by the database only (Gemini unavailable, capped, or the function was unreachable).
  quick;

  String get badgeLabel => switch (this) {
        ai => 'AI pick',
        quick => 'Quick pick',
      };

  /// Label for a chat reply bubble.
  String get replyLabel => switch (this) {
        ai => 'AI reply',
        quick => 'Quick reply',
      };
}

/// Response of the `recommend` Edge Function (either mode), or the direct RPC
/// fallback built by the repository.
class RecommendationResult {
  const RecommendationResult({
    required this.source,
    required this.picks,
    this.moodId,
    this.reply,
  });

  /// Throws if the shape is wrong, so the caller can fall back.
  factory RecommendationResult.fromJson(Map<String, dynamic> json) {
    final source = switch (json['source']) {
      'gemini' => RecommendationSource.ai,
      'fallback' => RecommendationSource.quick,
      _ => throw const FormatException('Unknown source'),
    };
    final picks = (json['picks'] as List<dynamic>)
        .map((row) => DishRecommendation.fromJson(row as Map<String, dynamic>))
        .toList();
    return RecommendationResult(
      source: source,
      moodId: json['mood_id'] as String?,
      reply: json['reply'] as String?,
      picks: picks,
    );
  }

  final RecommendationSource source;
  final String? moodId;

  /// Chat reply (chat mode only).
  final String? reply;
  final List<DishRecommendation> picks;
}

/// One turn of the food chat.
class ChatMessage {
  const ChatMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  Map<String, String> toJson() => {'role': isUser ? 'user' : 'assistant', 'text': text};
}
