import '../../models/dish_recommendation.dart';
import '../../models/mood.dart';

/// Number of dishes shown for a mood.
const recommendationCount = 5;

/// Picks [count] dishes from score-ordered [ranked] so the list is varied:
/// first pass allows one dish per restaurant and two per category; if that
/// gives too few, the best remaining dishes fill the gaps.
List<DishRecommendation> selectDiverse(
  List<DishRecommendation> ranked, {
  int count = recommendationCount,
}) {
  final picked = <DishRecommendation>[];
  final restaurants = <String>{};
  final categories = <String, int>{};

  for (final rec in ranked) {
    if (picked.length == count) break;
    final categoryCount = categories[rec.category] ?? 0;
    if (restaurants.contains(rec.restaurantId) || categoryCount >= 2) continue;
    picked.add(rec);
    restaurants.add(rec.restaurantId);
    categories[rec.category] = categoryCount + 1;
  }
  for (final rec in ranked) {
    if (picked.length == count) break;
    if (!picked.contains(rec)) picked.add(rec);
  }
  return picked;
}

/// Template reason used when there is no AI-written one (SQL baseline and
/// the fallback path).
String templateReason(DishRecommendation rec, Mood mood) {
  final distance = rec.distanceLabel;
  return '${mood.emoji} A good match for feeling ${mood.label.toLowerCase()}, '
      'from ${rec.restaurantName}, $distance away.';
}
