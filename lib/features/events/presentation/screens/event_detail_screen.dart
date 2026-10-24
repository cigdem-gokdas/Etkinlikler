import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/status_message.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../favorites/controllers/favorites_controller.dart';
import '../../controllers/event_detail_controller.dart';
import '../../data/events_repository.dart';
import '../../models/event.dart';
import '../widgets/adaptive_event_composition.dart';

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
    this.imageProvider,
  });

  final String eventId;
  final EventsRepository repository;
  final FavoritesController favorites;
  final AuthController auth;
  final Future<void> Function() onSignIn;
  final Event? initialEvent;
  final String? initialImageUrl;
  final ImageProvider? imageProvider;

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
      final detailTheme = theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          onSurface: Colors.white,
          onSurfaceVariant: Colors.white70,
          primary: const Color(0xFFC4DFC8),
          surfaceContainerHighest: const Color(0xFF3D4D45),
        ),
        textTheme: theme.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      );
      return Theme(
        data: detailTheme,
        child: Scaffold(
          backgroundColor: const Color(0xFF14251F),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle.light,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const BackButton(),
              ),
            ),
            actions: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Semantics(
                  container: true,
                  button: true,
                  toggled: saved,
                  child: IconButton(
                    tooltip: saved ? 'Favorilerden kaldır' : 'Favorilere ekle',
                    onPressed: !pending && canFavorite ? _toggleFavorite : null,
                    color: Colors.white,
                    icon: pending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(saved ? Icons.favorite : Icons.favorite_border),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: event == null && error
              ? SafeArea(
                  child: StatusMessage(
                    title: _controller.status == EventDetailStatus.notFound
                        ? 'Etkinlik bulunamadı'
                        : 'Etkinlik yüklenemedi',
                    description: _controller.errorMessage,
                    onRetry: _controller.load,
                  ),
                )
              : AdaptiveEventComposition(
                  safePadding: MediaQuery.viewPaddingOf(context),
                  imageProvider: widget.imageProvider,
                  imageUrl:
                      event?.imageUrl ??
                      (event == null ? widget.initialImageUrl : null),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (event == null)
                        const EventDetailSkeleton(image: SizedBox.shrink())
                      else ...[
                        if (event.category.isNotEmpty)
                          Text(
                            event.category,
                            style: const TextStyle(
                              color: Color(0xFFC4DFC8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Semantics(
                          header: true,
                          child: Text(
                            event.title,
                            style: TextStyle(
                              fontSize: MediaQuery.sizeOf(context).width < 360
                                  ? 28
                                  : event.title.length > 70
                                  ? 32
                                  : 36,
                              height: 1.1,
                              letterSpacing: -1,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _information(
                          Icons.calendar_today_outlined,
                          _dateRange(event),
                        ),
                        if (event.isOnline ||
                            event.location?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 16),
                          _information(
                            event.isOnline
                                ? Icons.language_outlined
                                : Icons.location_on_outlined,
                            event.isOnline
                                ? 'Çevrim içi etkinlik'
                                : event.location!,
                          ),
                        ],
                        if (event.organizer.trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _information(
                            Icons.people_outline,
                            'Düzenleyen: ${event.organizer}',
                          ),
                        ],
                        if (event.description != null) ...[
                          const SizedBox(height: 28),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .22),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .12),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: SelectableText(
                                event.description!,
                                style: const TextStyle(
                                  fontSize: 17,
                                  height: 1.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ] else if (_controller.status ==
                            EventDetailStatus.loading) ...[
                          const SizedBox(height: 28),
                          const EventDetailSkeleton(descriptionOnly: true),
                        ],
                      ],
                      if (error) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Güncel bilgi alınamadı. Son bilinen bilgiler gösteriliyor.',
                        ),
                        Semantics(
                          liveRegion: true,
                          child: Text(_controller.errorMessage!),
                        ),
                        TextButton(
                          onPressed: _controller.load,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                      if (favorites.errorMessage != null) ...[
                        const SizedBox(height: 24),
                        Semantics(
                          liveRegion: true,
                          child: Text(favorites.errorMessage!),
                        ),
                        TextButton(
                          onPressed: favorites.requiresSignIn
                              ? widget.onSignIn
                              : favorites.load,
                          child: Text(
                            favorites.requiresSignIn
                                ? 'Yeniden giriş yap'
                                : 'Favorileri yenile',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      );
    },
  );

  Widget _information(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: const Color(0xFFC4DFC8)),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            height: 1.45,
            color: Colors.white,
          ),
        ),
      ),
    ],
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
