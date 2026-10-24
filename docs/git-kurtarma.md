# Eksik Git metadata için güvenli kurtarma yönergesi

> **Güncel durum — 24 Ekim 2026:** Kullanıcı ayrı `Etkinlikler-git-kurtarma` klonunu oluşturup dosyaları aktardı ve stage etti. Bu klonda geçmiş, aktarım, secret taraması, 180 test ve analiz doğrulandı. Aşağıdaki metin önceki metadata kaybı için hazırlanmış tarihî rehberdir; mevcut klonda tekrar uygulanması gerekmiyor. Güncel doğrulamalar ve kalan manuel kabul adımları [README](../README.md) içindedir.

Bu yönergedeki yedek/clone/aktarım komutları Codex tarafından çalıştırılmadı. Asıl proje `/Users/cigdemgokdas/Desktop/Etkinlikler`; `.git` bu dizinde hâlâ yok. `/private/tmp` test kopyaları tam proje veya Git geçmişi yedeği değildir. Orijinal dizini değiştirmeden, aşağıdaki planı inceleyip açıkça onayladıktan sonra ilerleyin.

## 1. Tam yerel yedek

Önce editörde kaydedilmemiş dosyaları kaydedin. Finder ile asıl klasörün tamamını ayrı, yerel bir klasöre çoğaltabilirsiniz. Terminal alternatifi (zsh):

```sh
source_dir="/Users/cigdemgokdas/Desktop/Etkinlikler"
umask 077
backup_dir="$(mktemp -d "$HOME/Desktop/Etkinlikler-yedek.XXXXXX")"
COPYFILE_DISABLE=1 rsync -rlt "$source_dir/" "$backup_dir/"
ls -la "$backup_dir"
```

Yedek yerel config ve diğer özel dosyaları da içerir; GitHub'a yüklemeyin. Önemli dosyaları yedekten açıp kontrol edin. Bu adım Git geçmişini üretmez; mevcut dosyaları korur. Kaynak veya yedek üzerinde silme/temizleme yapmayın.

## 2. Remote adresini kullanıcı olarak doğrulayın

Önceki oturumlarda okunan ve salt okunur erişimde mevcut bulunan adres:
[github.com/cigdem-gokdas/Etkinlikler](https://github.com/cigdem-gokdas/Etkinlikler).

GitHub'da doğru hesabı/repository'yi açıp bu adresin size ait doğru hedef olduğunu doğrulayın. Önceki görülen HEAD `0010faf` idi; adres/branch değişmişse varsayım yapmayın. URL içine token veya parola koymayın.

## 3. Yalnızca ayrı, boş klasöre clone

Yedek ve adres doğrulamasından ve kullanıcı onayından sonra:

```sh
remote_url="https://github.com/cigdem-gokdas/Etkinlikler.git"
recovery_dir="$(mktemp -d "$HOME/Desktop/Etkinlikler-kurtarma.XXXXXX")"
git clone -- "$remote_url" "$recovery_dir"
git -C "$recovery_dir" remote -v
git -C "$recovery_dir" log -5 --oneline
git -C "$recovery_dir" status --short
```

Asıl proje yolunu clone hedefi olarak kullanmayın. Clone içindeki `.git` klasörünü asıl projeye kopyalamayın. Remote farklıysa yukarıdaki URL'yi ancak doğruladığınız değerle değiştirin. Clone, sunucudaki geçmişi getirir; kayıp yerel branch/stash veya push edilmemiş commit'leri kurtardığı anlamına gelmez. Bunlar için varsa ayrıca eski disk/Time Machine yedeği araştırılmalı.

## 4. Salt okunur karşılaştırma

Önce clone edilmiş ağacın geçmişini ve README'sini inceleyin. Ardından aktarılacak dosyaların yalnızca önizlemesini alın:

```sh
COPYFILE_DISABLE=1 rsync -rltni \
  --exclude=.git --exclude=build --exclude=.dart_tool \
  --exclude=.idea --exclude=.DS_Store --exclude=Pods \
  --exclude=.symlinks --exclude=ephemeral \
  --exclude=.flutter-plugins-dependencies --exclude='*.log' \
  --exclude='/config/supabase.local.json' --exclude='.env*' \
  --exclude='*.pem' --exclude='*.p12' --exclude='*.p8' \
  "$source_dir/" "$recovery_dir/"
```

`-n` sayesinde bu komut dosya yazmaz; `--delete` içermez. Değişen ortak dosyaların içeriğini karşılaştırın. Örnek:

```sh
git diff --no-index -- "$recovery_dir/README.md" "$source_dir/README.md"
```

Diff'in exit 1 vermesi fark bulunduğu anlamına gelir. Kaynakta yeni olup clone'da olmayan dosyaları da editörde açarak inceleyin. Secret dosyaları dışında farklı adla tutulmuş anahtar/özel dosyalar olup olmadığını ayrıca değerlendirin; exclude listesi bütün olası secret türlerini tanıyamaz.

## 5. Kontrollü aktarım planı — onay noktası

İncelemede doğrulanan `lib/`, `test/`, `tool/`, gerekli platform kaynakları, `pubspec.yaml`/lock, örnek config, `.gitignore`, workflow ve belgeler için bir aktarım listesi çıkarın. Mevcut clone dosyalarının üzerine yazılacak her farkı gözden geçirin. Asıl proje yerinde kalmalı; dosya taşıma veya kaynak silme yapılmamalı.

**Bu liste ve karşılaştırma onaylanmadan dry-run komutundaki `n` seçeneğini kaldırmayın.** Onaydan sonra yalnızca onaylanan dosyalar kopyalanır. `.git`, yerel config, servis anahtarları ve özel dosyalar aktarılmaz. `git init`, reset/clean veya geçmişi zorla değiştirme gerekmez. Bilinmeyen remote değişikliklerinin üzerine yazmayın.

## 6. Geçmiş, secretsiz test ve CI kontrolü

Aktarım sonrasında, clone edilmiş çalışma ağacında:

```sh
cd "$recovery_dir"
git status --short --untracked-files=all
git diff --check
git diff --stat
git check-ignore -v config/supabase.local.json
git ls-files config/supabase.local.json
flutter pub get
flutter analyze
flutter test
```

`git ls-files config/supabase.local.json` boş olmalı. Tracked farkları ve yeni untracked dosyaları ayrı ayrı inceleyin; toplu stage işleminden önce secret kontrolünü bitirin. Testler gerçek Supabase anahtarı gerektirmez. Uygulamayı gerçek yerel ayarla denemek için config'i clone'a kopyalamak yerine dışarıdaki dosyaya referans verilebilir:

```sh
flutter run -d "iPhone 17" --dart-define-from-file="$source_dir/config/supabase.local.json"
```

Son commit/push işlemini kullanıcı incelemesinden sonra kendiniz yapın. GitHub Actions'ın main push / pull request koşularını açıp analyze ve test adımlarının gerçekten geçtiğini görün. Yerel YAML doğrulaması GitHub koşusunun yerine geçmez. Her şey doğrulanana kadar asıl proje ve yedeği koruyun.
