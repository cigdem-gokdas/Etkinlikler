import 'package:etkinlik_kesif/core/widgets/detail_text_surface.dart';
import 'package:etkinlik_kesif/core/widgets/skeleton.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/adaptive_event_composition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lighter photograph preserves normal text and mint contrast', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveEventComposition(
            imageUrl: null,
            content: Text('Etkinlik'),
          ),
        ),
      ),
    );
    final scrim = tester
        .widget<ColoredBox>(find.byKey(const ValueKey('detail-scrim')))
        .color;
    final brightest = Color.alphaBlend(scrim, Colors.white);
    for (final foreground in [
      Colors.white,
      const Color(0xFFC4DFC8),
      Colors.white.withValues(alpha: .85),
    ]) {
      final text = Color.alphaBlend(foreground, brightest);
      final contrast =
          (text.computeLuminance() + .05) /
          (brightest.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    }
    expect(scrim.a, lessThan(const Color(0xB8000000).a));
  });

  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'description skeleton shares text insets and line metrics at $scale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SizedBox(
                  width: 320,
                  child: EventDetailSkeleton(descriptionOnly: true),
                ),
              ),
            ),
          ),
        );
        final line0 = find.byKey(const ValueKey('detail-paragraph-line-0'));
        final line1 = find.byKey(const ValueKey('detail-paragraph-line-1'));
        final loadedText = TextPainter(
          text: const TextSpan(
            text: 'Örnek',
            style: DetailTextSurface.textStyle,
          ),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout(maxWidth: 280);
        expect(tester.getSize(line0).width, 280);
        expect(tester.getTopLeft(line0).dx, 20);
        expect(
          tester.getTopLeft(line1).dy - tester.getTopLeft(line0).dy,
          closeTo(loadedText.height, .01),
        );
        loadedText.dispose();
        final placeholderWidth = tester.getSize(line0).width;
        final placeholderLeft = tester.getTopLeft(line0).dx;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SizedBox(
                  width: 320,
                  child: DetailTextSurface(
                    child: SelectableText(
                      'Uzun açıklama metni',
                      style: DetailTextSurface.textStyle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final text = find.byType(SelectableText);
        expect(tester.getSize(text).width, placeholderWidth);
        expect(tester.getTopLeft(text).dx, placeholderLeft);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
