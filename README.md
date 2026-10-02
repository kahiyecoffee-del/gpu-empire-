# GPU Empire

Bir garajda tek GPU ile başlayıp dünyanın en büyük yapay zeka altyapı şirketini kurduğunuz idle tycoon mobil oyunu.

Projenin ana referansı: [`GAME_BRIEF.md`](GAME_BRIEF.md). Kapsam dışı fikirler: [`IDEAS.md`](IDEAS.md).

## Oyunu denemek

Her push'ta GitHub Actions oyunu derler. Varsayılan dala gelen her değişiklik web sürümü olarak yayınlanır:

**https://kahiyecoffee-del.github.io/gpu-empire-/**

iPhone'da Safari ile açın. Paylaş → "Ana Ekrana Ekle" ile tam ekran uygulama gibi çalışır. Ekranın altındaki "Sürüm" etiketi, açtığınız derlemenin hangi commit olduğunu gösterir.

Android APK her CI çalışmasında `gpu-empire-apk` adıyla Actions sekmesine yüklenir (14 gün saklanır).

## Geliştirme

- Flutter stable (CI'da sürüm `.github/workflows/ci.yml` içinde sabitli), Dart, Riverpod.
- Klasörler:
  - `lib/core/`: BigNumber ve ekonomi motoru (saf Dart, Flutter'a bağımlı değil)
  - `lib/game/`: oyun sistemleri
  - `lib/ui/`: ekranlar ve widget'lar
  - `lib/services/`: kayıt, reklam, analitik, satın alma
  - `lib/l10n/`: çeviri dosyaları (`app_en.arb`, `app_tr.arb`)
  - `assets/config/economy.json`: tüm ekonomi sayıları
  - `tool/`: ekonomi simülatörü gibi komut satırı araçları

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Lisanslar

Inter yazı tipi SIL Open Font License 1.1 ile kullanılmaktadır (`assets/fonts/OFL.txt`).
