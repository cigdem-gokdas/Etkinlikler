class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  const SupabaseConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

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
