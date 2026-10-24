import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/constants/categories.dart';
import 'package:moodbite/constants/copy.dart';

void main() {
  test('there are enough quips and notification lines, all non-empty and unique', () {
    expect(AppCopy.loadingQuips.length, greaterThanOrEqualTo(10));
    expect(AppCopy.loadingQuips.toSet(), hasLength(AppCopy.loadingQuips.length));
    expect(AppCopy.flirtyNotifications.length, greaterThanOrEqualTo(10));
    for (final n in [
      ...AppCopy.flirtyNotifications,
      ...AppCopy.breakfastNotifications,
      ...AppCopy.lunchNotifications,
      ...AppCopy.dinnerNotifications,
    ]) {
      expect(n.title.trim(), isNotEmpty);
      expect(n.body.trim(), isNotEmpty);
    }
  });

  test('randomQuip is deterministic with a seeded Random and always from the list', () {
    expect(AppCopy.randomQuip(Random(1)), AppCopy.randomQuip(Random(1)));
    for (var seed = 0; seed < 20; seed++) {
      expect(AppCopy.loadingQuips, contains(AppCopy.randomQuip(Random(seed))));
    }
  });

  test('every mood in data/moods.csv has a one-line subtitle', () {
    for (final id in ['happy', 'stressed', 'sad', 'tired', 'celebratory', 'adventurous', 'romantic', 'energetic']) {
      final subtitle = AppCopy.moodSubtitle(id, 'ignored');
      expect(subtitle, isNotEmpty);
      expect(subtitle, isNot(contains('\n')));
      expect(subtitle.length, lessThanOrEqualTo(40));
    }
  });

  test('an unknown mood uses the start of its description as the subtitle', () {
    expect(
      AppCopy.moodSubtitle('nostalgic', 'Feeling nostalgic: old-school comfort food. Plus more words.'),
      'old-school comfort food',
    );
    expect(AppCopy.moodSubtitle('x', ''), '');
  });

  test('greeting follows the time of day', () {
    expect(AppCopy.greetingForHour(0), 'Good morning');
    expect(AppCopy.greetingForHour(11), 'Good morning');
    expect(AppCopy.greetingForHour(12), 'Good afternoon');
    expect(AppCopy.greetingForHour(16), 'Good afternoon');
    expect(AppCopy.greetingForHour(17), 'Good evening');
    expect(AppCopy.greetingForHour(23), 'Good evening');
  });

  test('the price legend explains all four levels', () {
    expect(AppCopy.priceLegend, allOf(contains('₹ '), contains('₹₹ '), contains('₹₹₹ '), contains('₹₹₹₹ ')));
  });

  test('category placeholders', () {
    expect(DishCategories.emojiFor('dessert'), '🍨');
    expect(DishCategories.emojiFor('unknown'), '🍽️');
    expect(DishCategories.labelFor('street_food'), 'Street food');
  });
}
