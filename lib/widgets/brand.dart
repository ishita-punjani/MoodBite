import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The MoodBite logo (bundled `assets/logo/logo_512.png`).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      'assets/logo/logo_512.png',
      width: size,
      height: size,
      cacheWidth: pixels,
      semanticLabel: 'MoodBite logo',
    );
  }
}

/// App bar title: the logo followed by the screen title.
class BrandTitle extends StatelessWidget {
  const BrandTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandLogo(size: 32),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
