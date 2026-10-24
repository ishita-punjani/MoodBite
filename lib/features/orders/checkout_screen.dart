import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/copy.dart';
import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/address.dart';
import '../../widgets/state_views.dart';
import '../../widgets/sticky_total_bar.dart';
import '../cart/cart_controller.dart';
import 'address_repository.dart';
import 'new_address_form.dart';
import 'order_repository.dart';

/// Pick or add a delivery address, then place the order via `place_order`.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _selectedId;
  bool _addingNew = false;
  bool _savingAddress = false;
  bool _placing = false;
  String? _error;

  Future<void> _saveAddress(AddressDraft draft) async {
    setState(() {
      _savingAddress = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(addressRepositoryProvider)
          .add(label: draft.label, line1: draft.line1, location: draft.location);
      ref.invalidate(addressesProvider);
      if (!mounted) return;
      setState(() {
        _selectedId = saved.id;
        _addingNew = false;
        _savingAddress = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _savingAddress = false;
      });
    }
  }

  Future<void> _placeOrder(String addressId) async {
    final cart = ref.read(cartProvider);
    final restaurantId = cart.restaurantId;
    if (cart.isEmpty || restaurantId == null) return;
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final orderId = await ref.read(orderRepositoryProvider).placeOrder(
            addressId: addressId,
            restaurantId: restaurantId,
            lines: cart.lines,
            moodId: cart.moodId,
          );
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(ordersProvider);
      if (mounted) context.go(AppRoutes.orderConfirmation(orderId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _placing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final addresses = ref.watch(addressesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: cart.isEmpty && !_placing
          ? const EmptyView(emoji: '🛍️', title: 'Your cart is empty', message: 'Add a dish before checking out.')
          : addresses.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(addressesProvider),
              ),
              data: (saved) {
                final selected = saved.any((a) => a.id == _selectedId) ? _selectedId : saved.firstOrNull?.id;
                final showForm = _addingNew || saved.isEmpty;
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          _SectionCard(
                            title: '1. Order summary',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cart.restaurantName ?? 'Your order', style: textTheme.titleSmall),
                                const SizedBox(height: AppSpacing.sm),
                                for (final line in cart.lines)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text('${line.quantity} x ${line.dish.name}')),
                                        Text('₹${line.totalInr}'),
                                      ],
                                    ),
                                  ),
                                const Divider(height: AppSpacing.lg),
                                Row(
                                  children: [
                                    Expanded(child: Text('Total', style: textTheme.titleMedium)),
                                    Text('₹${cart.totalInr}', style: textTheme.titleMedium),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SectionCard(
                            title: '2. Delivery address',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final address in saved)
                                  _AddressTile(
                                    address: address,
                                    selected: address.id == selected && !showForm,
                                    onTap: _placing
                                        ? null
                                        : () => setState(() {
                                              _selectedId = address.id;
                                              _addingNew = false;
                                            }),
                                  ),
                                if (showForm) ...[
                                  if (saved.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                      child: Text('Add your first delivery address.', style: textTheme.bodySmall),
                                    ),
                                  NewAddressForm(onSubmit: _saveAddress, busy: _savingAddress),
                                ] else
                                  TextButton.icon(
                                    onPressed: _placing ? null : () => setState(() => _addingNew = true),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add a new address'),
                                  ),
                              ],
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.md),
                              child: Text(_error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.error)),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '${AppCopy.demoDeliveryLabel}: no real rider or payment is involved.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!showForm)
                      StickyTotalBar(
                        totalInr: cart.totalInr,
                        caption: '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
                        buttonLabel: 'Place order',
                        busy: _placing,
                        onPressed: selected == null ? null : () => _placeOrder(selected),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address, required this.selected, required this.onTap});

  final Address address;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(address.label),
      subtitle: Text(address.line1),
      onTap: onTap,
    );
  }
}
