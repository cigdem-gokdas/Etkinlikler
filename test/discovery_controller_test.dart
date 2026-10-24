import 'dart:async';

import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/events/controllers/events_controller.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/discovery_fake.dart';

void main() {
  testWidgets('350ms debounce hızlı yazmada yalnızca son sorguyu gönderir', (
    tester,
  ) async {
    final repo = DiscoveryFake((_) async => testPage(['a']));
    final c = EventsController(repo);
    await c.load();
    c.setSearchQuery('K');
    await tester.pump(const Duration(milliseconds: 200));
    c.setSearchQuery('Kod');
    await tester.pump(const Duration(milliseconds: 200));
    c.setSearchQuery('Kotlin');
    await tester.pump(const Duration(milliseconds: 349));
    expect(repo.requests.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repo.requests.length, 2);
    expect(repo.requests.last.query, 'Kotlin');
    expect(repo.requests.last.page, 1);
    c.dispose();
  });

  testWidgets('debounce sürerken eski ilk yanıt yeni sorguya uygulanmaz', (
    tester,
  ) async {
    final old = Completer<EventsPage>();
    final repo = DiscoveryFake(
      (r) => r.query == '' ? old.future : Future.value(testPage(['new'])),
    );
    final c = EventsController(repo);
    final initial = c.load();
    c.setSearchQuery('yeni');
    old.complete(testPage(['old']));
    await initial;
    expect(c.events, isEmpty);
    expect(c.activity, EventsActivity.debouncing);
    await tester.pump(const Duration(milliseconds: 350));
    expect(c.events.single.id, 'new');
    c.dispose();
  });

  testWidgets(
    'geç gelen arama cevabı daha yeni sonucu ve activity durumunu ezmez',
    (tester) async {
      final old = Completer<EventsPage>();
      final repo = DiscoveryFake(
        (r) => r.query == 'eski' ? old.future : Future.value(testPage(['new'])),
      );
      final c = EventsController(repo);
      c.setSearchQuery('eski');
      await tester.pump(const Duration(milliseconds: 350));
      c.setSearchQuery('yeni');
      await tester.pump(const Duration(milliseconds: 350));
      old.complete(testPage(['old']));
      await tester.pump();
      expect(c.events.single.id, 'new');
      expect(c.query, 'yeni');
      expect(c.activity, EventsActivity.idle);
      c.dispose();
    },
  );

  testWidgets('arama temizlenir; kategori korunur ve sayfa 1 istenir', (
    tester,
  ) async {
    final repo = DiscoveryFake((_) async => testPage(['a']));
    final c = EventsController(repo);
    await c.selectCategory('Workshop');
    c.setSearchQuery('flutter');
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.requests.last.category, 'Workshop');
    expect(repo.requests.last.query, 'flutter');
    c.clearSearch();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.requests.last.query, '');
    expect(repo.requests.last.category, 'Workshop');
    expect(c.currentPage, 1);
    c.dispose();
  });

  testWidgets(
    'kategori seçimi bekleyen debounce ile aynı sorguyu tek istekle birleştirir',
    (tester) async {
      final repo = DiscoveryFake((_) async => testPage(['a']));
      final c = EventsController(repo);
      c.setSearchQuery('flutter');
      await c.selectCategory('Workshop');
      await tester.pump(const Duration(seconds: 1));
      expect(repo.requests.length, 1);
      expect(repo.requests.single.query, 'flutter');
      expect(repo.requests.single.category, 'Workshop');
      await c.selectCategory(null);
      expect(repo.requests.last.category, isNull);
      c.dispose();
    },
  );

  test(
    'ilk yükleme ve devam isteği sırasında duplicate istek engellenir',
    () async {
      final first = Completer<EventsPage>();
      final more = Completer<EventsPage>();
      final repo = DiscoveryFake(
        (r) => r.page == 1 ? first.future : more.future,
      );
      final c = EventsController(repo);
      addTearDown(c.dispose);
      final initial = c.load();
      await c.loadMore();
      await c.load();
      expect(repo.requests.length, 1);
      first.complete(testPage(['a']));
      await initial;
      final next = c.loadMore();
      await c.loadMore();
      expect(repo.requests.map((r) => r.page), [1, 2]);
      more.complete(testPage(['b'], page: 2));
      await next;
      expect(c.events.map((e) => e.id), ['a', 'b']);
    },
  );

  for (final totalReached in [false, true]) {
    test(
      'hasMore false veya total sınırı yeni isteği durdurur: $totalReached',
      () async {
        final repo = DiscoveryFake(
          (_) async => testPage(
            ['a'],
            total: totalReached ? 1 : 30,
            hasMore: totalReached,
          ),
        );
        final c = EventsController(repo);
        addTearDown(c.dispose);
        await c.load();
        await c.loadMore();
        expect(repo.requests.length, 1);
        expect(c.hasMore, isFalse);
      },
    );
  }

  test('ilk ve devam sayfalarındaki duplicate ID tek kez tutulur', () async {
    final repo = DiscoveryFake(
      (r) async => r.page == 1
          ? testPage(['a', 'a', 'b'])
          : testPage(['b', 'c', 'c'], page: 2, total: 3),
    );
    final c = EventsController(repo);
    addTearDown(c.dispose);
    await c.load();
    await c.loadMore();
    expect(c.events.map((e) => e.id), ['a', 'b', 'c']);
    expect(c.hasMore, isFalse);
    expect(() => c.events.clear(), throwsUnsupportedError);
  });

  for (final duplicate in [false, true]) {
    test(
      'ilerleme sağlamayan boş/duplicate sayfa otomatik döngüyü durdurur: $duplicate',
      () async {
        final repo = DiscoveryFake(
          (r) async =>
              testPage(r.page == 1 || duplicate ? ['a'] : [], page: r.page),
        );
        final c = EventsController(repo);
        addTearDown(c.dispose);
        await c.load();
        await c.loadMore();
        await c.loadMore();
        expect(repo.requests.length, 2);
        expect(c.hasMore, isFalse);
      },
    );
  }

  test(
    'pagination hatasında liste/page korunur; açık retry aynı sayfayı ister',
    () async {
      var fail = true;
      final repo = DiscoveryFake((r) async {
        if (r.page == 2 && fail) throw const ApiException('Offline');
        return testPage([r.page == 1 ? 'a' : 'b'], page: r.page);
      });
      final c = EventsController(repo);
      addTearDown(c.dispose);
      await c.load();
      final before = c.events;
      await c.loadMore();
      expect(c.events, same(before));
      expect(c.currentPage, 1);
      expect(c.paginationError, 'Offline');
      expect(c.errorMessage, isNull);
      await c.loadMore();
      expect(repo.requests.length, 2);
      fail = false;
      await c.loadMore(retry: true);
      expect(repo.requests.map((r) => r.page), [1, 2, 2]);
      expect(c.currentPage, 2);
      expect(c.paginationError, isNull);
    },
  );

  test('yanlış sayfa numarası page ilerletmez ve retry mümkün kalır', () async {
    final repo = DiscoveryFake((_) async => testPage(['a']));
    final c = EventsController(repo);
    addTearDown(c.dispose);
    await c.load();
    await c.loadMore();
    expect(c.currentPage, 1);
    expect(c.paginationError, isNotNull);
  });

  test('kategori değişimi page reset eder; eski pagination başarı/hatası uygulanmaz', () async {
    for (final fail in [false, true]) {
      final pending = Completer<EventsPage>();
      final repo = DiscoveryFake(
        (r) => r.page == 2
            ? pending.future
            : Future.value(testPage([r.category ?? 'all'])),
      );
      final c = EventsController(repo);
      await c.load();
      final old = c.loadMore();
      await c.selectCategory('Workshop');
      if (fail) {
        pending.completeError(const ApiException('Eski hata'));
      } else {
        pending.complete(testPage(['old'], page: 2));
      }
      await old;
      expect(c.events.single.id, 'Workshop');
      expect(c.currentPage, 1);
      expect(c.paginationError, isNull);
      expect(c.activity, EventsActivity.idle);
      c.dispose();
    }
  });

  test(
    'refresh eski pagination yanıtını yok sayar ve ilk sayfaya döner',
    () async {
      final pending = Completer<EventsPage>();
      var firstCount = 0;
      final repo = DiscoveryFake(
        (r) => r.page == 2
            ? pending.future
            : Future.value(testPage(['first-${++firstCount}'])),
      );
      final c = EventsController(repo);
      addTearDown(c.dispose);
      await c.load();
      final more = c.loadMore();
      await c.load();
      pending.complete(testPage(['old'], page: 2));
      await more;
      expect(c.events.single.id, 'first-2');
      expect(c.currentPage, 1);
      expect(c.paginationError, isNull);
      expect(c.isLoadingMore, isFalse);
    },
  );

  test('kategoriler hata verse de etkinlikler kullanılabilir; bağımsız retry çalışır', () async {
    final repo = DiscoveryFake((_) async => testPage(['a']))
      ..categoriesHandler = () async => throw const ApiException('Offline');
    final c = EventsController(repo);
    addTearDown(c.dispose);
    await Future.wait([c.load(), c.loadCategories()]);
    expect(c.status, EventsStatus.success);
    expect(c.categoriesStatus, CategoriesStatus.error);
    repo.categoriesHandler = () async => ['Yarışma'];
    await c.loadCategories();
    expect(c.categories, ['Yarışma']);
    expect(c.categoriesError, isNull);
  });

  testWidgets(
    'dispose debounce timerını iptal eder; geç sayfa yanıtı bildirim yapmaz',
    (tester) async {
      final repo = DiscoveryFake((_) async => testPage(['a']));
      final c = EventsController(repo);
      c.setSearchQuery('bekleyen');
      c.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(repo.requests, isEmpty);
      final pending = Completer<EventsPage>();
      final c2 = EventsController(repo);
      await c2.load();
      repo.handler = (_) => pending.future;
      var notified = 0;
      c2.addListener(() => notified++);
      final request = c2.loadMore();
      c2.dispose();
      pending.complete(testPage(['b'], page: 2));
      await request;
      expect(notified, 1);
    },
  );
}
