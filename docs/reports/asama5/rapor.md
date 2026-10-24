# MOBILAB / SKYLAB — Aşama 5

> **Tarihî aşama kaydı:** Bu rapor kurtarma klonu oluşturulmadan önceki durumu anlatır. Kullanıcı daha sonra projeyi ayrı `Etkinlikler-git-kurtarma` klonuna aktardı. Güncel Git, test ve teslim durumu [README](../../../README.md) içindedir.

24 Ekim 2026. Ortak statik skeleton sistemi tamamlandı. **180/180 test başarılı, flutter analyze temiz.** Mevcut mimari ve işlevler korundu. Git metadata eksikliği çözülmedi; otomatik commit/push veya kurtarma yapılmadı.

## 1. Oluşturulan bileşenler

`lib/core/widgets/skeleton.dart`:

- SkeletonBlock: tema renkli, 4/8px köşeli, statik nötr alan.
- EventRowSkeleton: 96px kapak, tarih, iki başlık satırı, konum/kategori geometrisi.
- EventListSkeleton: Keşfet/Favoriler için üç satır ve tek yükleme semantiği.
- EventDetailSkeleton: 16:9 görsel, başlık/tarih/konum/açıklama; mevcut Event için yalnızca açıklama varyantı.
- CategorySkeleton: yatay üç kategori placeholder'ı.

Yeni diğer dosyalar: `test/skeleton_loading_test.dart`, `tool/skeleton_preview.dart`, `docs/git-kurtarma.md`, bu rapor ve 10 PNG.

## 2. Değiştirilen ekranlar

Keşfet, detay, Favoriler ve ortak EventImage yükleme görünümü bağlandı. README güncellendi. `test/widget_test.dart` ve `test/auth_favorites_widget_test.dart` içindeki iki ilk-yükleme spinner beklentisi skeleton'a uyarlandı; senaryolar korundu. Hiçbir eski test dosyası silinmedi.

Controller'lar, auth/OTP, Supabase repository'leri, ana giriş, navigation ve dependency dosyaları değiştirilmedi. Yeni paket eklenmedi. Liste, query/category generation, %70 pagination ve ortak FavoritesController aynı kaldı.

## 3. Tasarım kararları

AppTheme `surfaceContainerHighest` rengi kullanılır. Açık temada çok açık gri, koyuda hafif ayrılan koyu gri. Shimmer/gradient/animasyon/overlay yok. Fotoğraf ölçüsü ve 8px spacing korunur. Placeholder'lar IgnorePointer/ExcludeSemantics ile etkileşimsizdir; her blok ayrı içerik gibi okunmaz. Alan başına tek anlamlı loading etiketi vardır. Reduced motion davranışı korunur.

320px, iPhone'a yakın 402px ve geniş Chrome'a karşılık gelen 1440px ölçüler iki temada widget testinde doğrulandı. Bu, gerçek Chrome oturumunda görsel test yapıldığı anlamına gelmez.

## 4. API loading davranışı

İlk liste isteğinde üç satır skeleton; ilk kategorilerde Tümü aktif kalırken üç placeholder. Arama yazılırken eski sonuçlar gizlenir, mevcut 350ms debounce tamamlanmadan skeleton ağacı başlatılmaz. İstek başladığında const statik skeleton kullanılır. Frame öncesinde biten hızlı yanıt testinde skeleton flaşı yoktur; ek timer/cache katmanı eklenmedi.

Detayda mevcut Event varsa gerçek başlık/görsel URL'si ve bilgiler hemen kalır, yalnızca eksik açıklama yüklenir. Event yoksa tam detay skeleton'ı kullanılır. Aynı Hero tag iki kez oluşturulmaz. Fotoğrafın decode/load sürecinde sabit boyutlu placeholder vardır; gerçek URL/key/cache genişlikleri değiştirilmedi.

Pagination beklerken gerçek liste ve scroll korunur; mevcut küçük footer spinner'ı kalır. Hata footer retry'a döner. hasMore false olduğunda yükleme footer'ı yoktur. Favori mutation sırasında yalnızca kalp pending'dir; tüm ekran skeleton olmaz. OTP buton loading'i korundu, tam sayfa skeleton eklenmedi.

