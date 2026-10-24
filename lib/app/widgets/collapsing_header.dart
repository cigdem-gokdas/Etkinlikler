import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class CollapsingHeader extends StatelessWidget {
  const CollapsingHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: true,
    delegate: _TitleHeader(
      title,
      actions,
      Theme.of(context),
      MediaQuery.textScalerOf(context).scale(34).clamp(34, 54),
    ),
  );
}

class _TitleHeader extends SliverPersistentHeaderDelegate {
  _TitleHeader(this.title, this.actions, this.theme, this.largeSize);
  final String title;
  final List<Widget> actions;
  final ThemeData theme;
  final double largeSize;
  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 76 + largeSize;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned(
            left: 24,
            right: 112 * t,
            bottom: lerpDouble(10, 16, t),
            child: Semantics(
              header: true,
              child: Text(
                title,
                key: ValueKey('collapsing-title:$title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: lerpDouble(largeSize, 20, t),
                  letterSpacing: -.6,
                ),
              ),
            ),
          ),
          Positioned(top: 0, right: 12, child: Row(children: actions)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TitleHeader oldDelegate) => true;
}

/// A zero-minimum sliver clips the controls as its geometry shrinks. Keeping
/// the same child mounted preserves TextField focus and selection throughout.
class SearchFilterHeader extends SliverPersistentHeaderDelegate {
  SearchFilterHeader({required this.child, required this.height});
  final Widget child;
  final double height;
  @override
  double get minExtent => 0;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ClipRect(
    child: OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: height,
      maxHeight: height,
      child: Transform.translate(
        offset: Offset(0, -shrinkOffset * .35),
        child: child,
      ),
    ),
  );
  @override
  bool shouldRebuild(SearchFilterHeader oldDelegate) => true;
}
