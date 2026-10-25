# Public demo yapılandırması — 25 Ekim 2026

**Sonuç:** Yerel config gerektirmeyen public istemci başlangıcı hazır. Mevcut 223 test korundu; 7 yeni testle **230/230 Flutter testi**, ayrıca **7/7 Python araç testi** başarılı. SMTP teslimi ve iki hesaplı canlı RLS ayrı manuel kabul olarak açıktır. Commit/push yapılmadı; public GitHub main hâlâ `0277ae4` sürümündedir.

## 1. Bu istekte değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/core/config/supabase_config.dart` | Public demo URL/publishable key varsayılanları ve alan bazlı Dart define önceliği |
| `tool/run.sh` | Flutter’ın config seçimini aynen kullanır; yerel JSON’u otomatik seçmez |
| `tool/build_web.py` | Varsayılanları merkezi Dart config’e bırakır; yalnızca açık dosya/dolu ortam override’larını iletir |
| `README.md` | İlk kurulum `flutter pub get` + `flutter run`; public istemci/override/SMTP/RLS açıklaması |
| `docs/teslim.md` | Demo için GitHub URL/key variable’larının zorunlu olmaması; güncel araç davranışı |
| `test/public_demo_config_test.dart` | 7 yeni config/anon erişim/başlangıç UI testi |
| `tool/test_public_demo_tools.py` | 7 internetsiz yardımcı araç testi |
| `docs/reports/public-demo/rapor.md` | Bu kayıt |

`lib/main.dart`, auth/favorites production repository ve controller’ları, tasarım dosyaları, `pubspec.yaml`, örnek/yerel JSON, `.gitignore`, Supabase tablo/policy ve mevcut kullanıcı verileri bu istekte değiştirilmedi. Git status’ta görünen önceki UI/audit/Pages değişiklikleri korundu; bunlar bu istekte yapılmış gibi listelenmedi.

## 2. Public config mimarisi

Tek kaynak **SupabaseConfig** sınıfıdır. Yerel dosyada geçerli HTTPS Project URL ve `sb_publishable_` istemci anahtarı bulundu; yalnızca bu iki alan varsayılan Dart kaynaklarına aktarıldı. Gerçek değerler bu rapora/loglara yazılmadı.

`SupabaseConfig.fromEnvironment()` her alan için `String.fromEnvironment(..., defaultValue: ...)` kullanır:

1. Açık `--dart-define` veya `--dart-define-from-file` değeri.
2. Alan hiç tanımlanmamışsa public demo varsayılanı.

Açık boş/geçersiz değer demo ile sessizce değiştirilmez; mevcut problem doğrulamasına gider. `SUPABASE_URL` ve `SUPABASE_PUBLISHABLE_KEY` isimleri korundu. Farklı proje için URL/key birlikte verilmelidir. OTP varsayılanı mevcut merkezi `OtpConfig` içinde 6; mevcut 6/8 override desteği korundu.

Dart config’de URL/key’nin ikinci kopyası Python/bash içine eklenmedi. `run.sh` bütün Flutter argümanlarını aynen geçirir. `build_web.py` argümansızken hiçbir ignored dosya okumaz; varsayılanları Dart’a bırakır. Açık `--config` dosyasındaki alanlar ve dolu CI ortam değerleri derlemeye geçer; dolu ortam alanları açık dosyanın aynı alanına üstün gelir. Opsiyonel boş GitHub Variables, override verilmemiş sayılır. Açık JSON’daki boş alan ise geçersizdir. Geçici override dosyası temizlenir.

Favoriler, paylaşılan demo Supabase projesinde her oturumun kendi `user_id` alanıyla saklanır. Kullanıcının ayrıca kendi Supabase projesini açması gerekmez. Public anahtar ortak kullanıcı hesabı veya ortak kullanıcı session’ı değildir.

## 3. Gizli anahtar güvenliği

