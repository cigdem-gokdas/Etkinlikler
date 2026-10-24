import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../events/models/event.dart';
import '../data/favorites_repository.dart';
import '../models/favorite.dart';

enum FavoritesStatus { signedOut, loading, success, error }

class FavoritesController extends ChangeNotifier {
  FavoritesController(this._repository);
  final FavoritesRepository? _repository;
  String? _userId;
  Map<String, Favorite> _items = {};
  final Set<String> _pending = {};
  FavoritesStatus _status = FavoritesStatus.signedOut;
  String? _error;
  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;
  bool _requiresSignIn = false;
  int _generation = 0;

  FavoritesStatus get status => _status;
  String? get errorMessage => _error;
  bool get requiresSignIn => _requiresSignIn;
  bool get isLoading => _loading;
  bool get canMutate =>
      _userId != null && _loaded && !_loading && !_requiresSignIn;
  bool contains(String eventId) => _items.containsKey(eventId);
  bool isPending(String eventId) => _pending.contains(eventId);
  List<Favorite> get favorites {
    final sorted = _items.values.toList()
      ..sort((a, b) {
        final date = (b.savedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.savedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        return date != 0 ? date : a.eventId.compareTo(b.eventId);
      });
    return List.unmodifiable(sorted);
  }

  void setUser(String? userId) {
    if (_disposed || userId == _userId) return;
    _generation++;
    _userId = userId;
    _items = {};
    _pending.clear();
    _error = null;
    _requiresSignIn = false;
    _loaded = false;
    _loading = false;
    _status = userId == null
        ? FavoritesStatus.signedOut
        : FavoritesStatus.loading;
    notifyListeners();
    if (userId != null) unawaited(load());
  }

  Future<void> load() async {
    final userId = _userId;
    if (_disposed ||
        userId == null ||
        _repository == null ||
        _loading ||
        _pending.isNotEmpty) {
      return;
    }
    final generation = _generation;
    _loading = true;
    _error = null;
    _requiresSignIn = false;
    if (!_loaded) _status = FavoritesStatus.loading;
    notifyListeners();
    try {
      final result = await _repository.fetchFavorites(userId);
      if (!_current(generation)) return;
      if (result.any((favorite) => favorite.userId != userId)) {
        throw const ApiException('Favori yanıtı hesabınızla eşleşmiyor.');
      }
      _items = {for (final favorite in result) favorite.eventId: favorite};
      _loaded = true;
      _status = FavoritesStatus.success;
    } on ApiException catch (error) {
      if (_current(generation)) _recordError(error);
    } catch (error) {
      if (_current(generation)) _unexpected(error);
    } finally {
      if (_current(generation)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggle(Event event) async {
    final userId = _userId;
    if (userId == null) return;
    await _mutate(event.id, () async {
      if (contains(event.id)) {
        await _repository!.remove(userId, event.id);
        return null;
      }
      return _repository!.add(Favorite.fromEvent(userId, event));
    });
  }

  Future<void> remove(String eventId) async {
    final userId = _userId;
    if (userId == null || !contains(eventId)) return;
    await _mutate(eventId, () async {
      await _repository!.remove(userId, eventId);
      return null;
    });
  }

  Future<void> _mutate(
    String eventId,
    Future<Favorite?> Function() operation,
  ) async {
    if (_disposed ||
        !canMutate ||
        _repository == null ||
        _pending.contains(eventId)) {
      return;
    }
    final generation = _generation;
    _pending.add(eventId);
    _error = null;
    notifyListeners();
    try {
      final result = await operation();
      if (!_current(generation)) return;
      if (result == null) {
        _items.remove(eventId);
      } else {
        if (result.userId != _userId || result.eventId != eventId) {
          throw const ApiException('Favori yanıtı hesabınızla eşleşmiyor.');
        }
        _items[eventId] = result;
      }
    } on ApiException catch (error) {
      if (_current(generation)) _recordError(error);
    } catch (error) {
      if (_current(generation)) _unexpected(error);
    } finally {
      if (_current(generation)) {
        _pending.remove(eventId);
        notifyListeners();
      }
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _recordError(ApiException error) {
    _error = error.message;
    _requiresSignIn = error.statusCode == 401;
    if (!_loaded) _status = FavoritesStatus.error;
  }

  void _unexpected(Object error) {
    debugPrint('Favori işlemi başarısız (${error.runtimeType}).');
    _recordError(
      const ApiException('Favori işlemi tamamlanamadı. Lütfen tekrar deneyin.'),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
