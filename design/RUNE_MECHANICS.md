# RuneCraft — Rün mekaniği ve sınırsız otomatik craft (v1)

**Durum:** tasarım + çalışan referans uygulama + Godot oyunu · son güncelleme 2026-10-31 (revizyon)
**Güncel kararlar:** [`DECISIONS.md`](DECISIONS.md) bu belgenin önüne geçer (kamera, Mana rünü, çarpansal Shop
fiyatları, grafting paradigması, okunabilirlik, gelecek kapsamı).
**Tek doğruluk kaynağı (sayılar):** `spec/rune_mechanics_v1.json` (oyunda `data/rune_mechanics_v1.json`)
**Kaynaklar:**
- Kullanıcının GDD v4 belgesi: `design/source_package/RuneCraft_Rune_Ability_Function_Plan_MVP_v4.md`.
- Kullanıcının 30–31 Ekim kararları. Bu kararlar v4'ün önüne geçer.

**Sayıların kaynağı:**
- Numaralar prototip içindir.
- Denge `mechanics/balance.py` ile ölçülüp ayarlandı.
- Davranış `mechanics/test_mechanics.py` ile doğrulandı (127/127; ekonomi testleri dahil).
- Godot oyunu ile referans arasındaki farklar: Codex eşdeğerlik raporu (`docs/PARITY_REPORT.md`). Yalnızca referansta
  doğrulanan bir davranış, oyunda da doğrulanmış sayılmaz.

---

## 1. Kafamdaki model — tek cümle

> **Her yetenek bir OLAY üretir. Aşı o olaya abone olur. Olay her olduğunda verici rün kendi açık yeteneklerini
> o olayın hedefine ve taşıyıcısına uygular.**

```
ANA: Ateş G3
 ├─ Ateş isabeti ─► olay: mermi çarptı        ← aşı: her isabette
 ├─ Yanma        ─► olay: yanma tikledi        ← aşı: her tikte
 └─ Ateş izi     ─► olay: izin içindekiler     ← aşı: izdeki herkese (her sn)
                       ▲
                       └─ Buz G2 aşılı → izden geçen düşmanlar yavaşlar
```

Sistem bir **derleyici** gibi çalışır:
- Tarif ağacı (`ateş3{yanma:[elektrik3{sekme:[buz2]}]}`) derlenince her olay için düz bir "yapılacaklar listesi" çıkar.
- Savaş sırasında yalnızca bu liste çalışır.
- Hiçbir yerde `ateş+elektrik` gibi ikili kod yoktur.
- 13. bir rün eklemek yalnızca JSON satırı eklemektir.

## 2. Oyuncunun yaptığı şey: craft masası

Kullanıcı kararı şöyle:
- Önizleme yoktur. Sonuç, çıktı rünün açıklamasında okunur.
- Sağ panel yukarıdan aşağı sıralanır:
  1. **Ana rün yuvası.**
  2. **Aşı yuvaları:** ana rünün açık yetenekleri. Rün başına doğal sayıda yetenek vardır; açık olanlar yuva olur.
     Örneğin Ateş G3'te 3 yuva vardır.
  3. **Çıktı rünü** ve **Craft et** düğmesi.
  4. **Envanter.**
- Oyuncu bir rünü bir yuvaya bırakır ve "Craft et"e basar. Zamanlama, tetik ya da sıra programlamaz.
- Craft sonrası çıktı rünün kartında `describe()` metni görünür. Örnek: `reports/mechanics_scenarios.md`.
- Uyumsuz bırakmalar craft masasında reddedilir (`check_graft`). Örneğin Golem'in Taş derisine Elektrik
  konamaz, çünkü hiçbir katkısı oraya taşınamaz.

## 3. Rün kataloğu (kullanıcı kuralı: doğal yetenek sayısı)

Kurallar:
- Hit dışında en az 2 yetenek vardır.
- Doğası çok olan rünlerde (Buz gibi) her grade bir yetenek açar.
- Yetenek açmayan grade'ler **stat artışıdır**.
- Açılım hızlıdır, çoğu G2–G3'tedir.

