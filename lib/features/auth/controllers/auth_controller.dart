import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/otp_config.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../models/auth_user.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    AuthRepository? repository,
    this.configurationMessage,
    DateTime Function()? now,
    this.otpConfig = const OtpConfig(),
  }) : _repository = repository,
       _now = now ?? DateTime.now {
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
  final OtpConfig otpConfig;
  final DateTime Function() _now;
  final String? configurationMessage;
  StreamSubscription<AuthUser?>? _subscription;
  AuthUser? _user;
  String? _email;
  String? _error;
  bool _codeSent = false;
  bool _busy = false;
  bool _disposed = false;
  Timer? _ticker;
  DateTime? _nextSendAt;

  AuthUser? get user => _user;
  bool get isConfigured => _repository != null && otpConfig.problem == null;
  String? get setupMessage => otpConfig.problem ?? configurationMessage;
  int get otpLength => otpConfig.length;
  bool get isBusy => _busy;
  bool get codeSent => _codeSent;
  String? get email => _email;
  String? get errorMessage => _error;
  int get resendSeconds {
    final difference = _nextSendAt?.difference(_now()).inMilliseconds ?? 0;
    return difference <= 0 ? 0 : (difference / 1000).ceil();
  }

  static bool validEmail(String value) =>
      value.length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

  void beginSignIn() {
    if (_busy) return;
    _email = null;
    _codeSent = false;
    _error = null;
    notifyListeners();
  }

  void useDifferentEmail() {
    if (_busy) return;
    _email = null;
    _codeSent = false;
    _error = null;
    notifyListeners();
  }

  void _setUser(AuthUser? user) {
    if (_disposed) return;
    _user = user;
    notifyListeners();
  }

  Future<bool> sendCode(String value) async {
    if (_busy || _disposed) return false;
    final email = value.trim();
    if (!validEmail(email)) {
      return _validationError('Geçerli bir e-posta adresi girin.');
    }
    if (resendSeconds > 0) {
      return _validationError('Yeni kod için $resendSeconds saniye bekleyin.');
    }
    return _execute(() async {
      _startCooldown();
      await _repository!.sendCode(email);
      if (_disposed) return;
      _email = email;
      _codeSent = true;
    });
  }

  Future<bool> verifyCode(String value) async {
    if (_busy || _disposed) return false;
    if (_email == null || !_codeSent) {
      return _validationError('Önce bir giriş kodu isteyin.');
    }
    if (!otpConfig.accepts(value)) {
      return _validationError('$otpLength haneli kodu girin.');
    }
    return _execute(() async {
      final user = await _repository!.verifyCode(_email!, value);
      if (_disposed) return;
      final current = _repository.currentUser;
      if (current?.id != user.id) {
        throw const ApiException('Oturum değişti. Lütfen tekrar giriş yapın.');
      }
      _setUser(current);
    });
  }

  Future<bool> signOut() => _execute(() async {
    await _repository!.signOut();
    if (_disposed) return;
    _user = null;
    _email = null;
    _codeSent = false;
    _nextSendAt = null;
    _ticker?.cancel();
  });

  bool _validationError(String message) {
    _error = message;
    notifyListeners();
    return false;
  }

  void _startCooldown() {
    _nextSendAt = _now().add(const Duration(seconds: 60));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || resendSeconds == 0) timer.cancel();
      if (!_disposed) notifyListeners();
    });
  }

  Future<bool> _execute(Future<void> Function() operation) async {
    if (_busy || _disposed) return false;
    if (!isConfigured) {
      return _validationError(setupMessage ?? 'Supabase yapılandırması eksik.');
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
    } catch (error) {
      // SDK errors may contain credentials, so only the type is logged.
      debugPrint('Auth işlemi başarısız (${error.runtimeType}).');
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
    _ticker?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
