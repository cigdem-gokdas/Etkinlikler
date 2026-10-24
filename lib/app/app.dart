import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import '../core/config/otp_config.dart';
import '../core/network/api_client.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/screens/account_screen.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/events/controllers/events_controller.dart';
import '../features/events/data/events_repository.dart';
import '../features/events/presentation/screens/explore_screen.dart';
import '../features/events/presentation/screens/event_detail_screen.dart';
import '../features/events/models/event.dart';
import '../features/favorites/models/favorite.dart';
import '../features/events/presentation/widgets/event_row.dart';
import '../features/favorites/controllers/favorites_controller.dart';
import '../features/favorites/data/favorites_repository.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/onboarding/presentation/onboarding_gate.dart';
import 'theme/app_theme.dart';
import 'theme/theme_repository.dart';
import 'theme/theme_controller.dart';

class EtkinlikKesifApp extends StatefulWidget {
  const EtkinlikKesifApp({
    super.key,
    this.repository,
    this.authRepository,
    this.favoritesRepository,
    this.configurationMessage,
    this.otpConfig = const OtpConfig(),
    this.onboardingRepository,
    this.themeRepository,
  });

  final EventsRepository? repository;
  final AuthRepository? authRepository;
  final FavoritesRepository? favoritesRepository;
  final String? configurationMessage;
  final OtpConfig otpConfig;
  final OnboardingRepository? onboardingRepository;
  final ThemeRepository? themeRepository;

  @override
  State<EtkinlikKesifApp> createState() => _EtkinlikKesifAppState();
}

class _EtkinlikKesifAppState extends State<EtkinlikKesifApp> {
  http.Client? _ownedClient;
  late final EventsController _events;
  late final EventsRepository _eventsRepository;
  late final AuthController _auth;
  late final FavoritesController _favorites;
  late final ThemeController _theme;

  @override
  void initState() {
    super.initState();
    _theme = ThemeController(widget.themeRepository);
    _theme.addListener(_themeChanged);
    unawaited(_theme.load());
    final repository = widget.repository;
    if (repository != null) {
      _eventsRepository = repository;
    } else {
      final client = http.Client();
      _ownedClient = client;
      _eventsRepository = HttpEventsRepository(ApiClient(client));
    }
    _events = EventsController(_eventsRepository);
    _auth = AuthController(
      repository: widget.authRepository,
      configurationMessage: widget.configurationMessage,
      otpConfig: widget.otpConfig,
    );
    _favorites = FavoritesController(widget.favoritesRepository);
    _auth.addListener(_syncFavorites);
    _syncFavorites();
    unawaited(_events.load());
    unawaited(_events.loadCategories());
  }

  void _themeChanged() {
    if (mounted) setState(() {});
  }

  void _syncFavorites() => _favorites.setUser(_auth.user?.id);

  @override
  void dispose() {
    _theme.removeListener(_themeChanged);
    _theme.dispose();
    _auth.removeListener(_syncFavorites);
    _auth.dispose();
    _favorites.dispose();
    _events.dispose();
    _ownedClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Etkinlik Keşif',
    debugShowCheckedModeBanner: false,
    locale: const Locale('tr', 'TR'),
    supportedLocales: const [Locale('tr', 'TR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: _theme.mode,
    home: _launch(),
  );

  Widget _launch() {
    final home = _Home(
      events: _events,
      eventsRepository: _eventsRepository,
      auth: _auth,
      favorites: _favorites,
      onToggleTheme: (brightness) => _theme.setMode(
        brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
      ),
    );
    final onboarding = widget.onboardingRepository;
    return onboarding == null
        ? home
        : OnboardingGate(repository: onboarding, child: home);
  }
}

class _Home extends StatefulWidget {
  const _Home({
    required this.events,
    required this.eventsRepository,
    required this.auth,
    required this.favorites,
    required this.onToggleTheme,
  });
  final EventsController events;
  final EventsRepository eventsRepository;
  final AuthController auth;
  final FavoritesController favorites;
  final Future<bool> Function(Brightness) onToggleTheme;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _selectedIndex = 0;
  bool _authRouteOpen = false;

  void _openDetail(
    String eventId, {
    Event? initialEvent,
    String? imageUrl,
    required String source,
  }) {
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        transitionDuration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        reverseTransitionDuration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            EventDetailScreen(
              eventId: eventId,
              repository: widget.eventsRepository,
              initialEvent: initialEvent,
              initialImageUrl: imageUrl,
              imageHeroTag: 'event-image:$source:$eventId',
              favorites: widget.favorites,
              auth: widget.auth,
              onSignIn: () =>
                  _openSignIn(reauthenticate: widget.favorites.requiresSignIn),
            ),
      ),
    );
  }

