# MOBILAB — Parolalı demo ve ücretsiz teslim

Değerlendirici güncel kaynakları klonladıktan sonra:

```sh
git clone https://github.com/cigdem-gokdas/Etkinlikler.git
cd Etkinlikler
flutter pub get
flutter run
```

Public Supabase istemci ayarları merkezi Dart config’dedir; yerel dosya veya yeni Supabase projesi gerekmez. Birden çok cihaz varsa cihaz seçilir; doğrudan `flutter run -d chrome` veya `flutter run -d "iPhone 17"` kullanılabilir. [Güncel auth raporu](reports/password-auth/rapor.md).

## Giriş ve kayıt

Giriş Yap: E-posta + Şifre + göster/gizle. Kayıt Ol: E-posta + Şifre + Şifre tekrar. Yeni şifre için istemci alt sınırı 8 karakter; sunucu parola politikası ayrıca geçerlidir. Eski hesaba girişte yeni kayıt uzunluğu uygulanmaz. Şifre trim edilmez, loglanmaz ve uygulama tarafından ayrıca saklanmaz.

`signUp(email,password)` ve `signInWithPassword(email,password)` kullanılır. Confirm Email proje sahibi tarafından **kapatılmıştır**; public settings endpoint’inden salt okunur doğrulandı. Kod bu ayarı değiştirmez. Gerçek Session dönmeden uygulama başarılı giriş göstermez. Bu demo e-posta sahipliğini doğrulamaz; production doğrulanmış kimlik sistemi olarak sunulmamalıdır. [Supabase signUp](https://supabase.com/docs/reference/dart/auth-signup).

Kayıt/giriş için **SMTP, Resend, Gmail veya OTP gerekmez**. Yanlış şifre, kayıtlı adres, ağ/servis hatası ve rate limit sade Türkçe geri bildirim verir. Form tekrar gönderilebilir; işlem sürerken yinelenen istek başlatılmaz.

## Oturum ve favoriler

SDK `persistSession` ve `autoRefreshToken` ile oturumu korur. Favoriler aynı Supabase projesinde kendi `user_id` değeriyle kalıcıdır. Çıkış/hesap değişiminde UI favorileri temizlenir, önceki hesabın geç yanıtı yeni hesaba uygulanmaz. `public.favorites` şeması, PK ve RLS bu geçişte değiştirilmedi. Publishable key session yerine geçmez; anon favori işlemleri reddedilir.

Gerçek testlerin kapsamı raporda belirtilir. QA dışında mevcut kullanıcıya ait kayıt silme, hesap değiştirme veya veri taşıma yapılmaz.

## Şifremi Unuttum sınırlaması

Bu demoda parola sıfırlama butonu/akışı yoktur. E-posta yoluyla reset SMTP gerektirir; SMTP kullanılmadığından çalıştığı iddia edilmez. Şifre kaybında kimlik doğrulayan yetkili proje sahibiyle güvenli manuel süreç gerekir; ortak demo parolası veya auth bypass eklenmez.

## Eski OTP hesapları için geçiş

Eski OTP kullanıcısının UUID’si ve ona bağlı favorileri korunur. Kullanıcıda otomatik parola oluştuğu varsayılmaz. Aynı e-postayla yeni kayıt açmak çözüm değildir; mevcut hesap silinmez, başka UUID’ye favori taşınmaz. Özellikle parolası olmayan eski kullanıcı **açık oturumunu güvenli geçiş yapılana kadar kapatmamalıdır**.

Desteklenen yöntemler:

1. Kullanıcı hâlâ geçerli oturumdaysa kendi session’ıyla `updateUser(UserAttributes(password: ...))` kullanılabilir. Bu uygulamaya ayrı bir parola ayar ekranı eklenmedi; işlem güvenilir bir bakım aracı/akışıyla ve kullanıcının kendi seçtiği parolayla yapılmalıdır. Sunucu güvenli parola değişimi/current-password/reauthentication kuralı istiyorsa bu kural atlanmaz. Bazı durumlarda nonce/e-posta gerekebilir; SMTP olmadan tamamlanmış sayılmaz. [Authenticated updateUser](https://supabase.com/docs/reference/dart/auth-updateuser) · [Parola güvenliği](https://supabase.com/docs/guides/auth/password-security).
2. Açık oturum yoksa yetkili proje sahibi kullanıcının kimliğini güvenli biçimde doğrulayıp **sunucu tarafında**, aynı UUID üzerinde `auth.admin.updateUserById(..., {password: ...})` uygulayabilir. Admin key yalnızca güvenilir sunucu ortamında tutulur; Flutter’a, public GitHub’a, sohbete veya README’ye yazılmaz. Bu, herkese açık reset endpoint’i yapılarak sunulmaz. [Admin updateUserById](https://supabase.com/docs/reference/javascript/auth-admin-updateuserbyid).

Bu çalışmada hiçbir eski hesabın parolası değiştirilmedi. Eski kullanıcının manuel parola belirlemesi, kayıt/giriş doğrulamasından ayrı bir kabul adımıdır.

## Yerel override ve güvenlik

Demo için gerekmez; farklı Supabase bağlantısı istenirse:

```sh
flutter run --dart-define-from-file=config/supabase.local.json
```

`--dart-define` → `--dart-define-from-file` → public demo varsayılanı önceliği doğrulandı. `tool/run.sh` aynı argümanları Flutter’a geçirir; yerel dosyayı otomatik seçmez. `tool/build_web.py --config config/supabase.local.json` açık override destekler. Eski yerel dosyada kalan `OTP_LENGTH` artık kullanılmaz; yerel özel dosya bu geçişte değiştirilmedi. Örnek config ve yayın aracından OTP ayarı çıkarıldı.

URL ve `sb_publishable_` key public istemci ayarlarıdır, gizli anahtar diye tanıtılmaz. Güvenlik sınırı session ve RLS’dir. Service-role/secret/SMTP/Gmail/Resend anahtarı veya kullanıcı access/refresh token’ı kaynaklara eklenmez. `supabase/favorites.sql` referanstır; migration çalıştırılmaz.

## Ücretsiz GitHub Pages yayını

1. Kullanıcı güncel kaynakları commit/push eder. Bu çalışma commit/push yapmaz.
2. Public repo → Settings → Pages → Source: **GitHub Actions**.
3. Actions Variables → `PAGES_ENABLED=true`. Public demo bağlantısı için başka değişken gerekmez. Farklı proje için `SUPABASE_URL` ve eşleşen `SUPABASE_PUBLISHABLE_KEY` override’ı opsiyoneldir. Parola/SMTP/server key girilmez.
4. Actions → **Flutter Web Pages** → Run workflow → main. Pub get/analyze/Flutter testleri ve Python araç testleri geçmeden deploy yapılmaz.
5. Yeşil Deploy çıktısındaki gerçek URL kontrol edilip kaynak bağlantısıyla ödeve eklenir. Varsayılan hedef `https://cigdem-gokdas.github.io/Etkinlikler/`; canlı deploy yapılmadan yayında olduğu söylenmez.

Statik Pages yalnızca Flutter dosyalarını sunar; Supabase veya MOBILAB API’sini deploy etmez. Web’de oturum/tema/onboarding deposu iOS’tan ayrıdır. `/Etkinlikler/` base path ve self-hosted renderer kaynakları workflow’da hazırdır.

Yerel web release:

```sh
python3 tool/build_web.py --base-href /
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/web
```

Tarayıcıdan `http://127.0.0.1:8000/` açılır. Public defaults veya açık override kullanılır; yerel JSON kendiliğinden okunmaz.

## Ücretsiz servis sınırları

Önceki denetimde Supabase Free ve Resend Free/pay-as-you-go kapalı görüldü; bu geçişte plan veya faturalandırma değiştirilmedi. Resend artık uygulamanın kayıt/girişine bağlı değildir. Supabase Free kullanımında ücret alınmaz, kota aşımında/düşük etkinlikte hizmet kısıtlanabilir veya duraklatılabilir. Ücretli plan/eklenti/domain açılmadı. [Maliyet](https://supabase.com/docs/guides/platform/cost-control) · [Duraklama](https://supabase.com/docs/guides/platform/free-project-pausing).

Public repo/standart Ubuntu Actions ve GitHub Free Pages kullanılır; larger runner veya özel domain gerekmez. [Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions) · [Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).

Teslimden önce aktif proje, ilgili commit’in CI/Pages yayını, fiziksel cihaz/Android kabulü ve eski OTP kullanıcısının güvenli parola geçişi kontrol edilmelidir. [Güncel kayıt](reports/password-auth/rapor.md); önceki raporlar tarihîdir.


## Son yayın öncesi kabul

[25 Ekim 2026 denetimi](reports/release-readiness/rapor.md): index kaynaklarıyla yerel config içermeyen izole dağıtım, 230 Flutter + 7 Python testi, temiz analiz, temiz iPhone 17 kurulumu, web release ve `/Etkinlikler/` önizleme/refresh başarılı. Canlı iki QA hesabında parola girişi, favori kalıcılığı ve iki yönlü RLS engelleri doğrulandı; geçici favoriler temizlendi. İlk iOS API isteğinde sunucu hatası görüldü, Tekrar dene ile düzeldi; servis kesintisizliği garanti edilmez.

CI, main push ve pull request’te bağımsız kontrol yapar; Pages ayrı ve isteğe bağlıdır. Son staging kaynakları henüz GitHub’da değildir. Kullanıcı commit/push sonrasında online CI ve tercih edilirse Pages Deploy çıktısını kontrol eder. Repository Settings veya deployment bu denetimde değiştirilmedi.

`docs/reports/password-auth/live-results.json` ve `git-status.txt` yerel QA kayıtlarıdır; dosyaya özel ignore edilir, dağıtıma/commit’e dahil edilmez. Public raporlar bu yerel dosyalara bağlı değildir.
