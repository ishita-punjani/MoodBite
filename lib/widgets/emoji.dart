import 'package:flutter/material.dart';

/// An emoji with a screen-reader label. Pass `label: null` for a purely
/// decorative emoji that sits next to text saying the same thing.
class Emoji extends StatelessWidget {
  const Emoji(this.emoji, {super.key, this.label, this.size = 28});

  final String emoji;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Text(emoji, style: TextStyle(fontSize: size));
    if (label == null) return ExcludeSemantics(child: text);
    return Semantics(label: label, excludeSemantics: true, child: text);
  }
}
