# Canlı API fotoğraf denetimi — 25 Ekim 2026

Kaynak: [MOBILAB API](https://mobilab-task-api.vercel.app/docs). Canlı `GET /events?page=1&limit=10` ve page 2 alındı; 10 + 6 = **16 benzersiz etkinlik**, `total=16`, son `hasMore=false`. Her etkinliğin `GET /events/{id}` yanıtı ayrıca karşılaştırıldı. İki sayfa ve 16 detay isteği HTTP 200 döndü. Sayfa döngüsü ilerleme yoksa veya en fazla 20 sayfada durur; canlı istekler 18 saniye timeout, en fazla iki deneme, en fazla iki paralel bağlantı ve 8 MiB dosya sınırı kullanır.

**Sonuç: 14 geçerli fotoğraf, 1 null fotoğraf (A), 1 bozuk URL (B).** Boş string veya eksik imageUrl alanı yok. Liste–detay farkı (D) yok. Uygulama kaynaklı görünmeme (C) tespit edilmedi: 14 HTTP 200 JPEG dosyasının tamamı gerçek Flutter codec’iyle 800×450 piksele çözüldü; simülatörde geçerli görsel ve iki fallback örneği ayrıca incelendi. Bu, 14 fotoğrafın tamamı için fiziksel cihaz testi yapıldığı anlamına gelmez.

Yalnızca HEAD kullanılmadı: redirect takip eden kontrollü GET ile dosya indirildi; HTTP kodu, Content-Type ve `ui.instantiateImageCodec` / `getNextFrame()` sonucu birlikte değerlendirildi. HTTP 200 HTML olsaydı decode geçerli sayılmayacaktı. Bozuk 400 yanıtı decode edilmedi; 200 olmayan cevabı resim gibi göstermeye çalışmak başarı sayılmadı.

| Event ID | Başlık | Liste imageUrl | Detay imageUrl | HTTP/Decode durumu | Neden | Uygulama davranışı |
|---|---|---|---|---|---|---|
| evt-012 | Sky Lab Tanışma Kahvaltısı | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-001 | Flutter ile İlk Uygulamanı Yayınla | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-005 | Git ve GitHub: Takımla Çalışmanın Temelleri | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-010 | Python ile Veri Analizine Giriş | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-002 | GECEKODU | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-003 | AI Destekli Geliştirme: Prompt'tan Ürüne | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-015 | Web Geliştirme: Next.js ile Hızlı Başlangıç | Var · `450.invalid` son eki | Var · `450.invalid` son eki | 400 · text/plain; charset=utf-8 · decode edilmez | B — görsel sunucusu HTTP 400 | İkonsuz nötr fallback; etkinlik ekranı çalışır |
| evt-004 | Kariyer Sohbetleri: Mobil Sektöründe İlk Yıl | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-011 | Flutter'da State Management: Kavramlar, Paketler Değil | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-006 | Siber Güvenlik CTF Gecesi | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-007 | Figma'dan Flutter'a: Tasarımcı ve Geliştirici Aynı Masada | null | null | İstek yok — kaynak fotoğraf yok | A — API verisi null | Listede sabit nötr alan; detayda ikonsuz nötr yüzey; bilgiler/geri/favori kullanılabilir |
| evt-016 | Teknofest Bilgilendirme Toplantısı | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-008 | Oyun Geliştirme Jam'i: 48 Saatte Bir Oyun | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-009 | Startup Fikrinden MVP'ye: Kampüsten Çıkan Girişimler Anlatıyor ve Sorularınızı Yanıtlıyor | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-013 | Açık Kaynağa İlk Katkı | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |
| evt-014 | Demo Günü: Bu Dönem Ne Yaptık? | Var · HTTPS | Var · HTTPS | 200 · image/jpeg · Flutter 800×450 | Geçerli | Gerçek API fotoğrafı; detayda tek atmosferik yüzey |

## Eksik fotoğrafların kesin nedeni

- **evt-007 — Figma'dan Flutter'a: Tasarımcı ve Geliştirici Aynı Masada:** Liste ve detay `imageUrl: null`. Flutter’ın yükleyebileceği gerçek fotoğraf yok. API verisi değiştirilmedi, başka fotoğraf eklenmedi.
- **evt-015 — Web Geliştirme: Next.js ile Hızlı Başlangıç:** Liste ve detay aynı geçersiz Picsum URL’sini veriyor; `/800/450.invalid` yolu tam GET isteğinde **HTTP 400**, `text/plain; charset=utf-8` döndürüyor. Bu Flutter decode/cache hatası değil, bozuk kaynak URL’sidir. URL uydurularak düzeltilmedi.

## Uygulama düzeltmesi

Önceki adaptive detay fallback’i null/hata durumunda `image_not_supported_outlined` ikonu çiziyordu. Yeni gereksinimin ikonsuz fallback kuralına aykırıydı. Dört regresyon senaryosunda önce hata üretildi; yalnızca ikon katmanı sabit nötr ColoredBox ile değiştirildi. Listede zaten ikon yoktu. Renk/scrim, tek yüzey tasarımı ve içerik geometrisi korundu. Null, boş, geçersiz URL, başarısız image stream ve listeden farklı güncel detay URL’si internetsiz testlerle doğrulanır.

## Yeniden çalıştırma

Bu canlı denetim CI/unit testlerinden ayrıdır. Gerçek servise sınırlı GET gönderir; sunucu veya Supabase verisini değiştirmez. Ham dosyalar ve manifest yalnızca belirtilen geçici klasöre yazılır.

```sh
python3 tool/audit_api_images.py --output /private/tmp/mobilab-api-image-audit
flutter test tool/audit_image_decode_test.dart --dart-define=AUDIT_MANIFEST=/private/tmp/mobilab-api-image-audit/manifest.json
```

Decode denetimi: **1/1 başarılı**; bu entegrasyon yardımcısı normal `flutter test` sayısına dahil değildir. Son kullanıcı gözlemleri ve genel gereksinim matrisi [ana raporda](rapor.md).
