class EventCategories {
  EventCategories._(this.items);
  final List<String> items;

  factory EventCategories.fromJson(Map<String, Object?> json) {
    final items = json['items'];
    if (items is! List<Object?> ||
        items.any((value) => value is! String || value.trim().isEmpty)) {
      throw const FormatException('Kategori listesi beklenen biçimde değil.');
    }
    return EventCategories._(List.unmodifiable(items.cast<String>().toSet()));
  }
}
