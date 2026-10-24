import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/copy.dart';
import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../models/geo_point.dart';
import '../../models/order.dart';
import '../../widgets/state_views.dart';
import '../orders/order_repository.dart';
import 'route_service.dart';
import 'tracking_logic.dart';

/// Simulated delivery tracking for one order ("Demo delivery").
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Track order')),
      body: order.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(orderProvider(orderId)),
        ),
        data: (order) => order == null
            ? const EmptyView(emoji: '🤔', title: 'Order not found', message: 'It may have been removed.')
            : TrackingBody(order: order),
      ),
    );
  }
}

class TrackingBody extends ConsumerStatefulWidget {
  const TrackingBody({super.key, required this.order, this.schedule = TrackingSchedule.demo});

  final Order order;
  final TrackingSchedule schedule;

  @override
  ConsumerState<TrackingBody> createState() => _TrackingBodyState();
}

class _TrackingBodyState extends ConsumerState<TrackingBody> {
  Timer? _ticker;
  late DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final elapsed = widget.order.elapsedAt(DateTime.now());
    setState(() => _now = DateTime.now());
    if (widget.schedule.statusAt(elapsed) == DeliveryStatus.delivered) _ticker?.cancel();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final schedule = widget.schedule;
    final elapsed = order.elapsedAt(_now);
    final status = schedule.statusAt(elapsed);

    final ends = (order.restaurantLocation, order.deliveryLocation);
    final route = ref.watch(orderRouteProvider(ends)).asData?.value ??
        RouteResult([order.restaurantLocation, order.deliveryLocation], isStraightLine: true);
    final rider = pointAlongRoute(route.points, schedule.routeProgress(elapsed));
    final riderVisible = status.index >= DeliveryStatus.pickedUp.index;

    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _TrackingMap(
            order: order,
            route: route.points,
            rider: riderVisible ? rider : null,
          ),
        ),
        Expanded(
          flex: 6,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(Icons.science_outlined, size: 18),
                  label: Text(AppCopy.demoDeliveryLabel),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(status.label, key: const Key('tracking-headline'), style: textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(schedule.etaLabel(elapsed), style: textTheme.titleMedium),
              Text(order.restaurantName, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              if (route.isStraightLine)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Showing a straight line because the road route is unavailable.',
                    style: textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              _StatusTimeline(current: status),
              const SizedBox(height: AppSpacing.md),
              Text(
                'There is no real rider. This delivery is simulated for demonstration.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

LatLng _latLng(GeoPoint point) => LatLng(point.lat, point.lng);

class _TrackingMap extends StatelessWidget {
  const _TrackingMap({required this.order, required this.route, required this.rider});

  final Order order;
  final List<GeoPoint> route;
  final GeoPoint? rider;

  @override
  Widget build(BuildContext context) {
    final restaurant = _latLng(order.restaurantLocation);
    final delivery = _latLng(order.deliveryLocation);
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: [restaurant, delivery],
          padding: const EdgeInsets.all(56),
          maxZoom: 16,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ishita.moodbite',
        ),
        PolylineLayer(
          polylines: [
            Polyline(points: route.map(_latLng).toList(), strokeWidth: 4, color: AppColors.primary),
          ],
        ),
        MarkerLayer(
          markers: [
            _marker(restaurant, Icons.storefront, AppColors.textPrimary),
            _marker(delivery, Icons.home, AppColors.success),
            if (rider != null) _marker(_latLng(rider!), Icons.delivery_dining, AppColors.primary, size: 40),
          ],
        ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
      ],
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color, {double size = 34}) => Marker(
        point: point,
        width: size + 8,
        height: size + 8,
        child: Icon(icon, size: size, color: color),
      );
}

/// Vertical timeline: a filled dot and line for finished steps, a ring for the
/// current one, grey for the steps still to come.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.current});

  final DeliveryStatus current;

  @override
  Widget build(BuildContext context) {
    const steps = DeliveryStatus.values;
    return Column(
      children: [
        for (final status in steps)
          _TimelineRow(
            status: status,
            done: status.index < current.index,
            isCurrent: status == current,
            isLast: status == steps.last,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.status, required this.done, required this.isCurrent, required this.isLast});

  final DeliveryStatus status;
  final bool done;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final reached = done || isCurrent;
    final state = done ? 'done' : (isCurrent ? 'current step' : 'upcoming');
    return Semantics(
      label: '${status.label}, $state',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Icon(
                    done ? Icons.check_circle : (isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    size: 24,
                    color: reached ? AppColors.success : AppColors.textSecondary,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: done ? AppColors.success : AppColors.border),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  status.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                        color: reached ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
