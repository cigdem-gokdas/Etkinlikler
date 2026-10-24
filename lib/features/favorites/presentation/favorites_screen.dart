import 'package:flutter/material.dart';

import '../../../app/widgets/collapsing_header.dart';
import '../../../core/widgets/status_message.dart';
import '../../../core/widgets/skeleton.dart';
import '../../events/presentation/widgets/event_row.dart';
import '../controllers/favorites_controller.dart';
import '../models/favorite.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.controller,
    required this.onSignIn,
    this.onOpenEvent,
    this.headerActions = const [],
  });
  final FavoritesController controller;
  final VoidCallback onSignIn;
  final ValueChanged<Favorite>? onOpenEvent;
  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) => RefreshIndicator(
      onRefresh: controller.load,
      child: CustomScrollView(
        key: const PageStorageKey('favorites-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CollapsingHeader(title: 'Favoriler', actions: headerActions),
          if (controller.status == FavoritesStatus.loading)
            const SliverFillRemaining(
              child: EventListSkeleton(label: 'Favoriler yükleniyor'),
            )
          else if (controller.status == FavoritesStatus.signedOut)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kaydettiğin etkinliklere istediğin zaman ulaşabilirsin.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: onSignIn,
                        child: const Text('Giriş yap'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (controller.status == FavoritesStatus.error)
            SliverFillRemaining(
              hasScrollBody: false,
              child: StatusMessage(
                title: 'Favoriler yüklenemedi',
                description: controller.errorMessage,
                onRetry: controller.requiresSignIn ? onSignIn : controller.load,
                retryLabel: controller.requiresSignIn
                    ? 'Yeniden giriş yap'
                    : 'Tekrar dene',
              ),
            )
          else ...[
            if (controller.isLoading)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (controller.errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      children: [
                        Text(
                          controller.errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: controller.requiresSignIn
                              ? onSignIn
                              : controller.load,
                          child: Text(
                            controller.requiresSignIn
                                ? 'Yeniden giriş yap'
                                : 'Tekrar dene',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (controller.favorites.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: StatusMessage(title: 'Henüz kaydettiğin etkinlik yok.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList.builder(
                  itemCount: controller.favorites.length,
                  itemBuilder: (context, index) {
                    final favorite = controller.favorites[index];
                    return Column(
                      key: ValueKey(favorite.eventId),
                      children: [
                        if (index > 0) const Divider(),
                        EventRow.summary(
                          onTap: onOpenEvent == null
                              ? null
                              : () => onOpenEvent!(favorite),
                          imageHeroTag:
                              'event-image:favorites:${favorite.eventId}',
                          title: favorite.title,
                          startDate: favorite.startsAt,
                          imageUrl: favorite.imageUrl,
                          category: favorite.category,
                          location: favorite.location == 'Online'
                              ? 'Çevrim içi'
                              : favorite.location,
                          isFavorite: true,
                          isFavoriteBusy: controller.isPending(
                            favorite.eventId,
                          ),
                          onFavorite: controller.canMutate
                              ? () => controller.remove(favorite.eventId)
                              : null,
                          showFavorite: true,
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    ),
  );
}
