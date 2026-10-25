# MOBILAB — Gereksinim denetimi ve hata düzeltme

**Tarih:** 25 Ekim 2026 · **Son durum: READY — yerel teknik denetim başarılı.** Yeni alıcıya OTP teslimi **NOT VERIFIED**, iki hesaplı canlı RLS izolasyonu **BLOCKED**; bunlar teslim öncesi manuel kabul gerektirir. Bu denetimde commit/push yapılmadı.

## Yönetici özeti

1. **Zorunlu maddeler:** Liste/detay, sunucuda arama/kategori, kalıcı favoriler, loading/error/empty ve public repo/README ölçülen kapsamda **PASS**. Favori kalıcılığı mevcut gerçek oturumda tam süreç kapatma/açma ile de doğrulandı. İki hesaplı sunucu izolasyonu ve yeni OTP teslimi ayrıca açıktır.
2. **Bonuslar:** Pagination, tema, anlamlı animasyonlar ve public commit’e ait gerçek GitHub CI **PASS**. Bu denetimin yeni yerel düzeltmelerine ait online CI henüz çalışmadı.
3. **Eksik/bozuk fotoğraflar:** `evt-007` null, `evt-015` kaynak URL’si HTTP 400. **16 kaydın 14 fotoğrafı geçerli**; hepsi Flutter codec’iyle 800×450 JPEG olarak çözüldü.
4. **Neden:** Fotoğraf eksikliği/bozukluğu API verisi ve görsel kaynağına ait. Liste ve detay URL’leri aynı; uygulama kaynaklı geçerli-fotoğrafı-göstermeme bulgusu yok. Ayrıntılı kayıtlar [API görsel raporunda](api-images.md).
5. **Düzeltilen uygulama hataları:** Null/bozuk fotoğraf fallback’indeki istenmeyen ikon kaldırıldı. İlk sayfa hatasından sonra retry devam ederken eski hata başlığında kalma düzeltildi; skeleton artık geri gelir. İkisi de önce başarısız regresyonla yeniden üretildi.
6. **Temiz clone:** Public `0277ae4` yeni klasöre gerçekten clone edildi; kişisel config olmadan pub get, analiz, 209 test ve iOS Simulator build başarılı. Değerlendirici girişsiz keşfi çalıştırabilir. OTP/favoriler için geçerli Supabase URL/publishable key ve çalışan SMTP gereklidir; production demo/bypass yoktur.
7. **Manuel işler:** Yeni yetkili alıcıya OTP teslimi/Resend gönderici kısıtı, iki yetkili test hesabıyla RLS A/B izolasyonu, fiziksel cihaz/Android kabulü ve yeni değişiklikler yayımlandıktan sonra CI kontrolü. Yeni gerçek hesap veya e-posta oluşturulmadı/gönderilmedi; tablo/policy değiştirilmedi.
8. **GitHub’a hazır mı?** Yerel kod ve belgeler teknik incelemeye/yayımlanmaya hazır. Bu iki düzeltme, 11 yeni test ve denetim dosyaları henüz GitHub’da değildir. Son yayın ve harici servis kabulleri proje sahibi tarafından tamamlanmalıdır.

## Gereksinim matrisi

PASS yalnızca aşağıda adı verilen test/gözlem kapsamını ifade eder. BLOCKED ve NOT VERIFIED maddeler başarılı sayılmadı.

