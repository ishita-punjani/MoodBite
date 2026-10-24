import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../widgets/emoji.dart';
import '../../widgets/state_views.dart';
import 'order_repository.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Order placed'), automaticallyImplyLeading: false),
      body: order.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(orderProvider(orderId)),
        ),
        data: (order) => order == null
            ? const EmptyView(emoji: '🤔', title: 'Order not found', message: 'It may have been removed.')
            : _Receipt(order: order),
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Center(child: Emoji('🎉', label: 'Celebration', size: 56)),
        const SizedBox(height: AppSpacing.sm),
        Text('Order placed!', textAlign: TextAlign.center, style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(order.restaurantName, textAlign: TextAlign.center, style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(child: Text('${item.quantity} x ${item.name}')),
                Text('₹${item.totalInr}'),
              ],
            ),
          ),
        const Divider(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: Text('Total', style: textTheme.titleMedium)),
            Text('₹${order.totalInr}', style: textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => context.go(AppRoutes.trackOrder(order.id)),
          child: const Text('Track order'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.orders),
          child: const Text('View my orders'),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Back to home'),
        ),
      ],
    );
  }
}
