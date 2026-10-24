import 'dart:async';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/core/widgets/skeleton.dart';
import 'package:etkinlik_kesif/features/auth/controllers/auth_controller.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:etkinlik_kesif/features/events/presentation/screens/event_detail_screen.dart';
import 'package:etkinlik_kesif/features/events/presentation/screens/explore_screen.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/event_image.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/event_row.dart';
import 'package:etkinlik_kesif/features/favorites/controllers/favorites_controller.dart';
import 'package:etkinlik_kesif/features/favorites/models/favorite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/account_fakes.dart';
import 'helpers/detail_fixture.dart';
import 'helpers/discovery_fake.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('ilk yüklemede üç etkileşimsiz satır; bitince gerçek EventRow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<EventsPage>();
    var detailCalls = 0;
    final repo = DiscoveryFake((_) => pending.future)
      ..detailHandler = (_) async {
        detailCalls++;
        return testEvent('a');
      };
    await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
    await tester.pump();
    expect(find.byType(EventListSkeleton), findsOneWidget);
    expect(find.byType(EventRowSkeleton), findsNWidgets(3));
    expect(find.byType(EventRow), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byType(EventRowSkeleton).first, warnIfMissed: false);
    await tester.pump();
    expect(detailCalls, 0);
    await tester.tap(find.text('Favoriler'));
    await tester.pumpAndSettle();
    expect(find.byType(EventListSkeleton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Giriş yap'), findsOneWidget);
    await tester.tap(find.text('Keşfet'));
    await tester.pumpAndSettle();
    pending.complete(testPage(['a'], total: 1, hasMore: false));
    await tester.pumpAndSettle();
    expect(find.byType(EventListSkeleton), findsNothing);
    expect(find.byType(EventRow), findsOneWidget);
  });

  for (final error in [false, true]) {
    testWidgets(
      '${error ? 'hata' : 'empty'} skeleton değildir; hata retry çalışır',
      (tester) async {
        final repo = DiscoveryFake((_) async {
          if (error) throw const ApiException('Bağlantı kurulamadı.');
          return testPage([], total: 0, hasMore: false);
        });
        await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
        await tester.pumpAndSettle();
        expect(find.byType(EventListSkeleton), findsNothing);
        expect(find.byType(EventRowSkeleton), findsNothing);
        expect(
          find.text(error ? 'Etkinlikler yüklenemedi' : 'Henüz etkinlik yok.'),
          findsOneWidget,
        );
        if (error) {
          repo.handler = (_) async => testPage(['a'], total: 1, hasMore: false);
          await tester.tap(find.text('Tekrar dene'));
          await tester.pumpAndSettle();
          expect(find.text('Etkinlik a'), findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'kategori beklerken placeholder ve kullanılabilir Tümü; hata bağımsızdır',
    (tester) async {
      final categories = Completer<List<String>>();
      final repo = DiscoveryFake(
        (_) async => testPage(['a'], total: 1, hasMore: false),
      )..categoriesHandler = () => categories.future;
      await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
      await tester.pumpAndSettle();
      expect(find.byType(CategorySkeleton), findsOneWidget);
      expect(find.text('Etkinlik a'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('category:all')))
            .onPressed,
        isNotNull,
      );
      categories.completeError(const ApiException('Offline'));
      await tester.pumpAndSettle();
      expect(find.byType(CategorySkeleton), findsNothing);
      expect(find.text('Kategoriler yüklenemedi.'), findsOneWidget);
      expect(find.text('Etkinlik a'), findsOneWidget);
      repo.categoriesHandler = () async => ['Workshop'];
      await tester.tap(find.text('Kategorileri yenile'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category:Workshop')), findsOneWidget);
    },
  );

  testWidgets(
    'yazarken eski sonuç yok; debounce sonrası tek skeleton, stale yanıt yok',
    (tester) async {
      final firstSearch = Completer<EventsPage>();
      final latest = Completer<EventsPage>();
      final repo = DiscoveryFake(
        (r) => r.query == ''
            ? Future.value(testPage(['old'], total: 1, hasMore: false))
            : r.query == 'ilk'
            ? firstSearch.future
            : latest.future,
      );
      await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('event-search'));
      await tester.enterText(search, 'ilk');
      await tester.pump(const Duration(milliseconds: 349));
      expect(find.text('Etkinlik old'), findsNothing);
      expect(find.byType(EventListSkeleton), findsNothing);
      expect(repo.requests.length, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(EventListSkeleton), findsOneWidget);
      await tester.enterText(search, 'son');
      firstSearch.complete(testPage(['stale'], total: 1, hasMore: false));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Etkinlik stale'), findsNothing);
      expect(find.byType(EventListSkeleton), findsOneWidget);
      latest.complete(testPage(['new'], total: 1, hasMore: false));
      await tester.pumpAndSettle();
      expect(find.text('Etkinlik new'), findsOneWidget);
      expect(find.byType(EventListSkeleton), findsNothing);
    },
  );

  testWidgets(
    'anlık arama yanıtı frame içinde tamamlanır; skeleton flaşı ve ek timer yok',
    (tester) async {
      final repo = DiscoveryFake(
        (r) async =>
            testPage([r.query == '' ? 'old' : 'new'], total: 1, hasMore: false),
      );
      await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('event-search')),
        'yeni',
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(EventListSkeleton), findsNothing);
      expect(find.text('Etkinlik new'), findsOneWidget);
    },
  );

  testWidgets(
    'pagination beklerken liste/konum korunur; hata retry ve hasMore false footer',
    (tester) async {
      final more = Completer<EventsPage>();
      final repo = DiscoveryFake(
        (r) => r.page == 1
            ? Future.value(testPage(List.generate(10, (i) => 'a$i'), total: 11))
            : more.future,
      );
      await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<ExploreScreen>(find.byType(ExploreScreen))
          .controller;
      final list = find.byKey(const PageStorageKey('events-list'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: list,
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            ),
          )
          .position;
      final before = position.maxScrollExtent * .70;
      position.jumpTo(before);
      await tester.pump();
      expect(controller.isLoadingMore, isTrue);
      expect(controller.events.length, 10);
      expect(position.pixels, closeTo(before, .1));
      expect(find.byType(EventListSkeleton), findsNothing);
      expect(find.byType(EventRow), findsWidgets);
      more.completeError(const ApiException('Offline'));
      await tester.pumpAndSettle();
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Kalan etkinlikler yüklenemedi.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repo.handler = (r) async =>
          testPage(['b'], page: r.page, total: 11, hasMore: false);
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(controller.events.length, 11);
      expect(controller.hasMore, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(EventRowSkeleton), findsNothing);
    },
  );

  for (final cached in [false, true]) {
    testWidgets(
      'detay beklerken ${cached ? 'gerçek başlık/görsel korunur' : 'tam skeleton gösterilir'}',
      (tester) async {
        final pending = Completer<Event>();
        final repo = DiscoveryFake((_) async => testPage(['a']))
          ..detailHandler = (_) => pending.future;
        final auth = AuthController();
        final favorites = FavoritesController(null);
        addTearDown(auth.dispose);
        addTearDown(favorites.dispose);
        final event = testEvent('a');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: EventDetailScreen(
              eventId: 'a',
              repository: repo,
              auth: auth,
              favorites: favorites,
              onSignIn: () async {},
              initialEvent: cached
                  ? detailEvent({
                      'id': 'a',
                      'imageUrl': null,
                      'description': null,
                    })
                  : null,
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(EventDetailSkeleton), findsOneWidget);
        expect(
          tester
              .widget<EventDetailSkeleton>(find.byType(EventDetailSkeleton))
              .descriptionOnly,
          cached,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        if (cached) expect(find.text(detailEvent().title), findsOneWidget);
        pending.complete(event);
        await tester.pumpAndSettle();
        expect(find.byType(EventDetailSkeleton), findsNothing);
        expect(find.text('Etkinlik a'), findsOneWidget);
        expect(find.text(event.description!), findsOneWidget);
      },
    );
  }

  for (final status in [404, 503]) {
    testWidgets('detay $status skeletonı kaldırır; retry yeniden yükler', (
      tester,
    ) async {
      final pending = Completer<Event>();
      final repo = DiscoveryFake((_) async => testPage(['a']))
        ..detailHandler = (_) => pending.future;
      final auth = AuthController();
      final favorites = FavoritesController(null);
      addTearDown(auth.dispose);
      addTearDown(favorites.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: EventDetailScreen(
            eventId: 'a',
            repository: repo,
            auth: auth,
            favorites: favorites,
            onSignIn: () async {},
          ),
        ),
      );
      await tester.pump();
      pending.completeError(
        ApiException('İstek başarısız.', statusCode: status),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailSkeleton), findsNothing);
      expect(
        find.text(
          status == 404 ? 'Etkinlik bulunamadı' : 'Etkinlik yüklenemedi',
        ),
        findsOneWidget,
      );
      repo.detailHandler = (_) async => testEvent('a');
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.text('Etkinlik a'), findsOneWidget);
    });
  }

  testWidgets(
    'Favoriler signedOut/loading/empty ayrımı ve hesap değişiminde temizlik',
    (tester) async {
      final a = Completer<List<Favorite>>();
      final b = Completer<List<Favorite>>();
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final favorites = FakeFavoritesRepository()
        ..onFetch = (id) => id == userA.id ? a.future : b.future;
      await tester.pumpWidget(
        EtkinlikKesifApp(
          repository: DiscoveryFake(
            (_) async => testPage(['x'], total: 1, hasMore: false),
          ),
          authRepository: auth,
          favoritesRepository: favorites,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favoriler'));
      await tester.pumpAndSettle();
      expect(find.byType(EventListSkeleton), findsNothing);
      auth.emit(userA);
      await tester.pumpAndSettle();
      expect(find.byType(EventListSkeleton), findsOneWidget);
      a.complete([Favorite.fromEvent(userA.id, testEvent('private-a'))]);
      await tester.pumpAndSettle();
      expect(find.text('Etkinlik private-a'), findsOneWidget);
      auth.emit(null);
      await tester.pumpAndSettle();
      expect(find.text('Etkinlik private-a'), findsNothing);
      expect(find.byType(EventListSkeleton), findsNothing);
      auth.emit(userB);
      await tester.pumpAndSettle();
      expect(find.byType(EventListSkeleton), findsOneWidget);
      expect(find.text('Etkinlik private-a'), findsNothing);
      b.complete([]);
      await tester.pumpAndSettle();
      expect(find.byType(EventListSkeleton), findsNothing);
      expect(find.text('Henüz kaydettiğin etkinlik yok.'), findsOneWidget);
    },
  );

  testWidgets(
    'favori mutation sadece kalbi pending yapar; satırlar skeletona dönmez',
    (tester) async {
      final pending = Completer<void>();
      final auth = FakeAuthRepository(user: userA);
      addTearDown(auth.dispose);
      final favorites = FakeFavoritesRepository();
      favorites.byUser[userA.id] = [
        Favorite.fromEvent(userA.id, testEvent('a')),
      ];
      favorites.onRemove = (_, _) => pending.future;
      await tester.pumpWidget(
        EtkinlikKesifApp(
          repository: DiscoveryFake(
            (_) async => testPage(['a'], total: 1, hasMore: false),
          ),
          authRepository: auth,
          favoritesRepository: favorites,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favoriler'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favorilerden kaldır'));
      await tester.pump();
      expect(find.byType(EventListSkeleton), findsNothing);
      expect(find.text('Etkinlik a'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Henüz kaydettiğin etkinlik yok.'), findsOneWidget);
    },
  );

  testWidgets('tek yükleme semantiği; bloklar dokunma ve animasyon içermez', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: const Scaffold(body: EventListSkeleton())),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(EventListSkeleton)),
      matchesSemantics(label: 'Etkinlikler yükleniyor', isLiveRegion: true),
    );
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 402.0, 1440.0]) {
      testWidgets(
        '${brightness.name} $width skeleton boyut/renk ve reduced motion',
        (tester) async {
          tester.view.physicalSize = Size(width, 860);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final theme = brightness == Brightness.dark
              ? AppTheme.dark
              : AppTheme.light;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(disableAnimations: true),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const EventRowSkeleton(),
                        const SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: CategorySkeleton(),
                        ),
                        const SizedBox(height: 24),
                        const EventDetailSkeleton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final boxes = tester.widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(SkeletonBlock),
              matching: find.byType(ColoredBox),
            ),
          );
          expect(boxes, isNotEmpty);
          expect(
            boxes.every(
              (box) => box.color == theme.colorScheme.surfaceContainerHighest,
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(Hero), findsNothing);
          expect(tester.binding.transientCallbackCount, 0);
        },
      );
    }
  }

  for (final url in <String?>[null, 'https://example.invalid/broken.jpg']) {
    testWidgets(
      '${url == null ? 'null' : 'bozuk'} görsel sabit 96px placeholder ve aynı URL',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox.square(
                  dimension: 96,
                  child: EventImage(imageUrl: url),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(EventImage)), const Size(96, 96));
        expect(find.byType(SkeletonBlock), findsOneWidget);
        if (url != null) {
          final image = tester.widget<Image>(find.byType(Image));
          expect(
            ((image.image as ResizeImage).imageProvider as NetworkImage).url,
            url,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
