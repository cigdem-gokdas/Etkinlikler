import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'app/launch/launch_intro.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/theme/theme_repository.dart';
import 'core/config/supabase_config.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/favorites/data/favorites_repository.dart';
import 'features/onboarding/data/onboarding_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  runApp(_Startup(application: _application()));
}

Future<Widget> _application() async {
  const config = SupabaseConfig.fromEnvironment();
  var problem = config.problem;
  SupabaseClient? client;
  if (problem == null) {
    try {
      final supabase = await Supabase.initialize(
        url: config.url,
        publishableKey: config.publishableKey,
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUri: false,
        ),
      ).timeout(const Duration(seconds: 15));
      client = supabase.client;
    } on TimeoutException {
      problem =
          'Hesap bağlantısı zaman aşımına uğradı. Uygulamayı yeniden başlatın.';
    } catch (error) {
      debugPrint('Hesap bağlantısı başlatılamadı (${error.runtimeType}).');
      problem = 'Hesap bağlantısı başlatılamadı. Yerel yapılandırmayı kontrol edip uygulamayı yeniden başlatın.';
    }
  }
  return EtkinlikKesifApp(
    themeRepository: PreferencesThemeRepository(SharedPreferencesAsync()),
    onboardingRepository:
        kDebugMode && const bool.fromEnvironment('FORCE_ONBOARDING')
        ? PreviewOnboardingRepository()
        : PreferencesOnboardingRepository(SharedPreferencesAsync()),
    authRepository: client == null ? null : SupabaseAuthRepository(client),
    favoritesRepository: client == null
        ? null
        : SupabaseFavoritesRepository(client),
    configurationMessage: problem,
  );
}

class _Startup extends StatelessWidget {
  const _Startup({required this.application});
  final Future<Widget> application;

  @override
  Widget build(BuildContext context) => LaunchIntro(
    child: FutureBuilder<Widget>(
      future: application,
      builder: (context, snapshot) =>
          snapshot.data ??
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Color(0xFFFAFAF8),
              body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
    ),
  );
}
