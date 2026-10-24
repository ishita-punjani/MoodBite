/// One photo per dish type. The slug is the file name in `assets/dishes/`
/// (`<slug>.jpg`) and must match the list in `scripts/fetch_images.py`.
class DishImageType {
  const DishImageType(this.slug, this.keywords);

  final String slug;

  /// Lower-case words looked for in the dish name.
  final List<String> keywords;
}

abstract final class DishImageTypes {
  /// Order matters: the first type with a matching keyword wins, so specific
  /// types come before general ones (e.g. "samosa chaat" before "samosa").
  static const all = [
    DishImageType('coffee', ['coffee', 'cappuccino', 'hot chocolate']),
    DishImageType('ice-cream', ['ice cream', 'kulfi', 'falooda']),
    DishImageType('vada-pav', ['vada pav', 'batata vada']),
    DishImageType('pav-bhaji', ['pav bhaji']),
    DishImageType('misal', ['misal']),
    DishImageType('pani-puri', ['pani puri']),
    DishImageType('soup', ['soup', 'shorba']),
    DishImageType('dim-sum', ['dim sum', 'har gow']),
    DishImageType('chaat', ['bhel', 'sev puri', 'dahi puri', 'chaat', 'ragda']),
    DishImageType('samosa', ['samosa', 'kachori']),
    DishImageType('bakery', ['croissant', 'puff', 'bun maska', 'brun maska', 'doughnut', 'apple pie', 'cinnamon']),
    DishImageType('kathi-roll', ['roll', 'frankie']),
    DishImageType('burger', ['burger']),
    DishImageType('sandwich', ['sandwich']),
    DishImageType('pizza', ['pizza']),
    DishImageType('risotto', ['risotto']),
    DishImageType('pasta', ['pasta', 'penne', 'spaghetti', 'lasagne', 'alfredo']),
    DishImageType('manchurian', ['manchurian', 'chilli paneer', 'chilli chicken', 'kung pao', 'chopsuey']),
    DishImageType('noodles', ['noodle', 'khow suey', 'hakka']),
    DishImageType('fried-rice', ['fried rice']),
    DishImageType('biryani', ['biryani', 'pulao']),
    DishImageType('dal', ['dal makhani']),
    DishImageType('chole-bhature', ['chole', 'bhature', 'dal pakwan']),
    DishImageType('paneer-curry', ['paneer butter', 'malai kofta', 'kofta', 'mushroom xacuti']),
    DishImageType('mutton-curry', ['laal maas', 'nihari', 'dhansak', 'salli boti', 'vindaloo', 'kheema', 'bheja']),
    DishImageType('chicken-curry', ['butter chicken', 'changezi', 'ghee roast', 'xacuti', 'chicken stew', 'chicken curry', 'kori rotti']),
    DishImageType('prawns', ['prawn', 'crab', 'tisrya']),
    DishImageType('paneer-tikka', ['paneer tikka']),
    DishImageType('kebab-tikka', ['kebab', 'seekh', 'galouti', 'tikka', 'tandoori', 'raan', 'barbeque', 'barbecue', 'bbq', 'wings', 'farcha']),
    DishImageType('fish-fry', ['bombil', 'pomfret', 'fish and chips', 'fish fry']),
    DishImageType('fish-curry', ['fish curry', 'surmai', 'patra ni', 'basa', 'machhi']),
    DishImageType('thali', ['thali', 'undhiyu']),
    DishImageType('dosa', ['dosa', 'uttapam', 'appam']),
    DishImageType('idli', ['idli', 'medu vada']),
    DishImageType('upma-poha', ['upma', 'poha', 'sabudana khichdi']),
    DishImageType('paratha', ['paratha', 'thepla', 'puri bhaji', 'aamras puri']),
    DishImageType('comfort-rice', ['khichdi', 'dal dhokli', 'bisi bele', 'curd rice', 'rasam rice', 'pongal']),
    DishImageType('eggs', ['egg', 'omelette', 'baida', 'shakshuka', 'akuri', 'kejriwal']),
    DishImageType('bread', ['naan', 'roti', 'bhakri', 'kulcha', 'zunka']),
    DishImageType('fruit-dessert', ['mango cream', 'strawberry cream', 'sitaphal cream', 'fruit salad', 'pineapple']),
    DishImageType('salad', ['salad', 'quinoa', 'greens']),
    DishImageType('grill-platter', ['sizzler', 'steak', 'grilled chicken', 'roast duck', 'sausage']),
    DishImageType('breakfast', ['breakfast', 'pancake', 'toast', 'waffle']),
    DishImageType('gujarati-snack', ['dhokla', 'handvo', 'panki', 'kothimbir vadi', 'khaman']),
    DishImageType('pakora', ['bhaji', 'sabudana vada', 'vade', 'vada']),
    DishImageType('nachos', ['nachos', 'cajun', 'fondue', 'potatoes', 'fries']),
    DishImageType('cake', ['cake', 'pastry', 'brownie', 'eclair', 'tiramisu']),
    DishImageType('indian-sweet', [
      'gulab jamun', 'jalebi', 'rasmalai', 'kaju katli', 'shahi tukda', 'malpua', 'phirni',
      'payasam', 'modak', 'puran poli', 'shrikhand', 'amrakhand', 'rava kesari', 'bebinca', 'custard',
    ]),
    DishImageType('lassi', ['lassi', 'chaas', 'piyush', 'sol kadhi']),
    DishImageType('juice', ['juice', 'soda', 'sharbat', 'lime', 'iced tea', 'kokum']),
    DishImageType('chai', ['chai', 'tea']),
  ];

  /// Used when no keyword matches. Veg-safe on purpose: a vegetarian dish
  /// should never get a chicken photo.
  static const categoryFallback = {
    'starter': 'pakora',
    'main': 'paneer-curry',
    'rice': 'comfort-rice',
    'street_food': 'chaat',
    'south_indian': 'dosa',
    'breakfast': 'breakfast',
    'bread': 'bread',
    'bakery': 'bakery',
    'snack': 'sandwich',
    'pizza_pasta': 'pizza',
    'salad': 'salad',
    'dessert': 'indian-sweet',
    'beverage': 'juice',
    'thali': 'thali',
    'seafood': 'fish-curry',
  };
}

/// Picks a bundled photo for a dish. Only assets that really exist in the
/// app bundle are returned, so the app works with zero images (callers show
/// the emoji placeholder when this returns `null`).
class DishImageResolver {
  const DishImageResolver(this.availableAssets);

  /// Resolver for an app with no photos.
  static const none = DishImageResolver({});

  final Set<String> availableAssets;

  static String assetPath(String slug) => 'assets/dishes/$slug.jpg';

  /// Asset path for a dish: keyword match on the name, then the category
  /// fallback, then `null`.
  String? assetFor(String name, String category) {
    final lower = name.toLowerCase();
    for (final type in DishImageTypes.all) {
      if (type.keywords.any(lower.contains) && availableAssets.contains(assetPath(type.slug))) {
        return assetPath(type.slug);
      }
    }
    final fallback = DishImageTypes.categoryFallback[category];
    if (fallback != null && availableAssets.contains(assetPath(fallback))) {
      return assetPath(fallback);
    }
    return null;
  }
}
