import 'package:flutter/foundation.dart';

import '../data/onboarding_repository.dart';

enum OnboardingStatus { loading, active, completed }

class OnboardingController extends ChangeNotifier {
  OnboardingController(this._repository);
  final OnboardingRepository _repository;
  OnboardingStatus _status = OnboardingStatus.loading;
  int _page = 0;
  bool _saving = false;
  bool _disposed = false;
  String? _error;

  OnboardingStatus get status => _status;
  int get page => _page;
  bool get isSaving => _saving;
  String? get errorMessage => _error;

  Future<void> load() async {
    try {
      final completed = await _repository.isCompleted().timeout(
        const Duration(seconds: 5),
      );
      if (_disposed) return;
      _status = completed
          ? OnboardingStatus.completed
          : OnboardingStatus.active;
    } catch (error) {
      if (_disposed) return;
      debugPrint('Başlangıç tercihi okunamadı (${error.runtimeType}).');
      _status = OnboardingStatus.active;
      _error =
          'İlk açılış tercihi okunamadı. Devam ederken tekrar kaydedilecek.';
    }
    if (!_disposed) notifyListeners();
  }

  void next() {
    if (_disposed || _saving || _status != OnboardingStatus.active) return;
    _page = 1;
    notifyListeners();
  }

  Future<void> complete() async {
    if (_disposed || _saving || _status != OnboardingStatus.active) return;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.complete().timeout(const Duration(seconds: 5));
      if (!_disposed) _status = OnboardingStatus.completed;
    } catch (error) {
      if (_disposed) return;
      debugPrint('Başlangıç tercihi kaydedilemedi (${error.runtimeType}).');
      _error = 'Tercih kaydedilemedi. Lütfen tekrar deneyin.';
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
