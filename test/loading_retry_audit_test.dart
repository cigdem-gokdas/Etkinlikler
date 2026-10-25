import 'dart:async';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/core/widgets/skeleton.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'initial error retry replaces the error with loading until response',
    (tester) async {
      final pending = Completer<EventsPage>();
      var calls = 0;
      final repository = StubEventsRepository(() {
        calls++;
        return calls == 1
            ? Future.error(
                const ApiException('Sunucu hatası.', statusCode: 500),
              )
            : pending.future;
      });
      addTearDown(() {
        if (!pending.isCompleted) pending.complete(samplePage());
      });
      await tester.pumpWidget(EtkinlikKesifApp(repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('Etkinlikler yüklenemedi'), findsOneWidget);
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      expect(calls, 2);
      expect(find.byType(EventListSkeleton), findsOneWidget);
      expect(find.text('Etkinlikler yüklenemedi'), findsNothing);
      pending.complete(samplePage());
      await tester.pumpAndSettle();
      expect(find.byType(EventListSkeleton), findsNothing);
      expect(find.text('Etkinlikler yüklenemedi'), findsNothing);
      expect(find.byKey(const PageStorageKey('events-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