## 5. Hata / empty / loading ayrımı

Empty ve hata skeleton'a dönüştürülmez. 404 ve genel detay hatası yükleme görünümünü kaldırır; retry tekrar gerçek isteği başlatır. Kategori hatası listeyi kilitlemez. Girişsiz Favoriler giriş çağrısı; girişli ilk fetch skeleton; başarılı boş yanıt empty; hata gerçek mesaj gösterir. Kullanıcı değişiminde eski favoriler hemen temizlenir ve eski yanıtlar mevcut generation kontrolüyle uygulanmaz.

## 6. Test sayısı

Başlangıçtaki 158 test geçti. 22 test eklendi; son tam paket:

```text
00:08 +180: All tests passed!
```

Kapsam: ilk yükleme→EventRow, empty/error/retry, kategori loading/error, debounce/stale/instant yanıt, pagination liste/konum/retry/hasMore, detay tam/cached skeleton ve 404/503, signedOut/A-B favori geçişi ve mutation, tek semantics etiketi, etkileşimsizlik/statik durum, iki tema ve üç ekran genişliği, null/bozuk görselin boyutu ve URL'si.

Bütün unit/widget testleri fake/controllable response kullanır. Canlı Supabase'e/e-postaya bağlanmaz. Önceki 158 senaryo korunur; iki eski assertion istenen yeni görünümü kontrol edecek şekilde değişti.

## 7. Analiz

`flutter pub get` başarılı. Flutter 3.47.7 stable / Dart 3.13.5:

```text
No issues found! (ran in 2.4s)
```

Yeni dependency veya üretim gecikmesi yok. GitHub Actions workflow'u değiştirilmedi ve GitHub'da çalıştırılmadı.

## 8. iPhone 17 sonucu

Önceki Desktop Xcode status 255 kısıtı nedeniyle mevcut `/private/tmp/mobilab-ios-validation` kaynak kopyası kullanıldı. Yeni proje oluşturulmadı. Üretim Dart dosyaları, debug giriş dosyası ve pubspec/lock karşılaştırmasında fark yok; local config kopyası aynı. iPhone 17 / iOS 26.3 üzerinde iki ayrı giriş çalıştırıldı:

| Giriş | Doğrulanan |
| --- | --- |
| Debug `tool/skeleton_preview.dart` | Gerçek API yanıtına 30sn yerel gecikme; fake auth/bellek favorileri. Açık/koyu Keşfet ve Favoriler skeleton'ı, tam detay skeleton'ı, gerçek API liste/detay verisine geçiş, gerçek null görsel placeholder'ı. Kategori hata/retry alanı da görüldü. |
| Normal `lib/main.dart` + yerel config | Yapay gecikmesiz gerçek liste/fotoğraflar, üç sonuçlu flutter araması, iki sonuçlu Workshop birleşimi, cached detay/açıklama yükleme geçişi ve tam gerçek açıklama/fotoğraf, geri navigasyonu. |

Debug önizleme Supabase'e bağlanmaz, e-posta göndermez, session/tema tercihini diske yazmaz. Görülen favori loading'i canlı Supabase testi değildir. Preview'da tek gerçek kamuya açık evt-007 kaydı bellek favorisine dönüştürülür; üretimde sahte kayıt veya gecikme yoktur. Normal girişte gerçek login/favori DB işlemi yapılmadı.

Skeleton ekranlarında taşma, aşırı parlama veya spinner tekrarı görülmedi. Native kaydırma otomasyonu bu aşamada görünür ilerleme vermedi; %70 boundary/pagination loading sonucu widget testlerinde geçti. Bu aşamada native pagination yeniden ölçülmüş sayılmıyor. Gerçek Chrome/fiziksel cihaz/Android koşusu ve FPS profil ölçümü yapılmadı.

Görüntüler:

