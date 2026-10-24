import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/user_avatar.dart';
import '../auth/auth_repository.dart';
import '../auth/session_controller.dart';
import '../notifications/meal_notifications_tile.dart';
import 'profile_repository.dart';

enum DietChoice {
  veg('Veg', true),
  nonVeg('Non-veg only', false),
  any('No preference', null);

  const DietChoice(this.label, this.isVeg);

  final String label;
  final bool? isVeg;

  static DietChoice from(bool? isVeg) =>
      values.firstWhere((choice) => choice.isVeg == isVeg);
}

/// Profile completion after first sign-in, and profile editing later.
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _maxPrice;
  late DietChoice _diet;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(sessionControllerProvider).profile;
    _name = TextEditingController(text: profile?.fullName ?? '');
    _phone = TextEditingController(text: profile?.phone ?? '');
    _maxPrice = TextEditingController(text: profile?.defaultMaxPrice?.toString() ?? '');
    _diet = DietChoice.from(profile?.isVeg);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref.read(profileRepositoryProvider).save(
            userId: userId,
            fullName: _name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
            phone: Validators.normalizePhone(_phone.text.trim()),
            isVeg: _diet.isVeg,
            defaultMaxPrice: Validators.parseMaxPrice(_maxPrice.text),
          );
      ref.read(sessionControllerProvider).updateProfile(saved);
      if (!mounted) return;
      if (!widget.isOnboarding) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnboarding ? 'Tell us about you' : 'Your profile'),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _name,
                    builder: (context, value, _) => UserAvatar(name: value.text, size: 80),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (widget.isOnboarding) ...[
                  Text('Just a few details so we can deliver to you.', style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  maxLength: Validators.maxNameLength,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    hintText: 'e.g. Priya Sharma',
                    prefixIcon: Icon(Icons.person_outline),
                    counterText: '',
                  ),
                  validator: Validators.fullName,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phone,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d+ -]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '98765 43210',
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '+91 ',
                  ),
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Food preference', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<DietChoice>(
                  segments: [
                    for (final choice in DietChoice.values)
                      ButtonSegment(value: choice, label: Text(choice.label)),
                  ],
                  selected: {_diet},
                  onSelectionChanged: _saving ? null : (selection) => setState(() => _diet = selection.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _maxPrice,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  decoration: const InputDecoration(
                    labelText: 'Usual max price per dish (optional)',
                    hintText: 'e.g. 400, leave empty for no limit',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  validator: Validators.maxPriceInr,
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.isOnboarding ? 'Continue' : 'Save'),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!widget.isOnboarding) ...[
                  const MealNotificationsTile(),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (!widget.isOnboarding)
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.about),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('About MoodBite'),
                  ),
                TextButton(onPressed: _saving ? null : _signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
