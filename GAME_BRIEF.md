# Proje Brifi: "GPU Empire" (çalışma adı) — Idle AI Veri Merkezi Tycoon

Sen bu projede baş geliştiricimsin. Benimle birlikte Google Play'e (sonra App Store'a) çıkacak, ödüllü reklamla para kazanan, global pazar için bir **idle tycoon mobil oyunu** geliştireceksin. Bu dosya projenin ana referansıdır; her aşamada buna sadık kal ve karar değiştikçe güncelle.

---

## 1. Hedef ve başarı kriterleri

- Global kitle (öncelik ABD, Avrupa), 13+ genel kitle. **Çocuklara yönelik değil.**
- Gelir modeli: **ödüllü reklam (ana gelir)** + düşük sıklıkta geçiş reklamı + "Reklamları kaldır" ve başlangıç paketi satın alımları.
- Hedef metrikler: 1. gün tutma %35+, 7. gün %10+, ortalama oturum 8+ dakika, günde 3+ oturum.
- Pazardaki rakiplerin (AI Empire, Idle Data Center Tycoon) ortak zayıflığı **bozuk ekonomi dengesi** (kazanç, yükseltme maliyetine yetişmiyor). Bizim farkımız: **pürüzsüz, tatmin edici ilerleme hissi.** Ekonomiyi en ciddi iş olarak ele al.

## 2. Oyun özeti

Oyuncu bir garajda tek bir GPU ile başlar ve dünyanın en büyük yapay zeka altyapı şirketini kurar.

**Çekirdek döngü:**
1. Sunucu rafları **Compute** üretir.
2. Compute, AI modellerini eğitir ve müşterilere API olarak satılır, yani **$** kazandırır.
3. $ ile raflar yükseltilir, yenileri alınır, kısıtlar açılır.
4. Kısıtlar: **Elektrik (MW)** ve **Soğutma**. Kapasite aşılırsa sistem **throttle** olur (üretim düşer). Bu, oyuncuya basit ama anlamlı bir denge kararı verir.

**Üretim hatları (ilk veri merkezi için 6 adet, sırayla açılır):**
Eski GPU → Oyun GPU'su kümesi → Veri merkezi GPU'su → TPU podu → Süper bilgisayar → Kuantum hızlandırıcı

**Yöneticiler:** Her hattı otomatikleştirir ve bonus verir (ör. "Baş Mühendis: Soğutma maliyeti −%20").

**Lokasyonlar (ilerleme haritası):** Garaj → Depo → Kampüs → Hiperölçek Merkez (İzlanda, soğuk iklim bonusu) → Okyanus Altı Merkez → Yörünge Veri Merkezi. Her lokasyon yeni bir "dünya"dır, ilerleme çarpanı taşır.

**Prestij: "Halka Arz (IPO)"**
- Oyuncu şirketi halka arz eder, her şey sıfırlanır, karşılığında **Hisse (Shares)** kazanır.
- Hisseler kalıcı global çarpan verir ve **Yatırımcı Yetenek Ağacı**'nda harcanır.
- Formül önerisi: `shares = floor(k * (toplam_kazanç / 1e6) ^ 0.5)`. Simülasyonla ayarla.

**Diğer sistemler:** Çevrimdışı kazanç (başlangıçta 2 saat sınırlı, yükseltilebilir), günlük giriş ödülleri, 4 saatte bir şans çarkı, kilometre taşı görevleri, rastgele olaylar ("Viral AI ürünü: 60 sn ×10 talep!").

## 3. Ekonomi tasarımı (en kritik bölüm)

