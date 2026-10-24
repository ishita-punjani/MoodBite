import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/brand.dart';
import 'auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sending = false;
  bool _googleBusy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      await ref.read(authRepositoryProvider).sendEmailOtp(email);
      if (mounted) context.push(AppRoutes.verifyFor(email));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _googleBusy;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(size: 96)),
                  const SizedBox(height: AppSpacing.md),
                  Text('MoodBite', textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Food for every mood', textAlign: TextAlign.center, style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    maxLength: Validators.maxEmailLength,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.mail_outline),
                      counterText: '',
                    ),
                    validator: Validators.email,
                    onFieldSubmitted: (_) => _sendCode(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('We will email you a 6-digit code to sign in.', style: textTheme.bodySmall),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.error)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: busy ? null : _sendCode,
                    child: _sending
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send code'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text('or', style: textTheme.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _signInWithGoogle,
                    icon: _googleBusy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.account_circle_outlined),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kMinTouchTarget)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
