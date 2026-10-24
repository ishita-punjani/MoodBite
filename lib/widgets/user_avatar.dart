import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../features/auth/session_controller.dart';

/// "Priya Sharma" -> "PS", "priya" -> "P". Empty when there is no name.
String initialsFor(String? name) {
  final words = (name ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  final first = words.first.characters.first;
  final last = words.length > 1 ? words.last.characters.first : '';
  return (first + last).toUpperCase();
}

/// Stable colour for a name (same name, same colour, on every device).
Color avatarColorFor(String? name) {
  final key = (name ?? '').trim().toLowerCase();
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return AppColors.avatarPalette[hash % AppColors.avatarPalette.length];
}

/// Circle with the user's initials on a colour derived from their name.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.size = 36});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = initialsFor(name);
    return Semantics(
      label: initials.isEmpty ? 'Profile picture placeholder' : 'Profile picture, initials $initials',
      excludeSemantics: true,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: avatarColorFor(name),
        foregroundColor: Colors.white,
        child: initials.isEmpty
            ? Icon(Icons.person, size: size * 0.55)
            : Text(
                initials,
                style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: Colors.white),
              ),
      ),
    );
  }
}

/// App bar button: the user's avatar, opens the profile screen.
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Tooltip(
          message: 'Profile',
          child: InkResponse(
            onTap: () => context.push(AppRoutes.profile),
            radius: kMinTouchTarget / 2,
            child: SizedBox.square(
              dimension: kMinTouchTarget,
              child: Center(child: UserAvatar(name: session.profile?.fullName, size: 36)),
            ),
          ),
        ),
      ),
    );
  }
}
