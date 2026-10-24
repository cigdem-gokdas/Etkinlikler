import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/widgets/floating_navigation.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/discovery_fake.dart';
import 'helpers/detail_fixture.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  testWidgets(
    'header geometry collapses, filters disappear and return; focus survives query rebuild',
    (tester) async {
      final repo = DiscoveryFake(
        (_) async => testPage(
          List.generate(15, (i) => 'a$i'),
          total: 15,
          hasMore: false,
        ),
      );
      await tester.pumpWidget(EtkinlikKesifApp(repository: repo));
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('collapsing-title:Keşfet'));
      expect(tester.widget<Text>(title).style!.fontSize, 34);
      final scroll = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const PageStorageKey('events-list')),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            ),
          )
          .position;
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(title).style!.fontSize, 20);
      expect(
        find.byKey(const ValueKey('category:all')).hitTestable(),
        findsNothing,
      );
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(title).style!.fontSize, 34);
      expect(
        find.byKey(const ValueKey('category:all')).hitTestable(),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Flut');
      await tester.pump(const Duration(milliseconds: 200));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, true);
      await tester.enterText(find.byType(TextField), 'Flutter');
      await tester.pump(const Duration(milliseconds: 349));
      expect(repo.requests.length, 1);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(repo.requests.last.query, 'Flutter');
      expect(editable.focusNode.hasFocus, true);
    },
  );

  testWidgets('floating bar respects bottom safe area and hides for keyboard', (
    tester,
  ) async {
    Widget nav(double keyboard) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          padding: const EdgeInsets.only(bottom: 34),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Scaffold(
          bottomNavigationBar: FloatingNavigation(index: 1, onChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpWidget(nav(0));
    final bar = find.byType(NavigationBar);
    expect(tester.getBottomLeft(bar).dy, lessThanOrEqualTo(600 - 34));
    expect(tester.getTopLeft(bar).dx, 24);
    expect(
      (tester.widget<NavigationBar>(bar).destinations[1]
              as NavigationDestination)
          .selectedIcon,
      isA<Icon>(),
    );
    await tester.pumpWidget(nav(300));
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('missing organizer remains absent instead of fabricated', () {
    final json = detailJson()..remove('organizer');
    expect(Event.fromJson(json).organizer, isEmpty);
  });
}
