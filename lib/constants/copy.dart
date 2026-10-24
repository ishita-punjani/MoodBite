import 'dart:math';

/// App personality copy (CLAUDE.md section 10). All lines are original.

class NotificationCopy {
  const NotificationCopy(this.title, this.body);

  final String title;
  final String body;
}

abstract final class AppCopy {
  static const demoDataNotice =
      'Demo data: restaurant names are real Mumbai places, but menus and '
      'prices are illustrative and are not the restaurants\' actual menus.';
  static const demoDeliveryLabel = 'Demo delivery';

  /// Shown above the restaurant list so the ₹ symbols are not a mystery.
  static const priceLegend = '₹ budget, ₹₹ moderate, ₹₹₹ premium, ₹₹₹₹ luxury';

  static const searchSuggestions = [
    'Biryani',
    'Pizza',
    'Dosa',
    'Dessert',
    'Coffee',
    'Seafood',
    'Street food',
    'Thali',
  ];

  static const chatHint = "Tell me how you feel or what you're craving";
  static const chatSuggestions = [
    "I'm stressed, something warm",
    'Spicy under ₹300',
    'Surprise me',
    'Light and healthy',
  ];

  /// One-line subtitle per mood card.
  static const _moodSubtitles = {
    'happy': 'Fun, colourful food to share',
    'stressed': 'Warm, soothing comfort food',
    'sad': 'Sweet treats and a hug on a plate',
    'tired': 'Light, quick and easy',
    'celebratory': 'Rich, festive platters',
    'adventurous': 'Bold, spicy, unusual picks',
    'romantic': 'Elegant dishes for two',
    'energetic': 'Fresh, light and protein-rich',
  };

  /// Subtitle for a mood card; unknown moods use the start of their description.
  static String moodSubtitle(String moodId, String description) {
    final known = _moodSubtitles[moodId];
    if (known != null) return known;
    final afterColon = description.contains(':') ? description.split(':').last.trim() : description.trim();
    return afterColon.split(RegExp(r'[.;]')).first.trim();
  }

  /// "Good morning" / "Good afternoon" / "Good evening" for an hour 0-23.
  static String greetingForHour(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const loadingQuips = [
    'Asking the chef how you are feeling...',
    'Matching your mood with something delicious...',
    'Consulting the snack council...',
    'Reading your mood like a menu...',
    'Warming up the tandoor of recommendations...',
    'Counting the pav for your bhaji...',
    'Negotiating extra crispiness with the dosa...',
    'Stirring the algorithm with a little masala...',
    'Checking which kitchens are close to you...',
    'Finding food that gets you...',
    'Separating the biryani from the rest...',
    'Teaching the AI the difference between hungry and hangry...',
    'Plating up your picks...',
    'Making sure dessert gets a seat at the table...',
    'One moment, the chutney is still deciding...',
    'Scanning Mumbai for your next favourite bite...',
  ];

  static const flirtyNotifications = [
    NotificationCopy('Thinking of you', 'And a plate of hot pav bhaji. Coincidence? We think not.'),
    NotificationCopy('Are you a samosa?', 'Because you have been on our mind all day, warm and crispy.'),
    NotificationCopy('It is not you, it is your stomach', 'Let us fix that. Tell us your mood and we will handle dinner.'),
    NotificationCopy('Hey good-looking', 'What is cooking? Nothing? Let a Mumbai kitchen cook for you.'),
    NotificationCopy('We saved you a seat', 'Pick a mood and we will bring the food to you.'),
    NotificationCopy('Plot twist', 'Your mood today might just be "biryani". Want to find out?'),
    NotificationCopy('We need to talk', 'About how you have not had dessert today.'),
    NotificationCopy('Roses are red, chutney is green', 'The best meal of your week is one tap away.'),
    NotificationCopy('Not to be clingy, but...', 'Your favourite comfort food is still waiting for you.'),
    NotificationCopy('Swipe right on lunch', 'We found dishes that match your vibe. No awkward small talk.'),
    NotificationCopy('You + chai = a love story', 'Treat yourself to something warm today.'),
    NotificationCopy('Feeling some type of way?', 'There is a dish for that. Pick a mood and see.'),
  ];

  static const breakfastNotifications = [
    NotificationCopy('Rise and dine', 'Poha, idli or a buttery bun maska? Start the day right.'),
    NotificationCopy('Good morning!', 'Breakfast is the most important mood of the day.'),
  ];

  static const lunchNotifications = [
    NotificationCopy('Lunch o\'clock', 'Your desk deserves a break, and so do you.'),
    NotificationCopy('Hungry yet?', 'Tell us how the day is going and we will match your lunch.'),
  ];

  static const dinnerNotifications = [
    NotificationCopy('Dinner plans?', 'Skip the "what should we eat" debate. Pick a mood instead.'),
    NotificationCopy('The day is done', 'Wind down with something comforting from nearby.'),
  ];

  static T pick<T>(List<T> options, [Random? random]) =>
      options[(random ?? Random()).nextInt(options.length)];

  static String randomQuip([Random? random]) => pick(loadingQuips, random);
}