- Kaynaklara aktarılan alanlar yalnızca public URL ve publishable key’dir; service-role/secret/Resend/SMTP/Google uygulama şifresi veya kullanıcı token’ı aktarılmadı.
- Yerel JSON’un SHA-256 karşılaştırması **aynı**; dosya ignored ve untracked kaldı. Değerler terminal/rapor/debug çıktısına yazılmadı.
- Tracked ve ignore edilmeyen yeni metin dosyalarında credential kalıpları tarandı; gerçek secret/private key/JWT/Resend-key kalıbı bulgusu yok. Testlerde yalnızca açıkça sentetik fixture değerleri kullanılır. Kalıp taraması tek başına bütün olası sırları matematiksel olarak dışlamaz; yeni kaynak aktarımı ayrıca alan bazında incelendi.
- Auth/RLS kapatılmadı. Gerçek SDK repository testi, session yokken favori SELECT/INSERT/DELETE için **401** üretip sıfır HTTP isteği attığını doğrular.
- Canlı, tek salt-okunur anonim favorites SELECT isteği kullanıcı/session token’ı olmadan **HTTP 401, PostgreSQL 42501** döndürdü; veri dönmedi. URL/key stdin üzerinden iletildi, argv/loga yazılmadı. Bu yalnızca anonim erişim reddine kanıttır; A/B RLS izolasyonu veya policy introspection yerine geçmez.

## 4. Varsayılan `flutter run` ve temiz çalışma kopyası

GitHub’daki eski commit’i yeni kod gibi test etmek yerine, mevcut tracked + ignore edilmeyen untracked dosyaların güncel içerikleri ayrı kopyaya alındı:

`/private/tmp/mobilab-public-demo-clean-0xziwqf8/Etkinlikler`

290 dosya kopyalandı. `.git`, `.dart_tool`, build çıktıları ve `config/supabase.local.json` aktarılmadı. Kaynak/asset/test’lerin yayımlanmamış sürümü dahil edildi. Bu **güncel kaynaklardan temiz çalışma kopyasıdır**, henüz yayımlanmamış sürümün GitHub’dan clone edildiği iddia edilmez. Ana çalışma ağacına reset/clean/copy-over yapılmadı.

Bu kopyada:

```sh
flutter pub get
flutter analyze
flutter test
python3 -m unittest discover -s tool -p test_public_demo_tools.py
flutter run -d <iPhone-17-ID> --no-resident
```

Pub get başarılı, analiz temiz, **230 Flutter + 7 Python testi PASS**. Config define/file argümanı verilmeden iPhone17/iOS26.3 debug build/launch başarılı; Xcode build **28.8s**. `-d` yalnızca cihaz seçimi, `--no-resident` yalnızca denetim sürecini sonlandırmak içindir; config taşımaz. Değerlendirici normalde `flutter run` kullanabilir; birden çok cihaz varsa Flutter cihaz seçimi ister.

Orijinal proje kökünde de hiçbir config argümanı olmadan normal uygulama yeniden başlatıldı. Mevcut oturum/user verisi silinmedi. Gerçek API’nin geçici kategori hatası mevcut retry ile ele alındı; servis hatası config hatası gibi raporlanmadı. Yeni e-posta/OTP gönderilmedi.

## 5. Yerel config override sonucu

Mevcut dosya değiştirilmeden:

```sh
flutter test test/public_demo_config_test.dart --dart-define-from-file=config/supabase.local.json
flutter run -d <iPhone-17-ID> --dart-define-from-file=config/supabase.local.json --no-resident
```

**7/7 test PASS**, iPhone build/launch başarılı (**10.2s**). Ayrıca sentetik farklı URL/key ile `--dart-define` üzerinden **7/7**, açık boş URL/key define’larıyla **7/7** geçti. Gerçek değerler assertion çıktısına düşmesin diye hassas karşılaştırmalar boolean olarak yapıldı.

Bu testlerde yerel gerçek çiftin public varsayılanlarla aynı olduğu yalnızca boolean eşitlikle doğrulandı. Farklı değerlerin önceliği ayrı sentetik derleme testindedir; aynı çiftin kullanılması tek başına override önceliği kanıtı diye sunulmaz.

Web aracı `python3 tool/build_web.py --base-href /Etkinlikler/` ile, çalışma klasöründe yerel JSON mevcut olmasına rağmen **public demo varsayılanları** modunda release build aldı. JSON otomatik okunmadı. Web build başarılı (**28.3s**); canlı Pages deploy yapılmadı.

## 6. Testler

| Test/koşu | Sonuç |
|---|---|
| Önceki testler | 223 test korundu, silinmedi veya gevşetilmedi |
| `public_demo_config_test.dart` | Public defaults; compiled define önceliği; açık eksik config; geçersiz URL/server key; gerçek SDK anon favori gate; anonim Keşfet; oturumsuz kalpten auth UI: **7 PASS** |
| Aynı dosyanın sentetik Dart define derlemesi | **7 PASS** |
| Açık boş Dart define derlemesi | **7 PASS**, boş değerler hata olarak korunur |
| Aynı dosyanın gerçek yerel file override derlemesi | **7 PASS**, mail gönderilmez |
| Tam `flutter test`, orijinal klasör | **230/230 PASS** |
| Tam `flutter test`, temiz güncel kopya | **230/230 PASS** |
| `tool/test_public_demo_tools.py`, orijinal ve temiz kopya | Her ikisi **7/7 PASS**; Flutter sayısına dahil değil |

