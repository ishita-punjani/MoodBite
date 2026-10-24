import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/diet.dart';
import '../../models/zone.dart';
import '../auth/session_controller.dart';

/// Delivery area chosen with the area picker. GPS comes in a later step.
class DeliveryZoneController extends Notifier<Zone?> {
  @override
  Zone? build() => null;

  void select(Zone zone) => state = zone;
}

final deliveryZoneProvider =
    NotifierProvider<DeliveryZoneController, Zone?>(DeliveryZoneController.new);

class RecommendationFilters {
  const RecommendationFilters({this.maxPriceInr, this.diet = Diet.any});

  final int? maxPriceInr;
  final Diet diet;
}

/// Starts from the profile defaults; the user can change them per search.
class RecommendationFiltersController extends Notifier<RecommendationFilters> {
  @override
  RecommendationFilters build() {
    final profile = ref.read(sessionControllerProvider).profile;
    return RecommendationFilters(
      maxPriceInr: profile?.defaultMaxPrice,
      diet: Diet.fromProfile(profile?.isVeg),
    );
  }

  void setMaxPrice(int? price) =>
      state = RecommendationFilters(maxPriceInr: price, diet: state.diet);

  void setDiet(Diet diet) => state = RecommendationFilters(maxPriceInr: state.maxPriceInr, diet: diet);
}

final recommendationFiltersProvider =
    NotifierProvider<RecommendationFiltersController, RecommendationFilters>(
  RecommendationFiltersController.new,
);