| Gereksinim | Durum | Kanıt | Düzeltilen hata | Kalan risk |
|---|---|---|---|---|
| A — Etkinlik listesi ve güncel detay | PASS | Canlı 2 sayfa/16 detay; `events_repository_test`, `event_detail_test`, `event_detail_widget_test`; simülatör | Tasarım korunarak ikonsuz fallback | API zaman zaman 500 döner |
| B — Sunucu araması ve birleşik kategori | PASS | Canlı q=flutter: 3; Seminer: 3; flutter+Workshop: 2; boş arama: 0; `discovery_*` testleri; `02-search-category.png` | Yok | Ağ/servis kesintileri güvenli hata durumuna gider |
| C — Kalıcı favori ve mevcut oturum restore | PASS | Gerçek ekleme → process terminate/launch → Favoriler’de geri yükleme → kaldırma; `05`, `06` PNG; controller yeniden yaratma testi | Yok | Tek mevcut kullanıcıyla canlı kabul |
| C — İstemci A/B, logout temizliği, duplicate/offline | PASS | `favorites_controller_test`, `auth_controller_test`, `supabase_repositories_test`, auth/favorites widget testleri | Yok | Fake/MockClient kanıtı sunucu RLS kabulünün yerine geçmez |
| D — Loading/error/empty/retry/refresh | PASS | Canlı 500 ve retry; skeleton testleri; timeout/JSON/404 testleri; yeni `loading_retry_audit_test` | İlk sayfa retry’sinde loading’e geçiş | API/SMTP kesintisi uygulamada giderilemez |
| E — Public GitHub ve README | PASS | GitHub public=true; main=0277ae4; gerçek temiz clone; bağlantı/asset kontrolü | Eski test/CI/Git teslim ve AI açıklamaları güncellendi | Yeni denetim değişiklikleri yalnızca yerel |
| F — %70 pagination | PASS | Gerçek 10+6 kayıt; %69/%70, dedup, pending, retry, hasMore ve sliver testleri | Yok | Gerçek serviste yalnızca 16 kayıt var |
| G — Açık/koyu tema ve status bar | PASS | `theme_screens_test`, `theme_persistence_test`, `final_polish_test`, iki temalı skeleton/discovery testleri; Simulator | Yeni tema değişikliği yapılmadı | Fiziksel cihaz erişilebilirlik/kontrast kabulü ayrı |
| H — Cold start intro / onboarding / collapse / reduced motion | PASS | `launch_motion_test`, `onboarding_test`, `premium_navigation_test`; gerçek videodan `07–09` kareleri; önceki motion kanıtları | Yeni efekt eklenmedi | Fiziksel cihaz FPS/GPU profili ölçülmedi |
| I — Yayındaki commit için gerçek Actions CI | PASS | 0277ae4 → run 40132592274 → completed/success; pub get/analyze/test adımları success | Yok | Yeni yerel değişiklikleri kapsamaz |
| I — Bu denetimin yerel düzeltmeleri için online CI | NOT VERIFIED | Push yapılmadı; yerelde 220 test/temiz analiz | — | Yayın sonrası koşu bekliyor |
| J — Bütün API fotoğrafları ve A/B/C/D sınıflaması | PASS | 16 liste/detay karşılaştırması; 15 görsel GET; 14 Flutter decode; [tablo](api-images.md) | Bozuk görsel ikonu kaldırıldı | A: evt-007 null; B: evt-015 HTTP 400 |
| K — Anonim favorites SELECT’in reddi | PASS | Oturum token’ı olmadan tek read-only istek: HTTP 401, PostgreSQL 42501 | Yok | Yalnızca anonim erişimin reddini kanıtlar |
| K — İki hesaplı canlı RLS izolasyonu/policy introspection | BLOCKED | İki yetkili test hesabı ve yönetim erişimi sağlanmadı | Sunucu değiştirilmedi | A/B SELECT/INSERT/DELETE ve etkin policy kabulü gerekli |
| K — Yeni alıcıya OTP / SMTP / Resend teslimi | NOT VERIFIED | OTP hata/6–8 hane/cooldown testleri var; bu denetim mail göndermedi | Auth bypass yapılmadı | Test gönderici kısıtı varsa yeni değerlendirici giriş yapamayabilir |
| L — Güvenlik, config ve Git geçmişi | PASS | Local config ignored/untracked/hash aynı; 3 revision ve tracked/yeni metinlerde kalıp taraması; HEAD korundu | Yok | Kalıp taraması mutlak secret garantisi değildir |
| M — iPhone 17 gözlemleri | PASS | Gerçek API, iki fallback, retry, favori restore, intro; güncel build başarılı | İki uygulama hatası giderildi | Android/fiziksel cihaz testi yapılmadı |
| N — AI kullanım açıklaması | PASS | README: gerçek araç, kurallar, gerçek istem örnekleri, insan/teknik karar ayrımı ve doğrulama | Eksik/güncel olmayan açıklamalar tamamlandı | Değerlendirmeci yerel son belgeleri yayın sonrası görür |

