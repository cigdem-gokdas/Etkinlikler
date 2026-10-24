import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/network/api_exception.dart';
import '../models/auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> get userChanges;
  Future<void> sendCode(String email);
  Future<AuthUser> verifyCode(String email, String code);
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  AuthUser? _user(Session? session) {
    if (session == null || session.isExpired) return null;
    return AuthUser(id: session.user.id, email: session.user.email ?? '');
  }

  @override
  AuthUser? get currentUser => _user(_client.auth.currentSession);

  @override
  Stream<AuthUser?> get userChanges =>
      _client.auth.onAuthStateChange.map((state) => _user(state.session));

  @override
  Future<void> sendCode(String email) => _perform(
    () => _client.auth.signInWithOtp(email: email, shouldCreateUser: true),
  );

  @override
  Future<AuthUser> verifyCode(String email, String code) => _perform(() async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.email,
    );
    final user = _user(response.session);
    if (user == null || _client.auth.currentSession?.user.id != user.id) {
      throw const ApiException(
        'Oturum oluşturulamadı. Lütfen yeni bir kod isteyin.',
      );
    }
    return user;
  });

  @override
  Future<void> signOut() => _perform(() => _client.auth.signOut());

  Future<T> _perform<T>(Future<T> Function() operation) async {
    try {
      return await operation().timeout(const Duration(seconds: 20));
    } on AuthException catch (error) {
      throw ApiException(authErrorMessage(error));
    } on http.ClientException {
      throw const ApiException(
        'Bağlantı kurulamadı. İnternet bağlantınızı kontrol edin.',
      );
    } on TimeoutException {
      throw const ApiException(
        'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.',
      );
    }
  }
}

String authErrorMessage(AuthException error) {
  if (error.statusCode == '429' ||
      const {
        'over_email_send_rate_limit',
        'over_request_rate_limit',
      }.contains(error.code)) {
    return 'Çok fazla istek gönderildi. Bir süre bekleyip tekrar deneyin.';
  }
  if (error.code == 'otp_expired') {
    return 'Kod hatalı veya süresi dolmuş. Kodu kontrol edin ya da yeni bir kod isteyin.';
  }
  if (const {
    'email_address_invalid',
    'validation_failed',
  }.contains(error.code)) {
    return 'Geçerli bir e-posta adresi girin.';
  }
  if (error.code == 'email_address_not_authorized') {
    return 'E-posta sağlayıcısı bu adrese gönderime izin vermiyor. SMTP gönderici alan adını kontrol edin.';
  }
  if (const {
    'session_not_found',
    'session_expired',
    'refresh_token_not_found',
    'refresh_token_already_used',
  }.contains(error.code)) {
    return 'Oturumunuz geçersizleşti. Lütfen tekrar giriş yapın.';
  }
  if (error is AuthRetryableFetchException && error.statusCode == null) {
    return 'Bağlantı kurulamadı. İnternet bağlantınızı kontrol edin.';
  }
  if (error.code == 'unexpected_failure' ||
      (int.tryParse(error.statusCode ?? '') ?? 0) >= 500) {
    return 'Giriş hizmeti veya e-posta gönderimi şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
  }
  return 'İşlem tamamlanamadı. E-posta adresinizi ve kodunuzu kontrol edip tekrar deneyin.';
}
