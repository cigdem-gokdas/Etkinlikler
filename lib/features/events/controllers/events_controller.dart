import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import '../models/events_page.dart';

enum EventsStatus { loading, success, empty, error }

enum EventsActivity { idle, initial, debouncing, refreshing, more }

enum CategoriesStatus { loading, success, error }

class EventsController extends ChangeNotifier {
  EventsController(this._repository);

  static const searchDebounce = Duration(milliseconds: 350);
  static const pageSize = 10;
  final EventsRepository _repository;
  EventsStatus _status = EventsStatus.loading;
  EventsActivity _activity = EventsActivity.idle;
  CategoriesStatus _categoriesStatus = CategoriesStatus.loading;
  List<Event> _events = const [];
  List<String> _categories = const [];
  String? _errorMessage;
  String? _paginationError;
  String? _categoriesError;
  String _query = '';
  String? _category;
  int _page = 0;
  int _total = 0;
  int _generation = 0;
  int _filterRevision = 0;
  bool _hasMore = false;
  bool _categoriesBusy = false;
  bool _disposed = false;
  Timer? _debounce;

  EventsStatus get status => _status;
  EventsActivity get activity => _activity;
  List<Event> get events => _events;
  String get query => _query;
  String? get selectedCategory => _category;
  int get currentPage => _page;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get isRefreshing => _activity == EventsActivity.refreshing;
  bool get isLoadingMore => _activity == EventsActivity.more;
  String? get errorMessage => _errorMessage;
  String? get paginationError => _paginationError;
  List<String> get categories => _categories;
  CategoriesStatus get categoriesStatus => _categoriesStatus;
  String? get categoriesError => _categoriesError;
  // Filters reset scroll; refresh resets only the viewport-fill budget.
  int get filterRevision => _filterRevision;
  int get paginationCycle => _generation;

  Future<void> loadCategories() async {
    if (_disposed || _categoriesBusy) return;
    _categoriesBusy = true;
    _categoriesStatus = CategoriesStatus.loading;
    _categoriesError = null;
    notifyListeners();
    try {
      final result = await _repository.fetchCategories();
      if (_disposed) return;
      _categories = List.unmodifiable(result);
      _categoriesStatus = CategoriesStatus.success;
    } catch (error) {
      if (_disposed) return;
      _categoriesStatus = CategoriesStatus.error;
      _categoriesError = 'Kategoriler yüklenemedi.';
    } finally {
      _categoriesBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void setSearchQuery(String value) {
    final query = value.trim();
    if (_disposed || query == _query) return;
    _query = query;
    _resetFilters();
    final generation = _generation;
    _activity = EventsActivity.debouncing;
    notifyListeners();
    _debounce = Timer(searchDebounce, () {
      _debounce = null;
      unawaited(_fetchFirst(generation));
    });
  }

  void clearSearch() => setSearchQuery('');

  Future<void> selectCategory(String? category) async {
    final selected = category == null || category.isEmpty ? null : category;
    if (_disposed || selected == _category) return;
    _category = selected;
    _resetFilters();
    await _fetchFirst(_generation);
  }

  void _resetFilters() {
    _debounce?.cancel();
    _generation++;
    _filterRevision++;
    _events = const [];
    _page = 0;
    _total = 0;
    _hasMore = false;
    _errorMessage = null;
    _paginationError = null;
    _status = EventsStatus.loading;
  }

  /// Refresh/retry starts at page 1, preserving visible items until success.
  Future<void> load() async {
    if (_disposed ||
        _activity == EventsActivity.initial ||
        _activity == EventsActivity.refreshing) {
      return;
    }
    _debounce?.cancel();
    _debounce = null;
    await _fetchFirst(++_generation);
  }

  Future<void> _fetchFirst(int generation) async {
    if (!_isCurrent(generation)) return;
    _activity = _page == 0 ? EventsActivity.initial : EventsActivity.refreshing;
    if (_page == 0) _status = EventsStatus.loading;
    _errorMessage = null;
    _paginationError = null;
    notifyListeners();
    try {
      final result = await _repository.fetchEvents(
        query: _query,
        category: _category,
        page: 1,
        limit: pageSize,
      );
      if (!_isCurrent(generation)) return;
      _validatePage(result, 1);
      _events = _unique(result.items);
      _page = result.page;
      _total = result.total;
      _hasMore = _canContinue(result, madeProgress: _events.isNotEmpty);
      _status = _events.isEmpty ? EventsStatus.empty : EventsStatus.success;
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _errorMessage = _message(error);
      if (_page == 0) _status = EventsStatus.error;
    } finally {
      if (_isCurrent(generation)) {
        _activity = EventsActivity.idle;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore({bool retry = false}) async {
    if (_disposed ||
        _activity != EventsActivity.idle ||
        _status != EventsStatus.success ||
        !_hasMore ||
        (_paginationError != null && !retry)) {
      return;
    }
    final generation = _generation;
    final nextPage = _page + 1;
    _activity = EventsActivity.more;
    _paginationError = null;
    notifyListeners();
    try {
      final result = await _repository.fetchEvents(
        query: _query,
        category: _category,
        page: nextPage,
        limit: pageSize,
      );
      if (!_isCurrent(generation)) return;
      _validatePage(result, nextPage);
      final combined = _unique([..._events, ...result.items]);
      final madeProgress = combined.length > _events.length;
      _events = combined;
      _page = result.page;
      _total = result.total;
      _hasMore = _canContinue(result, madeProgress: madeProgress);
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _paginationError = _message(error);
    } finally {
      if (_isCurrent(generation)) {
        _activity = EventsActivity.idle;
        notifyListeners();
      }
    }
  }

  bool _canContinue(EventsPage result, {required bool madeProgress}) =>
      result.hasMore && _events.length < _total && madeProgress;

  void _validatePage(EventsPage result, int expectedPage) {
    if (result.page != expectedPage || result.total < 0) {
      throw const ApiException(
        'Sayfa yanıtı okunamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  List<Event> _unique(List<Event> items) {
    final byId = <String, Event>{};
    for (final event in items) {
      byId.putIfAbsent(event.id, () => event);
    }
    return List.unmodifiable(byId.values);
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
