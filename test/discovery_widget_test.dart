import 'dart:async';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/events/controllers/events_controller.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:etkinlik_kesif/features/events/presentation/screens/explore_screen.dart';
import 'package:etkinlik_kesif/features/events/presentation/screens/event_detail_screen.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/event_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/account_fakes.dart';
import 'helpers/discovery_fake.dart';

Finder get listFinder => find.byKey(const PageStorageKey('events-list'));
ScrollableState listState(WidgetTester tester) => tester.state<ScrollableState>(
  find.descendant(
    of: listFinder,
    matching: find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    ),
  ),
);

Future<void> showExplore(
  WidgetTester tester,
  EventsController controller, {
  bool tinyRows = false,
  Brightness brightness = Brightness.light,
}) async {
  await controller.loadCategories();
  await controller.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(
        body: ExploreScreen(
          controller: controller,
          eventBuilder: (context, event) => SizedBox(
            height: tinyRows ? 1 : 100,
            child: tinyRows ? null : Text(event.title),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    '%69 istek atmaz; %70 bir sonraki sayfayı tek kez başlatır, scroll korunur',
    (tester) async {
      final pending = Completer<EventsPage>();
      final repo = DiscoveryFake(
        (r) => r.page == 1
            ? Future.value(testPage(List.generate(10, (i) => 'a$i')))
            : pending.future,
      );
      final c = EventsController(repo);
      addTearDown(c.dispose);
      await showExplore(tester, c);
      final position = listState(tester).position;
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent * .69);
      await tester.pump();
      expect(repo.requests.length, 1);
      final threshold = position.maxScrollExtent * .70;
      position.jumpTo(threshold);
      await tester.pump();
      expect(repo.requests.map((r) => r.page), [1, 2]);
      position.jumpTo(threshold + 1);
      await tester.pump();
      expect(repo.requests.length, 2);
      pending.complete(
        testPage(['a9', 'b'], page: 2, total: 11, hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(c.events.length, 11);
      expect(position.pixels, closeTo(threshold + 1, .1));
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(repo.requests.length, 2);
      expect(find.byType(Scrollbar), findsNothing);
    },
  );

  testWidgets('viewport dolmazsa otomatik doldurma en fazla üç ek sayfadır', (
    tester,
  ) async {
    final repo = DiscoveryFake(
      (r) async => testPage(['a${r.page}'], page: r.page, total: 100),
    );
    final c = EventsController(repo);
    addTearDown(c.dispose);
    await showExplore(tester, c, tinyRows: true);
    expect(repo.requests.map((r) => r.page), [1, 2, 3, 4]);
    expect(c.hasMore, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(repo.requests.length, 4);
  });

  testWidgets(
    'devam hatasında footer eski listeyi korur ve aynı sayfayı tekrar ister',
    (tester) async {
      var fail = true;
      final repo = DiscoveryFake((r) async {
        if (r.page == 2 && fail) throw const ApiException('Offline');
        return testPage(
          r.page == 1 ? List.generate(10, (i) => 'a$i') : ['b'],
          page: r.page,
          hasMore: r.page == 1,
        );
      });
      final c = EventsController(repo);
      addTearDown(c.dispose);
      await showExplore(tester, c);
      listState(tester).position
          .jumpTo(listState(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kalan etkinlikler yüklenemedi.'));
      await tester.pumpAndSettle();
      expect(c.events.length, 10);
      fail = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(repo.requests.map((r) => r.page), [1, 2, 2]);
      expect(c.events.last.id, 'b');
      expect(find.text('Kalan etkinlikler yüklenemedi.'), findsNothing);
    },
  );

  testWidgets(
    'arama ve kategori UI sunucu sorgusunda birleşir; boş sonuç temizlenebilir',
    (tester) async {
      final repo = DiscoveryFake(
        (r) async => r.query?.isNotEmpty == true
            ? testPage([], total: 0, hasMore: false)
            : testPage(['a'], total: 1, hasMore: false),
      );
      await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('event-search')),
        'Türkçe arama',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu aramayla eşleşen etkinlik bulunamadı.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('category:Workshop')));
      await tester.pumpAndSettle();
      expect(repo.requests.last.query, 'Türkçe arama');
      expect(repo.requests.last.category, 'Workshop');
      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repo.requests.last.query, '');
      expect(repo.requests.last.category, 'Workshop');
      expect(find.text('Etkinlik a'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('category:all')));
      await tester.pumpAndSettle();
      expect(repo.requests.last.category, isNull);
    },
  );

  testWidgets(
    'kategori hatası etkinlikleri kilitlemez; ayrı retry kategorileri getirir',
    (tester) async {
      final repo = DiscoveryFake(
        (_) async => testPage(['a'], total: 1, hasMore: false),
      )..categoriesHandler = () async => throw const ApiException('Offline');
      await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('Etkinlik a'), findsOneWidget);
      expect(find.text('Kategoriler yüklenemedi.'), findsOneWidget);
      repo.categoriesHandler = () async => ['Workshop'];
      await tester.tap(find.text('Kategorileri yenile'));
      await tester.pumpAndSettle();
      expect(
        find.text('Workshop'),
        findsNWidgets(2),
      ); // Event category + filter.
      expect(repo.requests.length, 1);
    },
  );

  testWidgets(
    'kalp navigasyonu ölçü/selected label tutarlı; sekmeler veri ve scroll korur',
    (tester) async {
      final repo = DiscoveryFake(
        (_) async => testPage(
          List.generate(12, (i) => 'a$i'),
          total: 12,
          hasMore: false,
        ),
      );
      await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
      await tester.pumpAndSettle();
      final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final favorite = nav.destinations[1] as NavigationDestination;
      expect((favorite.icon as Icon).icon, Icons.favorite_border);
      expect((favorite.selectedIcon as Icon).icon, Icons.favorite);
      final position = listState(tester).position;
      position.jumpTo(250);
      await tester.pump();
      await tester.tap(find.text('Favoriler'));
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(NavigationBar)))
          .navigationBarTheme;
      expect(
        theme.iconTheme!.resolve({WidgetState.selected})!.size,
        theme.iconTheme!.resolve({})!.size,
      );
      expect(
        theme.labelTextStyle!.resolve({WidgetState.selected})!.fontWeight,
        FontWeight.w600,
      );
      await tester.tap(find.text('Keşfet'));
      await tester.pumpAndSettle();
      expect(listState(tester).position.pixels, 250);
      expect(repo.requests.length, 1);
    },
  );

  testWidgets(
    'filtre sonuçları scrollu sıfırlar; detaydan geri ve kalp durumu korunur',
    (tester) async {
      final repo = DiscoveryFake(
        (_) async => testPage(
          List.generate(12, (i) => 'a$i'),
          total: 12,
          hasMore: false,
        ),
      );
      final auth = FakeAuthRepository(user: userA);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        EtkinlikKesifApp(
          repository: repo,
          authRepository: auth,
          favoritesRepository: FakeFavoritesRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favorilere ekle').first);
      await tester.pumpAndSettle();
      listState(tester).position.jumpTo(400);
      await tester.pump();
      // Filters now return when scrolling back toward the expanded header.
      listState(tester).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category:Workshop')));
      await tester.pumpAndSettle();
      expect(listState(tester).position.pixels, 0);
      expect(find.byTooltip('Favorilerden kaldır'), findsOneWidget);
      await tester.tap(find.text('Etkinlik a0'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.byTooltip('Favorilerden kaldır'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(repo.requests.length, 2);
      expect(listState(tester).position.pixels, 0);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'arama/kategori/uzun satır ${brightness.name} temada küçük ekranda klavyeyle taşmaz',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = DiscoveryFake(
          (_) async => testPage(['a'], total: 1, hasMore: false),
        );
        final c = EventsController(repo);
        addTearDown(c.dispose);
        await c.load();
        await c.loadCategories();
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light,
            home: Scaffold(
              body: ExploreScreen(
                controller: c,
                eventBuilder: (context, event) => EventRow(
                  event: testEvent(
                    'a',
                    title: List.filled(6, 'Uzun etkinlik başlığı').join(' '),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('event-search')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollbar), findsNothing);
      },
    );
  }

  testWidgets('pull-to-refresh bütün sayfaları page 1 ile değiştirir', (
    tester,
  ) async {
    final repo = DiscoveryFake(
      (r) async =>
          testPage(['p${r.page}'], page: r.page, total: 3, hasMore: r.page < 3),
    );
    final c = EventsController(repo);
    addTearDown(c.dispose);
    await showExplore(tester, c, tinyRows: true);
    expect(c.currentPage, 3);
    final before = repo.requests.length;
    await tester.drag(listFinder, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(repo.requests[before].page, 1);
    expect(c.events.map((e) => e.id).toSet(), {'p1', 'p2', 'p3'});
  });
}
