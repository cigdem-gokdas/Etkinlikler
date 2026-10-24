import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/status_message.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../favorites/controllers/favorites_controller.dart';
import '../../controllers/event_detail_controller.dart';
import '../../data/events_repository.dart';
import '../../models/event.dart';
import '../widgets/event_image.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.repository,
    required this.favorites,
    required this.auth,
    required this.onSignIn,
    this.initialEvent,
    this.initialImageUrl,
    this.imageHeroTag,
  });

  final String eventId;
  final EventsRepository repository;
  final FavoritesController favorites;
  final AuthController auth;
  final Future<void> Function() onSignIn;
  final Event? initialEvent;
  final String? initialImageUrl;
  final String? imageHeroTag;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EventDetailController(
      widget.repository,
      eventId: widget.eventId,
      initialEvent: widget.initialEvent,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final favorites = widget.favorites;
    if (widget.auth.user == null || favorites.requiresSignIn) {
      await widget.onSignIn();
    } else if (favorites.contains(widget.eventId)) {
      await favorites.remove(widget.eventId);
    } else if (_controller.event != null) {
      await favorites.toggle(_controller.event!);
    }
  }

  Widget _photo(String? url) => AspectRatio(
    aspectRatio: 16 / 9,
    child: EventImage(
      imageUrl: url,
      cacheWidth: 800,
      heroTag: url != null && url == widget.initialImageUrl
          ? widget.imageHeroTag
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, widget.favorites, widget.auth]),
    builder: (context, child) {
      final theme = Theme.of(context);
      final event = _controller.event;
      final favorites = widget.favorites;
      final saved = favorites.contains(widget.eventId);
      final pending = favorites.isPending(widget.eventId);
      final canFavorite =
          widget.auth.user == null ||
          favorites.requiresSignIn ||
          (favorites.canMutate && (event != null || saved));
      final error =
          _controller.status == EventDetailStatus.error ||
          _controller.status == EventDetailStatus.notFound;
      return Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          actions: [
            Semantics(
              container: true,
              button: true,
              toggled: saved,
              child: IconButton(
                tooltip: saved ? 'Favorilerden kaldır' : 'Favorilere ekle',
                onPressed: !pending && canFavorite ? _toggleFavorite : null,
                color: theme.colorScheme.primary,
                icon: pending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(saved ? Icons.favorite : Icons.favorite_border),
              ),
            ),
            const SizedBox(width: AppSpacing.small),
          ],
        ),
        body: SafeArea(
          top: false,
          child: event == null && error
              ? StatusMessage(
                  title: _controller.status == EventDetailStatus.notFound
                      ? 'Etkinlik bulunamadı'
                      : 'Etkinlik yüklenemedi',
                  description: _controller.errorMessage,
                  onRetry: _controller.load,
                )
              : SingleChildScrollView(
                  key: const ValueKey('event-detail-scroll'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.small,
                    AppSpacing.page,
                    AppSpacing.large,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (event == null) ...[
                            EventDetailSkeleton(
                              image: widget.initialImageUrl == null
                                  ? null
                                  : _photo(widget.initialImageUrl),
                            ),
                          ] else ...[
                            _photo(event.imageUrl),
                            const SizedBox(height: AppSpacing.page),
                            Semantics(
                              header: true,
                              child: Text(
                                event.title,
                                style: theme.textTheme.headlineLarge,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.page),
                            Text(
                              _dateRange(event),
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (event.isOnline ||
                                event.location?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: AppSpacing.medium),
                              Text(
                                event.isOnline
                                    ? 'Çevrim içi etkinlik'
                                    : event.location!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                            if (event.category.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.medium),
                              Text(
                                event.category,
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                            if (event.organizer.trim().isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.small),
                              Text(
                                'Düzenleyen: ${event.organizer}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if (event.description != null) ...[
                              const SizedBox(height: AppSpacing.large),
                              SelectableText(
                                event.description!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.6,
                                ),
                              ),
                            ] else if (_controller.status ==
                                EventDetailStatus.loading) ...[
                              const SizedBox(height: AppSpacing.large),
                              const EventDetailSkeleton(descriptionOnly: true),
                            ],
                          ],
                          if (error) ...[
                            const SizedBox(height: AppSpacing.page),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _controller.errorMessage!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _controller.load,
                                child: const Text('Tekrar dene'),
                              ),
                            ),
                          ],
                          if (favorites.errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.page),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                favorites.errorMessage!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: favorites.requiresSignIn
                                    ? widget.onSignIn
                                    : favorites.load,
                                child: Text(
                                  favorites.requiresSignIn
                                      ? 'Yeniden giriş yap'
                                      : 'Favorileri yenile',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );

  String _dateRange(Event event) {
    final start = event.startDate.toLocal();
    final end = event.endDate.toLocal();
    if (DateUtils.isSameDay(start, end)) {
      return '${DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(start)}\n${DateFormat.Hm('tr_TR').format(start)} – ${DateFormat.Hm('tr_TR').format(end)}';
    }
    final format = DateFormat('d MMMM yyyy · HH:mm', 'tr_TR');
    return '${format.format(start)}\n${format.format(end)}';
  }
}
