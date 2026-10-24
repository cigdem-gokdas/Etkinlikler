import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/core/config/otp_config.dart';
import 'package:etkinlik_kesif/features/auth/controllers/auth_controller.dart';
import 'package:etkinlik_kesif/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_fakes.dart';

void main() {
  for (final length in [6, 8]) {
    test('$length haneli kod ve baştaki sıfırlar aynen iletilir', () async {
      final repository = FakeAuthRepository();
      final controller = AuthController(
        repository: repository,
        otpConfig: OtpConfig(length: length),
      );
      addTearDown(controller.dispose);
      addTearDown(repository.dispose);
      final code = length == 6 ? '001234' : '00123456';
      await controller.sendCode('a@example.com');
      expect(await controller.verifyCode(code), isTrue);
      expect(repository.lastVerifiedCode, code);
    });
  }

  test(
    'varsayılan altı hane, sekiz haneli kod kırpılmadan reddedilir',
    () async {
      final repository = FakeAuthRepository();
      final controller = AuthController(
        repository: repository,
        otpConfig: const OtpConfig(length: 6),
      );
      addTearDown(controller.dispose);
      addTearDown(repository.dispose);
      expect(const OtpConfig().length, 6);
      await controller.sendCode('a@example.com');
      expect(await controller.verifyCode('00123456'), isFalse);
      expect(controller.errorMessage, '6 haneli kodu girin.');
      expect(repository.verifications, 0);
    },
  );

  test('kod trim edilmez veya integera çevrilmez', () async {
    final repository = FakeAuthRepository();
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await controller.sendCode('a@example.com');
    expect(await controller.verifyCode(' 001234 '), isFalse);
    expect(repository.verifications, 0);
  });

  for (final length in [6, 8]) {
    testWidgets(
      '$length haneli input, metin ve fazla yapıştırma davranışı tutarlı',
      (tester) async {
        final repository = FakeAuthRepository();
        addTearDown(repository.dispose);
        final controller = AuthController(
          repository: repository,
          otpConfig: OtpConfig(length: length),
        );
        await controller.sendCode('a@example.com');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: AuthScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('$length haneli kod'), findsOneWidget);
        expect(
          find.text('Kod gelmediyse spam klasörünü de kontrol et.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('otp-input')),
          '00123456',
        );
        final input = tester.widget<TextField>(
          find.byKey(const ValueKey('otp-input')),
        );
        expect(input.controller?.text, '00123456');
        expect(input.maxLength, length);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
