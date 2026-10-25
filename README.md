# MOBILAB / SKYLAB — Etkinlik Keşif

Gerçek MOBILAB API’sinden etkinlik keşfi, sunucuda arama/kategori, %70 eşikli pagination ve Supabase hesabına bağlı kalıcı favoriler sunan Flutter uygulaması. Giriş yapmadan Keşfet, detaylar ve tema kullanılabilir. E-posta ve şifreyle giriş yalnızca kişisel favoriler ve hesap için gerekir. Yeni kullanıcı Kayıt Ol ile gerçek Supabase hesabı açar; doğrulama kodu veya SMTP gerekmez.

[Kaynak kod](https://github.com/cigdem-gokdas/Etkinlikler) · [Son yayın öncesi denetim](docs/reports/release-readiness/rapor.md) · [Public demo yapılandırma raporu](docs/reports/public-demo/rapor.md) · [Kurulum ve ücretsiz yayın rehberi](docs/teslim.md) · [Gereksinim denetimi](docs/reports/final-audit/rapor.md) · [API fotoğraf denetimi](docs/reports/final-audit/api-images.md)

## Hızlı inceleme

Flutter **3.47.7 stable**, birlikte gelen Dart **3.13.5** kullanılır. SDK’nin `bin` dizini PATH’te olmalı. [Flutter kurulumu](https://docs.flutter.dev/install) · [SDK arşivi](https://docs.flutter.dev/install/archive).

```sh
git clone https://github.com/cigdem-gokdas/Etkinlikler.git
cd Etkinlikler
flutter pub get
flutter run
```

Public demo Supabase bağlantısı kaynaklardaki merkezi config’den gelir; JSON hazırlamak, anahtar istemek veya ek bir çalıştırma parametresi vermek gerekmez. `flutter run` birden çok cihaz varsa seçim isteyebilir; doğrudan tarayıcı için `flutter run -d chrome`, açık Simulator için `flutter run -d "iPhone 17"` kullanılabilir. Confirm Email proje sahibi tarafından kapatılmıştır; kayıt ve giriş için e-posta gönderilmez. Parola sıfırlama bu demoda sunulmaz.

macOS / iPhone Simulator için Xcode ve iOS Simulator kurulmuş olmalı. [Resmî iOS hazırlığı](https://docs.flutter.dev/platform-integration/ios/setup):

```sh
open -a Simulator
flutter devices
flutter run -d "iPhone 17"
```

`-d` değerini `flutter devices` çıktısındaki cihaz adı veya ID ile eşleştirin. Fiziksel iPhone’un kablosuz bulunamama uyarısı, listelenmiş Simulator’ın çalışmasını engellemez. Android için Android SDK/emülatör kurulumu gerekir; bu makinede Android cihaz kabulü yapılmadı.

**İnceleme sırası:** Onboarding → Keşfet → arama/kategori → detay → tema → aşağı kaydırarak sonraki sayfa. Yapılandırılmış hesap bağlantısında Kayıt Ol / e-posta ve şifreyle Giriş Yap → favori ekle → uygulamayı kapat/aç → Favoriler → kaldır. Test için ortak hesap veya kişisel e-posta/parola yayımlanmaz.

### Public demo ve yerel override

`lib/core/config/supabase_config.dart` tek merkezi yapılandırmadır. Öncelik her alan için **`--dart-define` → `--dart-define-from-file` → public demo varsayılanı** şeklindedir. Aynı alan iki yerde verilirse komut satırındaki `--dart-define` kazanır. Alan hiç verilmezse demo değeri kullanılır; açık boş/geçersiz değer sessizce demo ile değiştirilmez ve kontrollü hata verir. Başka bir proje seçerken URL ve publishable key birlikte verilmelidir.

Mevcut yerel config’i kullanmak isteyen geliştirici açıkça seçer:

```sh
flutter run --dart-define-from-file=config/supabase.local.json
```

`bash tool/run.sh` aynı Flutter davranışını sağlar; yerel dosyayı kendiliğinden okumaz. Override için aynı parametre script’e de verilebilir. Mevcut yerel JSON silinmez/değiştirilmez veya otomatik kopyalanmaz. Değerler derleme zamanında okunur; config değişince yeni derleme gerekir. Kurulu uygulamayı normal kapatıp açarken terminal komutu gerekmez.

## Hesap ve kalıcı favori yapılandırması

Değerlendiricinin clone veya web incelemesi için config dosyası hazırlaması gerekmez. Public demo, uygulamanın paylaşılan Supabase projesine bağlanır. Her kullanıcı kendi e-postası ve şifresiyle gerçek Supabase oturumu açar; favoriler aynı proje içinde kendi `user_id` değeriyle saklanır, başka kullanıcının hesabına aktarılmaz. Değerlendiricinin kendi Supabase projesini açması gerekmez. Kendi projesini kullanmak isteyen geliştirici yerel override yapabilir.

**Yalnızca farklı bir bağlantı kullanmak isterseniz:** Yerel config yoksa `config/supabase.example.json` dosyasını `config/supabase.local.json` adıyla kopyalayıp placeholder’ları doldurun. Demo için bu adım gerekli değildir. Mevcut dosyanın üzerine yazmayın:

```json
{
  "SUPABASE_URL": "YOUR_SUPABASE_PROJECT_URL",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_SUPABASE_PUBLISHABLE_KEY"
}
```

Giriş ekranında e-posta, şifre ve göster/gizle kontrolü; kayıt ekranında ayrıca şifre tekrarı vardır. `signInWithPassword` ve `signUp` kullanılır. Form e-postayı trim eder, şifreyi değiştirmeden gönderir. Yeni şifre en az 8 karakter olmalı; sunucunun daha güçlü parola politikası ayrıca geçerlidir. Mevcut hesaba girişte yeni kayıt uzunluğu uygulanmaz. Hata/loading/retry ve çift tıklama koruması vardır. Yanlış şifrede güvenli ortak hata, tekrar kayıtta mevcut hesapla giriş önerisi gösterilir. Şifre loglanmaz veya uygulama tarafından diske yazılmaz. Oturumun korunması için SDK erişim/yenileme token’larını yerel oturum deposunda tutar; bunlar Git’e eklenmez.

Gerçek SDK Session oluşmadan başarı sayılmaz. SDK session saklama/yenileme ve auth state listener korunur; çıkış/hesap değişimi favorileri temizler, gecikmiş eski kullanıcı yanıtı uygulanmaz. Kullanıcı favorileri kendi değişmeyen UUID’siyle saklanır.

Project URL ve `sb_publishable_` istemci anahtarı public istemci ayarlarıdır; bu projenin Dart kaynaklarında ve build’inde bulunurlar, secret olarak tanıtılmazlar. **RLS kullanıcı verisini korur**. Server/secret/service-role, Resend/SMTP veya Gmail uygulama şifresi Flutter’a konmaz. Yerel JSON ignored’dır; dosyanın kendisi asset olarak paketlenmez. Yalnızca public varsayılanlar kaynakta bulunur. Açık override eksik/geçersizse veya hesap bağlantısı başlatılamazsa anlaşılır mesaj ve Keşfet’e dönüş kontrolü korunur. Public key, kullanıcı session’ı yerine geçmez; oturumsuz favori SELECT/INSERT/DELETE istemcide reddedilir ve sunucu tarafında RLS ile korunmalıdır.

### Demo sınırlaması ve eski OTP hesapları

Confirm Email proje sahibi tarafından kapatılmış ve public ayardan salt okunur doğrulanmıştır. Yeni kayıt anında session döner; kayıt/giriş için Resend, Gmail, OTP veya SMTP kullanılmaz. Bu demo e-posta sahipliğini doğruladığı iddiasında bulunmaz.

**Şifremi Unuttum yoktur:** SMTP kullanılmadığından e-posta ile parola sıfırlama sunulmaz. Şifreyi kaybeden kullanıcı için otomatik kurtarma sözü verilmez.

Eski OTP kullanıcıları silinmez, aynı e-postayla yeniden oluşturulmaz ve favorileri başka kullanıcıya taşınmaz. Açık oturumları korunur. Parolası olmayan eski hesabın yeni bir parolaya ihtiyacı vardır: aktif oturumla Supabase `updateUser(UserAttributes(password: ...))` veya kimliği doğrulanan kullanıcının mevcut UUID’sine yetkili **sunucu tarafında** admin `updateUserById` uygulanabilir. Bu işlem bu çalışmada hiçbir eski hesaba uygulanmadı; güvenli parola tanımlama ve olası yeniden doğrulama manuel kabul gerektirir. Admin key Flutter’a konmaz. [Geçiş ve teslim rehberi](docs/teslim.md).

## Ücretsiz GitHub Pages yayını

Web workflow’u [`.github/workflows/flutter_pages.yml`](.github/workflows/flutter_pages.yml) dosyasındadır. Public repo ve standart Ubuntu runner kullanır. Proje sahibi bir kez:

1. Güncel kaynakları kendisi GitHub’a gönderir. Bu çalışma commit/push yapmaz.
2. Repo **Settings → Pages → Source: GitHub Actions** seçer.
3. **Settings → Secrets and variables → Actions → Variables** içinde `PAGES_ENABLED=true` tanımlar. Demo bağlantısı için başka variable gerekmez. Farklı proje istenirse `SUPABASE_URL` ve `SUPABASE_PUBLISHABLE_KEY` birlikte override olarak eklenir. SMTP veya server key girilmez.
4. **Actions → Flutter Web Pages → Run workflow → main** çalıştırır. Sonraki main push’larında da yayınlanır. Analyze/test başarısızsa deploy yapılmaz.
5. Yeşil Deploy çıktısındaki URL’yi açıp kontrol eder, sonra ödeve kaynak ve yayın bağlantılarını ekler.

Bu repo için varsayılan yayın hedefi `https://cigdem-gokdas.github.io/Etkinlikler/`; **canlı deploy bu çalışma tarafından yapılmadı**, dolayısıyla yayında olduğu iddia edilmez. URL/key variable’ları yoksa aynı public demo bağlantısı kullanılır. Alan bazında override desteklenir; farklı proje için URL/key çiftini birlikte verin. Geçersiz açık ayar veya secret key build’i durdurur. `/Etkinlikler/` base path, kendi host’undan renderer dosyaları ve 1 günlük artifact retention workflow’da hazırdır. [Tam yayın, maliyet ve son kabul rehberi](docs/teslim.md).

Yerelde aynı release’i test etmek için (Python 3 ve Flutter PATH’te):

```sh
python3 tool/build_web.py --base-href /
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/web
```

Ardından `http://127.0.0.1:8000/` açılır. `build_web.py` varsayılanları Dart config’e bırakır; yerel dosyayı otomatik okumaz. Açık `--config config/supabase.local.json` veya dolu CI değişkenleri override sağlar; değerler loglanmaz. Mobil ve web oturum/tema/onboarding verileri kendi cihaz/origin depolarındadır.

### Maliyet sınırı

Dashboard’da Supabase **Free**, Resend **Free** ve Resend pay-as-you-go **kapalı** doğrulandı. Ücretli yükseltme/eklenti açılmadı. Supabase Free kullanımında ücret alınmaz; kota aşımında hizmet kısıtlanabilir. Spend Cap yalnızca Pro planında bulunur ve Pro taban ücretini ortadan kaldırmaz; sıfır maliyet için Free planda kalın. [Supabase maliyet açıklaması](https://supabase.com/docs/guides/platform/cost-control).

Public repoda standart Actions runner’ları ücretsizdir, Pages GitHub Free ile kullanılabilir. Özel domain/larger runner alınmaz. [Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions) · [Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits). Ücretsiz servislerin kota/duraklama sınırları vardır; Supabase projesinin teslimden önce aktif olduğunu kontrol edin. [Duraklama](https://supabase.com/docs/guides/platform/free-project-pausing). Bu çalışma hesap faturalandırmasını değiştirmez; uygulama içi istek sınırları finansal harcama limiti değildir.

## Özellikler ve yükleme davranışı

- Gerçek liste/detay ve API fotoğrafları; Türkçe yerel tarih/saat, eksik/bozuk fotoğrafta ikonsuz nötr fallback.
- Sunucuda `q` + `category`, 350ms debounce, eski yanıtı reddeden generation kontrolü.
- Scroll extent’in %70’inde yeni sayfa; deduplication, hasMore/total ve pending koruması, aynı sayfa retry. Refresh veya devam hatası görünür listeyi silmez.
- Supabase favorileri: Keşfet/Favoriler/detay ortak state, yalnızca sunucu başarısından sonra kalp güncellenir, kapat/aç sonrası kalıcıdır.
- Kalıcı açık/koyu tema; iki sayfalık onboarding; her cold start’ta 2.2s logo intro, reduced motion’da 360ms fade. Sekme/route/resume intro’yu tekrarlatmaz.
- Şeffaf, ince çerçeveli floating nav; keyboard açılınca gizlenir, SafeArea ve son satır için alan korunur. IndexedStack sekme/scroll state’ini korur.
- Sliver geometrisiyle büyük başlık 34→20px daralır, arama/filtre kaydırmayla gizlenip geri gelir. Focus ve %70 scroll ölçüsü korunur.
- İlk liste/kategori/detay/favori yüklemesinde statik skeleton; erişilebilir tek yükleme etiketi. Error/empty/retry, 20s ağ timeout’u; sonsuz retry yok.

### Daha net sinematik detay ve metin skeleton’ı

Fotoğraf API `imageUrl` alanından gelen tek `RawImage` yüzeyidir; ayrı foreground fotoğraf veya sahte görsel yok. `BoxFit.cover` oranı bozmaz; yatay fotoğrafın portre ekranda yanlardan kırpılması doğaldır. Gerçek oran tek ImageStream’den bulunur, N+1 metadata isteği atılmaz. Decode üst sınırı 1200×1600; disk cache paketi yok. Listener/generation/dispose korumaları korunur.

Son görsel ayarda blur landscape **1.3**, square **0.8**, portrait **0.4**; scrim **%64** siyah yapıldı. Önceki %72/sigma5 yatay görünüme göre fotoğraf daha belirgin/nettir. Beyaz ve mint metin en parlak beyaz fotoğraf üzerinde bile **4.5:1 veya üstü** kontrastla test edilir. Açıklama aynı hafif koyu panelde, 17px/1.6 satır yüksekliğinde tam ve seçilebilir metindir. AppBar geri/kalp kontrastı, kısa fade, status bar ve reduced motion korunur.

Açıklama skeleton’ı artık gerçek paragrafla aynı **20px iç boşluğu, metin genişliği ve font ölçeğine göre hesaplanan satır yüksekliğini** kullanır. İlk iki çizgi okuma alanını doldurur; son çizgi daha kısadır. API yanıtı gelmeden bilinmeyen metnin tam son satırı/satır sayısı önceden hesaplanamaz; gerçek boyut biliniyormuş gibi davranılmaz. Cached bilgi varsa metin gizlenmez; yalnızca eksik açıklama yükleme alır.

## API ve veri güvenliği

[API](https://mobilab-task-api.vercel.app) · [Swagger](https://mobilab-task-api.vercel.app/docs) · [OpenAPI](https://mobilab-task-api.vercel.app/openapi.json)

| Endpoint | Amaç |
|---|---|
| `GET /categories` | Gerçek `{items: [String, ...]}` kategorileri |
| `GET /events` | `q`, `category`, `online`, `page`, `limit` |
| `GET /events/{event_id}` | Güncel gerçek detay |

25 Ekim canlı denetimi: 10+6 kayıt, total16, son hasMore=false; 14 geçerli JPEG, evt-007 null, evt-015 görsel GET’i HTTP400. Liste/detay URL farkı yok. Geçerli 14 dosya gerçek Flutter codec’iyle decode edildi. Kaynak hataları uygulama hatası gibi gizlenmez; API zaman zaman500 döndürebilir. [Etkinlik bazlı kanıt](docs/reports/final-audit/api-images.md).

Supabase `public.favorites`: primary key `(user_id,event_id)`; title/image_url/starts_at/location/category ve sunucu saved_at. Repository SDK user/session eşleşmesini kontrol eder, SELECT user_id, DELETE ayrıca event_id ile sınırlıdır. UPDATE/upsert yok. DELETE sonrası SELECT başarısız silmeyi sahte başarı yapmaz. Logout/hesap değişiminde state temizlenir, eski async yanıt reddedilir. Onaylı yeni QA hesaplarında canlı A/B izolasyonu doğrulandı: başka hesaba SELECT boş, INSERT reddedildi, DELETE diğer hesabın kaydını silemedi. [Kanıt ve kapsam](docs/reports/password-auth/rapor.md). `supabase/favorites.sql` **çalıştırılmayan referanstır**, otomatik migration değildir.

## Mimari

```text
lib/
  app/                  # bağımlılık bağlama, intro, tema, floating nav
  core/
    config/             # public demo varsayılanları + derleme zamanı override
    network/            # HTTP client, timeout, hata eşleme
    widgets/            # skeleton, metin yüzeyi, ortak durumlar
  features/
    events/             # model, repository, controller, liste/detay UI
    auth/               # E-posta/şifre/session repository, controller ve ekranlar
    favorites/          # kullanıcıya özel kalıcı kayıt ve ekran
    onboarding/         # iki sayfa ve tercih kalıcılığı
config/supabase.example.json
supabase/favorites.sql
tool/run.sh             # flutter run ile aynı public demo/override davranışı
tool/build_web.py       # doğrulanmış istemci ayarlarıyla web release
.github/workflows/      # CI ve opt-in Pages yayını
test/                   # fake/MockClient ile internetsiz testler
docs/                   # teslim rehberi ve tarihli kanıtlar
```

**Widget → ChangeNotifier Controller → Repository → API/SDK.** Feature-first ilgili sorumlulukları bir arada tutar; Widget HTTP çağırmaz. Repository arayüzleri fake ile test edilir. Controller debounce, generation ve pending state’i yönetir. Ek state management framework’ü/paket eklenmedi. Paketler: http, intl, flutter_localizations, supabase_flutter2.18.3, shared_preferences2.5.6.

## Doğrulama ve kanıtlar

```sh
flutter pub get
flutter analyze
flutter test
```

E-posta/şifre sürümünde **230/230 Flutter testi** ve temiz analiz doğrulandı; yardımcı araçların ayrıca **7 Python testi** geçti. Artık geçerli olmayan OTP testleri parola davranışlarıyla değiştirildi; auth dışındaki regresyonlar korundu. Yerel JSON bulunmayan temiz çalışma kopyasında da aynı kontroller geçti. [Güncel yapılandırma ve başlangıç raporu](docs/reports/public-demo/rapor.md). Kontrast ve skeleton’ın gerçek paragrafla aynı genişlik/satır ölçüsünü, 1.8x yazı ölçeğini ölçen üç test eklendi. Unit/widget testleri internet, OTP maili veya production Supabase gerektirmez. [Bu devam çalışmasının sonuçları](docs/reports/final-delivery/rapor.md).

Önceki kapsamlı denetimde gerçek mevcut oturum/favori tam süreç kapatma/açma sonrası geri geldi; QA eklemesi kaldırılıp önceki kayıtlar korundu. Public `0277ae4` yeni geçici klasöre clone edilip kişisel config olmadan 209 test, analiz ve iOS Simulator build ile doğrulandı. Bu tarihî public commit için [Actions CI başarılıydı](https://github.com/cigdem-gokdas/Etkinlikler/actions/runs/40132592274). Yerel son değişiklikler henüz commit/push edilmedi; yeni online CI/Pages deploy yapılmış sayılmaz.

[CI workflow](.github/workflows/flutter_ci.yml): main push/PR, Flutter3.47.7, pub get/analyze/test; contents:read ve persist-credentials:false. Kişisel config/secret gerektirmez. Pages workflow’u ayrı ve opt-in’dir, testler geçmeden deploy etmez.

**Manuel kabul kalanları:** Eski OTP hesaplarına güvenli parola tanımlama; son commit’in online CI/Pages yayını; fiziksel cihaz/Android. Yeni auth ve canlı testlerin ayrıntıları [parola geçişi raporunda](docs/reports/password-auth/rapor.md). Bu adımlar tamamlanmış sayılmaz. Plan yükseltme, domain satın alma, auth bypass veya kullanıcı verisi silme yapılmadı.

### Ekran görüntüleri

Güncel görsel düzen ve web/native kanıtlar [son UI/teslim kaydında](docs/reports/final-delivery/rapor.md). Önceki 9 gerçek Simulator görüntüsü [gereksinim raporunda](docs/reports/final-audit/rapor.md); intro/status bar/collapse görüntüleri [motion raporunda](docs/reports/final-motion/rapor.md). Eski aşama raporları tarihîdir, son tasarımla birebir aynı olduğu iddia edilmez.

## AI kullanım açıklaması

Kullanılan AI aracı **Codex**. Flutter CLI/test araçları, Git, public API/GitHub REST istekleri ve iPhone Simulator gözlemleriyle desteklendi. Rolü kod incelemesi, mevcut mimariyi koruyarak uygulama/test geliştirme, hata analizi, UI iyileştirmeleri, kanıt ve README hazırlamadır. Logo kullanıcı tarafından sağlandı ve orijinal asset kullanıldı; yeni bir logo üretildiği iddia edilmez.

**Kullanıcının belirlediği ürün ve teknoloji kararları:** Flutter, Supabase, Email OTP, kalıcı hesap bazlı favoriler, gerçek API fotoğrafları, %70 pagination, minimal etkinlik odaklı tasarım, iki sayfalık onboarding, floating navigation, cold start intro, reduced motion desteği ve son aşamada ayrı foreground fotoğrafı kaldırılmış tek yüzeyli detay. SMTP ve veritabanı/RLS kurulumu kullanıcı tarafındaki servis yapılandırmasıdır; Codex bunları yeniden oluşturmadı.

**Mevcut mimariyi korumak için teknik uygulama kararları:** Feature-first klasörler auth/events/favorites/onboarding sorumluluklarını ayırır; ChangeNotifier/controller → repository → API/SDK akışı UI’dan veri işlemlerini ayırıp fake repository ile test etmeyi sağlar. Yeni state management paketi eklenmedi. Debounce/generation ve ID deduplication, sıralı preference yazmaları ve üç otomatik viewport doldurma sınırı gecikmiş yanıt ve istek döngüsü risklerini azaltır. Skeleton içerik geometrisini korur. Tek ImageStream ile gerçek boyut algılama, sınırlı decode ve RepaintBoundary aynı API fotoğrafının belleğini/blur maliyetini kontrol eder.

Bu görüşmede gerçekten verilen istemlerden kısa örnekler:

> “Bir problem gerçekten uygulama kaynaklıysa düzelt, yeniden test et ve sonucu kanıtla.”
>
> “Fotoğraf olmayan etkinliklere sahte görsel ekleme.”
>
> “Otomatik commit veya push yapma.”

AI’ya verilen sınırlar: mevcut özellikleri ve testleri korumak, sahte veri/fotoğraf üretmemek, auth/RLS’yi bypass etmemek, kullanıcı verilerini/Git geçmişini silmemek, izin olmadan servis yapılandırmasını değiştirmemek ve yalnızca gerçekten yapılan kontrolleri raporlamak.

AI çıktıları `flutter analyze`, internetsiz unit/widget testleri, sınırlı canlı API denetimi ve simülatörle kontrol edildi. Önceki status bar / SafeArea problemi render testleri ve gerçek ekranla düzeltildi. Son denetimde bozuk görsel ikonu dört testte önce yeniden üretildi, fallback katmanı düzeltildi; on görsel regresyonu ve ilk hata sonrası retry loading testi eklendi. İlk sayfa retry’sinde eski hata başlığının loading’e dönmemesi de aynı denetimde düzeltilip test edildi. API kaynaklı null fotoğraf/HTTP 400 URL’si uygulama hatası gibi gizlenmedi. Desktop Finder metadata’sının codesign 255 hatası yerel build cache konumu düzeltilerek giderildi; temiz clone iOS derlemesi ayrıca doğrulandı. Bu önceki denetimde canlı iki hesap RLS ve yeni alıcıya SMTP teslimi yapılmış gösterilmedi. Son parola geçişinde aşağıda bağlantısı verilen onaylı QA hesabı RLS testleri ayrıca gerçekleştirildi.

Son devam isteğinde kullanıcı fotoğrafların daha aydınlık/net olmasını, metin skeleton geometrisinin eşleşmesini ve ücretsiz GitHub inceleme/yayın akışını istedi. Codex daha hafif blur/scrim için kontrastı test etti, gerçek paragraf ve skeleton’ı ortak yüzeyde birleştirdi, yerel çalıştırma ve opt-in Pages araçlarını hazırladı. Dashboard’dan Free plan ve Resend alan adı engeli okunarak belgelendi; ayarlar değiştirilmedi. Gmail SMTP seçeneği hesap sahibinin uygulama şifresini kendisinin girmesini gerektirir; canlı teslim yapılmış gibi sunulmaz.

Public demo devamında kullanıcı yalnızca public URL/publishable key varsayılanı ve kurulum belgelerini istedi. Codex değerleri çıktı/log/rapora yazmadan merkezi Dart katmanına aktardı; açık override ve oturumsuz favori korumasını test etti. Yerel dosya, tasarım, auth/RLS ve mevcut favoriler değiştirilmedi. SMTP teslimi ayrı harici kabul olarak korundu.

Son auth devamında kullanıcı Confirm Email ayarını kendisi kapattığını belirterek e-posta/şifre akışını istedi. OTP controller/UI/testleri signUp/signInWithPassword, parola tekrarı, güvenli hata ve session kontrolleriyle değiştirildi. SMTP kurtarma akışı eklenmedi; eski kullanıcıların UUID/favorileri korunarak manuel parola geçişi belgelendi. Gerçek QA hesapları ve yalnızca bu hesapların geçici favori işlemleri için kullanıcı ayrıca açık onay verdi.

Son yayın öncesi denetimde güncel Git index’inden yerel config/QA kayıtları taşınmadan dağıtım simülasyonu oluşturuldu; 230 Flutter ve 7 Python testi, temiz analiz, iOS/web build, iki yeni onaylı QA hesabında canlı RLS ve Pages alt yolunda web oturum/favori kalıcılığı yeniden doğrulandı. CI ve Pages build adımlarına Python araç testleri de eklendi. Remote henüz önceki commit’tedir; bu sonuç online Actions/Pages yayını sayılmaz. [Kapsam ve sınırlamalar](docs/reports/release-readiness/rapor.md).
