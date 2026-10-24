import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/launch/launch_intro.dart';
import 'package:etkinlik_kesif/app/theme/theme_repository.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/adaptive_event_composition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/controlled_image.dart';
import 'helpers/discovery_fake.dart';

class _Theme implements ThemeRepository {
  _Theme(this.mode);
  final ThemeMode mode;
  @override
  Future<ThemeMode> load() async => mode;
  @override
  Future<void> save(ThemeMode mode) async {}
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '${mode.name}: detail pop restores status bar; auth has its own style',
      (tester) async {
        tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpWidget(
          EtkinlikKesifApp(
            repository: DiscoveryFake(
              (_) async => testPage(['a'], total: 1, hasMore: false),
            ),
            themeRepository: _Theme(mode),
          ),
        );
        await tester.pumpAndSettle();
        final homeBrightness = mode == ThemeMode.light
            ? Brightness.light
            : Brightness.dark;
        expect(SystemChrome.latestStyle?.statusBarBrightness, homeBrightness);
        await tester.tap(find.text('Etkinlik a'));
        await tester.pumpAndSettle();
        expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);
        expect(
          tester.getTopLeft(find.text('Etkinlik a')).dy,
          greaterThan(tester.getBottomLeft(find.byType(BackButton)).dy),
        );
        expect(find.byType(Hero), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(SystemChrome.latestStyle?.statusBarBrightness, homeBrightness);
        await tester.tap(find.byTooltip('Giriş yap'));
        await tester.pumpAndSettle();
        expect(SystemChrome.latestStyle?.statusBarBrightness, homeBrightness);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(SystemChrome.latestStyle?.statusBarBrightness, homeBrightness);
      },
    );
  }

  testWidgets('intro overrides the underlying dark route then restores it', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 59);
    tester.view.viewPadding = const FakeViewPadding(top: 59);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      const MaterialApp(
        home: LaunchIntro(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(backgroundColor: Colors.black),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.light);
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);
  });

  for (final dimensions in [
    const Size(800, 450),
    const Size(600, 600),
    const Size(450, 800),
  ]) {
    testWidgets(
      '$dimensions: one surface and complete large text remain scrollable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = ControlledImage();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                padding: EdgeInsets.only(top: 59, bottom: 34),
                viewPadding: EdgeInsets.only(top: 59, bottom: 34),
              ),
              child: Scaffold(
                body: AdaptiveEventComposition(
                  imageUrl: 'https://example.invalid/current-api-image',
                  imageProvider: provider,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(List.filled(8, 'Uzun etkinlik başlığı').join(' ')),
                      Text(
                        List.filled(
                          50,
                          'Tam açıklama kesilmeden okunur.',
                        ).join('\n'),
                      ),
                      const Text('Açıklamanın sonu'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => provider.emit(
            dimensions.width.toInt(),
            dimensions.height.toInt(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RawImage), findsOneWidget);
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        expect(position.maxScrollExtent, greaterThan(1000));
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(find.text('Açıklamanın sonu').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
