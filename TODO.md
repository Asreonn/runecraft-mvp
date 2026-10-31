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
- [ ] Yüksek zemin bonusu (+1 menzil) — kendi önerim, oynanışta onay bekliyor
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
- [~] Codex ile temizlik: c1 kod (ölü kod, kalan Türkçe metinler), c2 dosya manifesti + .gitignore + README
- [ ] GitHub'a temiz, private yükleme

## Codex işleri
| İş | Hesap | Durum |
|---|---|---|
| Kamera rig (`codex-mvp/camera_rig`) | c1 | [x] 167.638/167.638 kontrol, entegre |
| Harita üreticisi v2 (`codex-mvp/map_gen_v2`) | c2 | [x] 300/300 seed, entegre |
| Rün metinleri yerelleştirme TR/EN (`codex-mvp/rune_lib_i18n`) | c1 | [x] 70.738/70.738 test, entegre |
| Harita v3: doğal nehir, tile başına ağaç, orman derinliği (`codex-mvp/map_gen_v3`) | c1 | [x] 300/300 seed, ort. 45 ms, entegre |
| Kod temizliği (`codex-mvp/cleanup_code`) | c1 | [~] çalışıyor |
| Dosya manifesti + repo README (`codex-mvp/cleanup_files`) | c2 | [~] çalışıyor |
