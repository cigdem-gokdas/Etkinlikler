import 'dart:async';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/auth/controllers/auth_controller.dart';
import 'package:etkinlik_kesif/features/auth/models/auth_user.dart';
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
      expect(
        find.textContaining('Hesap bağlantısı şu anda kullanılamıyor'),
        findsOneWidget,
      );
      expect(find.text('SUPABASE_PUBLISHABLE_KEY eksik.'), findsNothing);
      expect(find.textContaining('--dart-define'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Keşfet’e dön'));
      await tester.tap(find.text('Keşfet’e dön'));
      await tester.pumpAndSettle();
      expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
    },
  );

  testWidgets('signup creates session, closes auth and supports logout', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    final pending = Completer<AuthUser>();
    auth.onSignUp = () => pending.future;
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
    await tester.tap(find.text('Hesabın yok mu? Kayıt Ol'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('email-input')),
      'a@example.com',
    );
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
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(auth.signUps, 1);
    pending.complete(userA);
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsNothing);
    await tester.tap(find.byTooltip('Hesabım'));
    await tester.pumpAndSettle();
    expect(find.text('a@example.com'), findsOneWidget);
    await tester.tap(find.text('Çıkış yap'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Giriş yap'), findsOneWidget);
  });

  testWidgets('wrong password preserves email and permits retry', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..onSignIn = () async =>
          throw const ApiException('E-posta veya şifre hatalı.');
    addTearDown(auth.dispose);
    final controller = AuthController(repository: auth);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AuthScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('email-input')),
      'a@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-input')),
      'wrong',
    );
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();
    expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);
    expect(controller.user, isNull);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
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

  testWidgets(
    '320px keyboard permits signup fields and button without overflow',
    (tester) async {
      final repository = FakeAuthRepository();
      addTearDown(repository.dispose);
      final controller = AuthController(repository: repository);
      addTearDown(controller.dispose);
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
      await tester.ensureVisible(find.text('Hesabın yok mu? Kayıt Ol'));
      await tester.tap(find.text('Hesabın yok mu? Kayıt Ol'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('password-confirmation-input')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('password-confirmation-input')),
        'fixture password',
      );
      await tester.ensureVisible(find.text('Hesap Oluştur'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