- Tüm sayılar **tek bir yapılandırma dosyasında** (ör. `assets/config/economy.json`). Kodda sihirli sayı yok.
- Maliyet: `cost(n) = base_cost * growth^n` (growth hat başına 1.07–1.15).
- Üretim: `income = base_income * level * çarpanlar`. Seviye 25, 50, 100, 200…'de kilometre taşı çarpanları (×2, ×3).
- Büyük sayılar: idle oyunlar 1e300'ü geçer. **Mantissa + üs tabanlı bir BigNumber sınıfı** yaz; gösterim: K, M, B, T, sonra aa, ab, ac…
- **Ekonomi simülatörü yaz** (Dart CLI veya test): "optimal oynayan" bir botla zamanı simüle etsin ve şunları raporlasın: her hattın açılma süresi, her lokasyona varış süresi, ilk IPO süresi.
- Hedef tempo:
  - İlk 60 saniyede ilk yükseltme, ilk 5 dakikada 3 hat açık.
  - İlk IPO ~60–90 dakika aktif oyun.
  - Oyuncu hiçbir zaman 2–3 dakikadan uzun süre "yapacak bir şey yok" hissine düşmesin.
- Simülatör çıktısını her ekonomi değişikliğinden sonra çalıştır ve bana tablo olarak göster.

## 4. Para kazanma

**Ödüllü reklam anları (oyuncu kendi seçer):**
| Yer | Ödül |
|---|---|
| "GPU Hızaşırtma" butonu | 4 saat ×2 gelir (izledikçe 12 saate kadar birikir) |
| Çevrimdışı kazanç ekranı | Kazancı ×3 |
| Anlık boost | 2 dakika ×5 gelir |
| Şans çarkı | Ekstra çevirme |
| Yükseltme maliyetine az kalınca | Eksik parayı ver ("bu yükseltmeyi şimdi al") |
| Rastgele olaylar | Olay ödülünü ×2 |

**Geçiş reklamı kuralları:** İlk 10 dakika hiç yok; en az 4 dakika aralık; asla bir eylemin ortasında değil, sadece doğal geçişlerde (lokasyon değişimi, IPO sonrası).

**Satın alımlar:** "Reklamsız" (geçiş reklamlarını kaldırır, ödüllüleri ücretsiz verir), başlangıç paketi, premium para birimi (GPU Token).

**Teknik:** Reklamları bir `AdService` arayüzünün arkasına koy. Önce **sahte (mock) uygulama** ile geliştir, sonra `google_mobile_ads` ile **sadece test reklam ID'lerini** kullan. Gerçek ID'leri ben vereceğim. GDPR için **Google UMP onay akışı** zorunlu.

## 5. Teknik yapı

- **Flutter (stable)**, Dart. Durum yönetimi: Riverpod. 2D animasyon gerekirse Flame veya basit Flutter animasyonları.
- Kayıt: yerel JSON, 10 saniyede bir ve uygulama arka plana alınınca otomatik kayıt. Kayıt sürüm numarası ve migrasyon desteği.
- Çevrimdışı kazanç zaman damgasıyla hesaplanır; basit saat geri alma koruması.
- Klasör yapısı: `lib/core` (BigNumber, ekonomi motoru), `lib/game` (sistemler), `lib/ui`, `lib/services` (ads, analytics, save, iap).
- Ekonomi motoru ve BigNumber için **birim testleri** zorunlu.
- Orta seviye Android telefonda 60 FPS.
- Dil: **İngilizce varsayılan, Türkçe ikinci dil** (Flutter l10n). Tüm metinler çeviri dosyalarında.

## 6. Görsel yön

- Temiz, okunaklı 2D; izometrik veya yandan görünen sunucu rafları; LED ışıklar, kablolar, fan animasyonları.
- Tatmin hissi kritik: para sayaçlarının akışı, yükseltmede parlama, kilometre taşında küçük kutlama.
- İlk aşamada görseller **kodla çizilen basit şekiller / placeholder** olabilir; asset'ler sonra değişecek şekilde soyutla.
- Tek elle, dikey (portrait) oynanış.

## 7. Analitik (Aşama 4)

Firebase Analytics + Remote Config. Olaylar: oturum, hat açılması, yükseltme, IPO, reklam gösterimi/tamamlanması (yerleşime göre), satın alma, tutorial adımları. Ekonomi parametreleri Remote Config ile uzaktan ayarlanabilsin.

