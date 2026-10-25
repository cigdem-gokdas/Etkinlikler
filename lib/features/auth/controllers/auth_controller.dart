import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../models/auth_user.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthRepository? repository, this.configurationMessage})
    : _repository = repository {
    _user = repository?.currentUser;
    _subscription = repository?.userChanges.listen(
      _setUser,
      onError: (Object error) {
        if (_disposed) return;
        _user = null;
        _error = 'Oturum doğrulanamadı. Lütfen tekrar giriş yapın.';
        notifyListeners();
      },
    );
  }

  final AuthRepository? _repository;
  final String? configurationMessage;
  StreamSubscription<AuthUser?>? _subscription;
  AuthUser? _user;
  String? _error;
  bool _busy = false;
  bool _disposed = false;

  AuthUser? get user => _user;
  bool get isConfigured => _repository != null;
  String? get setupMessage => configurationMessage;
  bool get isBusy => _busy;
  String? get errorMessage => _error;

  static bool validEmail(String value) =>
      value.length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

  void beginSignIn() {
    if (_busy || _disposed) return;
    _error = null;
    notifyListeners();
  }

  void _setUser(AuthUser? user) {
    if (_disposed) return;
    _user = user;
    notifyListeners();
  }

  Future<bool> signIn(String value, String password) {
    if (_busy || _disposed) return Future.value(false);
    final email = value.trim();
    if (!validEmail(email)) {
      return Future.value(
        _validationError('Geçerli bir e-posta adresi girin.'),
      );
    }
    if (password.trim().isEmpty) {
      return Future.value(_validationError('Şifrenizi girin.'));
    }
    // Existing passwords may predate the current signup policy. Never trim or
    // impose new-account rules on a password used to sign in.
    return _authenticate(() => _repository!.signIn(email, password));
  }

  Future<bool> signUp(String value, String password, String confirmation) {
    if (_busy || _disposed) return Future.value(false);
    final email = value.trim();
    if (!validEmail(email)) {
      return Future.value(
        _validationError('Geçerli bir e-posta adresi girin.'),
      );
    }
    if (password.trim().isEmpty || password.length < 8) {
      return Future.value(
        _validationError('Yeni şifre en az 8 karakter olmalı.'),
      );
    }
    if (password != confirmation) {
      return Future.value(_validationError('Şifreler eşleşmiyor.'));
    }
    // The server remains authoritative for stronger project password rules.
    return _authenticate(() => _repository!.signUp(email, password));
  }

  Future<bool> _authenticate(Future<AuthUser> Function() operation) =>
      _execute(() async {
        final user = await operation();
        if (_disposed) return;
        final current = _repository!.currentUser;
        if (current?.id != user.id) {
          throw const ApiException(
            'Oturum oluşturulamadı. Lütfen tekrar giriş yapın.',
          );
        }
        _setUser(current);
      });

  Future<bool> signOut() => _execute(() async {
    await _repository!.signOut();
    if (!_disposed) _user = null;
  });

  bool _validationError(String message) {
    if (_disposed) return false;
    _error = message;
    notifyListeners();
    return false;
  }

  Future<bool> _execute(Future<void> Function() operation) async {
    if (_busy || _disposed) return false;
    if (!isConfigured) {
      return _validationError(
        setupMessage ?? 'Hesap bağlantısı kullanılamıyor.',
      );
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
      return !_disposed;
    } on ApiException catch (error) {
      if (!_disposed) _error = error.message;
      return false;
    } catch (_) {
      // Never log SDK exceptions: they can include credentials.
      if (!_disposed) _error = 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
