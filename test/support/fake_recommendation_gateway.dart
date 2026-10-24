import 'package:moodbite/features/home/recommendation_repository.dart';

/// Row shaped like the `recommend_dishes` RPC / Edge Function pick.
Map<String, dynamic> dishRow(
  String id, {
  bool isVeg = true,
  int price = 150,
  String restaurant = 'r1',
  String? reason,
}) =>
    {
      'dish_id': id,
      'dish_name': 'Dish $id',
      'description': 'tasty',
      'price_inr': price,
      'is_veg': isVeg,
      'category': 'main',
      'restaurant_id': restaurant,
      'restaurant_name': 'Resto $restaurant',
      'area': 'Bandra West',
      'distance_km': 1.24,
      'score': 0.8,
      'reason': ?reason,
    };

Map<String, dynamic> edgeBody(
  String source,
  List<Map<String, dynamic>> picks, {
  String? reply,
  String? moodId = 'happy',
}) =>
    {'source': source, 'mood_id': moodId, 'reply': reply, 'picks': picks};

/// Scripted gateway: [edge] is returned (or thrown, if it is an Exception) by the
/// Edge Function call; [rpcRows] by the direct RPC. Everything sent is recorded.
class FakeRecommendationGateway implements RecommendationGateway {
  FakeRecommendationGateway({this.edge, this.rpcRows = const []});

  final Object? edge;
  final List<Map<String, dynamic>> rpcRows;

  final List<Map<String, dynamic>> edgeBodies = [];
  final List<Map<String, dynamic>> rpcParams = [];
  Duration? lastTimeout;

  @override
  Future<Object?> invokeRecommend(Map<String, dynamic> body, {required Duration timeout}) async {
    edgeBodies.add(body);
    lastTimeout = timeout;
    final scripted = edge;
    if (scripted is Exception) throw scripted;
    return scripted;
  }

  @override
  Future<List<dynamic>> rpcRecommendDishes(Map<String, dynamic> params) async {
    rpcParams.add(params);
    // Stands in for the SQL: applies the diet filter the way the RPC does.
    final diet = params['p_diet'];
    return [
      for (final row in rpcRows)
        if (diet == 'any' ||
            (diet == 'veg' && row['is_veg'] == true) ||
            (diet == 'nonveg' && row['is_veg'] == false))
          row,
    ];
  }
}
