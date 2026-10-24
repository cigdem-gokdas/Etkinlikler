import 'package:etkinlik_kesif/app/launch/launch_intro.dart';
import 'package:etkinlik_kesif/features/onboarding/data/onboarding_repository.dart';
import 'package:etkinlik_kesif/features/onboarding/presentation/onboarding_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/onboarding_fake.dart';

Widget launch({
  bool reduced = false,
  Widget child = const Text('Keşfet içerik'),
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: LaunchIntro(child: Scaffold(body: child)),
  ),
);

void main() {
  testWidgets(
    'cold start replays; rebuild and lifecycle resume do not replay',
    (tester) async {
      await tester.pumpWidget(launch());
      expect(find.byKey(const ValueKey('launch-intro')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1250));
      expect(find.byKey(const ValueKey('impact-fracture')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch-intro')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(launch(child: const Text('Favoriler içerik')));
      expect(find.byKey(const ValueKey('launch-intro')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(launch());
      expect(find.byKey(const ValueKey('launch-intro')), findsOneWidget);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('reduced motion fades in 360ms, without fracture', (
    tester,
  ) async {
    await tester.pumpWidget(launch(reduced: true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('impact-fracture')), findsNothing);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byKey(const ValueKey('launch-intro')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('early disposal cancels ticker with no callbacks after dispose', (
    tester,
  ) async {
    await tester.pumpWidget(launch());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  for (final completed in [false, true]) {
    testWidgets('intro then onboarding state $completed', (tester) async {
      final repository = MemoryOnboardingRepository()..completed = completed;
      await tester.pumpWidget(
        launch(
          child: OnboardingGate(
            repository: repository,
            child: const Text('Keşfet içerik'),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('launch-intro')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        find.text('Bir sonraki planın burada.'),
        completed ? findsNothing : findsOneWidget,
      );
      expect(repository.writes, 0);
    });
  }

  test('debug onboarding preview never persists completion', () async {
    final preview = PreviewOnboardingRepository();
    expect(await preview.isCompleted(), false);
    await preview.complete();
    expect(await PreviewOnboardingRepository().isCompleted(), false);
  });
}
