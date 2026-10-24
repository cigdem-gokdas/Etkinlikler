import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/auth/controllers/auth_controller.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:etkinlik_kesif/features/events/presentation/screens/event_detail_screen.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/event_image.dart';
import 'package:etkinlik_kesif/features/favorites/controllers/favorites_controller.dart';
import 'package:etkinlik_kesif/features/favorites/models/favorite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/account_fakes.dart';
import 'helpers/detail_fixture.dart';
import 'helpers/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('liste → detay → geri; liste tekrar yüklenmez', (tester) async {
    final repository = StubEventsRepository(() async => detailPage())
      ..detailHandler = (_) async => detailEvent();
    await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text(detailEvent().title));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(find.text(detailEvent().description!), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsNothing);
    expect(repository.calls, 1);
    expect(repository.detailCalls, 1);
  });

  testWidgets('detaydan geri dönüş scroll konumunu korur', (tester) async {
    final page = EventsPage.fromJson(readPageJson());
    final repository = StubEventsRepository(() async => page);
    await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
    await tester.pumpAndSettle();
    final list = find.byKey(const PageStorageKey('events-list'));
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final target = page.items.singleWhere((e) => e.id == 'evt-011');
    await tester.scrollUntilVisible(
      find.text(target.title),
      250,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));
    await tester.tap(find.text(target.title));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(before, 0.1),
    );
    expect(repository.calls, 1);
  });

  testWidgets('satırdaki kalp detay açmadan auth akışını açar', (tester) async {
    final repository = StubEventsRepository(() async => detailPage());
    await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorilere ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Hesabına giriş yap'), findsOneWidget);
    expect(repository.detailCalls, 0);
    expect(find.byType(EventDetailScreen), findsNothing);
  });

  testWidgets(
    'Favoriler detayı aynı controller ile senkronize; sekme korunur',
    (tester) async {
      final auth = FakeAuthRepository(user: userA);
      addTearDown(auth.dispose);
      final favorites = FakeFavoritesRepository();
      favorites.byUser[userA.id] = [
        Favorite.fromEvent(userA.id, detailEvent()),
      ];
      final repository = StubEventsRepository(() async => detailPage())
        ..detailHandler = (_) async => detailEvent();
      await tester.pumpWidget(
        EtkinlikKesifApp(
          repository: repository,
          authRepository: auth,
          favoritesRepository: favorites,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favoriler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(detailEvent().title));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Favorilerden kaldır'), findsOneWidget);
      await tester.tap(find.byTooltip('Favorilerden kaldır'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
      expect(repository.detailCalls, 1);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.text('Henüz kaydettiğin etkinlik yok.'), findsOneWidget);
      await tester.tap(find.text('Keşfet'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detaydan auth açılıp kapanınca aynı etkinlikte kalınır', (
    tester,
  ) async {
    final repository = StubEventsRepository(() async => detailPage())
      ..detailHandler = (_) async => detailEvent();
    await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text(detailEvent().title));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorilere ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Hesabına giriş yap'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(find.text(detailEvent().description!), findsOneWidget);
    expect(repository.detailCalls, 1);
  });

  testWidgets('404 ekranındaki Tekrar dene detay endpointini yeniden çağırır', (
    tester,
  ) async {
    final repository = StubEventsRepository(() async => detailPage())
      ..detailHandler = (_) async =>
          throw const ApiException('Etkinlik bulunamadı.', statusCode: 404);
    await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text(detailEvent().title));
    await tester.pumpAndSettle();
    expect(find.text('Etkinlik bulunamadı'), findsOneWidget);
    repository.detailHandler = (_) async => detailEvent();
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text(detailEvent().description!), findsOneWidget);
    expect(repository.detailCalls, 2);
  });

  for (final image in <String?>[
    null,
    'https://picsum.photos/seed/broken-image-test/800/450.invalid',
  ]) {
    testWidgets(
      '${image == null ? 'null' : 'bozuk'} görsel, uzun başlık/açıklama küçük ekranda taşmaz',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final event = detailEvent({
          'imageUrl': image,
          'location': null,
          'title': List.filled(4, detailEvent().title).join(' '),
          'description':
              '${List.filled(12, detailEvent().description!).join('\n\n')}\n\nAçıklamanın sonu.',
        });
        final repository = StubEventsRepository(() async => detailPage())
          ..detailHandler = (_) async => event;
        final auth = AuthController();
        final favorites = FavoritesController(null);
        addTearDown(auth.dispose);
        addTearDown(favorites.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: EventDetailScreen(
              eventId: event.id,
              repository: repository,
              favorites: favorites,
              auth: auth,
              onSignIn: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Konum belirtilmedi'), findsNothing);
        expect(find.byType(EventImage), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('event-detail-scroll')),
          const Offset(0, -1000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Hero etiketleri Keşfet/Favoriler kaynakları arasında çakışmaz', (
    tester,
  ) async {
    final auth = FakeAuthRepository(user: userA);
    addTearDown(auth.dispose);
    final favorites = FakeFavoritesRepository();
    favorites.byUser[userA.id] = [Favorite.fromEvent(userA.id, detailEvent())];
    final repository = StubEventsRepository(() async => detailPage())
      ..detailHandler = (_) async => detailEvent();
    await tester.pumpWidget(
      EtkinlikKesifApp(
        repository: repository,
        authRepository: auth,
        favoritesRepository: favorites,
      ),
    );
    await tester.pumpAndSettle();
    final tags = tester
        .widgetList<Hero>(find.byType(Hero, skipOffstage: false))
        .map((hero) => hero.tag)
        .toList();
    expect(tags.length, 2);
    expect(tags.toSet().length, 2);
    await tester.tap(find.text(detailEvent().title));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion tercihinde görsel Hero oluşturmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox.square(
            dimension: 96,
            child: EventImage(
              imageUrl: detailEvent().imageUrl,
              heroTag: 'test-image',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Hero), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
