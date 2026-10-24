import 'dart:async';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/event_row.dart';
import 'package:flutter/material.dart';
import 'package:etkinlik_kesif/core/widgets/skeleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('açılışta yükleme, başlık ve alt navigasyon görünür', (
    tester,
  ) async {
    final pending = Completer<EventsPage>();
    await tester.pumpWidget(
      EtkinlikKesifApp(repository: StubEventsRepository(() => pending.future)),
    );
    await tester.pump();
    expect(find.byType(EventListSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Keşfet'), findsNWidgets(2));
    expect(find.text('Favoriler'), findsOneWidget);
    pending.complete(samplePage());
    await tester.pumpAndSettle();
    expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('boş liste ve Favoriler sekmesi gösterilir', (tester) async {
    final repository = StubEventsRepository(
      () async => samplePage(empty: true),
    );
    await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Henüz etkinlik yok.'), findsOneWidget);
    await tester.tap(find.text('Favoriler'));
    await tester.pumpAndSettle();
    expect(
      find.text('Kaydettiğin etkinliklere istediğin zaman ulaşabilirsin.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Giriş yap'), findsOneWidget);
    await tester.tap(find.text('Keşfet'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz etkinlik yok.'), findsOneWidget);
    expect(repository.calls, 1);
  });

  testWidgets('hata mesajındaki Tekrar dene gerçek bir yükleme başlatır', (
    tester,
  ) async {
    final repository = StubEventsRepository(
      () async => throw const ApiException('Bağlantı kurulamadı.'),
    );
    await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Etkinlikler yüklenemedi'), findsOneWidget);
    repository.handler = () async => samplePage();
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('tema değişir ve sekme değişimi temayı korur', (tester) async {
    await tester.pumpWidget(
      EtkinlikKesifApp(
        repository: StubEventsRepository(() async => samplePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    await tester.tap(find.byTooltip('Koyu temaya geç'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.tap(find.text('Favoriler'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Açık temaya geç'), findsOneWidget);
    await tester.tap(find.byTooltip('Açık temaya geç'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });

  testWidgets(
    'pull-to-refresh hatası listeyi korur ve kullanıcıya gösterilir',
    (tester) async {
      final repository = StubEventsRepository(() async => samplePage());
      await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
      await tester.pumpAndSettle();
      repository.handler = () async => throw const ApiException('Zaman aşımı.');
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
      expect(find.textContaining('Yenileme başarısız.'), findsOneWidget);
      repository.handler = () async => samplePage(empty: true);
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.text('Henüz etkinlik yok.'), findsOneWidget);
      expect(find.textContaining('Yenileme başarısız.'), findsNothing);
    },
  );

  testWidgets('320px ekranda büyük metin, uzun başlık ve eksik konum taşmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final event = sampleEvent(
      title: 'Startup Fikrinden MVP’ye: Kampüsten Çıkan Girişimler Anlatıyor ve Sorularınızı Yanıtlıyor',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [EventRow(event: event)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Konum belirtilmedi'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('görsel yükleme hatası nötr placeholder ile karşılanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: EventRow(
            event: sampleEvent(
              imageUrl: 'https://picsum.photos/seed/broken-image-test/800/450.invalid',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
    expect(find.byType(ColoredBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
