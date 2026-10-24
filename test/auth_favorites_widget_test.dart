import 'dart:async';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/auth/controllers/auth_controller.dart';
import 'package:etkinlik_kesif/features/auth/presentation/screens/auth_screen.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:etkinlik_kesif/features/events/presentation/widgets/event_row.dart';
import 'package:etkinlik_kesif/features/favorites/models/favorite.dart';
import 'package:flutter/material.dart';
import 'package:etkinlik_kesif/core/widgets/skeleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/account_fakes.dart';
import 'helpers/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'config yokken Keşfet çalışır, kalp auth yapılandırma mesajını açar',
    (tester) async {
      await tester.pumpWidget(
        EtkinlikKesifApp(
          repository: StubEventsRepository(() async => samplePage()),
          configurationMessage: 'SUPABASE_PUBLISHABLE_KEY eksik.',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favorilere ekle').first);
      await tester.pumpAndSettle();
      expect(find.text('Hesabına giriş yap'), findsOneWidget);
      expect(find.text('SUPABASE_PUBLISHABLE_KEY eksik.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
    },
  );

  testWidgets(
    'kod gönderme loading ve yapıştırılabilir 6 haneli OTP ile giriş',
    (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final pending = Completer<void>();
      auth.onSend = () => pending.future;
      await tester.pumpWidget(
        EtkinlikKesifApp(
          repository: StubEventsRepository(() async => samplePage()),
          authRepository: auth,
          favoritesRepository: FakeFavoritesRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Giriş yap'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-input')),
        'invalid',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Kod gönder'));
      await tester.pump();
      expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('email-input')),
        'a@example.com',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Kod gönder'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(auth.sends, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('E-postanı kontrol et'), findsOneWidget);
      expect(find.text('Kodu tekrar gönder (60 sn)'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('otp-input')), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Doğrula'));
      await tester.pumpAndSettle();
      expect(find.text('E-postanı kontrol et'), findsNothing);
      expect(find.byTooltip('Hesabım'), findsOneWidget);
      await tester.tap(find.byTooltip('Hesabım'));
      await tester.pumpAndSettle();
      expect(find.text('a@example.com'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkış yap'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Giriş yap'), findsOneWidget);
    },
  );

  testWidgets('hatalı kod sonrası ekran ve giriş alanı korunur', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..onVerify = () async =>
          throw const ApiException('Kod hatalı veya süresi dolmuş.');
    addTearDown(auth.dispose);
    final controller = AuthController(repository: auth);
    await controller.sendCode('a@example.com');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AuthScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('otp-input')), '123456');
    await tester.tap(find.text('Doğrula'));
    await tester.pumpAndSettle();
    expect(find.text('Kod hatalı veya süresi dolmuş.'), findsOneWidget);
    expect(find.byKey(const ValueKey('otp-input')), findsOneWidget);
    expect(controller.user, isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('favoriler Keşfet/Favoriler arasında senkronize olur', (
    tester,
  ) async {
    final auth = FakeAuthRepository(user: userA);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      EtkinlikKesifApp(
        repository: StubEventsRepository(() async => samplePage()),
        authRepository: auth,
        favoritesRepository: FakeFavoritesRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorilere ekle'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Favorilerden kaldır'), findsOneWidget);
    await tester.tap(find.text('Favoriler'));
    await tester.pumpAndSettle();
    expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
    await tester.tap(find.byTooltip('Favorilerden kaldır'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz kaydettiğin etkinlik yok.'), findsOneWidget);
    await tester.tap(find.text('Keşfet'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
  });

  testWidgets('Favoriler loading/error/empty ayrımı ve retry', (tester) async {
    final auth = FakeAuthRepository(user: userA);
    addTearDown(auth.dispose);
    final pending = Completer<List<Favorite>>();
    final favorites = FakeFavoritesRepository()
      ..onFetch = (_) => pending.future;
    await tester.pumpWidget(
      EtkinlikKesifApp(
        repository: StubEventsRepository(() async => samplePage()),
        authRepository: auth,
        favoritesRepository: favorites,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Favoriler'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EventListSkeleton), findsOneWidget);
    pending.completeError(const ApiException('Veritabanına erişilemedi.'));
    await tester.pumpAndSettle();
    expect(find.text('Favoriler yüklenemedi'), findsOneWidget);
    expect(find.text('Henüz kaydettiğin etkinlik yok.'), findsNothing);
    favorites.onFetch = null;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz kaydettiğin etkinlik yok.'), findsOneWidget);
  });

  testWidgets('320px ve klavye açıkken OTP ekranı taşmaz', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    final controller = AuthController(repository: repository);
    await controller.sendCode('a@example.com');
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AuthScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('otp-input')), '12a3456');
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('otp-input')),
    );
    expect(input.controller?.text, '123456');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('API imageUrl aynı event kaydından Image.network’e aktarılır', (
    tester,
  ) async {
    final items = readPageJson()['items']! as List<Object?>;
    final json = items.first! as Map<String, Object?>;
    final event = Event.fromJson(json);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: EventRow(event: event)),
      ),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect((provider.imageProvider as NetworkImage).url, json['imageUrl']);
    expect(event.id, json['id']);
    expect(image.width, isNull);
    expect(tester.takeException(), isNull);
  });
}