## 8. Aşamalar ve kabul kriterleri

| Aşama | İçerik | Bittiğinde |
|---|---|---|
| 0. Kurulum | Flutter projesi, klasör yapısı, lint, git, CI (web + APK derlemesi) | Web sürümü GitHub Pages'te yayında, iPhone Safari'den açılıyor |
| 1. Çekirdek döngü | BigNumber, ekonomi motoru, 1 lokasyon, 6 hat, yükseltmeler, elektrik/soğutma, ilk 1–2 yönetici, kayıt, çevrimdışı kazanç, simülatör | İlk 15 dakika oynanabilir ve eğlenceli; simülatör raporu hazır |
| 2. Derinlik | Yöneticiler, 3 lokasyon, IPO ve yetenek ağacı, görevler, olaylar | İlk IPO'ya kadar tam döngü |
| 3. Para kazanma | AdService (mock → AdMob test), UMP onayı, IAP iskeleti | Tüm ödüllü reklam anları test reklamla çalışıyor |
| 4. Cila | Tutorial (ilk 3 dakika), ses, animasyonlar, analitik, Remote Config | Test oyuncusuna verilebilir |
| 5. Yayın | Release build (AAB), ikonlar, mağaza metinleri, Play Console dahili test | Dahili test kanalında yayında |

## 9. Çalışma kuralları

- Her aşamaya başlamadan önce kısa bir plan yaz ve onayımı al.
- Büyük teknik kararlarda (paket seçimi, mimari değişikliği) önce bana sor.
- Her aşama sonunda: testleri çalıştır, uygulamayı derle, ne yaptığını ve nasıl test edeceğimi 5–10 maddede özetle, git commit at.
- Aşamanın kapsamı dışında özellik ekleme; fikirlerin varsa `IDEAS.md` dosyasına yaz.
- Ben teknik olarak her detayı bilmiyorum; gereken adımlarda (GitHub ayarları, mağaza hesapları) beni adım adım yönlendir.
- Bu dosyayı (`GAME_BRIEF.md`) projenin kökünde tut ve kararlar değiştikçe güncelle.

## 10. Karar kaydı

