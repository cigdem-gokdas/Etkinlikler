import 'dart:async';

import 'package:etkinlik_kesif/core/config/supabase_config.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/auth/controllers/auth_controller.dart';
import 'package:etkinlik_kesif/features/auth/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_fakes.dart';

void main() {
  test('missing config identifies required settings', () {
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
  });
  test('invalid config rejects HTTP and server keys without echo', () {
    for (final c in [
      const SupabaseConfig(
        url: 'http://example.invalid',
        publishableKey: 'sb_publishable_fixture',
      ),
      const SupabaseConfig(
        url: 'https://example.invalid',
        publishableKey: 'test-only-secret',
      ),
    ]) {
      expect(c.problem, isNotNull);
      expect(c.problem!.contains(c.publishableKey), isFalse);
    }
  });
  test('unconfigured sign in fails safely', () async {
    final c = AuthController(configurationMessage: 'Bağlantı eksik.');
    addTearDown(c.dispose);
    expect(await c.signIn('a@example.com', 'fixture password'), isFalse);
    expect(c.errorMessage, 'Bağlantı eksik.');
    expect(c.user, isNull);
  });
  test('invalid email and empty password make no request', () async {
    final r = FakeAuthRepository();
    final c = AuthController(repository: r);
    addTearDown(c.dispose);
    addTearDown(r.dispose);
    for (final email in ['', 'invalid', 'a @example.com', 'a@b']) {
      expect(await c.signIn(email, 'fixture password'), isFalse);
      expect(
        await c.signUp(email, 'fixture password', 'fixture password'),
        isFalse,
      );
    }
    expect(await c.signIn('a@example.com', ''), isFalse);
    expect(r.signIns + r.signUps, 0);
  });
  test('signup enforces minimum length and matching confirmation', () async {
    final r = FakeAuthRepository();
    final c = AuthController(repository: r);
    addTearDown(c.dispose);
    addTearDown(r.dispose);
    expect(await c.signUp('a@example.com', '', ''), isFalse);
    expect(await c.signUp('a@example.com', 'short', 'short'), isFalse);
    expect(
      await c.signUp('a@example.com', 'fixture password', 'different'),
      isFalse,
    );
    expect(c.errorMessage, 'Şifreler eşleşmiyor.');
    expect(r.signUps, 0);
  });
  for (final register in [false, true]) {
    test(
      '${register ? 'signup' : 'signin'} loading blocks duplicate requests and succeeds',
      () async {
        final pending = Completer<AuthUser>();
        final r = FakeAuthRepository();
        if (register) {
          r.onSignUp = () => pending.future;
        } else {
          r.onSignIn = () => pending.future;
        }
        final c = AuthController(repository: r);
        addTearDown(c.dispose);
        addTearDown(r.dispose);
        Future<bool> submit() => register
            ? c.signUp('a@example.com', 'fixture password', 'fixture password')
            : c.signIn('a@example.com', 'fixture password');
        final result = submit();
        expect(c.isBusy, isTrue);
        expect(await submit(), isFalse);
        pending.complete(userA);
        expect(await result, isTrue);
        expect(c.user?.id, userA.id);
        expect(c.isBusy, isFalse);
        expect(r.signUps + r.signIns, 1);
      },
    );
  }
  test('wrong password and network failures preserve signed-out state and allow retry', () async {
    final r = FakeAuthRepository()
      ..onSignIn = () async =>
          throw const ApiException('E-posta veya şifre hatalı.');
    final c = AuthController(repository: r);
    addTearDown(c.dispose);
    addTearDown(r.dispose);
    expect(await c.signIn('a@example.com', 'wrong'), isFalse);
    expect(c.user, isNull);
    r.onSignIn = () async => throw const ApiException('Bağlantı kurulamadı.');
    expect(await c.signIn('a@example.com', 'fixture password'), isFalse);
    expect(c.errorMessage, 'Bağlantı kurulamadı.');
    r.onSignIn = null;
    expect(await c.signIn('a@example.com', 'fixture password'), isTrue);
  });
  test('duplicate signup is not successful login', () async {
    final r = FakeAuthRepository()
      ..onSignUp = () async =>
          throw const ApiException('Bu adresle hesap oluşturulamadı.');
    final c = AuthController(repository: r);
    addTearDown(c.dispose);
    addTearDown(r.dispose);
    expect(
      await c.signUp('a@example.com', 'fixture password', 'fixture password'),
      isFalse,
    );
    expect(c.user, isNull);
  });
  test(
    'restored user and account changes are observed; signout clears user',
    () async {
      final r = FakeAuthRepository(user: userA);
      final c = AuthController(repository: r);
      addTearDown(c.dispose);
      addTearDown(r.dispose);
      expect(c.user?.id, userA.id);
      r.emit(userB);
      expect(c.user?.id, userB.id);
      expect(await c.signOut(), isTrue);
      expect(c.user, isNull);
      expect(r.signOuts, 1);
    },
  );
  test('stream error clears stale user', () {
    final r = FakeAuthRepository(user: userA);
    final c = AuthController(repository: r);
    addTearDown(c.dispose);
    addTearDown(r.dispose);
    r.changes.addError(const ApiException('expired'));
    expect(c.user, isNull);
    expect(c.errorMessage, contains('tekrar giriş'));
  });
  test(
    'changing form clears errors without clearing existing session',
    () async {
      final r = FakeAuthRepository(user: userA);
      final c = AuthController(repository: r);
      addTearDown(c.dispose);
      addTearDown(r.dispose);
      await c.signIn('invalid', 'fixture');
      c.beginSignIn();
      expect(c.errorMessage, isNull);
      expect(c.user?.id, userA.id);
    },
  );
  test('dispose prevents notifications after pending authentication', () async {
    final pending = Completer<AuthUser>();
    final r = FakeAuthRepository()..onSignIn = () => pending.future;
    addTearDown(r.dispose);
    final c = AuthController(repository: r);
    var count = 0;
    c.addListener(() => count++);
    final result = c.signIn('a@example.com', 'fixture');
    c.dispose();
    pending.complete(userA);
    expect(await result, isFalse);
    expect(count, 1);
  });
}
