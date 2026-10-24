import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/restaurant.dart';

/// "₹₹ · Dishes from ₹120 to ₹380" for a restaurant. Draws nothing when
/// neither the price level nor the dish prices are known.
class PriceLine extends StatelessWidget {
  const PriceLine(this.restaurant, {super.key});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final text = restaurant.priceLine;
    if (text == null) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodyMedium;
    return Semantics(
      label: restaurant.priceSemanticLabel,
      excludeSemantics: true,
      child: Text(text, style: style?.copyWith(fontWeight: FontWeight.w500, color: AppColors.primary)),
    );
  }
}
