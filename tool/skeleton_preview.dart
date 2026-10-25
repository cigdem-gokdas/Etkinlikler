// Debug-only visual QA entry point. Never imported by lib/main.dart.
// Public API data is delayed; auth/favorites are in memory, with no Supabase.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/theme/theme_repository.dart';
import 'package:etkinlik_kesif/core/network/api_client.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/auth/data/auth_repository.dart';
import 'package:etkinlik_kesif/features/auth/models/auth_user.dart';
import 'package:etkinlik_kesif/features/events/data/events_repository.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:etkinlik_kesif/features/favorites/data/favorites_repository.dart';
import 'package:etkinlik_kesif/features/favorites/models/favorite.dart';

const _delay = Duration(
  milliseconds: int.fromEnvironment('PREVIEW_DELAY_MS', defaultValue: 18000),
);

Future<void> main() async {
  if (!kDebugMode) throw UnsupportedError('Önizleme yalnızca debug içindir.');
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  final live = HttpEventsRepository(ApiClient(http.Client()));
  runApp(
    EtkinlikKesifApp(
      repository: _DelayedEvents(live),
      authRepository: _PreviewAuth(),
      favoritesRepository: _PreviewFavorites(live),
      themeRepository: _PreviewTheme(),
    ),
  );
}

class _DelayedEvents implements EventsRepository {
  _DelayedEvents(this.live);
  final EventsRepository live;
  @override
  Future<EventsPage> fetchEvents({
    String? query,
    String? category,
    bool? online,
    int? page,
    int? limit,
  }) async {
    await Future<void>.delayed(_delay);
    return live.fetchEvents(
      query: query,
      category: category,
      online: online,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<String>> fetchCategories() async {
    await Future<void>.delayed(_delay);
    return live.fetchCategories();
  }

  @override
  Future<Event> fetchEvent(String eventId) async {
    await Future<void>.delayed(_delay);
    return live.fetchEvent(eventId);
  }
}

class _PreviewAuth implements AuthRepository {
  static const _user = AuthUser(
    id: 'preview-only',
    email: 'preview@example.invalid',
  );
  @override
  AuthUser get currentUser => _user;
  @override
  Stream<AuthUser?> get userChanges => const Stream.empty();
  @override
  Future<AuthUser> signIn(String email, String password) async =>
      throw const ApiException('Önizlemede giriş yapılmaz.');
  @override
  Future<AuthUser> signUp(String email, String password) async =>
      throw const ApiException('Önizlemede hesap oluşturulmaz.');
  @override
  Future<void> signOut() async =>
      throw const ApiException('Önizleme hesabı cihazda saklanmaz.');
}

class _PreviewFavorites implements FavoritesRepository {
  _PreviewFavorites(this.live);
  final EventsRepository live;
  @override
  Future<List<Favorite>> fetchFavorites(String userId) async {
    await Future<void>.delayed(_delay);
    // A real public event with a genuinely null API imageUrl.
    return [Favorite.fromEvent(userId, await live.fetchEvent('evt-007'))];
  }

  @override
  Future<Favorite> add(Favorite favorite) async =>
      throw const ApiException('Önizlemede kayıt değiştirilmez.');
  @override
  Future<void> remove(String userId, String eventId) async =>
      throw const ApiException('Önizlemede kayıt değiştirilmez.');
}

class _PreviewTheme implements ThemeRepository {
  ThemeMode _mode = const bool.fromEnvironment('PREVIEW_DARK')
      ? ThemeMode.dark
      : ThemeMode.light;
  @override
  Future<ThemeMode> load() async => _mode;
  @override
  Future<void> save(ThemeMode mode) async {
    _mode = mode;
  }
}