## A. Etkinlik listesi ve detay

Canlı sayfalama `page=1,limit=10` için 10, page 2 için 6 kayıt ve `hasMore=false` verdi. `total=16`; sayfa/ID deduplication kontrolüyle tamamlandı. 16 detay endpoint’i HTTP 200 ve aynı event ID döndürdü. OpenAPI `/categories`, `/events`, `/events/{event_id}` yolları ve gerçek model alanlarıyla karşılaştırıldı. Tarihler `startDate` / `endDate` alanlarından yerel Türkçe tarih/saat olarak gösterilir.

Liste → detay doğru ID’yi repository’ye geçirir. Cached liste temel bilgisi ilk çizimde kullanılabilir; detay yanıtı güncel başlık/açıklama/fotoğraf için esas alınır. `image_audit_regression_test.dart` iki ayrı durumda (liste URL’si null veya eski URL) güncel detay URL’sinin uygulanmasını ve açılmadan önce sıfır, açılınca tek detay isteği olmasını doğrular. Denetim aracının bütün kayıtları bir defa karşılaştırması production listeye N+1 istek eklemez.

Tek yüzeyli atmosferik düzen, sınırlı decode, düşük sigma blur, scrim, uzun SelectableText ve SafeArea korunur. Ayrı foreground fotoğraf eklenmedi. Görsel null/bozuk diye etkinlik bilgileri başarısız sayılmaz. `event_detail_widget_test.dart` geri dönüşte scroll/veri, nested kalp tıklaması, ortak favori state’i, küçük ekran/uzun metin ve Hero tag ayrımını doğrular.

## B. Arama ve kategori filtreleme

Repository gerçek `q` ve `category` parametrelerini Uri üzerinden encode eder; liste üzerinde yerel filtreyle sınırlı değildir. Canlı kontrol:

| Sorgu | HTTP | Total |
|---|---|---|
| `/categories` | 200 | 6 kategori |
| `q=flutter` | 200 | 3 |
| `category=Seminer` | 200 | 3 |
| `q=flutter&category=Workshop` | 200 | 2 |
| Benzersiz eşleşmeyen sorgu | 200 | 0 |

Simülatörde Figma araması + Workshop filtresi tek gerçek kaydı gösterdi. `discovery_repository_test.dart` Türkçe/boşluk/özel karakter encoding’ini; controller testleri 350ms debounce, eski yanıtların elenmesi ve kategori değişiminde page 1’i; widget testleri focus/header/keyboard ve temizleme/empty UI’ını kapsar. Kategori yükleme hatası ana listeyi kilitlemez.

## C. Kalıcı favoriler ve kullanıcı ayrımı

Bu denetimde gerçek mevcut kullanıcıyla daha önce favori olmayan `evt-011` kaydedildi. Detay, Keşfet ve Favoriler eşitlendi. Uygulama `simctl terminate` ile tamamen kapatıldı, `launch` ile yeni süreç açıldı; OTP yeniden gönderilmeden Hesabım ve üç favori geri geldi. `evt-011` veritabanından yeniden yüklenmiş halde `06-favorites-after-cold-start.png` içinde görülür. Ardından yalnızca QA sırasında eklenen kayıt kaldırıldı; önceki iki favori korundu.

Fake repository testi `controller yeniden oluşturulunca favorileri repository’den yükler` kalıcılık sözleşmesini ayrıca doğrular. Hızlı çift tıklama tek ekleme yapar; repository PK çakışmasını UPDATE yerine mevcut kayıtla çözer. Başarısız/offline ekleme başarı gibi gösterilmez; silme/refresh hatasında eski veri korunur. A çıkınca hemen temizleme, A’nın gecikmiş yanıtının B’ye uygulanmaması, hatalı kullanıcı yanıtının reddi ve SDK session kontrolü mevcut testlerde başarılıdır.

Canlı logout/yeni login ve iki gerçek kullanıcıyla izolasyon yapılmadı. Fake/MockClient A/B testleri yalnızca istemci korumalarına kanıttır. RLS’nin etkinliği/policy’lerin doğruluğu K bölümündeki manuel kabulün parçasıdır.

## D. Loading/error/empty