| Rün | G1 | G2 | G3 | G4 | G5 |
|---|---|---|---|---|---|
| **Ateş** | Ateş isabeti | Yanma | Ateş izi | stat | stat |
| **Buz** | Buz isabeti | Yavaşlatma | Donma | Buz parçaları | Çevreyi dondurma |
| **Elektrik** | Elektrik isabeti | Sekme (1) | stat (2 sekme) | Aşırı yük | stat (3 sekme) |
| **Zehir** | Zehir tiki | Yığılma | İyileşme baskısı | Bulaşma | stat |
| **Su** | Su isabeti | Islatma | Geri itiş | stat | Dalga |
| **Taş** | Ağır darbe | Zırh aşındırma | Taş parçaları | stat | Sarsıntı |
| **Işık** | Işın | Kamaşma | Delme | stat (2 delme) | Aydınlatma |
| **Kan** | Kanama | Yoğunluk | stat | Yırtılma | stat |
| **Meteor** | Meteor çarpması | Alan darbesi | Çarpma parçaları | stat | Meteor yağmuru |
| **Volkan** | Lav topu (çağrı) | Lav sıçraması | Geniş püskürme | Lav birikintisi | stat |
| **Golem** | Golem yumruğu | Taş deri | Zemin darbesi | stat | stat |
| **Kovan** | Böcek ısırığı | Üreme | Sürü odağı | stat | stat |
| **Mana** | Mana sifonu | stat | Mana işareti | stat | Kristalleşme |

Kullanıcının koyduklarına uyulan noktalar:
- Ateş vuruş → yanma → yanan düşmanın arkasında yerde ateş hasarı veren iz bırakır.
- Buz vuruş → yavaşlatma → donma → donukken ölünce parçalanma → çevreyi dondurma.
- Volkan çağrılan bir dağdır; kraterinden çevresine lav topları fışkırtır.
- Mana ekonomi rünüdür ve oyunda kalır (kullanıcı kararı): G1 hasarın bir kısmını manaya çevirir, G3 işaretlediği
  düşmanın çevresindeki tüm kulelerin hasarını manaya çevirir, G5 işaretli düşman ölünce mana taşı düşürür.
  Kurallar ve ölçümler §8'de.

Kalanlar v4'ten alındı ya da benim önerim; JSON'da `source` alanında işaretli. Her grade'in tam metni
`reports/rune_cards.md` dosyasında.

## 4. Verici ne getirir?

- Vericinin **yalnızca kendi grade'inde açık** yetenekleri gelir. Örneğin Elektrik G1'de sekme yoktur, Buz G2'de
  donma yoktur.
- Vericinin aracı (mermisi, çağrısı) gelmez, yalnızca etkisi gelir. Volkanı bir ateş mermisine aşılamak volkan
  çağırmaz; lav hasarı taşır.

| Aile | Etki |
|---|---|
| `Damage` | Ek elementli hasar. |
| `ApplyStatus` | Yanma, yavaşlatma, soğuk→donma, yük, zehir, ıslaklık, zırh, kamaşma, aydınlatma, sersemletme, kanama. |
| `ChainTransfer` | Sekme. **Ana rünün taşıyıcısının şeklini alır:** mermi seker, lav topu düşmandan düşmana zıplar, alev yandakine atlar, parça hedef arar. |
| `Pierce`, `AreaImpact`, `SpawnFragments`, `MultiImpact` | Olayın yükünü yeni hedeflere taşır. |
| `ForceMove` | Geri itiş. Önce durum uygulanır, sonra itiş yapılır (v4 §17.5). |
| `CreateGroundField` | Yer alanı. Alana aşılananlar alanın içindekilere uygulanır. |

**Uyumluluk:**
- Her taşıyıcının kabul ettiği aileler spec'teki `carriers` tablosunda tanımlı. Uyumsuz parça düşer ve rün
  açıklamasında gerekçesiyle görünür.
- Örnek: "Delme 'her tikte' taşıyıcısında anlamsız."
- Örnek: Kan'ın kanama yuvasına itiş konmaz, çünkü itiş → hareket → itiş döngüsü oluşur.

## 5. Kurallar — sınırsız ama kontrollü

1. **İç içe:** Vericinin kendi aşıları yalnızca kendi yeteneğine bağlıdır.
   - `Yanma ← (Elektrik ← Buz)` ifadesinde Buz yalnızca sekmeyle ulaşılan hedefe gider.
   - `Yanma ← Elektrik` yavaşlatmaz.
   - Bu fark testle doğrulandı.
