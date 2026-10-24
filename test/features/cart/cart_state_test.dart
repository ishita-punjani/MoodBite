import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/features/cart/cart_controller.dart';
import 'package:moodbite/models/dish.dart';

Dish dish(String id, {String restaurant = 'r001', int price = 100}) => Dish(
      id: id,
      restaurantId: restaurant,
      name: 'Dish $id',
      description: '',
      priceInr: price,
      isVeg: true,
      category: 'main',
    );

void main() {
  test('adding dishes accumulates quantity and total', () {
    var cart = CartState.empty;
    (cart, _) = cart.add(dish('d1', price: 120), 'Cafe');
    (cart, _) = cart.add(dish('d1', price: 120), 'Cafe');
    final (next, result) = cart.add(dish('d2', price: 80), 'Cafe');
    expect(result, AddResult.added);
    expect(next.quantityOf('d1'), 2);
    expect(next.itemCount, 3);
    expect(next.totalInr, 320);
    expect(next.restaurantName, 'Cafe');
  });

  test('quantity cannot go above 10', () {
    var cart = CartState.empty;
    for (var i = 0; i < 10; i++) {
      (cart, _) = cart.add(dish('d1'), 'Cafe');
    }
    final (next, result) = cart.add(dish('d1'), 'Cafe');
    expect(result, AddResult.maxQuantity);
    expect(next.quantityOf('d1'), 10);
  });

  test('a dish from another restaurant is refused until the cart is restarted', () {
    var (cart, _) = CartState.empty.add(dish('d1'), 'Cafe');
    final (same, result) = cart.add(dish('d9', restaurant: 'r002'), 'Diner');
    expect(result, AddResult.differentRestaurant);
    expect(same, same);
    expect(same.restaurantId, 'r001');

    cart = cart.startWith(dish('d9', restaurant: 'r002'), 'Diner');
    expect(cart.restaurantId, 'r002');
    expect(cart.lines, hasLength(1));
  });

  test('decrement to zero removes the line, and an empty cart forgets the restaurant', () {
    var (cart, _) = CartState.empty.add(dish('d1'), 'Cafe');
    cart = cart.decrement('d1');
    expect(cart.isEmpty, isTrue);
    expect(cart.restaurantId, isNull);
    expect(cart.decrement('missing'), same(cart));
  });

  test('remove deletes one dish only', () {
    var (cart, _) = CartState.empty.add(dish('d1'), 'Cafe');
    (cart, _) = cart.add(dish('d2'), 'Cafe');
    cart = cart.remove('d1');
    expect(cart.quantityOf('d1'), 0);
    expect(cart.quantityOf('d2'), 1);
  });

  group('mood tracking', () {
    test('a cart built only from one mood reports that mood', () {
      var (cart, _) = CartState.empty.add(dish('d1'), 'Cafe', moodId: 'happy');
      (cart, _) = cart.add(dish('d2'), 'Cafe', moodId: 'happy');
      expect(cart.moodId, 'happy');
    });

    test('browsed dishes have no mood', () {
      final (cart, _) = CartState.empty.add(dish('d1'), 'Cafe');
      expect(cart.moodId, isNull);
      expect(CartState.empty.moodId, isNull);
    });

    test('mixing a recommended dish with a browsed one drops the mood', () {
      var (cart, _) = CartState.empty.add(dish('d1'), 'Cafe', moodId: 'sad');
      (cart, _) = cart.add(dish('d2'), 'Cafe');
      expect(cart.moodId, isNull);
    });

    test('mixing two different moods drops the mood', () {
      var (cart, _) = CartState.empty.add(dish('d1'), 'Cafe', moodId: 'sad');
      (cart, _) = cart.add(dish('d2'), 'Cafe', moodId: 'happy');
      expect(cart.moodId, isNull);
    });

    test('removing the browsed dish brings the mood back, and decrement keeps it', () {
      var (cart, _) = CartState.empty.add(dish('d1'), 'Cafe', moodId: 'sad');
      (cart, _) = cart.add(dish('d1'), 'Cafe', moodId: 'sad');
      (cart, _) = cart.add(dish('d2'), 'Cafe');
      cart = cart.remove('d2').decrement('d1');
      expect(cart.moodId, 'sad');
      expect(cart.quantityOf('d1'), 1);
    });

    test('startWith keeps the mood of the new dish only', () {
      final (cart, _) = CartState.empty.add(dish('d1'), 'Cafe', moodId: 'sad');
      final restarted = cart.startWith(dish('d9', restaurant: 'r002'), 'Diner');
      expect(restarted.moodId, isNull);
    });
  });
}