| Tarih | Konu | Karar |
|---|---|---|
| 2026-10-02 | Geliştirme ortamı | Bilgisayar yok, test cihazı iPhone. Tüm geliştirme ve derleme bulutta (Claude Code + GitHub Actions). Aşama 0–2 testleri iPhone'da **web sürümüyle** (GitHub Pages). Android APK CI'da üretilir. |
| 2026-10-02 | İlk mağaza | **Google Play** (sonra App Store). Play Console kapalı test şartı için Aşama 5'te test grubu gerekecek. |
| 2026-10-02 | Repo | `kahiyecoffee-del/gpu-empire-` (public; Pages ücretsiz). |
| 2026-10-02 | Paket adı | `com.sozer.gpuempire` |
| 2026-10-02 | Hat mekaniği | Her hat bir "iş" döngüsü tamamlar; yöneticisi yoksa dokunarak başlatılır. İlk 1–2 yönetici Aşama 1'e çekildi. |
| 2026-10-02 | Compute | Sadece görüntü/tema; iş tamamlanınca doğrudan **$** kazanılır. |
| 2026-10-02 | Elektrik & soğutma | **Yumuşak throttle:** `verim = min(1, kapasite/talep)` (her iki kaynak için, düşük olanı geçerli). Altyapı yükseltmeleri $ ile alınır. |
| 2026-10-02 | Kayıt | JSON, `shared_preferences` içinde (Android + web aynı kod). Sürüm + migrasyon. |
| 2026-10-02 | Görsel | ~~Yandan görünüm raflar~~ → **2.5D izometrik** (kullanıcı kararı): kodla çizilmiş derinlikli raflar (gölge, parlayan LED, dönen fan), hat başına renk teması, cam görünümlü kartlar, basılınca çöken 3D butonlar, izometrik zemin ızgarası, iş bitince süzülen "+$" yazıları. Gerçek 3D yerine bu seçildi: her telefonda akıcı, ek dosya gerekmez. Flame şimdilik yok. |
| 2026-10-02 | Gelir yükseltmeleri | Aşama 1'e para ile alınan tek seferlik **gelir yükseltmeleri** eklendi (bir hat ×3 veya tüm hatlar ×3). Simülatör, bunlar olmadan 15. dakikadan sonra 6–25 dk'lık ölü süreler gösterdi. |
| 2026-10-02 | Elektrik/soğutma modeli | Rafın çektiği güç, rafın açılış fiyatıyla orantılı (×0.25 kW/$, soğutma ×0.2). Altyapı seviyesi kapasiteyi ve fiyatı aynı oranda (×1.5) büyütür, yani kW başı fiyat sabit. Her yeni hat açılışında elektrik kararı önem kazanır, hat büyüdükçe azalır. |
| 2026-10-02 | Kilometre taşları | 25, 50, 75, 100, 150, 200, 250, 300, 400, 500. seviyelerde ×2. |
| 2026-10-02 | "Yapacak bir şey yok" ölçütü | Simülatörde: geliri en az %1 artıracak, alınabilir hiçbir şey olmaması. Hedef ≤ 3 dk; CI'daki tempo testi ilk 30 dakika için bunu zorunlu kılar. |
| 2026-10-02 | Geliştirici menüsü | Sürüm etiketine 5 dokunuş: zaman ×10, +$1M, para ×10, kaydı sıfırla. Debug ve CI test derlemelerinde açık (`DEV_MENU=true`), mağaza sürümünde kapalı olacak. |
| 2026-10-02 | İkonlar | Web'de emoji fontu indirme gerektirdiği için arayüzde emoji yerine Material ikonları kullanılır. |
| 2026-10-02 | Tempo yavaşlatıldı | Oyuncu geri bildirimi: "bir anda dakikada yüz binler". Sonraki hatların açılış fiyatı arttı (TPU ×3, Süper Bilgisayar ×6, Kuantum ×5), yükseltmeler $15K'dan başlayıp ×7 artıyor, görev ödülleri %3–6. Yeni tempo: hatlar 0:23 / 2:41 / 7:33 / 15:06 / 29:31; 10. dk geliri $2.2M/s → ~$360K/s; görevler ~66 dakikaya yayılıyor. Altyapı harcama payı %4'e düştü; Aşama 2'de lokasyonlarla yeniden ele alınacak. |
| 2026-10-02 | Dil | Oyun şimdilik **yalnızca İngilizce** açılır (cihaz dili ne olursa olsun). Türkçe çeviri dosyası repoda duruyor ama yeni metinler çevrilmedi; ileride ayarlara dil seçeneği olarak eklenebilir. |
| 2026-10-02 | Müzik | Arka planda tatlı, döngüsel bir müzik (C majör, 92 BPM, ~42 sn döngü). Lisans derdi olmasın diye kodla sentezlendi (`tool/music/compose.py`). Ayarlar'dan kapatılabilir; tarayıcı kuralları gereği ilk dokunuşta başlar. Paket: `audioplayers`. |
| 2026-10-02 | Danışman karakter: Max | Kıvırcık saçlı, gözlüklü CTO "Max". Kodla çizilmiş avatar, ilk açılışta karşılama, ekranda sürekli görünen konuşma balonu. |
| 2026-10-02 | Yan görevler | Max sırayla 24 yan görev verir (`assets/config/quests.json`). Ödül = bu tur kazanılan toplamın %5–10'u (alt sınırlı), böylece ödüller ekonomiyle ölçeklenir ama katlanarak büyümez. Simülatör görevleri de oynar. Aşama 3'te "reklam izle, ödülü ×2 al" eklenecek. Kayıt formatı v2'ye geçti (eski kayıtlar otomatik dönüştürülür). |

---

**İlk görev:** Bu brifi oku, belirsiz gördüğün en önemli 3–5 noktayı bana sor, sonra Aşama 0 ve Aşama 1 için planını çıkar.