2. **Kardeşler sıradan bağımsızdır:**
   - Önce yükler birleşir, sonra yayılımlar birleşik yükü taşır.
   - Kardeş yayılımları birbirini tetiklemez.
   - Aynı elementli hasarlar ×1, ×0,5, ×0,25 ile toplanır.
   - Sıralama kanoniktir.
3. **Yük kuralı:** Yük/yığın yeteneğine yapılan aşı, yükün **etkisi gerçekleştiğinde** tetiklenir: tik, donma,
   boşalma, tavan. Yük eklendiğinde tetiklenmez.
4. **Güç azalması:**
   - **Hasar ve DoT:** derinlik başına ×0,7. Sekme gücü ve alan oranı da buna dahildir.
   - **Kontrol:** derinlik başına ×0,85.
   - **Olay katsayısı:** isabet ×1 · tik ×0,35 · durum uygulama ×0,5 · eşik ×1 · yeni hedef ×0,6 · alan ×0,6 ·
     yer alanı ×0,2/sn · yürüme ×0,4/karo.
5. **Bütçeler** (oyuncu görmez):
   - Kök olay başına en çok 16 hedef uygulaması.
   - Yayılım en çok 2 kuşak.
   - Bir durum örneği yalnızca ilk tikinde yayılır.
   - Aynı kaynaktan üst üste binen alanlar yığılmaz.
   - 24 düğümlü stres tarifinde bu sınırların hepsi tutuyor.
6. **Saflık:** Ana rünün statları değişmez. Üst yetenekler kapatılamaz.
7. **Durumlar düşmanın üzerindedir.** İstifleme ve sahiplik (2026-10-31, `DECISIONS.md` karar 10):
   - **Süreli hasar (yanma, zehir, kanama) kule başına ayrı örnektir.** Aynı tarifli iki kule aynı düşmanı
     ikisi de yakar; her örneğin kendi saati ve hasar kaydı vardır. Aynı kule kendi örneğini tazeler.
   - **Yardımcı durumlar (yavaşlatma, ıslak, zırh kırma, kamaşma, ışık, mana işareti) tarif düğümü başına tektir**
     ve en güçlüsü geçerlidir; iki kule bunları katlayamaz.
   - **Ölüm etkileri sahibine yazılır:** zehir bulaşması zehirleyen kuleye, donmuş ölüm kırıkları donduran kuleye,
     kristal aşıları işaretleyen kuleye. Öldüren kule bunları almaz.

   Etkileşimler:
   - ıslak + elektrik ×1,5 hasar, sekme ıslak hedefi seçer;
   - ıslak hedef bir soğuk eksikle donar;
   - ıslak hedefte yanma yarı sürer ve kurur;
   - yanan hedef ×1,5 itilir;
   - itiş kanamaya sayılır;
   - donmuş hedef yarı mesafe itilir.

## 6. Örnekler (dengelenmiş statlarla, simülasyon ölçümü)

Bu örneklerin simülasyon sayıları ve rün açıklamaları `reports/mechanics_scenarios.md` içinde.

- **`ateş3{yanma:[elektrik1]}`:**
  - Her yanma tikinde +2,2 elektrik (9 × 0,7 × 0,35).
  - Elektrik G1'de sekme yoktur.
- **`ateş3{ateş_isabeti:[elektrik3]}`:**
  - Mermi 2 hedefe seker.
  - Sekilen hedefler de yanar.
  - Yanma tikleri sekmez.
- **`ateş3{yanma:[elektrik3{sekme:[buz2]}]}`:**
  - Yanma, ilk tikinde yandakine atlar, en çok 2 kuşak.
  - Atlanan düşman %18 yavaşlar (0,25 × 0,85²).
  - Donma yoktur, çünkü Buz G2'de donma açık değildir.
- **`ateş3{ateş_izi:[buz2]}`** (kullanıcı örneği): İzden geçen düşmanlar yavaşlar ve izde daha uzun kalır.
- **`volkan3{lav_topu:[elektrik3, buz2]}`** (kullanıcı örneği): Lav topu düştükten sonra sıradaki düşmana zıplar
  ve yavaşlatır. Donma ve yanma yoktur.
