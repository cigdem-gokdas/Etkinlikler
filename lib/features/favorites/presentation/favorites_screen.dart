import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
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
  });
  final FavoritesController controller;
  final VoidCallback onSignIn;
  final ValueChanged<Favorite>? onOpenEvent;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      final favorites = controller.favorites;
      return switch (controller.status) {
        FavoritesStatus.signedOut => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kaydettiğin etkinliklere istediğin zaman ulaşabilirsin.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.page),
                FilledButton(
                  onPressed: onSignIn,
                  child: const Text('Giriş yap'),
                ),
              ],
            ),
          ),
        ),
        FavoritesStatus.loading => const EventListSkeleton(
          label: 'Favoriler yükleniyor',
        ),
        FavoritesStatus.error => StatusMessage(
          title: 'Favoriler yüklenemedi',
          description: controller.errorMessage,
          onRetry: controller.requiresSignIn ? onSignIn : controller.load,
          retryLabel: controller.requiresSignIn
              ? 'Yeniden giriş yap'
              : 'Tekrar dene',
        ),
        FavoritesStatus.success => Column(
          children: [
            if (controller.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            if (controller.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.small,
                ),
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.load,
                child: favorites.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: constraints.maxHeight,
                              child: const StatusMessage(
                                title: 'Henüz kaydettiğin etkinlik yok.',
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        key: const PageStorageKey('favorites-list'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.page,
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: favorites.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final favorite = favorites[index];
                          return EventRow.summary(
                            key: ValueKey(favorite.eventId),
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
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      };
    },
  );
}
