import 'package:flutter/material.dart';

/// The paragraph and its loading placeholder share the same reading area.
class DetailTextSurface extends StatelessWidget {
  const DetailTextSurface({super.key, required this.child});

  static const textStyle = TextStyle(
    fontSize: 17,
    height: 1.6,
    color: Colors.white,
  );
  static const padding = EdgeInsets.all(20);
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: Padding(padding: padding, child: child),
  );
}
