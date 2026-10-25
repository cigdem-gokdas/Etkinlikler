import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/core/config/supabase_config.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/auth/presentation/screens/auth_screen.dart';
import 'package:etkinlik_kesif/features/favorites/data/favorites_repository.dart';
import 'package:etkinlik_kesif/features/favorites/models/favorite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/account_fakes.dart';
import 'helpers/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  test('public demo defaults are valid public client settings', () {
    const config = SupabaseConfig(
      url: SupabaseConfig.publicDemoUrl,
      publishableKey: SupabaseConfig.publicDemoPublishableKey,
    );
    // Boolean expectations avoid displaying real values even on failure.
    expect(config.problem == null, isTrue);
    expect(config.publishableKey.startsWith('sb_publishable_'), isTrue);
  });

  test(
    'compiled defines override each public default including explicit empty',
    () {
      const compiled = SupabaseConfig.fromEnvironment();
      const expectedUrl = String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: SupabaseConfig.publicDemoUrl,
      );
      const expectedKey = String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: SupabaseConfig.publicDemoPublishableKey,
      );
      expect(compiled.url == expectedUrl, isTrue);
      expect(compiled.publishableKey == expectedKey, isTrue);
      if (expectedUrl.isEmpty || expectedKey.isEmpty) {
        expect(compiled.problem != null, isTrue);
      }
    },
  );

  test(
    'missing explicit config remains an error rather than demo fallback',
    () {
      const config = SupabaseConfig(url: '', publishableKey: '');
      expect(config.problem, contains('SUPABASE_URL'));
      expect(config.problem, contains('SUPABASE_PUBLISHABLE_KEY'));
    },
  );

  test(
    'invalid URLs and server credentials are rejected without echoing them',
    () {
      const configs = [
        SupabaseConfig(
          url: 'http://fixture.invalid',
          publishableKey: 'sb_publishable_fixture',
        ),
        // Deliberately invalid synthetic fixture, never a real server key.
        SupabaseConfig(
          url: 'https://fixture.invalid',
          publishableKey: 'sb_secret_fixture',
        ),
        SupabaseConfig(
          url: 'https://fixture.invalid',
          publishableKey: 'service_role',
        ),
        SupabaseConfig(
          url: 'https://user:password@fixture.invalid',
          publishableKey: 'sb_publishable_fixture',
        ),
      ];
      for (final config in configs) {
        expect(config.problem != null, isTrue);
        expect(config.problem!.contains(config.publishableKey), isFalse);
        expect(config.problem!.contains(config.url), isFalse);
      }
    },
  );

  SupabaseClient anonymousClient(void Function() request) {
    const config = SupabaseConfig(
      url: SupabaseConfig.publicDemoUrl,
      publishableKey: SupabaseConfig.publicDemoPublishableKey,
    );
    final client = SupabaseClient(
      config.url,
      config.publishableKey,
      httpClient: MockClient((_) async {
        request();
        return http.Response('{}', 401);
      }),
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryPkceStorage(),
      ),
    );
    addTearDown(client.dispose);
    return client;
  }

  test(
    'public key without session cannot read insert or delete favorites',
    () async {
      var requests = 0;
      final client = anonymousClient(() => requests++);
      final favorites = SupabaseFavoritesRepository(client);
      expect(client.auth.currentSession, isNull);
      final unauthorized = throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'status code', 401),
      );
      await expectLater(favorites.fetchFavorites(userA.id), unauthorized);
      await expectLater(
        favorites.add(Favorite.fromEvent(userA.id, sampleEvent())),
        unauthorized,
      );
      await expectLater(favorites.remove(userA.id, 'evt-012'), unauthorized);
      expect(requests, 0);
    },
  );

  for (final openSignIn in [false, true]) {
    testWidgets(
      openSignIn
          ? 'no local config: signed-out favorite opens auth UI without submitting credentials'
          : 'no local config: anonymous discovery needs no favorite request',
      (tester) async {
        final auth = FakeAuthRepository();
        final favorites = FakeFavoritesRepository();
        addTearDown(auth.dispose);
        final events = StubEventsRepository(() async => samplePage());
        await tester.pumpWidget(
          EtkinlikKesifApp(
            repository: events,
            authRepository: auth,
            favoritesRepository: favorites,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
        expect(auth.currentUser, isNull);
        expect(favorites.fetches, 0);
        expect(favorites.adds, 0);
        expect((auth.signIns + auth.signUps), 0);
        if (openSignIn) {
          await tester.tap(find.byTooltip('Favorilere ekle').first);
          await tester.pumpAndSettle();
          expect(find.byType(AuthScreen), findsOneWidget);
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('email-input')))
                .enabled,
            isTrue,
          );
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed !=
                null,
            isTrue,
          );
          expect(
            find.textContaining('bağlantısı şu anda kullanılamıyor'),
            findsNothing,
          );
          expect(favorites.fetches, 0);
          expect(favorites.adds, 0);
          expect(
            (auth.signIns + auth.signUps),
            0,
          ); // No mail, account creation or database call.
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
