import 'dart:async';

import 'package:etkinlik_kesif/core/config/supabase_config.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/auth/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_fakes.dart';

void main() {
  test('eksik config hangi ayarın eksik olduğunu bildirir', () {
    expect(
      const SupabaseConfig(url: '', publishableKey: '').problem,
      contains('SUPABASE_URL ve SUPABASE_PUBLISHABLE_KEY'),
    );
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: '',
      ).problem,
      contains('SUPABASE_PUBLISHABLE_KEY'),
    );
    expect(
      const SupabaseConfig(
        url: 'YOUR_SUPABASE_PROJECT_URL',
        publishableKey: 'YOUR_SUPABASE_PUBLISHABLE_KEY',
      ).problem,
      isNotNull,
    );
  });

  test(
    'config HTTPS ve publishable anahtar gerektirir; değerleri raporlamaz',
    () {
      const invalid = SupabaseConfig(
        url: 'http://example.supabase.co',
        publishableKey: 'test-only-secret',
      );
      expect(invalid.problem, contains('HTTPS'));
      expect(invalid.problem, isNot(contains('test-only-secret')));
      expect(
        const SupabaseConfig(
          url: 'https://example.supabase.co',
          publishableKey: 'test-only-secret',
        ).problem,
        contains('publishable'),
      );
      expect(
        const SupabaseConfig(
          url: 'https://example.supabase.co',
          publishableKey: 'sb_publishable_test_only',
        ).problem,
        isNull,
      );
    },
  );

  test('config eksikken auth kontrollü hata verir', () async {
    final controller = AuthController(
      configurationMessage: 'SUPABASE_URL eksik.',
    );
    addTearDown(controller.dispose);
    expect(await controller.sendCode('a@example.com'), isFalse);
    expect(controller.errorMessage, 'SUPABASE_URL eksik.');
    expect(controller.user, isNull);
  });

  test('boş/geçersiz e-posta ağ çağrısı yapmaz', () async {
    final repository = FakeAuthRepository();
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    for (final value in ['', 'invalid', 'a @example.com', 'a@b']) {
      expect(await controller.sendCode(value), isFalse);
    }
    expect(repository.sends, 0);
  });

  test('gönderme loading, eşzamanlı koruma ve 60 saniye cooldown', () async {
    final repository = FakeAuthRepository();
    final pending = Completer<void>();
    repository.onSend = () => pending.future;
    var now = DateTime(2026, 10, 24);
    final controller = AuthController(repository: repository, now: () => now);
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    final request = controller.sendCode('a@example.com');
    expect(controller.isBusy, isTrue);
    expect(await controller.sendCode('a@example.com'), isFalse);
    pending.complete();
    expect(await request, isTrue);
    expect(controller.codeSent, isTrue);
    expect(controller.user, isNull);
    expect(controller.resendSeconds, 60);
    now = now.add(const Duration(seconds: 30));
    expect(controller.resendSeconds, 30);
    expect(await controller.sendCode('a@example.com'), isFalse);
    expect(repository.sends, 1);
    now = now.add(const Duration(seconds: 30));
    expect(await controller.sendCode('a@example.com'), isTrue);
    expect(repository.sends, 2);
  });

  test('SMTP hatası kod gönderildi veya giriş başarılı sayılmaz', () async {
    final repository = FakeAuthRepository()
      ..onSend = () async => throw const ApiException('E-posta gönderilemedi.');
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    expect(await controller.sendCode('a@example.com'), isFalse);
    expect(controller.codeSent, isFalse);
    expect(controller.user, isNull);
    expect(controller.errorMessage, 'E-posta gönderilemedi.');
    expect(controller.resendSeconds, 60);
  });

  test('hatalı OTP düzeltilip yeniden doğrulanabilir', () async {
    final repository = FakeAuthRepository()
      ..onVerify = () async =>
          throw const ApiException('Kod hatalı veya süresi dolmuş.');
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await controller.sendCode('a@example.com');
    expect(await controller.verifyCode('12'), isFalse);
    expect(repository.verifications, 0);
    expect(await controller.verifyCode('123456'), isFalse);
    expect(controller.user, isNull);
    repository.onVerify = null;
    expect(await controller.verifyCode('654321'), isTrue);
    expect(controller.user?.id, userA.id);
  });

  test('restore edilen kullanıcı, auth değişimi ve çıkış dinlenir', () async {
    final repository = FakeAuthRepository(user: userA);
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    expect(controller.user?.id, userA.id);
    repository.emit(userB);
    expect(controller.user?.id, userB.id);
    expect(await controller.signOut(), isTrue);
    expect(repository.signOuts, 1);
    expect(controller.user, isNull);
  });

  test('oturum stream hatası eski kullanıcıyı temizler', () {
    final repository = FakeAuthRepository(user: userA);
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    repository.changes.addError(const ApiException('expired'));
    expect(controller.user, isNull);
    expect(controller.errorMessage, contains('tekrar giriş'));
  });

  test(
    'farklı e-posta ve route yeniden açılışı cooldown süresini sıfırlamaz',
    () async {
      final repository = FakeAuthRepository();
      final controller = AuthController(repository: repository);
      addTearDown(controller.dispose);
      addTearDown(repository.dispose);
      await controller.sendCode('a@example.com');
      controller.useDifferentEmail();
      controller.beginSignIn();
      expect(controller.codeSent, isFalse);
      expect(controller.resendSeconds, 60);
      expect(await controller.sendCode('b@example.com'), isFalse);
      expect(repository.sends, 1);
    },
  );

  test('dispose sonrası auth isteği bildirim yapmaz', () async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    final pending = Completer<void>();
    repository.onSend = () => pending.future;
    final controller = AuthController(repository: repository);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final request = controller.sendCode('a@example.com');
    controller.dispose();
    pending.complete();
    expect(await request, isFalse);
    expect(notifications, 1);
  });
}
