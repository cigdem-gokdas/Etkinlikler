import '../../events/models/event.dart';

class Favorite {
  const Favorite({
    required this.userId,
    required this.eventId,
    required this.title,
    this.imageUrl,
    this.startsAt,
    this.location,
    this.category,
    this.savedAt,
  });

  final String userId;
  final String eventId;
  final String title;
  final String? imageUrl;
  final DateTime? startsAt;
  final String? location;
  final String? category;
  final DateTime? savedAt;

  factory Favorite.fromEvent(String userId, Event event) => Favorite(
    userId: userId,
    eventId: event.id,
    title: event.title,
    imageUrl: event.imageUrl,
    startsAt: event.startDate,
    location: event.location,
    category: event.category,
  );

  factory Favorite.fromJson(Map<String, Object?> json) {
    if (json case {
      'user_id': final String userId,
      'event_id': final String eventId,
      'title': final String title,
    }) {
      return Favorite(
        userId: userId,
        eventId: eventId,
        title: title,
        imageUrl: _text(json['image_url']),
        location: _text(json['location']),
        category: _text(json['category']),
        startsAt: _date(json['starts_at']),
        savedAt: _date(json['saved_at']),
      );
    }
    throw const FormatException('Favori alanları beklenen biçimde değil.');
  }

  Map<String, Object?> toInsertJson() => {
    'user_id': userId,
    'event_id': eventId,
    'title': title,
    'image_url': imageUrl,
    'starts_at': startsAt?.toUtc().toIso8601String(),
    'location': location,
    'category': category,
  };

  static String? _text(Object? value) => switch (value) {
    null => null,
    String text => text,
    _ => throw const FormatException('Metin veya null bekleniyordu.'),
  };
  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(_text(value)!);
}
