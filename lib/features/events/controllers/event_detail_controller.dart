import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/events_repository.dart';
import '../models/event.dart';

enum EventDetailStatus { loading, success, notFound, error }

class EventDetailController extends ChangeNotifier {
  EventDetailController(
    this._repository, {
    required this.eventId,
    Event? initialEvent,
  }) : _event = initialEvent?.id == eventId ? initialEvent : null;

  final EventsRepository _repository;
  final String eventId;
  Event? _event;
  EventDetailStatus _status = EventDetailStatus.loading;
  String? _error;
  bool _busy = false;
  bool _disposed = false;

  Event? get event => _event;
  EventDetailStatus get status => _status;
  String? get errorMessage => _error;

  Future<void> load() async {
    if (_busy || _disposed) return;
    _busy = true;
    _status = EventDetailStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.fetchEvent(eventId);
      if (_disposed) return;
      if (result.id != eventId) {
        throw const ApiException('Etkinlik yanıtı istenen kayıtla eşleşmiyor.');
      }
      _event = result;
      _status = EventDetailStatus.success;
    } on ApiException catch (error) {
      if (_disposed) return;
      _error = error.message;
      _status = error.statusCode == 404
          ? EventDetailStatus.notFound
          : EventDetailStatus.error;
      if (_status == EventDetailStatus.notFound) _event = null;
    } catch (error) {
      if (_disposed) return;
      debugPrint('Etkinlik detayı alınamadı (${error.runtimeType}).');
      _error = 'Etkinlik yüklenemedi. Lütfen tekrar deneyin.';
      _status = EventDetailStatus.error;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