İlk liste/kategori/detay/favoriler skeleton’ları; pagination footer loading; gerçek/arama empty; 404/500/timeout/bağlantı/bozuk JSON; retry, refresh ve devam hatasında listeyi koruma testleri çalıştı. Gerçek API araması 500 verdi; uygulama Türkçe hata ve Tekrar dene kontrolü gösterdi (`04-live-error-retry.png`). Sonraki retry gerçek etkinliği getirdi.

### Hata 1 — Görsel fallback ikonu

`AdaptiveEventComposition` null/geçersiz/başarısız görsel için `image_not_supported_outlined` veya landscape ikonu çiziyordu. Son gereksinim ikonsuz nötr fallback istiyor. Dört yeni senaryo önce beklenen şekilde başarısız oldu. Yalnızca bu katman sabit nötr `ColoredBox` ile değiştirildi; scrim ve içerik geometrisi korundu. Liste zaten sabit boyutta ve ikonsuzdu. Null/boş/yanlış URL/failed decode, liste fallback ölçüsü ve güncel detay URL’si dahil **10 yeni görsel regresyonu** geçti.

### Hata 2 — İlk sayfa retry loading’i

`EventsController._fetchFirst` activity’yi initial’a alıp hata metnini temizliyor, önceki `EventsStatus.error` durumunu loading’e geçirmiyordu. Bekleyen retry sırasında eski hata başlığı kalıyordu. `loading_retry_audit_test.dart` önce `EventListSkeleton` bulunamadığı için başarısız oldu. `_page == 0` durumunda loading’e geçiş eklendi. Test şimdi hata → skeleton → başarılı sonuç akışını ölçer. `_page > 0` refresh/pagination’da görünür veriyi koruma davranışı değişmedi; ilgili regresyonlar da tekrar geçti.

API’nin kasıtlı gecikme/hatasını ortadan kaldırmak için backend değiştirilmedi. ApiClient, auth ve Supabase repository işlemlerinde 20 saniyelik timeout; kategori/OTP/onboarding/theme için mevcut guard ve dispose davranışları incelendi. Sonsuz otomatik retry eklenmedi.

## E. Public GitHub ve README

Repo public; local proje kökü `/Users/cigdemgokdas/Desktop/Etkinlikler`, branch main. Denetim başlangıcında çalışma ağacı temizdi; local HEAD ve public GitHub main aynıydı:

`0277ae4d98f5ecfa694da80c8ad574928e06048e — etkinlik detay sayfaları ui değişikliği`.

Dolayısıyla önceki motion/polish sürümü bu denetim başlamadan kullanıcı tarafından yayımlanmıştı. Mevcut denetimin iki düzeltmesi/testleri/belgeleri bunun üstünde yereldir; eski public sürüm yeni düzeltmeleri içeriyormuş gibi raporlanmadı. Reset/clean/rebase/force push veya geçmiş değiştiren işlem yapılmadı. Salt okunur denetim için ayrı geçici clone oluşturuldu.

### Gerçek temiz clone denemesi

Public repo geçici `/private/tmp/mobilab-clean-clone.fRpSBQ/Etkinlikler` klasörüne clone edildi; HEAD yukarıdaki SHA idi. Hiçbir kişisel config aktarılmadı. Şunlar başarılı oldu:

```sh
flutter pub get
flutter analyze
flutter test
flutter build ios --simulator --debug --no-codesign
```

Analiz temiz, **209/209 test**, iOS `Runner.app` build başarılı. Orijinal logo iOS app’in `flutter_assets` paketinde mevcut ve kaynak asset ile hash’i aynı. Clone’da `config/supabase.local.json` yok. Bu build yeni yerel düzeltmeleri değil, gerçek public commit’i doğrular. Yeni yerel sürüm ayrıca 220 testle doğrulandı.

Değerlendirici config olmadan girişsiz keşif/filtre/detay/tema akışını çalıştırabilir. Kalıcı favoriler için yapılandırılmış Supabase projesi, URL/publishable key ve gerçek OTP oturumu gerekir. README bu ayrımı, örnek JSON’u, Flutter sürümünü, iOS komutlarını, şema/policy referansının migration olmadığını ve production demo kullanıcı olmadığını açıklar. Mevcut README’nin bütün yerel link/PNG hedefleri bulundu; public HEAD’deki önceki hedefler de tracked idi. Yeni denetim linklerinin GitHub’da görünmesi için bu dosyalar yayınlanmalıdır.

