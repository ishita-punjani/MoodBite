import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/models/address.dart';
import 'package:moodbite/models/dish.dart';
import 'package:moodbite/models/dish_recommendation.dart';
import 'package:moodbite/models/mood.dart';
import 'package:moodbite/models/profile.dart';
import 'package:moodbite/models/restaurant.dart';
import 'package:moodbite/models/zone.dart';

void main() {
  test('Restaurant.fromJson reads ints as doubles and cuisine arrays', () {
    final r = Restaurant.fromJson({
      'id': 'r001',
      'name': 'Leopold Cafe',
      'area': 'Colaba',
      'address': 'Colaba Causeway',
      'lat': 19,
      'lng': 72.83,
      'cuisine': ['cafe', 'continental'],
      'price_level': 3,
      'is_open': true,
    });
    expect(r.location.lat, 19.0);
    expect(r.cuisines, ['cafe', 'continental']);
    expect(r.priceLabel, '₹₹₹');
  });

  group('Restaurant price line', () {
    Map<String, dynamic> row({Object? level = 2, Object? dishes}) => {
          'id': 'r1',
          'name': 'X',
          'area': 'Dadar',
          'lat': 19.0,
          'lng': 72.8,
          'cuisine': <String>[],
          'price_level': level,
          'dishes': dishes,
        };

    test('takes min and max of the embedded dish prices', () {
      final r = Restaurant.fromJson(row(dishes: [
        {'price_inr': 380},
        {'price_inr': 120},
        {'price_inr': 250},
      ]));
      expect(r.priceLine, '₹₹ · Dishes from ₹120 to ₹380');
      expect(r.priceSemanticLabel, 'Price level 2 of 4, dishes from 120 to 380 rupees');
    });

    test('no dishes or no embed leaves just the price level', () {
      expect(Restaurant.fromJson(row(dishes: [])).priceLine, '₹₹');
      expect(Restaurant.fromJson(row()).priceLine, '₹₹');
    });

    test('no price level leaves just the dish range, and nothing when both are missing', () {
      final onlyDishes = Restaurant.fromJson(row(level: null, dishes: [{'price_inr': 100}, {'price_inr': 200}]));
      expect(onlyDishes.priceLine, 'Dishes from ₹100 to ₹200');
      final none = Restaurant.fromJson(row(level: null));
      expect(none.priceLine, isNull);
      expect(none.priceSemanticLabel, isNull);
    });
  });

  test('Dish, Mood and Zone parse Supabase rows', () {
    final d = Dish.fromJson({
      'id': 'd001',
      'restaurant_id': 'r001',
      'name': 'Pav Bhaji',
      'description': null,
      'price_inr': 160,
      'is_veg': true,
      'category': 'street_food',
    });
    expect(d.description, '');
    expect(d.isVeg, isTrue);

    final m = Mood.fromJson({'id': 'happy', 'label': 'Happy', 'emoji': '😄'});
    expect(m.description, '');

    final z = Zone.fromJson({'id': 'z01', 'name': 'Colaba', 'lat': 18.9, 'lng': 72.8});
    expect(z.centre.lng, 72.8);
  });

  test('Profile.isComplete needs name and phone', () {
    expect(Profile.fromJson({'id': 'u1', 'liked_cuisines': null}).isComplete, isFalse);
    expect(const Profile(id: 'u1', fullName: 'Asha', phone: ' ').isComplete, isFalse);
    expect(const Profile(id: 'u1', fullName: 'Asha', phone: '9876543210').isComplete, isTrue);
  });

  test('Address and DishRecommendation parse', () {
    final a = Address.fromJson({
      'id': 'a1',
      'label': null,
      'line1': '12 Hill Road',
      'lat': 19.05,
      'lng': 72.83,
      'zone_id': 'z13',
    });
    expect(a.label, 'Home');

    final rec = DishRecommendation.fromJson({
      'dish_id': 'd001',
      'dish_name': 'Pav Bhaji',
      'description': 'Buttery',
      'price_inr': 160,
      'is_veg': true,
      'category': 'street_food',
      'restaurant_id': 'r020',
      'restaurant_name': 'Sardar Pav Bhaji',
      'area': 'Tardeo',
      'distance_km': 1.234,
      'score': 0.81,
    });
    expect(rec.distanceLabel, '1.2 km');
  });
}
