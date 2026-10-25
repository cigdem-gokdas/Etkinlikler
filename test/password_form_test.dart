import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/features/auth/controllers/auth_controller.dart';
import 'package:etkinlik_kesif/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_fakes.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} form validates signup and toggles password visibility',
      (tester) async {
        final repo = FakeAuthRepository();
        final c = AuthController(repository: repo);
        addTearDown(c.dispose);
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: AuthScreen(controller: c),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('otp-input')), findsNothing);
        expect(find.text('Şifremi Unuttum'), findsNothing);
        final field = find.byKey(const ValueKey('password-input'));
        expect(tester.widget<TextField>(field).obscureText, isTrue);
        await tester.tap(find.byTooltip('Şifreyi göster'));
        await tester.pump();
        expect(tester.widget<TextField>(field).obscureText, isFalse);
        await tester.tap(find.text('Giriş Yap'));
        await tester.pump();
        expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('email-input')),
          'a@example.com',
        );
        await tester.tap(find.text('Giriş Yap'));
        await tester.pump();
        expect(find.text('Şifrenizi girin.'), findsOneWidget);
        await tester.tap(find.text('Hesabın yok mu? Kayıt Ol'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).obscureText, isTrue);
        await tester.enterText(field, 'fixture password');
        await tester.enterText(
          find.byKey(const ValueKey('password-confirmation-input')),
          'mismatch',
        );
        await tester.ensureVisible(find.text('Hesap Oluştur'));
        await tester.tap(find.text('Hesap Oluştur'));
        await tester.pump();
        expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
        expect(repo.signUps + repo.signIns, 0);
        await tester.ensureVisible(
          find.text('Zaten hesabın var mı? Giriş Yap'),
        );
        await tester.tap(find.text('Zaten hesabın var mı? Giriş Yap'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        expect(
          find.byKey(const ValueKey('password-confirmation-input')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