## F. Sayfalama

Canlı API’de yalnızca 16 kayıt var; fazladan etkinlik üretilmedi. İlk 10 ve sonraki 6 kayıt, hasMore=false ve aynı ID’lerin korunması doğrulandı. `discovery_widget_test.dart` içindeki `%69 istek atmaz; %70 bir sonraki sayfayı tek kez başlatır, scroll korunur` testi sliver geometrisiyle geçti. Controller/repository testleri duplicate ID, pending koruması, total/hasMore, başarısız sayfanın ilerlememesi, aynı sayfa retry, arama/kategori reset ve en fazla üç viewport-fill isteğini kapsar. Önceki iPhone ikinci sayfa/collapse kanıtları [motion raporunda](../final-motion/rapor.md) korunur.

## G. Açık/koyu tema

`theme_screens_test.dart` iki tema için onboarding/auth/OTP/hesap/favoriler/detay/empty/error akışlarını; `theme_persistence_test.dart` kayıt, restore ve yarışları; `skeleton_loading_test.dart` loading yüzeylerini; `final_polish_test.dart` render’daki status bar stilini ve detay/auth dönüşlerini doğrular. Small-screen keyboard/search/filter testleri başarılıdır.

Cinematic detay iki temada da okunabilir koyu fotoğraf/scrim kimliğini kullanır; intro sabit açık marka zemini kullanır. Tema değiştirilerek tasarım yenilenmedi. Simülatörün denetim başındaki koyu tercihi korundu. Fiziksel cihazda erişilebilirlik/renk kabulü ayrıca yapılabilir.

## H. Animasyonlar

Orijinal logo hash’i ve asset yapılandırması korundu. `launch_motion_test.dart`: yeni root/cold start tekrar oynatma; rebuild, route/tab ve resume’de tekrarlamama; 360ms reduced motion; ticker dispose; onboarding active/completed sıralaması. `onboarding_test.dart` iki sayfa, atlama, kalıcılık ve kaydetme hatasını kapsar. `premium_navigation_test.dart` large/compact geometrisini, kontrollerin gizlenip geri gelmesini, focus ve keyboard/SafeArea’yı ölçer. Detay hâlâ 220/180ms fade, reduced motion’da sıfır süredir; ayrı foreground/Hero eklenmedi.

Bu denetimdeki gerçek cold start video kaydı AVFoundation ile karelere ayrılıp incelendi: küçük logo yaklaşması, büyümüş logo/impact/ince çatlak ve sonrasında Keşfet görüldü. `07`, `08`, `09` PNG’leri **gerçek Simulator video kareleridir**; widget golden’ı değildir. Kayıt zamanları native/JIT başlangıcını da içerir; 2.2 saniye Flutter intro controller süresidir, toplam debug process açılış süresi veya fiziksel cihaz performans ölçümü değildir. Animasyon koduna yeni efekt eklenmedi.

Kayıtlı onboarding tamamlandığından canlı cold start Intro → Keşfet oldu. İlk kullanım iki sayfa akışı bu denetimde widget testleriyle yeniden doğrulandı; kullanıcının tercih/oturumunu silerek temiz kurulum yapılmadı. Önceki debug FORCE_ONBOARDING simülatör kanıtı tarihî motion raporundadır.

## I. GitHub Actions CI

Workflow YAML Psych ile parse edildi. main push ve pull_request tetikleyicileri, Flutter 3.47.7 stable, pub get/analyze/test, 15 dakika sınırı, `contents: read` ve checkout credential persistence=false doğrulandı. CI testleri kişisel Supabase config/secret gerektirmez.