  void _openFavoriteDetail(Favorite favorite) => _openDetail(
    favorite.eventId,
    imageUrl: favorite.imageUrl,
    source: 'favorites',
  );

  Future<void> _openSignIn({bool reauthenticate = false}) async {
    if (_authRouteOpen) return;
    _authRouteOpen = true;
    try {
      if (reauthenticate && widget.auth.user != null) {
        final success = await widget.auth.signOut();
        if (!success || !mounted) return;
      }
      if (!mounted) return;
      widget.auth.beginSignIn();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => AuthScreen(controller: widget.auth)),
      );
    } finally {
      _authRouteOpen = false;
    }
  }

  void _openAccount() {
    if (widget.auth.user == null) {
      unawaited(_openSignIn());
    } else {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AccountScreen(controller: widget.auth),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.auth, widget.favorites]),
    builder: (context, child) {
      final theme = Theme.of(context);
      final dark = theme.brightness == Brightness.dark;
      final favorites = widget.favorites;
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.page,
                  AppSpacing.medium,
                  AppSpacing.medium,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          _selectedIndex == 0 ? 'Keşfet' : 'Favoriler',
                          style: theme.textTheme.headlineLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: widget.auth.user == null
                          ? 'Giriş yap'
                          : 'Hesabım',
                      onPressed: _openAccount,
                      color: theme.colorScheme.onSurfaceVariant,
                      icon: const Icon(Icons.person_outline),
                    ),
                    IconButton(
                      tooltip: dark ? 'Açık temaya geç' : 'Koyu temaya geç',
                      onPressed: () async {
                        final saved = await widget.onToggleTheme(
                          theme.brightness,
                        );
                        if (!saved && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tema tercihi kaydedilemedi.'),
                            ),
                          );
                        }
                      },
                      color: theme.colorScheme.onSurfaceVariant,
                      icon: Icon(
                        dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedIndex == 0 && favorites.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            favorites.errorMessage!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: favorites.requiresSignIn
                              ? () => _openSignIn(reauthenticate: true)
                              : favorites.load,
                          child: Text(
                            favorites.requiresSignIn
                                ? 'Giriş yap'
                                : 'Tekrar dene',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    ExploreScreen(
                      controller: widget.events,
                      eventBuilder: (context, event) => EventRow(
                        key: ValueKey(event.id),
                        event: event,
                        onTap: () => _openDetail(
                          event.id,
                          initialEvent: event,
                          imageUrl: event.imageUrl,
                          source: 'explore',
                        ),
                        imageHeroTag: 'event-image:explore:${event.id}',
                        showFavorite: true,
                        isFavorite: favorites.contains(event.id),
                        isFavoriteBusy: favorites.isPending(event.id),
                        onFavorite: widget.auth.user == null
                            ? () => _openSignIn()
                            : favorites.requiresSignIn
                            ? () => _openSignIn(reauthenticate: true)
                            : favorites.canMutate
                            ? () => favorites.toggle(event)
                            : null,
                      ),
                    ),
                    FavoritesScreen(
                      controller: favorites,
                      onOpenEvent: _openFavoriteDetail,
                      onSignIn: () =>
                          _openSignIn(reauthenticate: favorites.requiresSignIn),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Keşfet',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Favoriler',
              ),
            ],
          ),
        ),
      );
    },
  );
}