- **`su3{su_isabeti:[kan1]}`:** Önce kanama, sonra itiş. İtiş mesafesi kanama hasarı üretir.
- **`[su2] + [elektrik3]`** (iki kule): Islak hedefler elektrikten ×1,5 hasar alır.
- **Ret örnekleri:**
  - `buz3{buz_parçaları:…}`: G4'te açılır.
  - `su2{itiş:…}`: G3'te açılır.
  - `golem2{taş_deri:[elektrik3]}`: tümü uyumsuz.

## 7. Denge (`reports/mechanics_balance.md`)

**Hedef eğri** (6 düşmanlık paket, saf hasar akışı):
- G1 ≈ 4,5 DPS, her grade ×1,5.
- Bir üst grade iki rün birleştirerek yapılır ve kuleler mana taşıyla sınırlıdır; bu yüzden her grade hissedilir
  güçlenmeli.
- Kontrol rünlerinin (Buz, Su) hasar hedefi ×0,6. Değerleri yavaşlatma, donma ve itiştir.

**Sonuç:**
- 12 rünün hepsinde G5 ≈ 5× G1.
- Hedeften sapma en çok %21; sapma yeni yetenek açılan grade'lerde, bilinçli sıçrama.
- Her hasar statı her grade'de en az %5 büyür. Bu, kullanıcının "yetenek açmayan grade = stat artışı" kuralıdır.

**Rün kimliği için atış aralıkları:** Taş 2,2 sn (ağır), Işık 1,2 sn, Elektrik 1,3 sn, diğerleri 1,5 sn.

**Aşı verimi** (tek kulede aşılı ÷ iki ayrı kule):
- Geniş yuvalarda 1,1–1,3×.
- Dar yuvalarda (donma anı, parçalar) 0,5–0,6×.
- Aşı bir kule tasarrufu sağlar, bu yüzden geniş yuvada iki kuleden biraz iyidir.

## 8. Ekonomi

**Para birimleri:**
- **Mana:** zamanla dolar (+3/sn), öldürmelerden gelir (+2), Mana rünü üretir. Rün satın alma, birleştirme ve aşı
  ücretini öder.
- **Mana taşı:** düşmanlar öldükçe düşer (normal 1, iri 3, boss 10). Kule inşasını öder.

**Shop — çarpansal fiyat (kullanıcı kararı; oranlar geçici, denge kanıtı yok):**
- **Rün:** fiyat = taban (40, çağırma rünleri 60) × 1,15^k, en çok ×3.
  - k, o rünün yakın zamanda kaç kez alındığıdır.
  - Temizlenen her dalgada k yarıya iner, fiyatlar soğur.
- **Kule:** fiyat = 4 × 1,25^n; n, sahip olunan kule sayısıdır.
  - Satışta ödenen fiyat ile yeniden kurma fiyatından küçüğünün yarısı geri döner.
  - Al-sat döngüsü bu yüzden her zaman taş kaybettirir.
  - **Tarihçe:** eski formül `4 + 2(n−1)` ve "n. kule 1 + n" önerisi geçersizdir.
- **Gösterim:** Shop güncel fiyatı gösterir. Fiyat kaydedilir ve yüklenir.

**Birleştirme:** aynı tür ve aynı grade iki rün → bir üst grade, ücret 10 × (hedef grade − 1). İki girdinin aşıları
çıktıda birleşir.

**Aşı:**
- **Ücret:** `20 × 1,3^(N−2)` mana; N, aşıdan sonraki düğüm sayısıdır. 10. düğüm 163 mana, 24. düğüm ≈ 6.400 mana.
  Aşı sınırsızdır ama gittikçe pahalanır.
- **Sökme:** içerik geri gelir, ücret yanar.

