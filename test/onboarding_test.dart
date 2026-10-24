import 'dart:async';

import 'package:etkinlik_kesif/app/app.dart';
import 'package:etkinlik_kesif/features/onboarding/controllers/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/account_fakes.dart';
import 'helpers/fixtures.dart';
import 'helpers/onboarding_fake.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('ilk açılışta iki sayfa; tamamlama kaydedilir', (tester) async {
    final repository = MemoryOnboardingRepository();
    await tester.pumpWidget(
      EtkinlikKesifApp(
        onboardingRepository: repository,
        repository: StubEventsRepository(() async => samplePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bir sonraki planın burada.'), findsOneWidget);
    expect(find.text('01 / 02'), findsOneWidget);
    expect(find.text('Keşfet'), findsNothing);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.text('Güzel planları unutma.'), findsOneWidget);
    expect(find.text('02 / 02'), findsOneWidget);
    expect(repository.completed, isFalse);
    await tester.tap(find.text('Keşfetmeye başla'));
    await tester.pumpAndSettle();
    expect(repository.completed, isTrue);
    expect(repository.writes, 1);
    expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
  });

  testWidgets('geçme kaydedilir; ikinci açılışta onboarding görünmez', (
    tester,
  ) async {
    final preferences = MemoryOnboardingRepository();
    Widget app() => EtkinlikKesifApp(
      onboardingRepository: preferences,
      repository: StubEventsRepository(() async => samplePage()),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şimdilik geç'));
    await tester.pumpAndSettle();
    expect(preferences.completed, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Bir sonraki planın burada.'), findsNothing);
    expect(find.text('Sky Lab Tanışma Kahvaltısı'), findsOneWidget);
    expect(preferences.writes, 1);
  });

  testWidgets('onboarding mevcut auth oturumunu kapatmaz', (tester) async {
    final auth = FakeAuthRepository(user: userA);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      EtkinlikKesifApp(
        onboardingRepository: MemoryOnboardingRepository(),
        repository: StubEventsRepository(() async => samplePage()),
        authRepository: auth,
        favoritesRepository: FakeFavoritesRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şimdilik geç'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hesabım'), findsOneWidget);
    expect(auth.currentUser?.id, userA.id);
    expect(auth.signOuts, 0);
  });

  test('tamamlama başarısızsa tamamlandı sayılmaz; retry çalışır', () async {
    final repository = MemoryOnboardingRepository()
      ..onComplete = () async => throw StateError('storage unavailable');
    final controller = OnboardingController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.complete();
    expect(controller.status, OnboardingStatus.active);
    expect(controller.errorMessage, contains('kaydedilemedi'));
    expect(repository.completed, isFalse);
    repository.onComplete = null;
    await controller.complete();
    expect(controller.status, OnboardingStatus.completed);
  });

  test('çift tamamlama tek yazmadır; dispose sonrası bildirim yok', () async {
    final pending = Completer<void>();
    final repository = MemoryOnboardingRepository()
      ..onComplete = () => pending.future;
    final controller = OnboardingController(repository);
    await controller.load();
    var notifications = 0;
    controller.addListener(() => notifications++);
    final request = controller.complete();
    await controller.complete();
    expect(repository.writes, 1);
    controller.dispose();
    pending.complete();
    await request;
    expect(notifications, 1);
  });

  testWidgets('küçük ekran ve büyük metinde onboarding kaydırılabilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      EtkinlikKesifApp(
        onboardingRepository: MemoryOnboardingRepository(),
        repository: StubEventsRepository(() async => samplePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Şimdilik geç'));
    expect(tester.takeException(), isNull);
  });
}
