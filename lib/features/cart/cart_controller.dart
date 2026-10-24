import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/validators.dart';
import '../../models/dish.dart';

class CartLine {
  const CartLine(this.dish, this.quantity, {this.moodId});

  final Dish dish;
  final int quantity;

  /// Mood the user picked when adding this dish from the recommendations,
  /// or `null` when it came from browsing or search.
  final String? moodId;

  int get totalInr => dish.priceInr * quantity;
}

enum AddResult { added, differentRestaurant, maxQuantity }

/// Immutable cart. One restaurant per cart, because each order goes to a
/// single kitchen (`place_order` takes one restaurant).
class CartState {
  const CartState({this.restaurantId, this.restaurantName, this.lines = const []});

  static const empty = CartState();

  final String? restaurantId;
  final String? restaurantName;
  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
  int get totalInr => lines.fold(0, (sum, line) => sum + line.totalInr);

  /// Mood to record with the order (`place_order`'s `p_mood_id`): only when
  /// every dish was added from the same mood's recommendations, so feedback
  /// is never recorded for dishes the user found by browsing.
  String? get moodId {
    if (lines.isEmpty) return null;
    final first = lines.first.moodId;
    return lines.every((line) => line.moodId == first) ? first : null;
  }

  int quantityOf(String dishId) {
    for (final line in lines) {
      if (line.dish.id == dishId) return line.quantity;
    }
    return 0;
  }

  /// Returns the new cart (unchanged unless the result is [AddResult.added]).
  /// [moodId] is the mood the dish was recommended for, if any.
  (CartState, AddResult) add(Dish dish, String restaurantName, {String? moodId}) {
    if (!isEmpty && restaurantId != dish.restaurantId) {
      return (this, AddResult.differentRestaurant);
    }
    final next = quantityOf(dish.id) + 1;
    if (Validators.quantity(next) != null) return (this, AddResult.maxQuantity);
    return (_withQuantity(dish, next, restaurantName, moodId: moodId), AddResult.added);
  }

  /// Empties the cart and starts a new one with [dish].
  CartState startWith(Dish dish, String restaurantName, {String? moodId}) =>
      CartState.empty._withQuantity(dish, 1, restaurantName, moodId: moodId);

  CartState decrement(String dishId) {
    final line = _line(dishId);
    if (line == null) return this;
    return _withQuantity(line.dish, line.quantity - 1, restaurantName, moodId: line.moodId);
  }

  CartState remove(String dishId) {
    final line = _line(dishId);
    return line == null ? this : _withQuantity(line.dish, 0, restaurantName, moodId: line.moodId);
  }

  CartLine? _line(String dishId) {
    for (final line in lines) {
      if (line.dish.id == dishId) return line;
    }
    return null;
  }

  CartState _withQuantity(Dish dish, int quantity, String? name, {String? moodId}) {
    final updated = <CartLine>[];
    var found = false;
    for (final line in lines) {
      if (line.dish.id == dish.id) {
        found = true;
        if (quantity > 0) updated.add(CartLine(dish, quantity, moodId: moodId));
      } else {
        updated.add(line);
      }
    }
    if (!found && quantity > 0) updated.add(CartLine(dish, quantity, moodId: moodId));
    if (updated.isEmpty) return CartState.empty;
    return CartState(restaurantId: dish.restaurantId, restaurantName: name, lines: updated);
  }
}

class CartController extends Notifier<CartState> {
  @override
  CartState build() => CartState.empty;

  AddResult add(Dish dish, String restaurantName, {String? moodId}) {
    final (next, result) = state.add(dish, restaurantName, moodId: moodId);
    state = next;
    return result;
  }

  void startWith(Dish dish, String restaurantName, {String? moodId}) =>
      state = state.startWith(dish, restaurantName, moodId: moodId);

  void decrement(String dishId) => state = state.decrement(dishId);

  void remove(String dishId) => state = state.remove(dishId);

  void clear() => state = CartState.empty;
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);
