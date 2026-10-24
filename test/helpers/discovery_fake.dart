import 'package:etkinlik_kesif/features/events/data/events_repository.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';

import 'detail_fixture.dart';

class EventRequest {
  const EventRequest({
    this.query,
    this.category,
    this.page = 1,
    this.limit = 10,
  });
  final String? query;
  final String? category;
  final int page;
  final int limit;
}

class DiscoveryFake implements EventsRepository {
  DiscoveryFake(this.handler);
  Future<EventsPage> Function(EventRequest) handler;
  Future<List<String>> Function() categoriesHandler = () async => [
    'Workshop',
    'Seminer',
    'Yarışma',
  ];
  Future<Event> Function(String)? detailHandler;
  final requests = <EventRequest>[];
  int categoryCalls = 0;

  @override
  Future<EventsPage> fetchEvents({
    String? query,
    String? category,
    bool? online,
    int? page,
    int? limit,
  }) {
    final request = EventRequest(
      query: query,
      category: category,
      page: page ?? 1,
      limit: limit ?? 10,
    );
    requests.add(request);
    return handler(request);
  }

  @override
  Future<List<String>> fetchCategories() {
    categoryCalls++;
    return categoriesHandler();
  }

  @override
  Future<Event> fetchEvent(String eventId) async =>
      detailHandler == null ? testEvent(eventId) : detailHandler!(eventId);
}

Event testEvent(String id, {String? title}) =>
    detailEvent({'id': id, 'title': title ?? 'Etkinlik $id', 'imageUrl': null});

EventsPage testPage(
  List<String> ids, {
  int page = 1,
  int total = 30,
  bool hasMore = true,
}) => EventsPage(
  items: ids.map((id) => testEvent(id)).toList(),
  page: page,
  limit: 10,
  total: total,
  hasMore: hasMore,
);