[40132592274 numaralı gerçek koşu](https://github.com/cigdem-gokdas/Etkinlikler/actions/runs/40132592274), HEAD **0277ae4**, `completed / success`. Jobs API’sinde Set up Flutter, Install dependencies, Analyze ve Test adımlarının her biri success. Önceki MVP koşusu 40122113134 de başarılıdır. Yeni denetim değişiklikleri push edilmediği için bunların online CI durumu **NOT VERIFIED**; yerel aynı komutların geçmesi ayrı kanıttır.

## J. API görsel denetimi

[Etkinlik bazlı fotoğraf tablosu](api-images.md) bütün 16 kaydı içerir. 15 benzersiz URL’ye gerçek GET atıldı; 14 HTTP 200 image/jpeg cevabı Flutter’da gerçekten decode edildi. Bir null kayıtta indirme isteği atılmadı; bir URL HTTP 400 text/plain döndü. HEAD hatası veya yalnızca uzantıdan hüküm verilmedi. Liste/detay farkı yok. Sahte fotoğraf/başka etkinliğin fotoğrafı/URL düzeltmesi eklenmedi.

`tool/audit_api_images.py` sınırlı canlı veri toplama aracıdır; `tool/audit_image_decode_test.dart` indirilen dosyaları gerçek Flutter codec’iyle kontrol eder. İkisi normal unit test koşusundan ayrıdır. Sunucu verisine yazmazlar. HTTP/decode/alan eksikliği ayrı sınıflandırılır; kaynak hatası gizlenmez.

## K. Supabase ve SMTP manuel testleri

Anonim SELECT yalnızca public istemci API key ile, kullanıcı/session token’ı olmadan denendi: **HTTP 401, PostgreSQL 42501**. Veri dönmedi. Bu sonuç anonim endpoint erişiminin reddini gösterir; tablodaki RLS flag’ini, etkin policy tanımlarını veya A/B izolasyonunu tek başına kanıtlamaz.

**BLOCKED — canlı iki hesaplı RLS:** İki yetkili test hesabı ve yönetim/policy okuma erişimi yok. Proje sahibi A ile kendi SELECT/INSERT/DELETE işlemlerini, B ile kendi kayıtlarını; çapraz erişim/silmeyi ve anon reddini normal kullanıcı oturumlarıyla kontrol etmelidir. Service-role ile test RLS kabulü değildir. Şema/policy/tabloya dokunulmadı.

**NOT VERIFIED — SMTP/OTP teslimi:** Yeni gerçek hesap oluşturulmadı ve kullanıcı adına e-posta gönderilmedi. Resend test göndericisi/alan adı/alıcı kısıtının güncel durumu Dashboard’dan doğrulanamadı. Kısıt sürüyorsa yeni değerlendirici hesabı giriş yapamaz; bu kritik manuel teslim riskidir. Yetkili yeni test adresine kod teslimi, yanlış/süresi dolmuş kod, resend/rate limit ve spam kontrolü kullanıcı tarafından yapılmalıdır. Bu nedenle “bütün harici servis kabulleri tamam” sonucu çıkarılmadı.

## L. Güvenlik ve Git durumu

Başlangıç HEAD/branch/remote doğrulandı; mevcut kullanıcı commit’i ve kaynaklar korundu. Commit/push/reset/clean/rebase/force push yapılmadı. Geçici temiz clone ana çalışma ağacının üzerine yazılmadı.

`config/supabase.local.json` ignored ve untracked; önceki yerel iOS düzeltmesinde kaydedilmiş SHA-256 ile aynı. Temiz clone bu dosyayı içermiyordu. Mevcut tracked/yeni metinlerde ve erişilebilir **3 revision** içinde private key, Supabase secret, Resend key ve JWT biçimli credential kalıpları aranıp sıfır bulgu elde edildi; değerler loglanmadı. Kalıp taraması bütün olası sırları kesin dışlamaz. Public istemci publishable key ile server secret ayrımı README’de açık.

Ekranlarda kişisel e-posta/OTP/token yok; yalnızca public etkinlik içeriği, marka ve oturumun adsız kontrol durumu görünür. QA sırasında eklenen favori kaldırıldı; önceki kullanıcı favorileri, oturumu ve tema tercihi korundu.

## M. iPhone 17 gözlemleri

Orijinal Etkinlikler klasöründen iPhone 17 / iOS 26.3 Simulator’da debug build/launch başarılı. Geçerli API fotoğrafları, gerçek null ve bozuk URL detayları, ikonsuz fallback, arama+kategori, 500/retry, favori ekleme/eşitleme/süreç sonrası kalıcılık/silme ve cold start kaydı gözlendi. Son iki küçük düzeltme derlenmiş normal uygulamada bırakıldı.

| Görüntü | Gözlem |
|---|---|
| `01-null-image-dark.png` | evt-007 null; ikon yok, bilgiler okunabilir |
| `02-search-category.png` | Figma + Workshop birleşik sunucu filtresi |
| `03-broken-image-dark.png` | evt-015 HTTP 400; ikon yok, detay kullanılabilir |
| `04-live-error-retry.png` | Gerçek API 500 ve çalışan retry kontrolü |
| `05-favorites-before-restart.png` | QA eklemesi dahil, kapatma öncesi üç kayıt |
| `06-favorites-after-cold-start.png` | Yeni süreçte veritabanından aynı kayıtlar/oturum restore |
| `07-cold-start-approach.png` | Gerçek videodan küçük logo yaklaşması |
| `08-cold-start-impact.png` | Gerçek videodan impact ve ince fracture |
| `09-cold-start-explore.png` | Intro sonrası Keşfet |

Yeni gerçek OTP login/logout ve iki hesaplı test yapılmadı. %70 kesin sınırı widget testinde, gerçek ikinci sayfa önceki ve bu oturumdaki liste gözlemlerinde doğrulanır. Fiziksel iPhone ve Android cihaz testi yapılmadı; Android SDK kurulu değil. Native parmak gesture/FPS kabulü unit test başarısından çıkarılmadı.

## N. AI kullanım açıklamasının yeterliliği

README yalnızca kullanılan gerçek AI aracı Codex’i ve gerçek doğrulama araçlarını belirtir. Kullanıcının Flutter/Supabase/OTP/gerçek fotoğraf/%70/minimal tasarım/tek yüzeyli detay/floating nav/reduced motion kararları ile mevcut mimariyi koruyan teknik uygulama tercihleri ayrılır. Feature-first ve ChangeNotifier/repository gerekçesi, skeleton ve image stream/cache sınırları açıklanır. Bu görüşmedeki gerçek istemlerden üç kısa alıntı kullanılır; yeni tarihsel istem uydurulmaz.

Test koruma, fake fotoğraf/auth bypass yapmama, servis/Git geçmişini değiştirmeme ve doğrulanmayanı başarı saymama kuralları; çıktıların test/simülatörle nasıl düzeltildiği; gerçek status bar/SafeArea/codesign ve bu denetimin iki hatası belgelenir.

## Son komut sonuçları ve değişiklik kapsamı

| Kontrol | Sonuç |
|---|---|
| Başlangıç pub get / analyze / test | Başarılı / temiz / **209 test** |
| İkon/fallback regresyonunun ilk çalışması | **4 FAIL** ile sorun yeniden üretildi |
| İlk retry loading regresyonunun ilk çalışması | **1 FAIL** ile sorun yeniden üretildi |
| Hedefli görsel regresyonları | **24/24 PASS** |
| Retry + discovery + skeleton regresyonları | **33/33 PASS** |
| Son pub get / analyze / test | Başarılı / **No issues found / 220 test PASS** |
| Canlı indirilen dosyaların Flutter decode yardımcısı | **1/1 PASS**, normal 220’ye dahil değil |
| Gerçek public temiz clone | Analiz temiz / **209 test PASS / iOS build PASS** |
| Orijinal klasörde son native build/launch | Başarılı |
| Workflow YAML | Geçerli |
| Public commit’in online CI’ı | **success**, SHA eşleşiyor |
| Son `git diff --check` | Temiz |

Production kaynak değişikliği yalnızca iki dosyadır: `events_controller.dart` ilk sayfa retry loading geçişi ve `adaptive_event_composition.dart` ikonsuz fallback. Mevcut görsel testlerinin ikon beklentisi gereksinime göre güncellendi; test silinmedi. Yeni `image_audit_regression_test.dart` (10 senaryo), `loading_retry_audit_test.dart` (1 senaryo), iki canlı denetim yardımcısı ve bu belgeler eklendi. Dependency, auth/RLS veya etkinlik verisi değiştirilmedi.
