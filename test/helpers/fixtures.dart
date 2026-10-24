import 'dart:convert';
import 'dart:io';

import 'package:etkinlik_kesif/features/events/data/events_repository.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';

Map<String, Object?> readPageJson() {
  final Object? decoded = jsonDecode(
    File('test/fixtures/events_page.json').readAsStringSync(),
  );
  return decoded! as Map<String, Object?>;
}

Event sampleEvent({String? title, String? location, String? imageUrl}) {
  final items = readPageJson()['items']! as List<Object?>;
  final json = Map<String, Object?>.from(items.first! as Map<String, Object?>);
  json['imageUrl'] = imageUrl;
  json['location'] = location;
  if (title != null) json['title'] = title;
  return Event.fromJson(json);
}

EventsPage samplePage({bool empty = false}) => EventsPage(
  items: empty ? [] : [sampleEvent()],
  page: 1,
  limit: 10,
  total: empty ? 0 : 1,
  hasMore: false,
);

class StubEventsRepository implements EventsRepository {
  StubEventsRepository(this.handler);

  Future<EventsPage> Function() handler;
  int calls = 0;
  int detailCalls = 0;
  Future<Event> Function(String)? detailHandler;

  @override
  Future<Event> fetchEvent(String eventId) async {
    detailCalls++;
    if (detailHandler != null) return detailHandler!(eventId);
    final page = EventsPage.fromJson(readPageJson());
    for (final event in page.items) {
      if (event.id == eventId) return event;
    }
    throw const ApiException('Etkinlik bulunamadı.', statusCode: 404);
  }

  @override
  Future<List<String>> fetchCategories() async => const [];

  @override
  Future<EventsPage> fetchEvents({
    String? query,
    String? category,
    bool? online,
    int? page,
    int? limit,
  }) {
    calls += 1;
    return handler();
  }
}
