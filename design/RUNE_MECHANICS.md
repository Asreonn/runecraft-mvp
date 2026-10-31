# RuneCraft — Rün mekaniği ve sınırsız otomatik craft (v1)

**Durum:** tasarım önerisi + çalışan referans uygulama · 2026-10-31
**Tek doğruluk kaynağı:** `spec/rune_mechanics_v1.json`
**Kaynaklar:**
- Kullanıcının GDD v4 belgesi: `design/source_package/RuneCraft_Rune_Ability_Function_Plan_MVP_v4.md`.
- Kullanıcının 30–31 Ekim kararları. Bu kararlar v4'ün önüne geçer.

**Sayıların kaynağı:**
- Numaralar prototip içindir.
- Denge `mechanics/balance.py` ile ölçülüp ayarlandı.
- Davranış `mechanics/test_mechanics.py` ile doğrulandı (114/114).

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

Kullanıcının koyduklarına uyulan noktalar:
- Ateş vuruş → yanma → yanan düşmanın arkasında yerde ateş hasarı veren iz bırakır.
- Buz vuruş → yavaşlatma → donma → donukken ölünce parçalanma → çevreyi dondurma.
- Volkan çağrılan bir dağdır; kraterinden çevresine lav topları fışkırtır.

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
7. **Durumlar düşmanın üzerindedir**, hangi kuleden geldiği önemsizdir. Etkileşimler:
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
- **Mana:** zamanla dolar, öldürmelerden gelir. Rün satın alma, birleştirme ve aşı ücretini öder.
- **Mana taşı:** dalga ödülüdür. Kule inşasını öder.

**Rün ve birleştirme:**
- **Rün G1:** 40 mana; çağırma rünleri 60 mana.
- **Birleştirme:** aynı tür ve aynı grade iki rün → bir üst grade, ücret 10 × (hedef grade − 1).
- **Bir rünün değeri:** 40 / 90 / 200 / 430 / 900 mana. Çağırma rünlerinde 60 / 130 / 280 / 590 / 1220.
- **Önerim:** iki girdinin aşıları çıktıda birleşir.

**Aşı:**
- **Ücret:** `20 × 1,3^(N−2)` mana; N, aşıdan sonraki düğüm sayısıdır. 10. düğüm 163 mana, 24. düğüm ≈ 6.400 mana.
  Aşı sınırsızdır ama gittikçe pahalanır.
- **Sökme:** içerik geri gelir, ücret yanar.
- Örnek: `ateş3{yanma:[elektrik3{sekme:[buz1]}]}` = 200 + 200 + 40 + 20 + 26 = **486 mana**.

**Kule:** n. kule 1 + n mana taşı. Bu benim önerim; dengesi henüz yapılmadı.

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

## 10. Açık noktalar

- **Benim önerilerim:** v4'te olmayan ve kullanıcının saymadığı yetenekler:
  - Elektrik aşırı yük şoku;
  - Zehir bulaşma;
  - Su dalga;
  - Taş sarsıntı;
  - Işık aydınlatma;
  - Kan yırtılma;
  - Meteor yağmuru;
  - Volkan lav birikintisi;
  - Kovan üreme.

  Onay ya da değişiklik bekliyor.
- **İyileşen düşman yok:** Zehirin iyileşme baskısı (v4) şu an referans dalgada ölçülemiyor.
- **Golem'in taş derisi:** Düşmanlar saldırmadığı için ölçülemiyor. Bu kuralların hepsi düşman tasarımına bağlı.
- **Birleştirmede aşıların birleşmesi** ve **kule taşı formülü:** benim önerim.
- **Simülasyon kapsamı:** 1B yol yaklaşıktır. Gerçek harita topolojisi, boss dirençleri ve düşman çeşitliliği
  yoktur. Gerçek denge oyun içinde yeniden ölçülmeli.
