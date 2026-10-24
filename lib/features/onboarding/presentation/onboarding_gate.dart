import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../controllers/onboarding_controller.dart';
import '../data/onboarding_repository.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.repository,
    required this.child,
  });
  final OnboardingRepository repository;
  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final OnboardingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OnboardingController(widget.repository);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, child) => switch (_controller.status) {
      OnboardingStatus.loading => const Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      OnboardingStatus.completed => widget.child,
      OnboardingStatus.active => _OnboardingScreen(controller: _controller),
    },
  );
}

class _OnboardingScreen extends StatelessWidget {
  const _OnboardingScreen({required this.controller});
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = controller.page == 0;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - AppSpacing.page * 2).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Etkinlik Keşif',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          Text(
                            first ? '01 / 02' : '02 / 02',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.large * 2),
                      Semantics(
                        header: true,
                        child: Text(
                          first
                              ? 'Bir sonraki planın burada.'
                              : 'Güzel planları unutma.',
                          style: theme.textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        first
                            ? 'İlgini çeken etkinlikleri keşfet, yeni deneyimlere yer aç.'
                            : 'Beğendiğin etkinlikleri kaydet, istediğin zaman geri dön.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.large),
                      if (controller.errorMessage != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            controller.errorMessage!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                      ],
                      FilledButton(
                        onPressed: controller.isSaving
                            ? null
                            : first
                            ? controller.next
                            : controller.complete,
                        child: controller.isSaving
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Text(first ? 'Devam et' : 'Keşfetmeye başla'),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      if (first)
                        TextButton(
                          onPressed: controller.isSaving
                              ? null
                              : controller.complete,
                          child: const Text('Şimdilik geç'),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.small),
                          child: Text(
                            'Favorilerini saklamak için daha sonra giriş yapabilirsin.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
