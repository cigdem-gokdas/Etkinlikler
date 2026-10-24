import 'dart:async';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/theme/theme_controller.dart';
import 'package:etkinlik_kesif/app/theme/theme_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/fixtures.dart';

class MemoryThemeRepository implements ThemeRepository {
  ThemeMode saved = ThemeMode.system;
  Future<ThemeMode> Function()? loader;
  Future<void> Function(ThemeMode)? writer;
  @override
  Future<ThemeMode> load() async => loader == null ? saved : loader!();
  @override
  Future<void> save(ThemeMode mode) async {
    if (writer != null) await writer!(mode);
    saved = mode;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  test(
    'varsayılan sistem; kaydedilmiş tema yeni controllerda geri döner',
    () async {
      final repo = MemoryThemeRepository();
      final first = ThemeController(repo);
      expect(first.mode, ThemeMode.system);
      expect(await first.setMode(ThemeMode.dark), isTrue);
      first.dispose();
      final second = ThemeController(repo);
      addTearDown(second.dispose);
      await second.load();
      expect(second.mode, ThemeMode.dark);
    },
  );

  test('geç preference okuması kullanıcının yeni seçimini ezmez', () async {
    final pending = Completer<ThemeMode>();
    final repo = MemoryThemeRepository()..loader = () => pending.future;
    final c = ThemeController(repo);
    addTearDown(c.dispose);
    final load = c.load();
    await c.setMode(ThemeMode.light);
    pending.complete(ThemeMode.dark);
    await load;
    expect(c.mode, ThemeMode.light);
  });

  test('hızlı tema değişimlerinde yazmalar sırayla uygulanır', () async {
    final pending = Completer<void>();
    final writes = <ThemeMode>[];
    final repo = MemoryThemeRepository()
      ..writer = (mode) async {
        writes.add(mode);
        if (mode == ThemeMode.dark) await pending.future;
      };
    final c = ThemeController(repo);
    addTearDown(c.dispose);
    final first = c.setMode(ThemeMode.dark);
    final last = c.setMode(ThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    expect(writes, [ThemeMode.dark]);
    pending.complete();
    await Future.wait([first, last]);
    expect(writes, [ThemeMode.dark, ThemeMode.light]);
    expect(repo.saved, ThemeMode.light);
  });

  test(
    'okuma/yazma hatası sistem teması/aktif seçimi bozmadan bildirilir',
    () async {
      final repo = MemoryThemeRepository()
        ..loader = (() async => throw StateError('read'))
        ..writer = (_) async => throw StateError('write');
      final c = ThemeController(repo);
      addTearDown(c.dispose);
      await c.load();
      expect(c.mode, ThemeMode.system);
      expect(await c.setMode(ThemeMode.dark), isFalse);
      expect(c.mode, ThemeMode.dark);
      repo.writer = null;
      expect(await c.setMode(ThemeMode.light), isTrue);
    },
  );

  test('dispose sonrasında tamamlanan tema yükleme bildirim yapmaz', () async {
    final pending = Completer<ThemeMode>();
    final repo = MemoryThemeRepository()..loader = () => pending.future;
    final c = ThemeController(repo);
    var notifications = 0;
    c.addListener(() => notifications++);
    final request = c.load();
    c.dispose();
    pending.complete(ThemeMode.dark);
    await request;
    expect(notifications, 0);
  });

  testWidgets('uygulama yeniden kurulunca kayıtlı koyu tema geri yüklenir', (
    tester,
  ) async {
    final repo = MemoryThemeRepository();
    Widget app(Key key) => EtkinlikKesifApp(
      key: key,
      themeRepository: repo,
      repository: StubEventsRepository(() async => samplePage()),
    );
    await tester.pumpWidget(app(const ValueKey('first')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Koyu temaya geç'));
    await tester.pumpAndSettle();
    expect(repo.saved, ThemeMode.dark);
    await tester.pumpWidget(app(const ValueKey('second')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(find.byTooltip('Açık temaya geç'), findsOneWidget);
  });
}
