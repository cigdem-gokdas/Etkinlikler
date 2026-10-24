import 'dart:convert';
import 'dart:io';

import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';

Map<String, Object?> detailJson() =>
    jsonDecode(File('test/fixtures/event_detail.json').readAsStringSync())
        as Map<String, Object?>;
Event detailEvent([Map<String, Object?> changes = const {}]) =>
    Event.fromJson({...detailJson(), ...changes});
EventsPage detailPage() => EventsPage(
  items: [detailEvent()],
  page: 1,
  limit: 10,
  total: 1,
  hasMore: false,
);
