# RuneCraft MVP — TODO

Kullanıcının istediği her şey burada. Yeni istekler eklenir, durumlar güncellenir.
Durumlar: `[ ]` yapılacak · `[~]` sürüyor · `[x]` bitti (doğrulandı) · `[!]` sorun/karar bekliyor.
Son güncelleme: 2026-10-31

## A. Oynanış / dünya
- [x] Zaman ölçeği (1×/2×/3×, durdur) yalnızca simülasyonu etkilesin; UI, craft efekti ve kamera gerçek zamanda kalsın
- [x] Kule ilk kurulduğunda küçük kalma hatası (pop animasyonu artık gerçek zamanlı)
- [x] Menzil ve etki alanları grid hücreleri olarak gösterilsin; yalnızca hover'da ve inşa modunda görünsün (hedefleme de hücre tabanlı)
- [x] Yer alanları (ateş izi, lav birikintisi) grid hücresine otursun
- [x] Volkan, kovan, golem ve meteor hücre merkezine otursun
- [x] Dekorlar voxel grid'ine otursun (anchor/foot, 0.04 birim)
- [x] Her haritada nehir + köprü, yükselti (plato + merdiven) ve taşlık/dağlık alan olsun
- [x] Haritanın dışında boşluk görünmesin: harita çevresinde dekoratif apron (orman, nehir ve yol devamı)
- [x] Kamera: Q/E keskin 90° dönüş, WASD/oklar ile arcade pan, tekerlekle imlece doğru zoom, orta tuşla sürükleme; en uzak zoom ve kenarlarda bile harita dışı görünmesin (Codex c1)
- [x] Nehir daha doğal kıvrılsın (3–6 menderes, apron'da da kıvrılıyor) — Codex harita v3, 300/300 seed
- [x] Ağaçlar tile başına bir tane; orman derinliği: kenarda küçük, ortada orta, çekirdekte büyük ağaç — Codex harita v3
- [x] Diğer dekorlar da tile başına bir tane, tile ortasında — Codex harita v3
- [!] Yüksek zemin bonusu (+1 menzil) — kodda var, kullanıcı onayı bekliyor
- [ ] Her şey grid sistemine uyumlu olsun (genel kural; yeni özellikler bu kurala göre)

## B. UI / UX (oyun)
- [x] Menü takılması: HUD yenilemeleri kare başına bir kez, craft masası yalnızca değişince yeniden kuruluyor, açıklama/aşı kontrolü önbellekli
- [x] Sürükle-bırak: kabul eden yuvalar parlıyor, sürüklenen rün eğilip zıplıyor, altında "ne olacak" çipi (Birleştir → G3, Kuleye yerleştir...)
- [x] Rünü kuleye götürünce gösterge: tüm kuleler hedef olarak işaretleniyor, imleç altındaki kulede gelecek rün havada önizleniyor + menzili görünüyor
- [x] 45° köşeler kalsın, köşe yuvarlaklığı azaltıldı
- [x] Üst orta bar bulanıklığı (yarım piksel) — pikselde sabitlendi
- [x] UI daha "taş" görünsün, paletle uyumlu
- [x] Tuğla değil taş: her yerde aynı doku olmasın → v4: terrain kaya paletinden fasetli taş bloklar, yosun, rün taşlı köşeler, koyu okunur iç yüzey
- [x] Python ile UI üretimi bırakıldı: UI yalnızca Penpot'ta, oyuna Penpot export'u gidiyor (`ui_design/pull_penpot_exports.sh`)
- [x] Üst orta: büyük "W1/W2" sayacı + yanında kalan birim sayısı (captures/v13)
- [x] Dalga bitince altında sadece "Remaining 12s" + "Start now"
- [x] Sol üst panel kalktı; barlar çıplak
- [x] Durdur / 1× / 2× / 3× çıplak taş butonlar
- [x] "Build tower" Shop sekmesinde
- [x] Sağ panel sekmeli: Craft (masa + envanter), Shop (kule + rünler), Menu
- [x] Menu sekmesi oyunu durdurur: Resume, Settings (hasar sayıları, tam ekran, kenar kaydırma, kamera hızı), Save, Load, Quit
- [x] Oyun İngilizce; dil altyapısı hazır (`scripts/locale/{en,tr}.json`, Codex c1 70.738/70.738 test)
- [ ] Daha fazla güzel gösterge, UX iyileştirmeleri, akıcılık ve animasyonlar (sürekli)

## C. Penpot (HD UI tasarımı)
- [~] Tüm UI Penpot'ta HD olarak tasarlansın ve orada iyileştirilsin (sayfa "HUD v3 · Stone", token seti `runecraft-stone`)
  - [x] Kit v4 (Penpot board'ları `rcui / *`): panel, kart, sekmeler, 4 buton türü × durumlar, coin, yuvalar, bar, çip, 16 ikon, 65 rün ikonu (13×G1–G5), craft çemberi
  - [x] Ekran: HUD · Craft
  - [x] Ekran: HUD · Shop (+ tooltip örneği)
  - [x] Ekran: HUD · Menu (duraklatılmış, ayarlar açık)
- [x] Animasyonlar Penpot'ta: sekme/Resume prototip geçişleri (dissolve 160 ms) + "Motion spec" board'u (craft, dalga banner'ı, sekme, buton); Godot süreleri buna göre
- [x] VFX Penpot'ta: glow, spark, ring, burst, puff, shard, rün glifleri → oyunda vuruş parlaması, zemin halkası, UI kıvılcımları ve craft ışığı bunları kullanıyor
- [x] Penpot tasarımı Godot HUD'unda: 124 Penpot export'u (2×) → `assets/ui/`, 9-slice StyleBox (`ui/tex_box.gd`), Cinzel başlık fontu

## D. Teslim
- [x] Repo public yapıldı; AI incelemesi için `docs/PROJECT_OVERVIEW.md`, `design/` (mekanik doküman, referans uygulama + testler, raporlar, GDD) eklendi
- [x] Codex ile temizlik: 21 script temizlendi, 3 kullanılmayan dosya silindi; 142 kullanılmayan dosya release dışı (harita 40 tohumda birebir, oyun/kayıt sonuçları aynı)
- [x] GitHub'a temiz, private yükleme: https://github.com/Asreonn/runecraft-mvp (release kopyası `asset-work/claude-tileset/release/runecraft-mvp/`)

## E. Revizyon görevi (2026-10-31, "Hata Düzeltme, Mekanik Revizyon ve Dokümantasyon Senkronizasyonu")
Bu bölümdeki kararlar önceki belgelerin önüne geçer.
- [x] 1. Kamera: 90° zorunlu değil. **Karar (kullanıcı, F maddeleri "Claude'un önerisiyle"): 45° varsayılan**; 30° ve zoom'a bağlı Settings'te seçenek olarak kalıyor
- [x] 2. Mana rünü kalıyor: overkill manaya dönmez, öldürücü vuruş sifonu sayılır, Mana düğümü başına gelir tavanı (2,5–11/sn, fazlası %25), tek kristal, HUD gerçek gelir hızı + kule kartında mana/sn. 8 dalga ölçümü (yolun başında): toplam mana G1 +%10, G3 +%30, G5 +%51; sınırsız döngü yok (`reports/mana_economy.md`). Değerler geçici
- [x] 3. Shop çarpansal: rün ×1,15/alım (tavan ×3, dalga başına soğuma ½), kule 4×1,25^n, satış = min(ödenen, yeniden kurma)×½. Canlı fiyat, gerçek tahsilat, save/load ile korunur (testlerle). Oranlar geçici
- [x] 4.1 socket_output(): dolu envanterde artık işlem reddedilir, rün kaybolmaz (test)
- [x] 4.2 Tüm rün hareketleri işlemsel (`scripts/rune_store.gd`): iptal, ana rün değiştirme, bekleyen geri alma, sökme, teslim, combine, satış — kayıp/çoğalma yok (1448/1448 kontrol)
- [x] 4.3 Summon temizliği: rün değişimi/çıkarma/satışta tüm summon'lar kalkar; havadaki lav/meteor eski rünü uygulamaz (test)
- [x] 4.4 Save v2 (v1 de okunur): her şey + fiyat durumu + geri sayım korunur; kayıt yalnızca dalga aralarında; bozuk/yanlış sürüm/eksik dosya hiçbir şeyi değiştirmez; eski haritada kule en yakın uygun hücreye taşınır (test)
- [x] 5. Okunabilirlik (ilk tur): Rune inspector (sağ tık / Inspect: tüm ağaç, yetenek→donor→katkı, kilitli ◇, taşınmayan ✗), kulede en çok 4 donor + "+N", slotlarda "+N" rozeti, tooltip'te rün sayısı/derinlik
- [x] 6. Eşdeğerlik (Codex c2): derleyici 188/188 aynı; savaş farkları sınıflandırıldı (grid vs sürekli yarıçap vb.); bulunan 3 hata düzeltildi (B1 itilen düşman konumu, B2 ilk ateş izi — Godot; B3 öldürücü vuruş sifonu — Python). Rapor: `docs/PARITY_REPORT.md`
- [x] 7. Işık/Fog, Golem savunması, Zehir/iyileşme gelecek kapsamı olarak belgelendi (DECISIONS, RUNE_MECHANICS, PROJECT_OVERVIEW); kod korunuyor
- [x] 8. Roguelike sistemler gelecek kapsamı olarak belgelendi; hiçbiri iptal değil
- [~] 9. UI/teknik: game.gd'den rune_store/economy/save_system ayrıldı; paneller kenarlara sabitli ve 9-slice; partiküller pause/hıza uyuyor; fiyatlar canlı. Kalan: hud.gd hâlâ büyük, geniş/dar oran ekran görüntüsüyle kontrol ediliyor
- [x] 10. Dokümanlar: yeni `design/DECISIONS.md` (öncelikli), README baştan yazıldı, PROJECT_OVERVIEW, RUNE_MECHANICS (Mana, ekonomi, gelecek), raporlar yeniden üretildi, GDD'lere durum notu; yüksek zemin bonusu "onay bekliyor"; .vox kaynaklarının repoda olmadığı açık
- [x] 11. Testler: Godot invariant 1448/1448 (main'de 703/1134), Python 130/130, eşdeğerlik raporu + yeniden çalıştırma, ekonomi ölçümü, 21:9 / 4:3 / kamera ekran görüntüleri
- [x] 12. Nihai rapor (sohbette) — repo commit 94a1c1a

## F. Craft UI, Rune Inspector ve UX/QA revizyonu (2026-10-31)
Kullanıcı ara notları: "rün gösterimi AI slop olmuş — ortada bir rün, etrafında dallanan alt rünler", "14 runes depth 3 gibi alt başlıkları kaldır, bu bir oyun", "stonish'i koru, craft'taki runik dekor gibi", "grade'i loot oyunu gibi arka plan rengiyle göster", "rün ikonlarını çizmek yerine render'ını PNG al, güzel post efektlerle", "F'teki her şey senin önerinle olsun".
- [x] Craft sekmesi sırası: Crafting → Rün yapısı → Envanter (24 yuva her çözünürlükte tamamen görünür, doluluk çubuğu)
- [x] Yuva arkasındaki daireler kaldırıldı: G3+ rün ikonlarındaki gri hale (Penpot `svg-circle`), taban yuvasının arkasındaki vfx_glow ve yuvaların içinden geçen halkalar. Büyük büyü çemberi ve craft animasyonu korundu
- [x] Yeni kare taş yuvalar (Penpot `slot5_*`): normal / hover / selected / drop / invalid / output / pending / locked + kare drop ışığı (yuvarlak glow yok)
- [x] Grade = loot ışığı: yuvanın arka planı grade renginde (G1 gri, G2 yeşil, G3 mavi, G4 mor, G5 altın, ışıltılı); alttaki noktalar kaldırıldı
- [x] Rün ikonları artık oyundaki 3D voxel rün modellerinin render'ı (`tools/render_rune_icons.gd`: izometrik, anahtar+dolgu+rim ışık, bloom, koyu dış hat, 3× süper örnekleme)
- [x] Kilitli yetenekler craft masasında mühürlü yuva + "G4" olarak görünüyor; kilitliye bırakma kırmızı "olmaz" durumu
- [x] Craft butonu: mana ikonu + ücret, durum satırı (taban yok / aşı yok / mana yetmiyor / hazır)
- [x] Rün yapısı (orta): radyal taş ağacı — ortada ana rün, runik halka üstünde yetenek soketleri, oyulmuş kanallardan dallanan donor'lar, akan rün ışığı; tık = seç, hover = önizle; altında taş levha (açıklama). Bekleyen donor "pending" olarak görünür, etkisi craft'tan önce gösterilmez. "Geri al" / "Aşıyı sök" eylemleri levhada
- [x] Floating Inspector: ekran ortası taş panel, tam ağaç (iç içe tüm aşılar), sağda seçili düğümün levhası + yol (Fire G4 › Fire Hit › …). Meta alt başlıklar ("14 runes · depth 3") kaldırıldı
- [x] Inspector durum yönetimi: rün değişince takip eder, rün çıkarılınca / kule satılınca / tüketilince / load'da kapanır, yerinde düzenlemede yenilenir; Esc, ✕, dışarı tık kapatır; dışarı tık alttaki sekmeye geçmez; açıkken dünya ve kısayollar (B vb.) kilitli, Space/1/2/3 serbest; oyun duraklamaz (bilinçli seçim)
- [x] Tooltip: kısa loot tarzı (isim grade renginde, kimlik, aşı taşıyan yetenekler ≤4, kilitliler, "sağ tık: ayrıntı"), taş levha, ekran içinde kalır, yuvayı örtmez, Inspector açıkken çıkmaz
- [x] Kule kartı: uzun isim kırpılır, DPS ve mana/sn ayrı satır, 3 eşit buton; taşma yok (test)
- [x] Yerelleştirme: tüm HUD/Inspector/mesaj metinleri `scripts/locale/{en,tr}.json` "ui" bölümünde (105 anahtar); Settings → Language (yeniden başlatınca); `--lang tr`; TR'de taşma testleri geçiyor
- [x] UI etkileşim testleri (`tests/ui/run_ui.gd`, gerçek render + sentetik fare): 66 kontrol × 1280×720, 1366×768, 1920×1080, 2560×1080, 1440×1080, TR 1280×720, TR 1440×1080
- [x] Penpot: Kit v5 (taş yuvalar, düğüm soketleri, kanallar, glif halkası, levha, grade ışıkları, ikonlar), v5 kompozisyonlar (A satırlar / B dal haritası / floating / gömülü / tooltip+kart — kullanıcı geri bildirimiyle "superseded"), v6 radyal taş ağacı kompozisyonu; hızlı export: kit board tek PNG → `ui_design/pull_penpot_sheets.sh`
- [x] Eşdeğerlik yeniden çalıştırma (c2): 5065a12 → N1–N3 üç motorda geçti; d2d3af1 → istifleme/sahiplik probları eşit, R1/R2 düzeldi, yeni R3 (ölüm bütçesi) bulundu → düzeltildi; 20e959d → R3 üç motorda eşit (167,2632), 136/136 Python, 1242/1242 harness, 231/231 izolasyon
- [x] Ekonomi + istifleme ölçümü (c1, 108 tam koşu): bkz. `docs/ECONOMY_STACKING.md`
- [x] İstifleme kararı (kullanıcı onayı: "F senin önerinle"): yanma/zehir/kanama kule başına ayrı; yavaşlatma/ıslak/zırh/kamaşma/ışık/işaret düğüm başına tek (en güçlü kazanır) — iki motorda + testler
- [x] Muhasebe hataları: zehir bulaşması, donmuş ölüm kırıkları, kristal aşıları artık sahibine yazılıyor (öldürene değil) — iki motorda + testler
- [x] `vfx.gd` serbest bırakılmış hedef yakalayan geri çağrılar (108 koşunun 70'inde hata) düzeltildi
- [!] Açık karar: çok sayıda Mana donor'u tek yeteneğe (1→64) süper-doğrusal gelir veriyor (her donor olayın tüm hasarını sifonluyor). Öneri: kule başına toplam Mana tavanı. Ekonomi sayılarına onaysız dokunulmadı
- [~] hud.gd: rün yapısı / Inspector / ağaç ayrı bileşenlere çıktı (`rune_tree.gd`, `rune_view.gd`, `rune_inspector.gd`, `i18n.gd`); hud.gd yine ~1100 satır (craft sayfası + kart + tooltip + menü orada)

## Codex işleri
| İş | Hesap | Durum |
|---|---|---|
| Kamera rig (`codex-mvp/camera_rig`) | c1 | [x] 167.638/167.638 kontrol, entegre |
| Harita üreticisi v2 (`codex-mvp/map_gen_v2`) | c2 | [x] 300/300 seed, entegre |
| Rün metinleri yerelleştirme TR/EN (`codex-mvp/rune_lib_i18n`) | c1 | [x] 70.738/70.738 test, entegre |
| Harita v3: doğal nehir, tile başına ağaç, orman derinliği (`codex-mvp/map_gen_v3`) | c1 | [x] 300/300 seed, ort. 45 ms, entegre |
| Kod temizliği (`codex-mvp/cleanup_code`) | c2 (c1 limit) | [x] 0 parse hatası, uyarı 37→33, entegre |
| Dosya manifesti + repo README (`codex-mvp/cleanup_files`) | c2 | [x] 298 tut / 142 at |
| Invariant testleri (`codex-mvp/invariant_tests`) | c1 | [x] main: 703/1134 → düzeltmelerle 1448/1448 |
| Godot ↔ Python eşdeğerlik (`codex-mvp/parity`) | c2 | [x] rapor + 3 hata düzeltildi |
| Eşdeğerlik yeniden çalıştırma (commit 94a1c1a) | c2 | [x] B1/B2/B3 düzeldi (doğrulandı); yeni N1–N3 (gelir tavanı anahtarı) bulundu → iki motorda düzeltildi, Python testleri eklendi |
| Eşdeğerlik yeniden çalıştırma (commit 5065a12) | c2 | [x] N1–N3 Python/grid/replay'de geçti; 1242/1242 kontrol, yeni regresyon yok |
| Ekonomi + istifleme ölçümü (`codex-mvp/econ_stacking`) | c1 | [x] 108 koşu, 3 seed; 2 muhasebe hatası + genişlik riski bulundu |
| Eşdeğerlik d2d3af1 + 20e959d (istifleme, sahiplik, R1–R3) | c2 | [x] R3 bulundu ve düzeltildi; üç motor eşit |
