import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/features/home/recommendation_logic.dart';
import 'package:moodbite/models/dish_recommendation.dart';
import 'package:moodbite/models/mood.dart';

DishRecommendation rec(String id, String restaurant, String category, double score) => DishRecommendation(
      dishId: id,
      dishName: 'Dish $id',
      description: '',
      priceInr: 100,
      isVeg: true,
      category: category,
      restaurantId: restaurant,
      restaurantName: 'Restaurant $restaurant',
      area: 'Bandra West',
      distanceKm: 1.24,
      score: score,
    );

void main() {
  test('takes one dish per restaurant and at most two per category first', () {
    final ranked = [
      rec('d1', 'r1', 'dessert', 0.9),
      rec('d2', 'r1', 'dessert', 0.89), // same restaurant
      rec('d3', 'r2', 'dessert', 0.88),
      rec('d4', 'r3', 'dessert', 0.87), // third dessert
      rec('d5', 'r4', 'main', 0.86),
      rec('d6', 'r5', 'rice', 0.85),
      rec('d7', 'r6', 'snack', 0.84),
    ];
    final picked = selectDiverse(ranked);
    expect(picked.map((r) => r.dishId), ['d1', 'd3', 'd5', 'd6', 'd7']);
  });

  test('fills up with the best remaining dishes when variety runs out', () {
    final ranked = [
      rec('d1', 'r1', 'main', 0.9),
      rec('d2', 'r1', 'main', 0.8),
      rec('d3', 'r1', 'main', 0.7),
    ];
    expect(selectDiverse(ranked).map((r) => r.dishId), ['d1', 'd2', 'd3']);
    expect(selectDiverse(const []), isEmpty);
  });

  test('never returns more than the requested count', () {
    final ranked = [for (var i = 0; i < 20; i++) rec('d$i', 'r$i', 'c$i', 1 - i / 100)];
    expect(selectDiverse(ranked), hasLength(recommendationCount));
  });

  test('template reason mentions mood, restaurant and rounded distance', () {
    const mood = Mood(id: 'happy', label: 'Happy', emoji: '😄');
    final text = templateReason(rec('d1', 'r1', 'main', 1), mood);
    expect(text, contains('happy'));
    expect(text, contains('Restaurant r1'));
    expect(text, contains('1.2 km'));
  });
}
