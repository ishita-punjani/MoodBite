/// Emoji placeholders for dish categories (no dish photos are used).
abstract final class DishCategories {
  static const _emoji = {
    'starter': '🍢',
    'main': '🍛',
    'rice': '🍚',
    'street_food': '🌯',
    'south_indian': '🥞',
    'breakfast': '🍳',
    'bread': '🫓',
    'bakery': '🥐',
    'snack': '🥪',
    'pizza_pasta': '🍕',
    'salad': '🥗',
    'dessert': '🍨',
    'beverage': '🥤',
    'thali': '🍱',
    'seafood': '🦐',
  };

  static String emojiFor(String category) => _emoji[category] ?? '🍽️';

  /// "street_food" -> "Street food"
  static String labelFor(String category) {
    final words = category.replaceAll('_', ' ');
    return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
  }
}
