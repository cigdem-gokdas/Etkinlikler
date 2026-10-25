import 'dart:async';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/adaptive_event_composition.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/event_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/controlled_image.dart';
import 'helpers/detail_fixture.dart';
import 'helpers/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  for (final url in <String?>[null, '', 'not-an-image-url']) {
    testWidgets('missing image $url uses a neutral icon-free detail surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveEventComposition(
              imageUrl: url,
              content: const Text('Gerçek etkinlik bilgileri'),
            ),
          ),
        ),
      );
      expect(find.byType(Icon), findsNothing);
      expect(
        find.byKey(const ValueKey('detail-image-fallback')),
        findsOneWidget,
      );
      expect(find.text('Gerçek etkinlik bilgileri'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'failed decode keeps the same content geometry and no broken icon',
    (tester) async {
      final image = ControlledImage();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveEventComposition(
              imageUrl: 'https://example.invalid/broken-image',
              imageProvider: image,
              content: const Text('Gerçek etkinlik bilgileri'),
            ),
          ),
        ),
      );
      final before = tester.getRect(find.text('Gerçek etkinlik bilgileri'));
      image.fail();
      await tester.pumpAndSettle();
      expect(find.byType(Icon), findsNothing);
      expect(
        find.byKey(const ValueKey('detail-image-fallback')),
        findsOneWidget,
      );
      expect(tester.getRect(find.text('Gerçek etkinlik bilgileri')), before);
      expect(tester.takeException(), isNull);
    },
  );

  for (final url in <String?>[
    null,
    '',
    'not-an-image-url',
    'https://example.invalid/broken.jpg',
  ]) {
    testWidgets('list fallback $url stays neutral at the same size', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.square(
              dimension: 96,
              child: EventImage(imageUrl: url),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Icon), findsNothing);
      expect(tester.getSize(find.byType(EventImage)), const Size(96, 96));
      expect(tester.takeException(), isNull);
    });
  }

  for (final listImage in <String?>[null, 'https://example.invalid/list.jpg']) {
    testWidgets(
      'detail refresh replaces list photo $listImage without N+1 requests',
      (tester) async {
        final pending = Completer<Event>();
        final initial = detailEvent({
          'imageUrl': listImage,
          'description': null,
        });
        final repository = StubEventsRepository(
          () async => EventsPage(
            items: [initial],
            page: 1,
            limit: 10,
            total: 1,
            hasMore: false,
          ),
        )..detailHandler = (_) => pending.future;
        await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
        await tester.pumpAndSettle();
        expect(repository.detailCalls, 0);
        await tester.tap(find.text(initial.title));
        await tester.pumpAndSettle();
        expect(repository.detailCalls, 1);
        expect(
          tester
              .widget<AdaptiveEventComposition>(
                find.byType(AdaptiveEventComposition),
              )
              .imageUrl,
          listImage,
        );
        final fresh = detailEvent({
          'imageUrl': 'https://example.invalid/current-detail.jpg',
          'description': 'Sunucudaki güncel açıklama',
        });
        pending.complete(fresh);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AdaptiveEventComposition>(
                find.byType(AdaptiveEventComposition),
              )
              .imageUrl,
          fresh.imageUrl,
        );
        expect(find.text('Sunucudaki güncel açıklama'), findsOneWidget);
        expect(repository.detailCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
