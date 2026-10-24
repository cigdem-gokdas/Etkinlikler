import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Static theme-based placeholders; no animation, gestures or content semantics.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 4,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    ),
  );
}

class EventRowSkeleton extends StatelessWidget {
  const EventRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.page),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBlock(
              width: 96,
              height: 96,
              radius: AppSpacing.small,
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(
                        width: (width * .5).clamp(0, 112),
                        height: 12,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      SkeletonBlock(width: width.clamp(0, 360)),
                      const SizedBox(height: AppSpacing.small),
                      SkeletonBlock(width: (width * .8).clamp(0, 280)),
                      const SizedBox(height: AppSpacing.small),
                      SkeletonBlock(
                        width: (width * .9).clamp(0, 320),
                        height: 12,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      SkeletonBlock(
                        width: (width * .35).clamp(0, 72),
                        height: 12,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key, this.label = 'Etkinlikler yükleniyor'});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: label,
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: ListView.separated(
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          itemCount: 3,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) => const EventRowSkeleton(),
        ),
      ),
    ),
  );
}

class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Kategoriler yükleniyor',
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: Row(
          children: [
            SkeletonBlock(width: 88, height: 40),
            SizedBox(width: AppSpacing.small),
            SkeletonBlock(width: 72, height: 40),
            SizedBox(width: AppSpacing.small),
            SkeletonBlock(width: 96, height: 40),
          ],
        ),
      ),
    ),
  );
}

/// Content only: the real route retains its accessible back/favorite controls.
class EventDetailSkeleton extends StatelessWidget {
  const EventDetailSkeleton({
    super.key,
    this.image,
    this.descriptionOnly = false,
  });
  final Widget? image;
  final bool descriptionOnly;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Etkinlik detayı yükleniyor',
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!descriptionOnly) ...[
              image ??
                  const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: SkeletonBlock(
                      height: double.infinity,
                      radius: AppSpacing.small,
                    ),
                  ),
              const SizedBox(height: AppSpacing.page),
              const SkeletonBlock(height: 32),
              const SizedBox(height: AppSpacing.small),
              const FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: .75,
                child: SkeletonBlock(height: 32),
              ),
              const SizedBox(height: AppSpacing.page),
              const SkeletonBlock(height: 12),
              const SizedBox(height: AppSpacing.small),
              const FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: .4,
                child: SkeletonBlock(height: 12),
              ),
              const SizedBox(height: AppSpacing.medium),
              const SkeletonBlock(height: 12),
              const SizedBox(height: AppSpacing.large),
            ],
            const SkeletonBlock(),
            const SizedBox(height: AppSpacing.small),
            const SkeletonBlock(),
            const SizedBox(height: AppSpacing.small),
            const FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: .7,
              child: SkeletonBlock(),
            ),
          ],
        ),
      ),
    ),
  );
}
