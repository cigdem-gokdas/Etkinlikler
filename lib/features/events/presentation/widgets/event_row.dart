import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../models/event.dart';
import 'event_image.dart';

class EventRow extends StatelessWidget {
  EventRow({
    super.key,
    required Event event,
    this.onFavorite,
    this.onTap,
    this.imageHeroTag,
    this.isFavorite = false,
    this.isFavoriteBusy = false,
    this.showFavorite = false,
  }) : title = event.title,
       imageUrl = event.imageUrl,
       startDate = event.startDate,
       location = event.isOnline ? 'Çevrim içi' : event.location,
       category = event.category;

  const EventRow.summary({
    super.key,
    required this.title,
    this.imageUrl,
    this.startDate,
    this.location,
    this.category,
    this.onFavorite,
    this.onTap,
    this.imageHeroTag,
    this.isFavorite = false,
    this.isFavoriteBusy = false,
    this.showFavorite = false,
  });

  final String title;
  final String? imageUrl;
  final DateTime? startDate;
  final String? location;
  final String? category;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;
  final String? imageHeroTag;
  final bool isFavorite;
  final bool isFavoriteBusy;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = startDate?.toLocal();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.page),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 96,
              child: EventImage(imageUrl: imageUrl, heroTag: imageHeroTag),
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date != null) ...[
                    Text(
                      DateFormat('d MMM, EEE · HH:mm', 'tr_TR').format(date),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.small),
                  ],
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    location?.trim().isNotEmpty == true
                        ? location!
                        : 'Konum belirtilmedi',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (category?.isNotEmpty == true || showFavorite)
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.small,
                            ),
                            child: Text(
                              category ?? '',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ),
                        if (showFavorite)
                          Semantics(
                            container: true,
                            button: true,
                            toggled: isFavorite,
                            child: IconButton(
                              tooltip: isFavorite
                                  ? 'Favorilerden kaldır'
                                  : 'Favorilere ekle',
                              onPressed: isFavoriteBusy ? null : onFavorite,
                              color: theme.colorScheme.primary,
                              iconSize: 20,
                              icon: isFavoriteBusy
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
