import 'event.dart';

class EventsPage {
  EventsPage({
    required List<Event> items,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  }) : items = List.unmodifiable(items);

  final List<Event> items;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  factory EventsPage.fromJson(Map<String, Object?> json) {
    if (json case {
      'items': final List<Object?> items,
      'page': final int page,
      'limit': final int limit,
      'total': final int total,
      'hasMore': final bool hasMore,
    }) {
      if (page < 1 || limit < 1 || limit > 50 || total < 0) {
        throw const FormatException('Geçersiz sayfalama bilgisi.');
      }
      return EventsPage(
        items: items.map((item) {
          if (item is Map<String, Object?>) return Event.fromJson(item);
          throw const FormatException('Etkinlik nesnesi bekleniyordu.');
        }).toList(),
        page: page,
        limit: limit,
        total: total,
        hasMore: hasMore,
      );
    }
    throw const FormatException('Liste yanıtı beklenen biçimde değil.');
  }
}
