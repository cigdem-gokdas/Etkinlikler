class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  const SupabaseConfig.fromEnvironment()
    : url = const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: publicDemoUrl,
      ),
      publishableKey = const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: publicDemoPublishableKey,
      );

  // Public client settings only. Authorization still requires a user session
  // and server-side RLS. Explicit (including empty) Dart defines take priority.
  static const publicDemoUrl = "https://ldxlanrtzafwbffdmnhv.supabase.co";
  static const publicDemoPublishableKey =
      "sb_publishable_Dt-ySutFmHwJEQT4SpP8VQ_W9EnpNt6";

  final String url;
  final String publishableKey;

  String? get problem {
    final missing = <String>[
      if (url.isEmpty || url.startsWith('YOUR_')) 'SUPABASE_URL',
      if (publishableKey.isEmpty || publishableKey.startsWith('YOUR_'))
        'SUPABASE_PUBLISHABLE_KEY',
    ];
    if (missing.isNotEmpty) {
      return '${missing.join(' ve ')} ayarını config/supabase.local.json dosyasına ekleyip uygulamayı --dart-define-from-file ile yeniden başlatın.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return 'SUPABASE_URL geçerli bir HTTPS proje adresi olmalı.';
    }
    if (!publishableKey.startsWith('sb_publishable_') ||
        publishableKey.trim() != publishableKey) {
      return 'SUPABASE_PUBLISHABLE_KEY için Dashboard’daki publishable anahtarını kullanın. Sunucu anahtarları bu uygulamada kullanılamaz.';
    }
    return null;
  }
}
