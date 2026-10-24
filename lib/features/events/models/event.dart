class Event {
  Event({
    required this.id,
    required this.title,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.organizer,
    required this.imageUrl,
    required this.capacity,
    required this.registeredCount,
    required this.isOnline,
    required List<String> tags,
    this.description,
  }) : tags = List.unmodifiable(tags);

  final String id;
  final String title;
  final String category;
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final String organizer;
  final String? imageUrl;
  final int capacity;
  final int registeredCount;
  final bool isOnline;
  final List<String> tags;
  final String? description;

  factory Event.fromJson(Map<String, Object?> json) {
    if (json case {
      'id': final String id,
      'title': final String title,
      'category': final String category,
      'startDate': final String startDate,
      'endDate': final String endDate,
      'capacity': final int capacity,
      'registeredCount': final int registeredCount,
      'isOnline': final bool isOnline,
      'tags': final List<Object?> tags,
    }) {
      return Event(
        id: id,
        title: title,
        category: category,
        startDate: DateTime.parse(startDate),
        endDate: DateTime.parse(endDate),
        location: _nullableString(json['location']),
        organizer: _nullableString(json['organizer']) ?? '',
        imageUrl: _nullableString(json['imageUrl']),
        description: _nullableString(json['description']),
        capacity: capacity,
        registeredCount: registeredCount,
        isOnline: isOnline,
        tags: tags.map((tag) {
          if (tag is String) return tag;
          throw const FormatException('Etiket metin olmalı.');
        }).toList(),
      );
    }
    throw const FormatException('Etkinlik alanları beklenen biçimde değil.');
  }

  static String? _nullableString(Object? value) => switch (value) {
    null => null,
    String value => value.trim().isEmpty ? null : value,
    _ => throw const FormatException('Metin veya null bekleniyordu.'),
  };
}