**Mana rünü ekonomisi (geçici değerler):**
- Overkill hasar hiçbir zaman manaya dönmez. Öldürücü vuruşun sifonu yine de ödenir.
- Gelir sınırı:
  - Sifon ve işaret geliri, onu üreten Mana düğümü başına saniyede 2,5 / 4 / 6 / 8 / 11 manaya kadar tam sayılır
    (G1–G5).
  - Fazlasının yalnızca %25'i sayılır.
  - Düğüm, kule ve tarifteki yeriyle tanımlanır. Bir düğümün sifonu ve işareti aynı tavanı paylaşır; iki ayrı Mana
    donörü ya da aynı tarifli iki kule ayrı tavan kullanır.
  - Bu sınır, büyük alan hasarıyla sınırsız mana döngüsünü engeller.
- Aynı düşmandaki birden çok kristal işareti yalnızca bir kez kristalleşir.
- HUD gerçek gelir hızını, kule kartı da kule başına mana/sn'yi gösterir.
- Oyun içi ölçüm (8 dalga, `reports/mana_economy.md`): yolun başındaki Mana kulesi toplam manayı G1'de ~%10, G3'te ~%30,
  G5'te ~%51 artırır. Arkada duran Mana kulesi çok daha az kazanır. Sınırsız döngü yoktur.

## 9. Kod ve dosyalar (hepsi `asset-work/claude-tileset/runes/` altında)

| Dosya | İş |
|---|---|
| `spec/rune_mechanics_v1.json` | Katalog, statlar, taşıyıcılar, etkileşimler, bütçeler, ekonomi, denge hedefi. |
| `mechanics/resolver.py` | Ayrıştır → kanonik → derle → rün açıklaması → maliyet → craft masası kontrolü. |
| `mechanics/sim.py` | Deterministik 1B yol simülasyonu. Bütün davranış genel aile işleyicileriyle çalışır. |
| `mechanics/balance.py` | Ölçüm ve stat ayarı (`--fit`), aşı verimi tablosu. |
| `mechanics/scenarios.json`, `test_mechanics.py` | v4'ün 24 senaryosu, kullanıcı örnekleri, retler, 24 düğümlü stres, değişmezler. |
| `mechanics/report.py` | `reports/mechanics_scenarios.md`, `reports/rune_cards.md`. |

**Godot'a geçiş** (Codex'in işi; paylaşılan `scripts/` ve sahneler onun):
- `RuneCompiler` = `resolver.compile_recipe`.
- `EffectBus` = `sim.World.run_event` ve `propagate`.
- Aile başına bir işleyici; durumlar düşman üzerinde, kaynak kimliğiyle tutulur.
- Spec JSON'u Godot tarafına aynen taşınır.

## 10. Açık noktalar ve gelecek kapsamı

- **Henüz onaylanmamış önerilerim:** v4'te olmayan ve kullanıcının saymadığı yetenekler:
  - Elektrik aşırı yük şoku;
  - Zehir bulaşma;
  - Su dalga;
  - Taş sarsıntı;
  - Işık aydınlatma;
  - Kan yırtılma;
  - Meteor yağmuru;
  - Volkan lav birikintisi;
  - Kovan üreme.
- **Gelecek kapsamı (kaldırılmayacak, şimdi geliştirilmiyor):**
  - **Işık:** bazı yetenekler ileride Fog of War ve keşif sistemiyle anlam kazanacak.
  - **Golem taş derisi:** düşmanlar çağrılan birimlere saldırdığında anlam kazanacak.
  - **Zehir iyileşme baskısı:** iyileşen düşmanlar geldiğinde anlam kazanacak.
- **Roguelike hedefi (gelecek):**
  - kule şasileri ve çeşitliliği, global artifact'ler, yerel kule modifier'ları, dalga sonrası ödüller;
  - harita keşfi ve Fog of War, sandık / tüccar / buluntular;
  - biyomlar, üç kale ilerlemesi, tanrısal güçler;
  - run ilerlemesi, Demon God hikâyesi ve yeniden doğuş döngüsü.
- **Aynı tarifli iki kule:** aynı durumu aynı düşmana uygularsa tek örnek tazelenir ve tikler ilk kuleye yazılır
  (Godot ve referans aynı). İstif edilmeli mi? Karar bekliyor.
- **Simülasyon kapsamı:**
  - Referans 1B yol ve sürekli yarıçap kullanır; oyun grid hücreleriyle hedefler ve alanlar tek hücredir.
  - Farklar eşdeğerlik raporunda sınıflandırıldı.
  - Gerçek denge oyun içinde ölçülmeli.
