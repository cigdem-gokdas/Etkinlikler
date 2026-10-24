import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/event.dart';
import '../models/events_page.dart';
import '../models/event_categories.dart';

abstract interface class EventsRepository {
  Future<EventsPage> fetchEvents({
    String? query,
    String? category,
    bool? online,
    int? page,
    int? limit,
  });
  Future<List<String>> fetchCategories();
  Future<Event> fetchEvent(String eventId);
}

class HttpEventsRepository implements EventsRepository {
  HttpEventsRepository(this._api);

  final ApiClient _api;

  @override
  Future<Event> fetchEvent(String eventId) async {
    final path = Uri(pathSegments: ['', 'events', eventId]).toString();
    final json = await _api.getJson(path);
    try {
      final event = Event.fromJson(json);
      if (event.id != eventId) {
        throw const FormatException('Etkinlik ID eşleşmiyor.');
      }
      return event;
    } on FormatException {
      throw const ApiException(
        'Etkinlik detayları okunamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  @override
  Future<EventsPage> fetchEvents({
    String? query,
    String? category,
    bool? online,
    int? page,
    int? limit,
  }) async {
    if ((page != null && page < 1) ||
        (limit != null && (limit < 1 || limit > 50))) {
      throw const ApiException('Geçersiz sayfa ayarı.');
    }
    final json = await _api.getJson(
      '/events',
      queryParameters: {
        if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
        if (category?.isNotEmpty == true) 'category': category!,
        if (online != null) 'online': online.toString(),
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      },
    );
    try {
      return EventsPage.fromJson(json);
    } on FormatException {
      throw const ApiException(
        'Etkinlik verileri okunamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  @override
  Future<List<String>> fetchCategories() async {
    final json = await _api.getJson('/categories');
    try {
      return EventCategories.fromJson(json).items;
    } on FormatException {
      throw const ApiException('Kategoriler okunamadı. Lütfen tekrar deneyin.');
    }
  }
}