- [01 Açık Keşfet loading — debug](01-kesfet-loading-debug.png)
- [02 Açık Favoriler loading — debug](02-favoriler-loading-debug.png)
- [03 Koyu Favoriler loading — debug](03-favoriler-loading-koyu-debug.png)
- [04 Koyu Keşfet loading — debug](04-kesfet-loading-koyu-debug.png)
- [05 Gerçek API liste verisi — debug adaptör](05-kesfet-loaded-debug.png)
- [06 Açıklaması yüklenmiş koyu detay, null görsel placeholder’ı — debug](06-detay-loading-koyu-debug.png)
- [07 Gerçek detay verisine geçiş — debug adaptör](07-detay-loaded-debug.png)
- [08 Normal canlı Keşfet](08-kesfet-live.png)
- [09 Normal canlı detay](09-detay-live.png)
- [10 Normal canlı arama + kategori](10-arama-filtre-live.png)

Görüntülerde kişisel e-posta/OTP/token yoktur. 01–04 liste/Favoriler skeleton’larını, 05–07 gerçek verinin debug adaptöründeki görünümünü gösterir; gerçek auth/RLS kabul kanıtı değildir. Son görsel denetimde 06 numaralı PNG’de açıklamanın zaten yüklendiği görüldü. Dosya adındaki “loading” tarihî adlandırmadır; nötr fotoğraf alanı null API görselinin placeholder’ıdır. Bu PNG tam detay skeleton’ını kanıtlamaz. Tam ve cached detay skeleton durumları widget testleriyle doğrulanır; yukarıdaki native gözlem kaydı ayrı değerlendirilmelidir.

## 9. Git metadata durumu

Asıl kök salt okunur tekrar kontrol edildi: `.git` dosyası/dizini bulunamadı; normal/mutlak Git komutları repository tespit edemiyor. Başka projeden metadata kopyalanmadı; init/reset/clean, clone/taşıma/geçmiş kurtarma, commit/push yapılmadı. `.gitignore` ve yerel config korundu. Son tracked/staged/geçmiş güvenliği metadata olmadan doğrulanamaz. 176 kaynak/ayar/belge dosyası yerel gerçek bağlantı değerleri ve yaygın secret biçimleri için değerler gösterilmeden tarandı; olası eşleşme bulunmadı. Bu sezgisel tarama Git geçmişi denetiminin yerini tutmaz. Public GitHub teslimi hâlâ engelli.

[Güvenli kurtarma yönergesi](../../git-kurtarma.md): tam yerel yedek, kullanıcıyla gerçek remote doğrulama, ayrı boş klasöre clone, salt okunur karşılaştırma, secret hariç dry-run aktarım planı ve açık onay noktası; ardından geçmiş/test/CI kontrolü. Bu rehberdeki kurtarma komutları çalıştırılmadı. Önceki geçici kaynak kopyaları tam Git kurtarma yedeği sayılmıyor.

## 10. Çözülmemiş canlı servis testleri

Gerçek OTP teslimi/spam, yanlış/süresi dolmuş kod, session restore/çıkış, hesap bazlı Supabase favori kalıcılığı ve canlı RLS hâlâ kullanıcıyla test edilmeli. SMTP deliverability servis tarafı konudur; Flutter'da çözülmüş gösterilmedi. GitHub Actions gerçek koşusu, metadata kurtarıldıktan ve kullanıcı push'undan sonra doğrulanmalı.

## 11. Kullanıcının manuel adımları

1. Normal girişle uygulamayı config parametresiyle açın. İlk/gecikmeli loading, gerçek veriye dönüş, kategori hata/retry ve arama temizlemeyi inceleyin.
2. Tümü listesinde aşağı kaydırın; %70 civarında devam yüklenirken mevcut liste/konum korunmalı. Hata footer'ı aynı sayfayı tekrar deneyebilmeli.
3. Keşfet ve Favoriler'den detay açın. Bilinen başlık/görsel kaybolmamalı; açıklama tamamlanmalı. Null/bozuk fotoğraf ve uzun içerikte taşma olmamalı.
4. Kendi hesabınızla gerçek OTP/session/favori/RLS kabul adımlarını uygulayın. Debug önizleme sonucu bunların yerine geçmez.
5. Git rehberini inceleyin; yedek/remote doğrulama ve karşılaştırma onayı olmadan kurtarma/aktarım yapmayın. Secret kontrolü tamamlanmadan public push yapmayın.

Bu aşamada duruldu. Kullanıcı kontrolü/onayı bekleniyor.
