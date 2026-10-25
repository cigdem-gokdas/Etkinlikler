import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/app/theme/theme_repository.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/account_fakes.dart';
import 'helpers/discovery_fake.dart';
import 'helpers/onboarding_fake.dart';

class FixedThemeRepository implements ThemeRepository {
  FixedThemeRepository(this.mode);
  final ThemeMode mode;
  @override
  Future<ThemeMode> load() async => mode;
  @override
  Future<void> save(ThemeMode mode) async {}
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    test('${mode.name} normal ve ikincil metin kontrastı en az 4.5', () {
      final theme = mode == ThemeMode.dark ? AppTheme.dark : AppTheme.light;
      final background = theme.scaffoldBackgroundColor.computeLuminance();
      for (final color in [
        theme.colorScheme.onSurface,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.primary,
      ]) {
        final text = color.computeLuminance();
        final ratio =
            (text > background ? text + .05 : background + .05) /
            (text > background ? background + .05 : text + .05);
        expect(ratio, greaterThanOrEqualTo(4.5));
      }
    });

    testWidgets(
      '${mode.name}: onboarding/auth/signup/hesap/favoriler/detay/empty/error teması korunur',
      (tester) async {
        final repo = DiscoveryFake(
          (_) async => testPage(['a'], total: 1, hasMore: false),
        );
        final auth = FakeAuthRepository();
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          EtkinlikKesifApp(
            repository: repo,
            onboardingRepository: MemoryOnboardingRepository(),
            themeRepository: FixedThemeRepository(mode),
            authRepository: auth,
            favoritesRepository: FakeFavoritesRepository(),
          ),
        );
        await tester.pumpAndSettle();
        void expectTheme(Finder target) {
          expect(
            Theme.of(tester.element(target)).brightness,
            mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );
          expect(tester.takeException(), isNull);
        }

        expectTheme(find.text('Bir sonraki planın burada.'));
        await tester.tap(find.text('Devam et'));
        await tester.pumpAndSettle();
        expectTheme(find.text('Güzel planları unutma.'));
        await tester.tap(find.text('Keşfetmeye başla'));
        await tester.pumpAndSettle();
        expectTheme(find.text('Etkinlik a'));
        await tester.tap(find.byTooltip('Giriş yap'));
        await tester.pumpAndSettle();
        expectTheme(find.text('Hesabına giriş yap'));
        await tester.enterText(
          find.byKey(const ValueKey('email-input')),
          'a@example.com',
        );
        await tester.tap(find.text('Hesabın yok mu? Kayıt Ol'));
        await tester.pumpAndSettle();
        expectTheme(find.text('Hesap oluştur'));
        await tester.enterText(
          find.byKey(const ValueKey('password-input')),
          'fixture password',
        );
        await tester.enterText(
          find.byKey(const ValueKey('password-confirmation-input')),
          'fixture password',
        );
        await tester.ensureVisible(find.text('Hesap Oluştur'));
        await tester.tap(find.text('Hesap Oluştur'));
        await tester.pumpAndSettle();
        expect(auth.signUps, 1);
        await tester.tap(find.byTooltip('Hesabım'));
        await tester.pumpAndSettle();
        expectTheme(find.text('Çıkış yap'));
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Favoriler'));
        await tester.pumpAndSettle();
        expectTheme(find.text('Henüz kaydettiğin etkinlik yok.'));
        await tester.tap(find.text('Keşfet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Etkinlik a'));
        await tester.pumpAndSettle();
        expectTheme(find.text('Etkinlik a'));
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        repo.handler = (_) async => testPage([], total: 0, hasMore: false);
        await tester.enterText(
          find.byKey(const ValueKey('event-search')),
          'boş',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expectTheme(find.text('Bu aramayla eşleşen etkinlik bulunamadı.'));
        repo.handler = (_) async => throw const ApiException('Offline');
        await tester.enterText(
          find.byKey(const ValueKey('event-search')),
          'hata',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expectTheme(find.text('Etkinlikler yüklenemedi'));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
