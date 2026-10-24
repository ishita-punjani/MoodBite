import 'package:flutter/material.dart';

import '../core/theme.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Remove one',
            icon: const Icon(Icons.remove, color: AppColors.primary),
            onPressed: onDecrement,
          ),
          Semantics(
            label: 'Quantity $quantity',
            excludeSemantics: true,
            child: Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            tooltip: 'Add one',
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}
