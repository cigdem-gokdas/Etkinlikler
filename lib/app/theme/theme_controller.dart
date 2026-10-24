import 'package:flutter/material.dart';

import 'theme_repository.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._repository);
  final ThemeRepository? _repository;
  ThemeMode _mode = ThemeMode.system;
  int _revision = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final revision = _revision;
    try {
      final restored = await _repository?.load().timeout(
        const Duration(seconds: 3),
      );
      if (!_disposed && revision == _revision && restored != null) {
        _mode = restored;
        notifyListeners();
      }
    } catch (_) {
      // Missing/unreadable preferences retain the platform system theme.
    }
  }

  Future<bool> setMode(ThemeMode mode) async {
    if (_disposed) return false;
    _revision++;
    _mode = mode;
    notifyListeners();
    var saved = true;
    _writes = _writes.then((_) async {
      try {
        await _repository?.save(mode);
      } catch (_) {
        saved = false;
      }
    });
    await _writes;
    return saved;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
