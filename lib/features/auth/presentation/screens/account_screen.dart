import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) => Scaffold(
      appBar: AppBar(
        title: const Text('Hesap'),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                controller.user?.email ?? 'Oturum kapalı',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.medium),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    controller.errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.page),
              FilledButton(
                onPressed: controller.isBusy
                    ? null
                    : () async {
                        final success = await controller.signOut();
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                child: controller.isBusy
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
