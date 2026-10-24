import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/skeleton.dart';

class EventImage extends StatelessWidget {
  const EventImage({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.cacheWidth = 288,
  });
  final String? imageUrl;
  final String? heroTag;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    const placeholder = SkeletonBlock(height: double.infinity, radius: 0);
    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl!);
    final usable =
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    final image = ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.small),
        child: usable
            ? Image.network(
                imageUrl!,
                key: ValueKey(imageUrl),
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                frameBuilder: (context, child, frame, synchronouslyLoaded) =>
                    synchronouslyLoaded || frame != null ? child : placeholder,
                errorBuilder: (context, error, stackTrace) => placeholder,
              )
            : placeholder,
      ),
    );
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (!usable || heroTag == null || reducedMotion) return image;
    return Hero(
      tag: heroTag!,
      flightShuttleBuilder: (context, animation, direction, from, to) =>
          (from.widget as Hero).child,
      child: image,
    );
  }
}
