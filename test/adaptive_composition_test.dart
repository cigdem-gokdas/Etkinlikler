import 'package:etkinlik_kesif/features/events/presentation/widgets/adaptive_event_composition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/controlled_image.dart';

Widget composition(
  ControlledImage? provider, {
  String? url = 'https://example.invalid/event.png',
}) => MaterialApp(
  home: Scaffold(
    body: AdaptiveEventComposition(
      imageUrl: url,
      imageProvider: provider,
      content: const Text(
        'API başlığı · Konum · Açıklama',
        style: TextStyle(color: Colors.white),
      ),
    ),
  ),
);

void main() {
  for (final entry in <(int, int, String)>[
    (1600, 900, 'landscape'),
    (800, 600, 'landscape'),
    (600, 600, 'square'),
    (600, 800, 'portrait'),
    (450, 800, 'portrait'),
    (16, 9, 'landscape'),
  ]) {
    testWidgets(
      '${entry.$1}×${entry.$2}: actual metadata, one surface, undistorted crop',
      (tester) async {
        final provider = ControlledImage();
        await tester.pumpWidget(composition(provider));
        await tester.runAsync(() => provider.emit(entry.$1, entry.$2));
        await tester.pumpAndSettle();
        final atmosphere = tester.widget<RawImage>(
          find.byKey(const ValueKey('atmospheric-image')),
        );
        expect(find.byType(RawImage), findsOneWidget);
        expect(find.byKey(ValueKey('composition:${entry.$3}')), findsOneWidget);
        expect(find.byKey(ValueKey('foreground:${entry.$3}')), findsNothing);
        expect(
          atmosphere.image!.width / atmosphere.image!.height,
          entry.$1 / entry.$2,
        );
        expect(atmosphere.fit, BoxFit.cover);
        final fitted = applyBoxFit(
          atmosphere.fit!,
          Size(entry.$1.toDouble(), entry.$2.toDouble()),
          tester.getSize(find.byKey(const ValueKey('atmospheric-image'))),
        );
        expect(
          fitted.destination.width / fitted.source.width,
          closeTo(fitted.destination.height / fitted.source.height, .00001),
        );
        expect(provider.loads, 1);
        expect(find.text('API başlığı · Konum · Açıklama'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('pending frame has stable placeholder and visible content', (
    tester,
  ) async {
    await tester.pumpWidget(composition(ControlledImage()));
    expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
    expect(find.text('API başlığı · Konum · Açıklama'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final url in <String?>[null, '', 'not-a-url', 'file:///private/photo']) {
    testWidgets('unusable URL $url stays readable without a request', (
      tester,
    ) async {
      await tester.pumpWidget(composition(null, url: url));
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.text('API başlığı · Konum · Açıklama'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('image failure keeps content, scrim and scroll usable', (
    tester,
  ) async {
    final provider = ControlledImage();
    await tester.pumpWidget(composition(provider));
    provider.fail();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('event-detail-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late old source cannot overwrite new event dimensions; dispose detaches',
    (tester) async {
      final old = ControlledImage();
      final current = ControlledImage();
      await tester.pumpWidget(composition(old));
      await tester.pumpWidget(
        composition(current, url: 'https://example.invalid/new.png'),
      );
      await tester.runAsync(() => current.emit(600, 800));
      await tester.pumpAndSettle();
      await tester.runAsync(() => old.emit(800, 450));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('composition:portrait')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('composition:landscape')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scrim preserves white text contrast over the brightest photograph',
    (tester) async {
      await tester.pumpWidget(composition(ControlledImage()));
      final scrim = tester
          .widget<ColoredBox>(find.byKey(const ValueKey('detail-scrim')))
          .color;
      final background = Color.alphaBlend(
        scrim,
        Colors.white,
      ).computeLuminance();
      expect(1.05 / (background + .05), greaterThanOrEqualTo(4.5));
    },
  );
}