Widget testleri fake auth/favorites ve kontrollü event repository ile UI sözleşmesini doğrular; gerçek SMTP/Supabase servisi çağırmaz. Gerçek SDK’nin session zorunluluğu ayrı MockClient unit testindedir. Gerçek `main.dart` startup’ı yerel JSON’suz native çalışma kopyasıyla ayrıca doğrulandı. Bir widget testi SMTP teslimi kanıtı olarak sunulmaz.

## 7. Analiz ve araç sonuçları

`flutter pub get` ve `flutter analyze` hem orijinal proje hem temiz kaynak kopyasında başarılı; iki analiz de **No issues found**. Dart kaynakları formatlandı. `bash -n tool/run.sh`, yardımcı araçların sentetik testleri ve `git diff --check` temiz.

Python araç testleri: ignored dosyanın otomatik okunmaması, boş opsiyonel CI alanları, açık dosya/ortam önceliği, tek alan override, geçersiz/secret/boş açık ayarların reddi, sadece açık alanların build’e geçmesi/geçici dosyanın temizlenmesi, boşluklu argümanlar ve yerel dosyanın korunması.

## 8. Git durumu

Branch main, HEAD `0277ae4d98f5ecfa694da80c8ad574928e06048e`; `git ls-remote origin refs/heads/main` aynı SHA’yı verdi. Bu istekte commit, stage veya push yapılmadı. Yerel değişiklikler GitHub’da görünmez; kullanıcı yayımladıktan sonra normal clone bu varsayılanları içerir.

Çalışma ağacında önceki UI/denetim/Pages değişikliklerine ek olarak merkezi config, README/teslim rehberi ve araç değişiklikleri; yeni config testi, Python araç testi ve bu rapor bulunur. Tam `git status --short` dosya listesi aşağıdadır; eski değişiklikler bu isteğin işi gibi sunulmaz.

```text
 M README.md
 M lib/app/widgets/floating_navigation.dart
 M lib/core/config/supabase_config.dart
 M lib/core/widgets/skeleton.dart
 M lib/features/auth/presentation/screens/auth_screen.dart
 M lib/features/events/controllers/events_controller.dart
 M lib/features/events/presentation/screens/event_detail_screen.dart
 M lib/features/events/presentation/widgets/adaptive_event_composition.dart
 M test/adaptive_composition_test.dart
 M test/auth_favorites_widget_test.dart
 M web/index.html
 M web/manifest.json
?? .github/workflows/flutter_pages.yml
?? docs/reports/final-audit/
?? docs/reports/final-delivery/
?? docs/reports/public-demo/
?? docs/teslim.md
?? lib/core/widgets/detail_text_surface.dart
?? test/detail_readability_test.dart
?? test/image_audit_regression_test.dart
?? test/loading_retry_audit_test.dart
?? test/public_demo_config_test.dart
?? tool/audit_api_images.py
?? tool/audit_image_decode_test.dart
?? tool/build_web.py
?? tool/run.sh
?? tool/test_public_demo_tools.py
```

## 9. Kalan manuel testler

- **Yeni/farklı yetkili alıcıya OTP teslimi ve yeni gerçek login/logout:** SMTP/Resend gönderici yapılandırmasına bağlı. Public istemci ayarının eklenmesi mail teslimini düzeltmez. Bu istekte e-posta gönderilmedi, hesap veya credential oluşturulmadı; önceki SMTP riski başarılı sayılmadı.
- **İki gerçek yetkili hesapla RLS A/B izolasyonu ve policy kabulü:** İstemci korumaları ve anon 401 doğrulandı; bunlar iki kullanıcıyla canlı izolasyonun yerine geçmez. Tablo/policy değiştirilmedi.
- Kullanıcının son kaynakları GitHub’a yayımlaması ve ilgili commit’in gerçek CI/Pages koşusu. Yeni sürüm yayımlanmadığı için online kabul tamam değildir.
- Fiziksel iPhone/Android kabulü ve ücretsiz servislerin aktif/kota durumunu teslimden önce kontrol etme.

Public demo yapılandırması için gereken uygulama işi tamamlandı. Tasarım, auth mekanizması, kullanıcı favorileri ve yerel özel dosya korunmuştur; tüm harici servis kabullerinin tamamlandığı iddia edilmez.
