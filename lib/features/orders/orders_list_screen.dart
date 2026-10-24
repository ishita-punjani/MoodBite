import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../widgets/brand.dart';
import '../../widgets/dish_image.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../tracking/tracking_logic.dart';
import 'order_repository.dart';

/// Orders tab: every order, newest first, with its (simulated) status.
class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('Orders'), actions: const [ProfileAvatarButton()]),
      body: orders.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(ordersProvider),
        ),
        data: (list) => list.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EmptyView(
                    emoji: '🍽️',
                    title: 'No orders yet',
                    message: 'Your orders will show up here.',
                  ),
                  FilledButton.tonal(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text('Pick a mood'),
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(ordersProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _OrderCard(order: list[index]),
                ),
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = TrackingSchedule.demo.statusAt(order.elapsedAt(DateTime.now()));
    final delivered = status == DeliveryStatus.delivered;
    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.trackOrder(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              RestaurantImage(restaurantId: order.restaurantId, width: 72, height: 72),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.restaurantName, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${order.itemCount} items · ₹${order.totalInr}', style: textTheme.bodyMedium),
                    Text(_formatPlaced(order.placedAt), style: textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        delivered ? Icons.check_circle : Icons.delivery_dining,
                        size: 18,
                        color: delivered ? AppColors.success : AppColors.primary,
                      ),
                      label: Text(status.label),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPlaced(DateTime time) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'am' : 'pm';
  return '${time.day} ${months[time.month - 1]}, $hour:$minute $period';
}
