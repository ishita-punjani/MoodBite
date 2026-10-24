import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/zone_check.dart';
import '../../models/geo_point.dart';
import '../browse/catalogue_repository.dart';
import '../home/area_picker.dart';
import '../location/location_service.dart';

class AddressDraft {
  const AddressDraft({required this.label, required this.line1, required this.location});

  final String label;
  final String line1;
  final GeoPoint location;
}

/// Form for a new delivery address: label, address line and a Mumbai
/// location from GPS or, as the fallback, the area picker.
class NewAddressForm extends ConsumerStatefulWidget {
  const NewAddressForm({super.key, required this.onSubmit, this.busy = false});

  static const labels = ['Home', 'Work', 'Other'];

  final ValueChanged<AddressDraft> onSubmit;
  final bool busy;

  @override
  ConsumerState<NewAddressForm> createState() => _NewAddressFormState();
}

class _NewAddressFormState extends ConsumerState<NewAddressForm> {
  final _formKey = GlobalKey<FormState>();
  final _line1 = TextEditingController();
  String _label = NewAddressForm.labels.first;
  GeoPoint? _point;
  String? _locationNote;
  String? _locationError;
  bool _locating = false;

  @override
  void dispose() {
    _line1.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final outcome = await ref.read(locationServiceProvider).currentLocation();
    if (!mounted) return;
    final point = outcome.point;
    if (point == null) {
      await _fallbackToAreaPicker(outcome.message);
      return;
    }
    try {
      final zones = await ref.read(zonesProvider.future);
      final match = ZoneCheck.nearest(point, zones);
      if (match == null) {
        await _fallbackToAreaPicker(ZoneCheck.outsideMumbaiMessage, notice: ZoneCheck.outsideMumbaiNotice);
        return;
      }
      if (!mounted) return;
      setState(() {
        _point = point;
        _locationNote = 'Using your current location, near ${match.zone.name}';
        _locating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = friendlyError(e);
        _locating = false;
      });
    }
  }

  Future<void> _fallbackToAreaPicker(String message, {String? notice}) async {
    if (!mounted) return;
    setState(() {
      _locationError = message;
      _locating = false;
    });
    await _chooseArea(notice: notice ?? message);
  }

  Future<void> _chooseArea({String? notice}) async {
    final zone = await showAreaPicker(context, notice: notice);
    if (zone == null || !mounted) return;
    setState(() {
      _point = zone.centre;
      _locationNote = 'Delivering to ${zone.name} (area centre). Add landmarks in the address.';
      _locationError = null;
    });
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    if (_point == null) {
      setState(() => _locationError = _locationError ?? 'Choose your delivery location');
      return;
    }
    if (!formValid) return;
    widget.onSubmit(AddressDraft(label: _label, line1: _line1.text.trim(), location: _point!));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _label,
            decoration: const InputDecoration(
              labelText: 'Save as',
              hintText: 'Home, Work or Other',
              prefixIcon: Icon(Icons.label_outline),
            ),
            items: [for (final label in NewAddressForm.labels) DropdownMenuItem(value: label, child: Text(label))],
            onChanged: (value) => setState(() => _label = value ?? _label),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _line1,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.done,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Delivery address',
              hintText: 'Flat, building, street, landmark',
              prefixIcon: Icon(Icons.home_outlined),
            ),
            validator: Validators.addressLine,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Location', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _locating || widget.busy ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: const Text('Use my location'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _locating || widget.busy ? null : _chooseArea,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Choose area'),
                ),
              ),
            ],
          ),
          if (_locationNote != null && _locationError == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_locationNote!, style: textTheme.bodySmall?.copyWith(color: AppColors.success)),
            ),
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_locationError!, style: textTheme.bodySmall?.copyWith(color: AppColors.error)),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: widget.busy || _locating ? null : _submit,
            child: widget.busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save address'),
          ),
        ],
      ),
    );
  }
}
