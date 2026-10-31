# RuneCraft — Rün, Yetenek ve İşlev Kataloğu

**MVP Oyun Tasarım Dokümanı (GDD) · v4.0 · 30 Ekim 2026**  
**Kapsam:** 12 ana rün · her rün G1–G5 · açılan doğal yetenekler · işlev kataloğu · iç içe aşılama · birleşik kule davranışları · test senaryoları  
**Durum:** Tasarım önerisi. Statlar ve eşikler ilk prototip için başlangıç değerleridir; gerçek oyun dengesi doğrulanmış değildir.

> **Amaç:** Bir programcının veya başka bir tasarım ajanının, “Ateş G3 yanma tiki tam olarak ne yapıyor?”, “Elektrik G3 hangi koşulla aktarılıyor?”, “Su G3 + Kan G1 neden aynı kulede işe yarıyor?”, “Volkan G5'e işlenmiş Elektrik G3'ün içinde Buz G1 bulunursa ne aktarılıyor?” sorularını tahmin etmeden cevaplayabilmesi. Bu belge **kod veya görsel üretim emri değildir**; oyun davranış sözleşmesidir. Önceki `RuneCraft_Rune_Design_Brief_MVP_v3.md` temel alınmıştır.

---

## 0. Kesin kararlar ve kapsam dışı olanlar

- **Oyun:** Yüksek açıdan ortografik, sade/kübik görselli, dalga savunmalı **tower defense**. Rünler kule üzerinde süzülür. RPG yetenek tuşları, karakter komboları veya manuel büyü programlama yok.
- **12 MVP rünü:** Ateş, Buz, Elektrik, Zehir, Su, Taş, Işık, Kan, Meteor, Volkan, Golem, Kovan.
- **Beş grade:** G1, G2, G3, G4, G5. G5 tavan. Yüksek grade önceki bütün açık yetenekleri korur; oyuncu **yetenek kapatamaz**.
- **Tek crafting paradigması:** `Ana rün / açık yetenek ← verici rün`. Bir yeteneğe **birden çok** verici bağlanabilir. Vericilerin içinde de başka vericiler olabilir. Vericiler bağımsız grade'e sahiptir.
- **Ayrı support/biçim/tetikleyici rünü yok.** `Summon`, `DoT`, `Hit`, `Chain`, `Impact`, `Fragment`, `ForceMove`, `Blind`, `SpawnUnit` gibi sözcükler **ortak işlev ailesi**, rün tipi değildir.
- **Meteor rünü** gökten meteor oluşturur; **Volkan rünü** lav atabilen geçici yapı çıkarır; **Golem rünü** hareketli savunma birimi üretir; **Kovan rünü** böcek üreten yuva kurar. Hepsi Summon altyapısını farklı kullanır.
- **MVP dışı rünler:** Rüzgâr, Gölge, ayrı Minyon, Portal, Zihin, Aura, Destek, Patlama, Sekme vb. Aura/buff/debuff odaklı destek rünleri gelecek içerik fikridir, şimdi eklenmeyecek.
- **Her rün DoT veya yerde iz bırakmak zorunda değildir.** Rün davranışları kendi kimliklerine göre büyür.
- **Her kombinasyon için ayrı efekt, ayrı kod veya ayrı `.vox` model üretilmez.** Oyundaki davranışlar ortak işlevlerden, görseller de gelecekte modüler katmanlardan üretilecek.
- **Ana rün kimliği değişmez.** Ana rün Volkan ise nihai sonuç hâlâ volkan çağırır; onun lavı, çağrılması veya başka **açılmış** özelliği modifiye olur.

---

## 1. Oyuncunun deneyimleyeceği tasarım döngüsü

1. Kule kurulur; üzerine bir **ana rün** yerleştirilir. Kule otomatik olarak o rünün saldırı/çağırma döngüsünü yürütür.
2. Ana rün geliştirilerek G1→G5 yetenekleri açılır. Bu yetenekler ayrı ayrı görünür: ör. Ateş `isabet`, `ısı yükü`, `yanma tiki`, `ateş izi`.
3. Oyuncu yeni bir rünü seçer, ana rünün **açık bir yeteneğine** bırakır. Ne zaman çalışacağını ayrıca programlamaz.
4. Verici rünün yalnızca **kendi grade'inde açılmış** davranışları uygun hedefe aktarılır. Elektrik G1 hasar ekler; Elektrik G3 hasar **ve aktarım** sağlayabilir.
5. Aynı özelliğe başka vericiler eklenebilir. Aşılı Elektrik'in içine Buz gibi başka bir rün de aşılanabilir.
6. Oyun sonucu önceden gösterir: etki türleri, kaç hedef, süre, tetikleme olayı, maliyet, engellenmiş katkılar ve toplam görsel karmaşıklık.
7. Oyuncu craft tarifini kaydedebilir. İki kule, farklı rünler taşısalar bile **ortak düşman durumları** üzerinden sinerji veya karşıtlık oluşturabilir.

**Temel tasarım farkı:** Rünün üzerinde açılmış bir yeteneği hedeflemek, saldırının zaman çizelgesini tasarlamak değildir. Örneğin `Yanma tiki` bir doğal olaydır; kullanıcı “her 0,5 saniyede bunu çağır” diye komut yazmaz.

---

## 2. Ortak kavramlar ve deterministik olay sözlüğü

### 2.1. Nesneler ve tanımlar

| Kavram | Açıklama | Örnek |
|---|---|---|
| **Rune Instance** | Ana veya aşılı bir rünün kendi grade ve tarif geçmişini taşıyan örneği | `Fire G5` |
| **Ability** | Bir rünün grade ile açılan, kendi başına anlamlı özelliği | `burn_tick` |
| **Ability Anchor** | Vericinin eklenebileceği açık ve uyumlu yetenek noktası | `Fire.burn_tick` |
| **Carrier** | Etkinin üzerinde çalıştığı nesne/olay | Mermi, DoT tiki, fiziksel parça, birim vuruşu |
| **Status** | Hedefin belli süre taşıdığı durum | Burn, Chill, Frozen, Poison, Wet, Bleed, Blind |
| **Field** | Bir alanda etkin kalan etki | G5 Ateş izi |
| **Summoned Entity** | Kule tarafından otomatik oluşturulmuş geçici nesne/birim | Meteor, Volkan, Golem, Kovan |
| **Graft** | Vericinin bir alıcı yeteneğe bağlandığı kayıt | `Fire.burn_tick ← Electric G3` |
| **Nested Graft** | Verici rünün kendi açık yeteneğine işlenmiş alt rün | `Electric G3 ← Ice G1` |
| **Grade** | Rünün doğal beceri kilidini ve temel istatistiklerini belirleyen 1–5 kademesi | `Ice G3` dondurur |
| **Visual Recipe** | Craft'a ait aynı girdide aynı görünümü üretecek gelecekteki veri | Küp, sembol, grade, işlenmiş katkı yoğunluğu |

### 2.2. Olayların ortak yaşam döngüsü

| Olay kimliği | Ne zaman? | Hangi rünler için önemli? |
|---|---|---|
| `CAST` | Kule yeni bir saldırı/çağrı döngüsü başlatır | Hepsi |
| `SPAWN_ENTITY` | Meteor, yapı, birim, mermi veya parça ortaya çıkar | Meteor, Volkan, Golem, Kovan, Taş, Buz |
| `HIT` | Doğrudan isabet gerçekleşir | Ateş, Su, Taş, Işık, Elektrik, Meteor, Golem vb. |
| `APPLY_STATUS` | Hedefe durum uygulanır veya yenilenir | Buz, Ateş, Zehir, Su, Kan, Işık |
| `STATUS_TICK` | Zamanla çalışan durum periyodik etki üretir | Yanma, zehir |
| `ACCUMULATE` | Hedefte yük/yoğunluk toplanır | Isı, soğuk, elektrik, zehir, kanama |
| `THRESHOLD_REACHED` | Yük sınırı aşılır | Buzun donması; ateşin ısı yükü |
| `MOVE_DISTANCE` | Düşman gerçekten mesafe kat eder | Kan; Su'nun geri itmesi |
| `FORCED_MOVE` | İtme/çekme ile fiziksel hareket oluşur | Su, Kan |
| `ENTITY_ATTACK` | Çağrılan varlık saldırır | Volkan lavı, Golem vuruşu, Kovan böceği |
| `IMPACT` | Meteor veya ağır cisim zemine/hedefe çarpar | Meteor, Taş |
| `ENTITY_DEATH` | Düşman veya çağrılmış nesne ölür | Buz G5 için donmuş düşman ölümü; summons |
| `FIELD_TICK` | Kalıcı etki alanı içindeki hedefler işlenir | Ateş G5 |
| `EXPIRE` | Durum, alan veya çağrı süresi dolar | Tüm süreli nesneler |
| `RETARGET` | Devam eden bir etki bir sonraki uygun hedefi bulur | Elektrik G3+ |

**Önemli:** Olaylar oyuncunun craft sırasında eklediği ekstra rünler değildir. Her rünün kendi doğal çalışmasının standart sinyalleridir.

### 2.3. Genel işleve sahip temel aileler

| Fonksiyon ailesi | Yaptığı iş | Kullanıldığı somut örnek | Ne yapmaz? |
|---|---|---|---|
| `DealHitDamage` | Tek bir hedefe doğrudan hasar | Ateş G1, Su G1 | Kendiliğinden DoT yaratmaz |
| `ApplyStatus` | Belirli süre/etki ile durum yerleştirir | Ateş G3 yanma, Kan G1 kanama | Yeni saldırı formu uydurmaz |
| `TickStatus` | Var olan DoT/durumun periyodik etkisini çalıştırır | Burn / Poison | Kendiliğinden patlatmaz |
| `AddStack` | Hedefte birikim artırır | Buz soğuk, Zehir yığını | Tanımsız eşiğe ulaşınca yeni efekt uydurmaz |
| `ResolveThreshold` | Tanımlanmış eşiğin sonucunu uygular | Buz G3'ün donması | Buz G1'de çalışmaz |
| `ModifySpeed` | Hedefin yürüme hızını geçici değiştirir | Buz G1 | Zorunlu hareketi kendiliğinden iptal etmez |
| `ApplyFreeze` | Hedefi kısa süre hareketsiz tutar | Buz G3 | G1–G2'de kullanılamaz |
| `ChainTransfer` | Uygun devam eden etkiyi komşu hedefe taşır | Elektrik G3 | Ayrı patlama oluşturmaz |
| `ForceMove` | Hedefi fiziksel olarak iter | Su G3 | Teleport sayılmaz |
| `DamageByMovedDistance` | Gerçek kat edilen mesafeye hasar bağlar | Kan G1 | Hedef duruyorsa hasar üretmez |
| `ApplyArmorShred` | Savunmayı azaltır | Taş G2 | Doğrudan çağrı yapmaz |
| `BeamAttack` | Işın isabeti üretir | Işık G1 | G1'de delme zorunlu değil |
| `ApplyBlind` | Saldıran düşmanın isabetini düşürür | Işık G2 | Yalnız yürüyen düşmanı durdurmaz |
| `PierceAttack` | İlerleyen ışının sonraki hedefi vurmasını sağlar | Işık G3 | Ayrı zincirleme değildir |
| `SummonObject` | Belirli türde geçici varlık oluşturur | Meteor, Volkan, Golem, Kovan | Hepsini aynı davranışa dönüştürmez |
| `PeriodicEntityAttack` | Geçici yapının atış döngüsünü yürütür | Volkan lav atımı | Çağrılan varlık sınırsız atış yapmaz |
| `UnitMeleeAttack` | Hareketli dostun hedefe vuruşu | Golem | Kendi başına bir Golem rünü değildir |
| `SpawnChildUnits` | Yuvadan alt birim üretir | Kovan | Sınırsız kopya üretmez |
| `AreaImpact` | Bir darbenin etrafındaki hedefleri etkiler | Meteor G2 | G1 Meteor'da alan yok |
| `SpawnFragments` | Fiziksel parçalar çıkarır | Taş G3, Meteor G3, Buz G5 | Her ründe zorunlu değil |
| `CreateGroundField` | Harita üzerinde kısa süreli etki oluşturur | Ateş G5 | Her DoT'tan otomatik alan oluşmaz |
| `ChooseUnitTarget` | Çağrılmış birimin hedef seçmesini sağlar | Golem / böcek | Başlı başına saldırı hasarı üretmez |
| `CoordinateSwarm` | Birden çok alt birimin aynı hedefe odaklanmasını sağlar | Kovan G3 | G1 Kovan'da kilitli |
| `ModifyIncomingDamage` | Savunmalı bedenin hasar azaltmasını uygular | Golem G2 | Başka rüne otomatik savunma bağlamaz |
| `ModifyStatusHealing` | Hedefin iyileşmesini kısar | Zehir G3 | Hasar yokken patlama üretmez |
| `VisualizeCombatEvent` | Mekaniğin ekranda okunur VFX/ses bildirimini üretir | Yanma tiki, su itişi, meteor çarpması | Mekanik etkisini hesaplamaz |

**Fonksiyon kataloğunun amacı:** `Fire+Electric`, `Volcano+Ice`, `Hive+Blood` gibi her bir çift için özel koşul yazmak değil; aynı çalışır mekanikleri uygun taşıyıcıya aktarmaktır. Yeni, gerçekten farklı bir davranış türü ilk kez ortaya çıkıyorsa **o işlev bir kez geliştirilir**; o işlevi kullanan her kombinasyon tekrar yazılmaz.

---

## 3. Grade, istatistik ve etkileşim için ortak kurallar

### 3.1. Grade açılımı

| Grade | Tasarım niyeti | Oynanış beklentisi |
|---|---|---|
| **G1** | Ana rünün tanınabilir temel saldırısı | Tek ve okunabilir işlev |
| **G2** | İlk özgün gelişim | Genellikle yeni durum/birikim/etkileşim |
| **G3** | Ana imza yeteneği | Donma, zincir, itiş, delme, zemin darbesi gibi önemli açılım |
| **G4** | Güç ve uzmanlık | Stat artışı; bazı rünlerde duruma bağlı özel bonus |
| **G5** | Güçlü son aşama | Stat tavanı; uygun rünlerde yeni kalıntı/parça/alan |

- G5 **G1–G4'teki bütün doğal açık yetenekleri** içerir. Her yetenek ayrı hedef olarak kalabilir.
- **Her G5 yeni fonksiyon açmak zorunda değildir**. Zehir, Kan, Golem, Kovan'ın son kademelerindeki büyüme daha çok etkinlik ve kapasite olabilir.
- İleri grade yetenekleri kapatılamaz. Örn. Buz G5 hem yavaşlatma hem donma hem buz parçaları içerir.
- Vericinin katkısı kendi grade'inden hesaplanır; ana rünün G5 olması Elektrik G1'e G3 sekmesi vermez.
- **Graft eklemek kendi başına grade yükseltmek değildir.** Grade upgrade ve graft iki farklı ilerleme kararıdır. Rün grade yükseltme ekonomisinin kesin maliyeti MVP dengesi sırasında belirlenir.

### 3.2. Kule genel referansları (test ortamı, kesin denge değil)

| Parametre | Pilot varsayım | Açıklama |
|---|---:|---|
| Kule varsayılan atış aralığı | **1,5 sn** | Her rün için nihai hız değil; karşılaştırma temelidir |
| Normal kule menzili | **4 karo** | Referans harita, 50×50 voxel bir karo / 2 Godot world unit |
| Durum tiki | **1 saniyede bir** | Ateş ve Zehir için başlangıç standardı; tüm etkilere zorlanmaz |
| Düşman yürüyüş hızı | **1 karo/sn** | Hasar/mesafe testlerinde karşılaştırma |
| Geri itmenin birimi | **Karo** | Su G3 `0,35 karo`; 1 karo = 2 world unit |
| Kule rün görseli | **Süzülen tek ana rün** | Grade ve aşılama ileride otomatik görsel bileşir |

> **Uyarı:** Sayılar ilk oynanış hissi için öneridir. Uygulama bunları sabit gerçek denge kabul etmemeli; özellikle grade'ler arasında rün farklı büyüme oranlarına sahiptir.

### 3.3. Durum/hasar kuralları

1. **Yanma:** Ateş G3+ ile açılır. `Burn` 1 saniyelik tiklerle hasar verir. Yeniden uygulamada kalan süre tazelenir; başlangıç MVP'sinde aynı kaynaktan gelen yanmalar bağımsız sonsuz kopya oluşturmaz. Başka graft ile yayılan yanmanın gücü otomatik aktarım katsayısından geçer.
2. **Zehir:** G1'de DoT; G2+ tekrar uygulama yığınları; G3+ iyileşme azaltma. Zehir **kendiliğinden patlamaz**.
3. **Yavaşlatma:** Buz G1+ düşmanın normal yürüme hızını azaltır. Buz G2 soğuk yükü biriktirir; Buz G3+ eşik dolunca 1+ sn dondurur.
4. **Dondurma:** Donmuş hedef yürüyemez ama zorunlu hareket ile etkileşimi birim dirençlerine bağlıdır; Buz G5'in `frozen_death_shards` işlevi yalnızca **ölüm anında gerçekten Frozen olan** düşmanda çalışır.
5. **Kanama:** Zaman geçişinden değil, **gerçek yol alma miktarından** hasar üretir. Kendi yürüme hareketi ve Su'nun geri itmesi sayılır; teleport, animasyon sarsıntısı veya yerinde hareket döngüsü sayılmaz.
6. **Islaklık:** Su G2'de açılır; hedefte süreli `Wet` durumu yaratır. Islak hedefle ilgili olası genel elektrik hedefleme avantajı ayrı dengelenebilir; elektrik G1'den gizli sekme üretmez.
7. **Kamaşma:** Işık G2+ düşmanın kullandığı saldırıların isabetini azaltır. Yalnızca rotada yürüyen, saldırısı olmayan düşmana karşı Işık yine ışın hasarı verir; körlük üzerine yanlışlıkla durdurma kurulmaz.
8. **Zırh aşındırma:** Taş G2+ gerçek düşman zırhı üzerinde çalışır. Zırhsız düşmana azaltılacak zırh kalmadığında yeni efekt doğmaz.
9. **Ateş izi:** Sadece Ateş G5. Merminin/etki yolunun uygun yüzeyinde kısa süre etkili `FireField` oluşturur. Normal yanma tikinden kendiliğinden yeni alan doğmaz.
10. **Hedef ölümünün nedeni ve rün kaynağı:** Buz G5 `frozen_death_shards` yalnızca hedefte bu yeteneği taşıyan **G5 Buz kökenli geçerli Frozen uygulaması** varsa çalışır. Son vuruşu başka bir kule yapabilir; ancak yalnız Buz G3 tarafından dondurulmuş bir hedefi başka kule öldürünce, sırf sahada Buz G5 var diye parçalar çıkmaz. Durum kaydı kaynak rün kimliğini/grade yetkisini korumalıdır.

### 3.4. Çatışmalı etkiler ve denge

- `Frozen` ve normal yavaşlatma bir arada kaydedilebilir; donma bitince yavaşlatmanın kalan süresi devam eder. **Donma otomatik iptal edilmez**.
- Ateş ile Buzun karşılaşması otomatik “eriyerek patlama” yapmaz. Böyle bir özel reaksiyon MVP kataloğunda yoktur.
- Islaklık ve Ateş bir arada bulunabilir; hangi sürenin azaldığı gibi ek elemental kurallar **kanıtlanmış ve istenmiş mekanik olmadıkça** eklenmez.
- `Su G4`: hedef üzerinde **Burn** varsa itişine `×1,5` uygular. Durum başka kuleden veya aynı ründeki graft'tan gelmiş olabilir.
- `Kan + Su`: Kan debuff'ı Su'nun zorunlu hareketinden önce uygulanırsa aynı atıştaki mesafe hasarı görülür. Birleşik vuruş için **durum-önce, zorunlu-hareket-sonra** işlem önceliği sabitlenir.
- Birden fazla `slow`, `burn`, `poison` kaynağı aynı anda varsa toplam güç için ortak stacking politikası gerekir; başlangıç testinde **kaynağa özel yığın + küresel güç tavanı** önerilir. Nihai denge açık karardır.

---

## 4. Rune 01 — ATEŞ (`fire`)

**Kule davranışı:** Belirlediği hedefe ateş mermisi gönderir. Ana kimliği doğrudan ısı vuruşudur; yüksek grade'de yanma ve arazi baskısı açılır. **TD rolü:** Süreli hasar, grup tutma kuleleriyle sinerji.

| Grade | Vuruş | Ek sayılar | Açık yetenekler / bu grade'deki gelişim |
|---|---:|---|---|
| **G1** | **10** | Atış: referans 1,5 sn | `fire_hit`: Isı vuruşu; **yanma yok** |
| **G2** | **12** | Isı yükü **2/isabet** | `heat_stack`: İsabet eden hedefte ısı birikimi. MVP önerisi: 4 yüke ulaşınca sonraki Ateş vuruşu **+%10** doğrudan hasar alır; yük tüketilir. DoT değildir. |
| **G3** | **14** | **3 hasar/sn × 3 sn** | `burn_apply`, `burn_tick`: Normal isabet yanma uygular; tik her 1 sn çalışır. `heat_stack` korunur. |
| **G4** | **16** | **4 hasar/sn × 3 sn** | Daha güçlü `fire_hit`, `burn_tick`; yeni mekanik zorunlu değil. |
| **G5** | **19** | **5 hasar/sn × 4 sn**; iz önerisi **2 sn** | `fire_trail`: Mermi izinin uygun kısa bölümünde ısı alanı bırakır; yerden geçen düşmanlara örnek **2 hasar/sn** uygular. |

**Fonksiyonlar ve aşı noktaları**

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun taşıyıcı |
|---|---|---|---|
| `fire_hit` | G1 | `HIT` → `DealHitDamage(heat)` | Doğrudan isabet / mermi |
| `heat_stack` | G2 | `HIT` → `AddStack(heat)`; eşik → güçlendirilmiş sonraki vuruş | Yük uygulaması |
| `burn_apply` | G3 | `HIT` → `ApplyStatus(Burn)` | Yanmanın uygulanması |
| `burn_tick` | G3 | `STATUS_TICK(Burn)` → `DealHitDamage(heat, dot)` | **Yanma tiki**: Elektrik, Buz, Zehir gibi vericiler bu olaya işlenebilir |
| `fire_trail` | G5 | `CAST/HIT` ile tanımlı mermi rotası → `CreateGroundField(Fire)` | Harita alanı (taşıyıcı türü Field) |

**Örnek:** `Fire G3.burn_tick ← Electric G3` yanmanın yakın hedefe taşınmasını sağlar; `← Electric G1` yalnızca elektrik hasarı ekler. `Fire G5.fire_trail ← Poison G1`, ateş izinin uygun alan vuruşunda zehir de uygular; ayrı bir “zehirli ateş” kodu yazılmaz.

**Görsel olaylar (oynanış için):** G1 kısa turuncu mermi ve isabet kıvılcımı; G3 yanan düşmanda ölçülü alev işareti ve her tikte ufak VFX; G5 zeminde sade, kısa canlı ateş izi. Ayrı kombinasyon modelleri yok.

---

## 5. Rune 02 — BUZ (`ice`)

**Kule davranışı:** Buz kristali atar. **TD rolü:** Rotada tutma, kümelendirme, yüksek grade'de donmuş ölümlerden fiziksel parçalar.

| Grade | Vuruş | Ek sayılar | Açık yetenekler |
|---|---:|---|---|
| **G1** | **7** | Yavaş **%20 / 1,5 sn** | `ice_hit`, `chill_slow`; **donma yok** |
| **G2** | **9** | Yavaş **%25 / 1,8 sn**; soğuk yükü önerisi **1/isabet** | `cold_stack` açılır; henüz dondurmaz |
| **G3** | **11** | Yavaş **%30 / 2 sn**; donma **1,0 sn** | `freeze_threshold`: Öneri **3 soğuk yükü** eşik; eşikte Frozen uygular |
| **G4** | **13** | Yavaş **%35 / 2,3 sn**; donma **1,2 sn** | Stat artışı |
| **G5** | **15** | Yavaş **%40 / 2,5 sn**; donma önerisi **1,4 sn**; parça **3** | `frozen_death_shards`: Frozen halde ölen düşman 3 fiziksel buz parçası üretir; varsayılan yere düşer |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `ice_hit` | G1 | `HIT` → buz hasarı | Mermi/isabet |
| `chill_slow` | G1 | `HIT` → `ModifySpeed` | Yavaşlatma uygulaması |
| `cold_stack` | G2 | `HIT` → `AddStack(Cold)` | Soğuk yükü |
| `freeze_threshold` | G3 | `THRESHOLD_REACHED` → `ApplyFreeze` | Donma gerçekleşmesi |
| `frozen_death_shards` | G5 | `ENTITY_DEATH` + `Frozen` → `SpawnFragments(Ice,3)` | **Ölümdeki fiziksel parçalar** |

**Örnek:** `Ice G5.frozen_death_shards ← Electric G3` fiziksel parçanın uygun hedefe yönelip sekebilmesini sağlar. Elektrik G1'de sekme açık değildir: parça varsa yalnızca elektrik hasarı katkısı bulunur. `Ice G2 ← Poison G1` yavaşlatır ve zehir uygular, ama **dondurmaz**.

**Not:** Dondurma oyuncu tarafından kapatılamaz. Buz G5'te `freeze_threshold` ve `frozen_death_shards` doğal olarak aktiftir. Parçaların varlığı “donmuşken ölüm” şartına **ve G5 Buz kaynaklı Frozen yetkisine** bağlıdır; bütün Buz vuruşlarında parça üretilmez.

---

## 6. Rune 03 — ELEKTRİK (`electric`)

**Kule davranışı:** Elektrik atışı/yük; G3'ten itibaren aktarım. **TD rolü:** Birden çok hedefe etki taşıma. “Sekme” ayrı rün değil, Elektrik'in açık yeteneğidir.

| Grade | Vuruş | Sekme | Açık yetenekler |
|---|---:|---:|---|
| **G1** | **8** | **0** | `electric_hit`: elektrik hasarı; **aktarım yok** |
| **G2** | **10** | **0** | `electric_charge`: uygun hedefte yük birikir (başlangıç önerisi **2 yük** tavan); sekme yok |
| **G3** | **12** | **1** | `electric_chain`: sonraki uygun hedefe bir kez aktarım |
| **G4** | **14** | **2** | `electric_chain` ikinci hedefe uzanır |
| **G5** | **17** | **3** | Aktarım kapasitesi yükselir; başka gizli patlama açılmaz |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `electric_hit` | G1 | `HIT` → elektrik hasarı | Mermi / status tiki / fiziksel parça / birim saldırısı |
| `electric_charge` | G2 | `HIT` → `AddStack(ElectricCharge)`; öneri: yüklü hedefe sonraki elektrik darbesi **+%10** hasar | Yük uygulaması |
| `electric_chain` | G3 | `HIT` veya izin verilen diğer taşıyıcı olayı → `RETARGET` ve `ChainTransfer` | Uygun mermi, durum tiki, fragment, çağrı saldırısı |

**Ortak aktarım sözleşmesi:** Elektrik yeni bir patlama veya bağımsız zamanlama yaratmaz. Hedef `burn_tick` ise tik kaynaklı yanma/etki başka hedefe taşınır; hedef `projectile_hit` ise mermi zincirlenir; hedef `ice_shard` ise parça yeni düşmana yönlenebilir. Her hop'ta güç azalır; aynı zincir aynı hedefi tekrar vurmaz (ilk pilot önerisi). G4+ hop sayısını yükseltir.

**Örnek:** `Fire G3.burn_tick ← (Electric G3.electric_chain ← Ice G1.chill_slow)` yanma tikini yakındaki hedefe aktarır; aktarılmış vuruşta Buz G1 yavaşlatması da uygulanır, **Frozen açılmaz**.

---

## 7. Rune 04 — ZEHİR (`poison`)

**Kule davranışı:** Hedefte zamanla toksin hasarı oluşturur. **TD rolü:** Uzun süre yaşayan hedefleri aşındırmak, sağlık yenilemeyi baskılamak.

| Grade | DoT | Süre / yığın | Açık yetenekler |
|---|---:|---|---|
| **G1** | **2/sn** | **3 sn**, tek yük | `poison_apply`, `poison_tick` |
| **G2** | **3/sn** | **3 sn**, max **2 yığın** | `poison_stack` açılır |
| **G3** | **4/sn** | **4 sn**, max **3 yığın** | `heal_suppression` **%20** |
| **G4** | **5/sn** | **4 sn**, max **4 yığın** | Sayısal büyüme |
| **G5** | **6/sn** | **5 sn**, max **5 yığın** | İyileşme baskısı **%30**; sayısal büyüme |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `poison_apply` | G1 | `HIT` → `ApplyStatus(Poison)` | Zehir uygulaması |
| `poison_tick` | G1 | `STATUS_TICK` → DoT hasarı | **Zehir tiki** |
| `poison_stack` | G2 | Yeniden uygulama → yük büyütme | Yığın ve yoğunluk |
| `heal_suppression` | G3 | Zehirli hedefin şifa etkinliğini düşürme | İyileşme baskısı |

**Örnek:** `Meteor G2.area_impact ← Poison G1` çarpma alanındaki düşmanları zehirler; `Volcano G3.lava_hit ← Poison G2` her uygun lav vuruşunda zehir yığını biriktirebilir. Zehir **kendiliğinden patlama**, ölümde sis veya yerde zehirli alan **üretmez**.

---

## 8. Rune 05 — SU (`water`)

**Kule davranışı:** Su vuruşuyla hasar verir; ileri grade'de ıslatır ve geri iter. **TD rolü:** Rotayı geriletme; kanama ile zorunlu hareket sinerjisi.

| Grade | Vuruş | Ek sayılar | Açık yetenekler |
|---|---:|---|---|
| **G1** | **8** | İtiş **0** | `water_hit`; sadece su hasarı |
| **G2** | **10** | Islaklık **3 sn**; itiş **0** | `wet_apply` açılır |
| **G3** | **12** | İtiş **0,35 karo** | `water_push` açılır |
| **G4** | **14** | İtiş **0,45 karo** | `burning_target_push` açılır: **Burn taşıyan hedefe ×1,5 itiş** |
| **G5** | **17** | İtiş **0,60 karo** | Yeni ana mekanik yok; yanan hedefe bonus sürer |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `water_hit` | G1 | `HIT` → su hasarı | Doğrudan vuruş |
| `wet_apply` | G2 | `HIT` → `ApplyStatus(Wet)` | Islatma |
| `water_push` | G3 | `HIT` → `ForceMove` (karo bazında) | **Zorunlu hareket** |
| `burning_target_push` | G4 | `water_push` hedefinde `Burn` varsa mesafeyi 1,5 ile çarp | Duruma bağlı itme bonusu |

**Birleşik kule senaryosu (kritik):** `Water G3.water_hit ← Blood G1` işlemi ile Su vuruşu önce Kanama uygular, ardından `water_push` çalışır. Düşmanın zorunlu hareket mesafesi Kan G1'in `DamageByMovedDistance` işlevini hemen tetikler. Başka Kan kulesi gerekmez.

**Mekanizmanın zıttı:** `Ice G1` düşmanın normal yürüme mesafesini azaltır; dolayısıyla Kan'ın hareket hasarı azalmış olabilir. Su'nun geri itmesi bunu aşabilir. `Water G4` yanan hedefleri daha fazla ittiği için `Fire G3` + `Water G4` + `Blood G1` üçlüsü ayrı kulelerle veya uygun iç içe aşılarla sinerji yapar.

---

## 9. Rune 06 — TAŞ (`stone`)

**Kule davranışı:** Ağır taş mermisi, zırh kırma, parça çıkarma. **TD rolü:** Tek hedef hasarı ve zırhlı düşmanlar.

| Grade | Vuruş | Ek sayılar | Açık yetenekler |
|---|---:|---|---|
| **G1** | **15** | — | `stone_impact` |
| **G2** | **18** | Zırh azaltma **%8 / 3 sn** | `armor_shred` |
| **G3** | **21** | Zırh azaltma **%12**; **2** parça | `stone_fragments` |
| **G4** | **25** | Zırh azaltma **%16** | Hasar/parça stat artışı |
| **G5** | **30** | Zırh azaltma **%20**; **3** parça | Güç artışı; zorunlu yeni tip yok |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `stone_impact` | G1 | `IMPACT/HIT` → fiziksel hasar | Ağır vuruş |
| `armor_shred` | G2 | `HIT` → zırhı geçici azalt | Zırh aşındırma |
| `stone_fragments` | G3 | Sert çarpışma → `SpawnFragments` | **Ortaya çıkan fiziksel taş parçaları** |

**Örnek:** `Stone G3.stone_fragments ← Electric G3` parçalara aktarım ekleyebilir. `Stone G2.armor_shred ← Poison G1` zırh azaltan vuruşla zehir de uygular; zehirden kendiliğinden kırıcı patlama oluşmaz.

---

## 10. Rune 07 — IŞIK (`light`)

**Kule davranışı:** Doğrusal ışın ve hedefi kamaştırma. **TD rolü:** Çoklu hizalı hedefleri vurma; saldıran düşmanları geçici bozma. Gelecekte harita tarama/keşif için adaydır.

| Grade | Işın hasarı | Ek sayılar | Açık yetenekler |
|---|---:|---|---|
| **G1** | **9** | Ek hedef **0** | `light_beam` |
| **G2** | **11** | Kamaşma **1,5 sn** | `light_blind`: düşman saldırısının isabetini düşürür (pilot önerisi **-%30**) |
| **G3** | **13** | Ek delme hedefi **1** | `beam_pierce` |
| **G4** | **15** | Kamaşma **2,0 sn** | Stat/süre artışı |
| **G5** | **18** | Ek delme hedefi **2** | Delme gücü artışı |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `light_beam` | G1 | `CAST` → `BeamAttack` → `HIT` | Işın/isabet |
| `light_blind` | G2 | `HIT` → `ApplyBlind` | Körlük/kamaşma |
| `beam_pierce` | G3 | `BEAM_HIT` → hatta sonraki hedefe devam | Delme hattı |

**Örnek:** `Light G3.beam_pierce ← Poison G1` ışının deldiği hedeflerde zehir uygular. `Light G2.light_blind ← Electric G3` kamaşma etkisinin komşu düşmana taşınmasına izin verebilir; **görünür alan otomatik map-scan değildir**. Haritayı tarama sadece gelecek özellik adayıdır; MVP'de aktif mekanik sayılmaz.

---

## 11. Rune 08 — KAN (`blood`)

**Kule davranışı:** Hedefe hareket ederken zarar veren kanama uygular. **TD rolü:** Hızlı düşmanlara karşı güçlü; Su'nun geri itmesiyle sinerji, Buzla doğal gerilim.

| Grade | Mesafe hasarı | Süre / ek | Açık yetenekler |
|---|---:|---|---|
| **G1** | **3 hasar/karo** | **3 sn** | `bleed_apply`, `movement_bleed` |
| **G2** | **4 hasar/karo** | **4 sn** | `bleed_intensity`: tekrar uygulama yoğunluğu artırır |
| **G3** | **5 hasar/karo** | **4 sn**; bonus **+%20** | `distance_bonus`: toplam kat edilen mesafe yoğunlaşmayı besler |
| **G4** | **6 hasar/karo** | **5 sn** | Stat gelişimi |
| **G5** | **8 hasar/karo** | **5 sn**; bonus **+%30** | Mesafe bonusu güçlenir; yeni ölüm patlaması yok |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `bleed_apply` | G1 | `HIT` → `ApplyStatus(Bleed)` | Kanama uygulaması |
| `movement_bleed` | G1 | `MOVE_DISTANCE` → `DamageByMovedDistance` | **Hareket tabanlı hasar** |
| `bleed_intensity` | G2 | Yeniden uygulama → yoğunluk artır | Kanama yoğunluğu |
| `distance_bonus` | G3 | Birikmiş hareket → ilave kanama çarpanı | Mesafeye bağlı uzmanlık |

**Örnek:** `Blood G1 ← Water G3` aynı ana Kan kimliğiyle hedefi itebilen bir saldırı oluşturabilir (alıcı saldırı taşıyıcısının ForceMove uyumlu olması koşuluyla). `Water G3 ← Blood G1` ise daha okunur ilk MVP demosudur: vuruş kanatır, itiş hasarı hemen tetikler.

**Düşman davranışları:** Hareketsiz kule kırıcı/kuşatma düşmanına karşı Kan düşük verimli kalabilir. Uçan birimin konumsal yol alma miktarı fiziksel yürüyüş gibi sayılıp sayılmayacağı düşman sınıfıyla tanımlanır. Teleport/dash animasyonları otomatik hareket sanılmaz.

---

## 12. Rune 09 — METEOR (`meteor`)

**Kule davranışı:** Hedeflenen noktaya **gökten fiziksel meteor çağırır**; yere iner, vurur, yüksek grade'de etki alanı ve parçalar gelişir. **TD rolü:** Gecikmeli güçlü vuruş, yoğun düşman hattı.

| Grade | Ana darbe | Alan / parça | Açık yetenekler |
|---|---:|---|---|
| **G1** | **24** | Tek hedef | `meteor_call`, `meteor_impact` — meteor düşüşü çağrısı; yere çarpınca tek hedefe zarar |
| **G2** | **29** | Yarıçap **0,45 karo** | `meteor_area`: çevresel çarpma hasarı açılır |
| **G3** | **34** | **2** parça | `meteor_fragments` |
| **G4** | **40** | Yarıçap **0,65 karo** | Stat / alan gelişimi |
| **G5** | **48** | Yarıçap **0,8 karo**; **3** parça | Stat/kapasite artışı |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `meteor_call` | G1 | `CAST` → `SummonObject(FallingMeteor)` | Çağırma davranışı ve varış |
| `meteor_impact` | G1 | `IMPACT` → tek hedefe ağır hasar | Meteor çarpması |
| `meteor_area` | G2 | `IMPACT` → alandaki uygun hedefleri vur | **Alan darbesi** |
| `meteor_fragments` | G3 | `IMPACT` → `SpawnFragments(Stone)` | Fiziksel parçalar |

**Örnek:** `Meteor G3.meteor_fragments ← Electric G3` açılmış parçaların sıçraması; `Meteor G2.meteor_area ← Poison G1` alan hasarına zehir uygulaması; `Meteor G1.meteor_call ← Ice G1` gelen meteorun etkisine yavaşlatma eklenebilir, ancak bu işlem kendi başına G2 alan etkisini yaratmaz.

**Kritik tasarım ayrımı:** “Patlama” rünü yok. Meteor G2'nin **alan çarpması** ve Volkan G2'nin **küçük lav sıçraması** ilgili fiziksel olaylarının ortak `AreaImpact` işlevidir; her Meteor'a sonsuz zincir patlama eklenmez.

---

## 13. Rune 10 — VOLKAN (`volcano`)

**Kule davranışı:** Hedef bölgeye geçici **sabit volkan** oluşturur. Volkan ömrü boyunca otomatik lav atar. **TD rolü:** Periyodik bölge baskısı; bölgesel saldırıların crafting'le derinleşmesi.

| Grade | Volkan ömrü | Lav hasarı | Aralık / açılım |
|---|---:|---:|---|
| **G1** | **6 sn** | **7** | **2,5 sn**; `volcano_summon`, `lava_shot`, `lava_hit` |
| **G2** | **7 sn** | **9** | **2,2 sn**; `lava_splash` (küçük çevresel sıçrama) |
| **G3** | **8 sn** | **11** | **2,0 sn**; `wide_eruption` (aynı atım döngüsünde uygun birkaç hedefe geniş püskürme) |
| **G4** | **10 sn** | **13** | **1,8 sn**; stat gelişimi |
| **G5** | **12 sn** | **16** | **1,6 sn**; süre/hasar/ritim gelişimi |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `volcano_summon` | G1 | `CAST` → `SummonObject(StationaryVolcano)` | Volkan çağrılması / ortaya çıkış |
| `lava_shot` | G1 | `ENTITY_ATTACK` → lav mermisi | Periyodik lav atımı |
| `lava_hit` | G1 | `HIT` → ısı vuruş hasarı | Lavın isabeti |
| `lava_splash` | G2 | `IMPACT` → küçük alan hasarı | Lav sıçrama alanı |
| `wide_eruption` | G3 | `ENTITY_ATTACK` → birden çok uygun yön/hedef | Geniş püskürme |

**Kritik:** Volkanın doğal lav hasarı, Ateş G3'ün `Burn` mekanizması **değildir**. `Volcano G3.lava_hit ← Fire G3` lav atışlarına yanma uygular. `Volcano G3.lava_shot ← Electric G3` lav hedefler arasında sekebilir. `Volcano G3.lava_shot ← (Electric G3 ← Ice G1)` sekmeli lavın ulaştığı hedef yavaşlayabilir.

**Çağrı sınırı:** Kule aynı anda çok sayıda volkan kurarak haritayı kapatmamalı; summon kapasitesi ve yaşam süresi genel bütçeye tabidir. Volkanlar düşmanın rotasını fiziksel duvar gibi tıkamaz.

---

## 14. Rune 11 — GOLEM (`golem`)

**Kule davranışı:** Hareket edip hedefe yakın dövüş saldırıları yapan **tek dost golem** çağırır. **TD rolü:** Hareketli yerel savunma, düşman saldırılarını üstüne çekme potansiyeli (ayrı provoke yeteneği şu anda açık değil).

| Grade | Golem HP | Vuruş | Ömür / açılım |
|---|---:|---:|---|
| **G1** | **60** | **8** | **10 sn**; çağır, hedef bul, normal vur |
| **G2** | **75** | **10** | **11 sn**; `armored_body` hasar azaltma; pilot önerisi **%10** |
| **G3** | **90** | **12** | **12 sn**; `ground_slam` yakın çevreye zemin darbesi |
| **G4** | **110** | **14** | **14 sn**; stat gelişimi |
| **G5** | **135** | **17** | **15 sn**; güçlenen darbe, zorunlu farklı bir tür yok |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `golem_summon` | G1 | `CAST` → `SummonObject(GolemUnit)` | Dost birimin varlığı |
| `golem_targeting` | G1 | Periyodik → yakın uygun düşmanı seç | Hedefleme davranışı (sınırlı graft uyumu) |
| `golem_melee_hit` | G1 | `ENTITY_ATTACK` → fiziksel hasar | **Golem'in normal vuruşu** |
| `armored_body` | G2 | Golem hasar alınca hasar azalt | Savunma, yalnız uyumlu graft'lar |
| `ground_slam` | G3 | `ENTITY_ATTACK` → yakın alan darbesi | Zemin darbesi |

**Örnek:** `Golem G3.golem_melee_hit ← Fire G3` her normal vuruş yanma uygular. `Golem G3.ground_slam ← Ice G1` alan darbesi yavaşlatır. Golemin fiziksel saldırısı veya konumlanması oyuncu karakteri gibi kontrol edilmez; kule otomatik komut verir.

**Tower defense kısıtı:** Golem düşman yolunu kalıcı kapatmaz. Birim canı ve hasar alması düşman tipine bağlıdır; düşman tarafından hedef alınabilen birimlerle hedef alamayan yürüyüşçülerin davranışları farklı olabilir.

---

## 15. Rune 12 — KOVAN (`hive`)

**Kule davranışı:** Sabit bir yuva oluşturur; ömrü boyunca küçük böcekler üretir. **TD rolü:** Küçük vuruşları çok kez uygulama, dağınık düşmanları oyalama, uzun dalgalarda baskı.

| Grade | Yuva ömrü | Böcek hasarı | Aktif böcek / açılım |
|---|---:|---:|---|
| **G1** | **10 sn** | **3** | En çok **2** böcek; yuva kur, böcek üret, normal vur |
| **G2** | **11 sn** | **4** | En çok **3** böcek; üretim kapasitesi artar |
| **G3** | **12 sn** | **5** | En çok **3** böcek; `swarm_focus` tek hedefe koordineli saldırı |
| **G4** | **14 sn** | **6** | En çok **4** böcek; stat/kapasite artışı |
| **G5** | **16 sn** | **7** | En çok **5** böcek; stat/kapasite artışı |

| Ability ID | Açılma | Olay → yaptığı iş | Aşıya uygun hedef |
|---|---|---|---|
| `hive_summon` | G1 | `CAST` → `SummonObject(HiveNest)` | Yuvanın kurulması |
| `spawn_beetles` | G1 | Yuva aktifken → `SpawnChildUnits(Beetle)` | **Böceklerin oluşması** |
| `beetle_hit` | G1 | `ENTITY_ATTACK` → böcek ısırığı | **Her böceğin normal vuruşu** |
| `swarm_focus` | G3 | Hedef atama → birkaç böcek aynı hedefe odaklanır | Sürü hedefleme |

**Örnek:** `Hive G3.beetle_hit ← Blood G1` böcek vuruşları hedefe mesafe bazlı kanama uygular. `Hive G3.beetle_hit ← Ice G1` böcekler yavaşlatır; `Hive G3.beetle_hit ← Fire G3` böceklerin isabetleri yanma uygular. Her böcek **ayrı ayrı** sınırsız summon üretmez.

---

## 16. Rün → özellik → fonksiyon matrisi (hızlı kontrol)

| Rün | G1 — çekirdek | G2 — ilk ek işlev | G3 — imza yetenek | G4 — gelişim | G5 — zirve |
|---|---|---|---|---|---|
| **Ateş** | Isı isabeti | Isı yükü | Yanma + tik | Güçlü yanma | Ateş izi |
| **Buz** | Yavaşlatma | Soğuk birikimi | Donma | Uzun donma | Frozen ölümünde buz parçaları |
| **Elektrik** | Elektrik isabeti | Yük birikimi | 1 sekme | 2 sekme | 3 sekme |
| **Zehir** | Zehir DoT | 2 yığın | İyileşme baskısı | 4 yığın | 5 yığın ve daha güçlü baskı |
| **Su** | Su hasarı | Islatma | Geri itiş | Yanana ekstra itiş | Daha güçlü itiş |
| **Taş** | Ağır darbe | Zırh aşındırma | Taş parçaları | Daha büyük hasar | 3 parça |
| **Işık** | Işın | Körlük/kamaşma | Delme | Uzun kamaşma | 2 ek hedef |
| **Kan** | Mesafe bazlı kanama | Yoğun kanama | Mesafeyle büyüyen hasar | Güçlü kanama | Yüksek hasar / yoğunluk |
| **Meteor** | Tek hedef düşüşü | Alan çarpması | Çarpma parçaları | Alan genişler | 3 parça / güçlü alan |
| **Volkan** | Geçici lav atan yapı | Sıçrama | Geniş püskürme | Daha hızlı lav | Uzun ömür / hızlı atış |
| **Golem** | Birim + vuruş | Zırhlı gövde | Zemin darbesi | HP ve hasar | Güçlü zemin darbesi |
| **Kovan** | Yuva + böcekler | Daha çok böcek | Sürü odağı | Daha yüksek kapasite | 5 böcek |

---

## 17. Otomatik grafting davranış sözleşmesi

### 17.1. Dört soruya cevap veren kural

Her graft denemesinde yalnızca bunlar değerlendirilir:

1. **Ana rün hangisi?** Saldırının temel kimliği (Volkan, Buz, Su, Golem vb.) korunur.
2. **Hedef açık mı?** `Ice G3.frozen_death_shards` kapalıdır; G5 gerekir.
3. **Vericinin hangi işlevleri açık?** `Electric G1` hasar, `Electric G3` hasar + sekme; başka şey yaratılmaz.
4. **Bu işlev, hedefin taşıyıcısında anlamlı mı?** Doğrudan vuruş, DoT tiki, fiziksel parça, alan vuruşu, summon saldırısı vb. desteklenebilir; savunma gövdesine mermi sekmesi sırf isim benziyor diye eklenmez.

Craft menüsü her uygun hedef için **önizleme metni ve stat farkını** göstermeli. Uygun olmayan hedef `uyumsuz`, `vericide kilitli`, `alıcıda kilitli` gibi anlaşılır bir gerekçeyle engellenmeli.

### 17.2. Taşıyıcılar ve genel aktarım tablosu

| Hedef taşıyıcı | Saf hasar katkısı | Durum katkısı | Zincir G3+ | Fiziksel parça | Summon/ayrı birim davranışı |
|---|---|---|---|---|---|
| **Doğrudan mermi HIT** | Evet | Evet | Evet | Yalnız vericide ve hedefte ilgili yetenek açık/uyumluysa | Doğrudan, genel olarak **hayır** |
| **Yanma / zehir STATUS_TICK** | Evet, kontrollü | Evet, uygulanabilir duruma göre | Evet, etki aktarımı | Hayır | Hayır |
| **Meteor/taş IMPACT** | Evet | Evet | Sıçrayabilen uygun çarpma parçasında; çarpma olayının kendisini körlemesine kopyalamaz | Uygunsa | Yalnız açık summon taşıma uyumu varsa |
| **Fiziksel FRAGMENT** | Evet | Evet | Evet, hedef bulma | Ek sonsuz parça üretimi varsayılan kapalı | Hayır |
| **GROUND FIELD_TICK** | Evet | Evet | Etki taşıma ancak bütçe ve işlev uyumuyla | Hayır | Hayır |
| **Golem / böcek ENTITY_ATTACK** | Evet | Evet | Vuruş etkisi komşu düşmana taşınabilir | Yalnız özel açık parça işlevi varsa | Birim çağrısını otomatik çoğaltmaz |
| **Summoned entity SPAWN** | Yalnız varlık üzerinde açık uyumlu spawn etkisi | Yalnız açık uyumlu spawn etkisi | Genelde hayır | Genelde hayır | Çağrının kimliği korunur |
| **Savunma gövdesi (Golem G2)** | Genelde hayır | Genelde hayır | Hayır | Hayır | Yalnız savunma uyumlu katkı |

**Örnek reddedilen craft:** `Golem G2.armored_body ← Electric G3.electric_chain` → sekme savunma gövdesinin aldığı hasara bağlanacak şekilde tasarlanmamışsa **uyumsuz**. Sırf iki rün var diye zırha elektrik patlaması eklenmez.

### 17.3. İç içe graft ve çoklu aşı

```text
Fire G5
├─ fire_hit
├─ heat_stack
├─ burn_tick                       ← ana rünün G3'te açılmış yeteneği
│  ├─ Electric G3                  ← yanma tiki uygun hedefe aktarılabilir
│  │  └─ [electric_chain] Ice G1   ← taşınan etkiye yavaşlatma katkısı
│  ├─ Poison G2                    ← aynı yanma olayında zehir yığınları
│  └─ Blood G1                     ← yanmanın ulaştığı hedefe kanama
└─ fire_trail
   └─ Poison G1                    ← zemindeki uygun alan vuruşuna zehir
```

- Aynı `burn_tick` özelliğinde üç graft vardır. **Tek verici sınırı yoktur.**
- Elektrik G3'ün içinde Buz G1 vardır: Buz **donma sağlamaz**, aktarılmış sonuçta yavaşlatma katkısı verir.
- Kardeş graft'ların crafting ekranındaki yer değişimi (aynı verilerde) güç/sonuç bakımından eşdeğer olmalıdır. **Ana rün ile verici rünün yönü ise önemli**: `Fire ← Electric` ve `Electric ← Fire` aynı saldırı değildir.
- **Nested davranış, üst bağlamın yetenek çıktısını değiştirmelidir.** İçteki Buz, üstteki ateşin bütün özelliklerine otomatik yayılmaz; Elektriğin aktardığı belirli etkiye bağlı kalır.
- Craft tarifi derinleşse de gerçek oyunda her olayın **bir kaynak kimliği, güç bütçesi ve çoğalma sınırı** vardır. 20 graft düğümlü rün 20 ayrı büyük mermi yapmak zorunda değildir.

### 17.4. Karmaşık grade örnekleri

- `Fire G3.burn_tick ← Electric G1` ⇒ yanma tikine elektrik **hasarı**, **sekme yok**.
- `Fire G3.burn_tick ← Electric G3` ⇒ yanma tikinin uygun yakın hedefe **taşınma olasılığı / kapasitesi** vardır.
- `Fire G3.burn_tick ← (Electric G3 ← Ice G1)` ⇒ aktarılan yanma **yavaşlatma** taşır, donma yok.
- `Fire G3.burn_tick ← (Electric G3 ← Ice G3)` ⇒ vericinin donma özelliği açılmıştır, ama otomatik frozen **yalnızca soğuk yükü ve threshold bütün şartları karşılanırsa** gerçekleşir; tek sekme anında sebepsiz donma olmaz.
- `Ice G3.frozen_death_shards ← Electric G3` ⇒ **imkânsız**, çünkü hedef özellik G5'te açılır.
- `Ice G5.frozen_death_shards ← Electric G1` ⇒ parçalar elektrik hasarı taşıyabilir; sekme yok.
- `Ice G5.frozen_death_shards ← Electric G3` ⇒ parçalar sekebilir.
- `Water G2.water_push ← Blood G1` ⇒ **imkânsız**, Su'da itiş G3'te açılır.
- `Volcano G1.lava_hit ← Fire G3` ⇒ lav yanma uygular; volkanın G2 sıçraması / G3 geniş püskürmesi açılmaz.

### 17.5. İşlem sırası; oyuncuya gösterilmez

Aynı fiziksel vuruşta **tutarlı** değerlendirme olmalıdır. Önerilen anlamlı sıralama:

`Temel isabet → açık durum uygulamaları → açık zorunlu hareket → gerçek MOVE_DISTANCE olayları → bunların hasarı / DoT kayıtları → ölüm kontrolleri → mevcut açık ölüm sonuçları`.

Durum tikinde: `Orijinal tik → graft katkısı → varsa izinli aktarım → yeni hedefte taşınmış etki`.

Bu sıra kullanıcıya programlama ekranı olarak sunulmaz; yalnızca oyun sonucunun tutarlı ve önizlenebilir kalmasını sağlar.

---

## 18. Birleşim ve savaş etkileşimi senaryoları

| # | Kurulum | Hedef | Kesin oynanış beklentisi / sınır |
|---|---|---|---|
| **01** | `Fire G3 ← Electric G1` | `burn_tick` | Yanma tiki elektrik hasarı da verir; sekme **yok**. |
| **02** | `Fire G3 ← Electric G3` | `fire_hit` | Ateş mermisi 1 ek uygun hedefe sekebilir, her isabette yanma uygular. |
| **03** | `Fire G3 ← Electric G3` | `burn_tick` | Yanma tiki etkiyi yakın hedefe taşıyabilir; ateş mermisi sekmez. |
| **04** | `Fire G3 ← (Electric G3 ← Ice G1)` | `burn_tick` | Yayılan yanma yavaşlatma da taşır; donma açılmaz. |
| **05** | `Fire G5 ← Electric G3 + Poison G2 + Blood G1` | `burn_tick` | Yanma tiki kontrollü şekilde yayılır; hedefe zehir yığını ve kanama uygulayabilir; kendi başına başka ateş izi üretmez. |
| **06** | `Ice G5 ← Electric G3` | `frozen_death_shards` | Frozen halde ölen düşmanın buz parçaları hedef arayarak sekebilir. |
| **07** | `Water G3 ← Blood G1` | `water_hit` | Tek birleşik kule kanatır ve iter; kat edilen geri itiş mesafesi kanama hasarı üretir. |
| **08** | `Blood G1 ← Water G3` | Kan ana isabeti | Kan ana rün kimliğini koruyup itişli kanama vuruşu yapar; uyumlu taşıyıcı olmalı. |
| **09** | `Water G4 ← Blood G1` + yanan düşman | `water_hit` | Yanma durumuna karşı ×1,5 itiş; kanama, daha uzun zorunlu hareketten daha yüksek hasar alır. |
| **10** | `Ice G3` + ayrı `Blood G1` kule | Ortak hedef | Yavaşlama Kan'ın normal mesafe hasarını düşürebilir; **sinerji değil, karşıtlık**. |
| **11** | `Volcano G3 ← Electric G3 + Ice G1` | `lava_shot` | Periyodik lav sekebilir ve yavaşlatır. Yanma zorunlu değildir. |
| **12** | `Volcano G3 ← (Electric G3 ← Fire G3 ← Ice G1)` | `lava_shot` | Açık katkılarla lav saldırısı zincirlenir, yanma ve yavaşlatma taşır; gizli Meteor oluşmaz. |
| **13** | `Meteor G2 ← Poison G1` | `meteor_area` | Çarpmanın vurduğu hedefler zehirlenir; zehir patlamaz. |
| **14** | `Meteor G3 ← Electric G3` | `meteor_fragments` | Meteor parçaları uygun hedefe sekebilir; Meteor G1'de parça yok. |
| **15** | `Golem G3 ← Fire G3` | `golem_melee_hit` | Golem vuruşları yanma uygular; golem hâlâ hareketli yakın dövüşçüdür. |
| **16** | `Golem G3 ← Ice G1` | `ground_slam` | Zemin darbesi yakın hedefleri yavaşlatır; dondurmaz. |
| **17** | `Hive G3 ← Blood G1` | `beetle_hit` | Böceklerin ısırıkları kanama uygular; ek böcek spawn etmez. |
| **18** | `Hive G3 ← Poison G2` | `beetle_hit` | Böcek vuruşları zehir yığınlarını artırır; sürü odaklanmasıyla tek hedefte yoğunlaşır. |
| **19** | `Light G3 ← Poison G1` | `beam_pierce` | Delici ışın birden fazla hedefe zehir uygular. |
| **20** | `Stone G3 ← Electric G3` | `stone_fragments` | Çıkan taş parçaları uygun hedefe yönelerek aktarılabilir. |
| **21** | `Fire G5 ← Poison G1` | `fire_trail` | Ateş alanına basan düşmanlar aynı zamanda zehir alır; DoT'tan yeni alan oluşmaz. |
| **22** | `Volcano G5 ← Fire G3 + Electric G3 + Ice G1` | `lava_hit` ve `lava_shot` | Volkan kimliği korunur; yanma lav isabetinde, zincirleme lavın taşıyıcısında, yavaşlatma aktarılmış uygun hasarda çalışır. Farklı hedeflere farklı graft uygulanır. |
| **23** | `Water G1 ← Blood G1` | `water_hit` | Su ve kanama uygulanır ama **itiş yoktur**; Kan ancak düşmanın daha sonra yaptığı gerçek hareketle hasar verir. |
| **24** | `Light G2 ← Electric G1` | `light_blind` | Kamaşma uygulamasına elektrik hasarı katkısı olabilir, **Elektrik zinciri yoktur**. |

### 18.1. Ayrıntılı vaka: İç içe yanma yayılması

```text
Ateş G3
└─ Yanma tiki
   └─ Elektrik G3 (1 hedefe taşıma açık)
      └─ Elektrik aktarımı / etkisi ← Buz G1 (yavaşlatma açık)
```

1. Ateş mermisi düşman A'yı vurur; A `Burn` taşır.
2. Yanma tiki gerçekleşir; ilk hasar A'ya uygulanır.
3. Elektrik G3'ün `ChainTransfer` yeteneği yakın uygun düşman B'yi seçer (aynı etki zincirinin sınırları dahilinde).
4. B'ye taşınan yanma katkısı uygulanır; Elektriğin içindeki Buz G1 ek yavaşlatma aktarır.
5. Buz G1'de soğuk yük / donma açık değildir. B Frozen olmaz. Zincir gereksizce başka sonsuz bir yanma zinciri üretmez.
6. Elektrik G3'ün yüksek grade'i ve craft güç aktarım katsayıları hasar/aktarım verimini belirler; kesin katsayılar ayrı denge çalışmasıdır.

### 18.2. Ayrıntılı vaka: Tek kulede Su + Kan

```text
Ana: Su G3 → su vuruşu, ıslaklık, 0,35 karo geri itiş
Graft: Kan G1 → doğrudan vuruşta kanama, 3 hasar/karo hareket
```

1. Su saldırısı isabet eder: doğrudan **12** su hasarı verir.
2. Graft katkısıyla kanama statüsü hedefe **önce** uygulanır.
3. Su G3 hedefi **0,35 karo** geri iter (direnç ve engeller gerçekleşen mesafeyi değiştirebilir).
4. Kan G1 gerçek hareket mesafesine göre yaklaşık **0,35 × 3 = 1,05** ek hasar üretir; gerçek uygulama kesirli hasarı destekler veya kontrollü yuvarlar.
5. Düşman yürüdükçe kanama devam eder. Su G4 ise ve hedef ayrıca Burn taşıyorsa teorik itiş `0,45 × 1,5 = 0,675 karo` olur (direnç/engel öncesi). Aynı G1 Kan katkısında **2,025** hareket hasarı örneklenir.
6. Buzla yavaşlatılırsa normal yürümeye bağlı kanama DPS'i azalabilir; **zorunlu itiş mesafesi** yine gerçekse hasar sayılır.

> Sayısal demo G3/G4 değerlerini doğrudan kullanır; burada *tek bir Water+Blood tarifine özel hasar bonusu* yazılmamıştır.

### 18.3. Ayrıntılı vaka: Volkanın lava kanalları

```text
Volkan G5 (ana)
├─ Volkan çağrılması (12 sn)
├─ Lav atımı (1,6 sn periyot)
│  └─ Elektrik G3 (atışın 1 kez sekebilmesi)
│     └─ Buz G1 (aktarılan isabetlerde yavaşlatma)
├─ Lav isabeti
│  └─ Ateş G3 (yanma uygula ve yanma tikleri)
├─ Lav sıçraması (Volkan G2)
└─ Geniş püskürme (Volkan G3)
```

**Beklenen:** Sahaya çıkan nesne hâlâ sabit Volkan'dır. Kendi periyoduyla lav atar. Uygun sekmeli lav hasarı hedeflere yavaşlatma taşır; lav vuruşunda yanma uygular. Graft'lar volkanın otomatik olarak Meteor, Golem veya sonsuz sayıda başka volkan çağırmasına yol açmaz.

---

## 19. Genel sınırlar: Çok derin tariflerde oynanışın bozulmaması

Bu sınırlar oyuncunun algoritma yazmasını önlemek için arka planda çalışır; **değerler MVP pilot varsayımıdır**, nihai denge değil.

| Risk | Başlangıç güvenliği | Oyuncuya görünümü |
|---|---|---|
| **Sonsuz sekme** | Tek zincirde hedef tekrarını engelle; etkin hop sayısını vericinin açık grade'iyle sınırla | Sekme sayısı ve etkili hasar tahmini |
| **Status tiki → yeni Status tiki** | Transfer edilen olayın tekrar aynı zinciri sınırsız başlatmasına izin verme; jenerasyon sınırı | “Zincir gücü azalıyor” bilgisi |
| **Summon zinciri** | Harita ve kule bazlı aktif varlık üst limiti; varlık başına ömür/üretim kapasitesi | Aktif varlık sınırı ve beklenen DPS |
| **Her böcek saldırısında daha fazla böcek** | Temel `beetle_hit` taşıyıcısı varsayılan olarak `SpawnChildUnits` yetkisi taşımaz | Uyumsuz graft gerekçesi |
| **Aynı anda onlarca parçacık** | VFX parçacıkları görsel bütçe; gerçek fiziksel parça sayısı ayrı mekanik bütçeye tabi | Gerçek parça sayısı ve etkisi |
| **Derin craft** | Craft ağacı kaydedilebilir; çalışma anındaki event derinliği kontrollü; içerik kaybı olmadan pasif statlara katkı | “Aktif katkılar” ve “güç katkıları” ayrı gösterilir |
| **Kule spam/VFX karmaşası** | Basit, büyük ve okunabilir etki şekilleri; uzaktaki VFX sadeleşir | Yakın incelemede detay, uzak kamerada sade görüntü |
| **Aşırı geri itiş** | Gerçek yol/topoloji ve boss direnci; ölümsüz yavaşlatma/itme döngüsü önlenir | Efektif itiş ve direnç uyarısı |

Açık tasarım sorusu: Çok derin iç içe graft'ların mekaniğini sadece sayısal güç olarak mı sıkıştıracağız, yoksa seçilmiş birkaç aktif katkı birlikte mi çalışacak? Pilot uygulamada **mekanik işlevler korunurken olay ve varlık sayısını bütçelemek** tercih edilir; gizlice katkı silmek yapılmamalıdır.

---

## 20. TD özgü dünya ve düşman kuralları

- **Otomatik hedefleme:** Kule, volkan, golem ve böcekler uygun düşmanları kendi davranışlarıyla seçer. Oyuncu her rünün hedefleme algoritmasını kodlamaz.
- **Yol/topoloji:** Düşmanların izlediği yol çizgisi önemlidir; zorunlu geri itiş yol üzerindeki geçerli konuma uygulanır. Yoksa su rünü düşmanı harita dışına veya nehre fırlatan hatalı bir özellik haline gelir.
- **Yol kapatma:** Golem, Volkan ve Kovan çağrıları düşman yolunu kalıcı kapatamaz. Savaşta kapladıkları pozisyon sadece geçici hedefleme/çarpışma davranışı yaratabilir.
- **Düşman dirençleri:** Boss'lar itişe/donmaya kısmi dirençli olabilir ama bütün rün kimliklerini etkisiz kılmamalıdır. Kanamanın hareket mesafesi, ışığın körlüğü ve taşın zırh aşındırması, düşman sınıfına göre farklı verim gösterir.
- **Çoklu kule sinerjisi:** Bir ründeki durum diğer kuleden de okunabilir; Fire G3 başka kulede olsa bile Su G4 hedefte Burn görünce ekstra itiş uygular.
- **Hedef ölümü:** Donmuş ölümünde buz parçası üretme G5 Buz kökenli ve kaynak takibi olan bir durum sonucudur. Frozen durumu silinmeden ölümün kontrolü yapılır; farklı kulenin son vuruşu da parçayı tetikleyebilir, ancak sırf G3 Buz donması tek başına G5 parçalarını açmaz.
- **Menzil:** Işık ışını delme hattı ve Meteor iniş alanı gibi rünler normal kuleden ayrı menzil/erişim ayarı gerektirebilir. Bunlar tasarım kademesidir, son değer değil.
- **Mana:** Mana Crystal / Mana ekonomi ayrımı önceki oyun planında vardır; bu belgede her işleme kesin maliyet vermiyoruz. Ayrı ekonominin yapılması gerektiği açık görevdir.
- **Harita görünürlüğü:** Işık rününün gelecekte keşif/tarama uygulaması düşünülebilir; MVP'de ayrı harita tarama fonksiyonu zorunlu değildir.

---

## 21. Mekanik ↔ görsel sözleşmesi (asset üretimi DEĞİL)

Görsel tasarımcı/ajan bu mekanik listeyi okuyarak otomatik rün sunum dilini tasarlayacak. Burada kesin görsel şekil, materyal veya rün skin'i dikte edilmez.

**Mecburi anlaşılabilirlik hedefleri:**

1. **Kulenin üstünde süzülen ana rün:** Tek baskın görsel nesne. Ana Volkan ise ana kimliği Volkan; aşılı Elektrik bunu ayrı Elektrik kulesine dönüştürmez.
2. **G1–G5:** En az beş grade durumu; eklenen mekanik ve gelişim okunabilir, her grade için ayrı büyük el yapımı model mecburi değildir.
3. **Açık yetenekler:** Buzun `freeze_threshold` ve `frozen_death_shards`, Ateşin `burn_tick` ve `fire_trail` gibi farklı graft hedefleri envanter/inceleme ekranında ayırt edilebilir olmalıdır.
4. **Aşılı rünler:** Bir ana rune 1, 4, 12, 20+ graft düğümü taşıyabilir. Görünüş her graft için zorunlu bir tam boy küp gerektirmez; otomatik ve deterministik yoğunluk dili bulunmalıdır.
5. **Nested graft:** `Fire.burn_tick ← (Electric G3 ← Ice G1)` ile `Fire.burn_tick ← Electric G3` oynanışta farklıdır; inceleme ekranı bu farkı açıkça göstermelidir.
6. **Graft'ların da grade'i:** Ana rün G5 iken aşılı Elektrik G3 ve onun içindeki Buz G1 olabilir. Üçü aynı görsel boyutta olmak zorunda değildir.
7. **Combat VFX ayrı:** Yanma tiki, sekme, kanama, lav atımı, meteor çarpması, summon oluşumu, buz parçaları birbirinden anlaşılabilir savaş VFX'leri gerektirir. Her olası kombinasyona ayrı VFX dosyası gerekmez.
8. **Minimalist sanat yönü:** Sade, kübik, büyük okunabilir şekiller; gürültülü minicik voxel detayı, sürekli yoğun partikül ve her graft için yeni detay yığını yok.
9. **Tekrar üretilebilirlik:** Aynı craft tarifi hem aynı mekanik sonuç hem tutarlı rün görünümü üretir.
10. **Görsel karar özgürlüğü:** Küp formu, model sayısı, sembol tekniği, grade geometrisi, yörünge, yüzey varyantı, shader, animasyon ve güç hissinin ifade yöntemi **ayrı görsel tasarım çalışmasına** bırakılmıştır.

### 21.1. Beklenen temel savaş VFX kategorileri

| Mekanik ailesi | Savaş sırasında görülecek olay (yön tarifidir) |
|---|---|
| Hit | Tek okunaklı vurma vurgusu; hasar türü küçük renk/şekil farkıyla okunur |
| DoT tick | Hedefte kısa periyodik ikon/partikül; sürekli ekran kaplayan alev değil |
| Chain | Kaynak/sonraki hedef arasında net, anlık bağlantı |
| Freeze | Hedef üzerinde sabit, çok kısa okunur buz formu |
| Shards | Sayılabilir fiziksel parçalar ve yöne hareket |
| ForceMove | Düşmanın yol boyunca geri taşınması; hareket hasarı bildirimi |
| AreaImpact | Çarpma çevresinde okunaklı halka/alan sınırı |
| SummonStructure | Volkan veya Kovan yapısının ortaya çıkışı |
| SummonUnit | Golem veya Kovan böceğinin ortaya çıkışı |
| Field | Sadece gerçek etkili bölgede sade yüzey işareti |
| Blind | Düşmanın saldırı davranışına bağlı kısa kamaşma sembolü |

**Önemli:** Rünlerin kendisine ait tasarımlar burada üretilmez; bu belge yalnızca “görünmesi gereken doğru olay hangisi?” sorusunu cevaplar.

---

## 22. MVP test kabul kriterleri (oynanış sözleşmesi)

- [ ] 12 rünün **her biri G1–G5** ile çalışır; tablodaki açılma/kapalı olma kuralları izlenir.
- [ ] Ateş G1/G2'de Burn yok; G3'te periyodik yanma var; G5'te gerçek alan izi bulunur.
- [ ] Buz G1 yavaşlatır, G2 soğuk biriktirir, G3 dondurur, G5 donmuş ölümünde parça çıkarır.
- [ ] Elektrik G1–G2 **sekmez**, G3–G5 1/2/3 aktarım kapasitesine sahiptir.
- [ ] Zehir G1 DoT'tur; G2+ yığın ve G3+ şifa baskısı; kendiliğinden patlama yaratmaz.
- [ ] Su G1–G2 **itmez**, G3 iter; G4 Burn taşıyan düşmana daha güçlü iter.
- [ ] Kan G1 hasarı gerçek yürüyüş mesafesinden gelir; Su zorunlu itişi mesafeye sayılır, teleport sayılmaz.
- [ ] Taş G2 zırh aşındırır, G3 fiziksel parça üretir.
- [ ] Işık G2 kamaştırır, G3 delme açar; harita tarama henüz zorunlu değil.
- [ ] Meteor G1 tek hedefe düşer, G2 alan açar, G3 parça üretir.
- [ ] Volkan G1 sabit geçici yapı olup lav atar, G2 sıçrama, G3 geniş püskürme açar; otomatik Burn yok.
- [ ] Golem G1 hareketli yakın dövüş summon; G2 savunma; G3 zemin darbesi.
- [ ] Kovan G1 böcek üretir, G3 odaklı sürü açar; böcek sayıları grade sınırına uyar.
- [ ] Aynı açık özelliğe birden fazla graft eklenir ve sonuçlar tutarlı birleştirilir.
- [ ] Verici içine ikinci/üçüncü kat graft eklenir; katkı yalnızca ilgili bağlamda kalır.
- [ ] Aşılanan düşük grade, daha yüksek yeteneği bedavaya açmaz.
- [ ] `Ice G3.frozen_death_shards` veya `Water G2.water_push` gibi kilitli hedefler graft ekranında reddedilir.
- [ ] Bir craft sonucu ana rünün kimliğini değiştirmez; Volkan hâlâ volkan, Kovan hâlâ kovan, Golem hâlâ golem üretir.
- [ ] Sekme, summon, status tiki ve parçalara ait sonsuz çoğalma engellenir.
- [ ] Aynı hedef üzerinde farklı kulelerden gelen durumlar ortaktır; Su G4 başka kulenin Burn durumunu tanır.
- [ ] Yavaşlama + Kan karşıtlığı ve Kan + Su sinerjisi hem aynı kulede hem farklı kulelerde çalışır.
- [ ] Her yetenek olayının gerçek oyun içinde **ayırt edilebilir, sade VFX** karşılığı tanımlanabilir.

---

## 23. Henüz kesinleşmemiş tasarım değerleri ve kararlar

Bunlar unutulmuş veya gizlice varsayılmış kurallar değildir; açık kararlar olarak ayrı tutulur:

1. **Grade ekonomi formülü:** Aynı grade iki rünün yükseltme maliyeti, farklı grade ile özellik güçlendirme katsayısı, tekrar crafting Mana bedeli.
2. **Her rünün atış aralığı ve menzili:** Şu an 1,5 sn / 4 karo genel karşılaştırma varsayımı var; Meteor ve summons için ayrı profil gerekli.
3. **Graft gücü düşümü:** Verici özelliğinin G1–G5'e göre ne kadarının geçtiği; çok katmanlı graft boyunca güç kaybı ve büyüme katsayıları.
4. **Status stacking:** Aynı hedefte birden fazla Burn/Poison/Bleed kaynağının toplanma/tazeleme yöntemi; küresel sınır.
5. **Alan ve fiziksel parça kalıcılığı:** G5 ateş izinin ne kadar sürdüğü; parçaların zeminde kalıp kalmadığı; parçaların gerçek collision/damage parametreleri.
6. **Chain hedef uzaklığı:** Elektrik G3+ hop menzili, güç düşümü ve ıslak hedeflerin tercih edilip edilmeyeceği.
7. **Freeze için tam eşik ve reset:** Burada G3'te 3 soğuk yükü önerildi; düşman direnci, yüklerin sönmesi ve tekrar donma bağışıklığı netleşmeli.
8. **Kanama yoğunluk formülü:** G2+ tekrar uygulama ve G3+ hareket bonusu hesabı; yüksek hızdaki düşmanlara tavan.
9. **Boss ve bağışıklık:** İtiş, donma, körlük, status direnci; kimi enemy türlerinin saldırı/iyileşme mekaniği olup olmadığı.
10. **Summon kapasitesi:** Volkan, Golem, Kovan sayısı; yuva üretim aralığı; düşmanla çarpışma ve aggro kuralları.
11. **Kule / summons hedef önceliği:** İlk/son/en yüksek can/en yakın; otomatik kural ve oyuncunun kolay seçimleri.
12. **Gerçek VFX ve rune appearance:** Ayrı görsel tasarım sistemi belirleyecek; bu belgede “küpün üzerinde hangi sembol olacak” zorunlu karar değildir.
13. **Işık harita taraması:** Gelecek keşif mekaniğine hangi grade'de ekleneceği MVP dışında.
14. **Oyuncu önizlemesi:** Çok derin graft ağacının anlaşılabilir biçimde nasıl özetleneceği ve 20+ düğümün oyun içi etkilerinin nasıl gösterileceği.
15. **Graft'in geriye alınması:** Craft kaydedildikten sonra graft ayrılabilir mi, kaynak geri kazanımı nasıl olur, ekonomisi ne? Bu dokümanda cevaplanmadı.

---

## 24. Sonuç — RuneCraft'ın rün kimliği

RuneCraft'ın rünleri **sabit iki efektli element taşları** değildir. Her rünün grade ile açılan kendi doğal işlevleri vardır: Ateş `hit/heat/burn tick/fire trail`, Buz `slow/cold stack/freeze/death shards`, Su `hit/wet/push/burning target bonus`, Meteor `summon/impact/area/fragments`, Volkan `summon/lava shot/lava splash/eruption`, Golem `summon/melee/armor/slam`, Kovan `summon/child units/swarm attacks` gibi.

Oyuncu yalnızca rünleri ve **açık yetenek hedeflerini** seçer. Ortak fonksiyonlar, grade kilitleri, dünya durumları ve iç içe graft bağlamı sonucunda otomatik çalışır. **Hiçbir bileşim için önceden ezberlenmiş eşleşme tarifi şart değildir; ama olmayan bir mekanik de kendiliğinden ortaya çıkmaz.**

Kule üzerindeki süzülen rün bütün bu craft'un tek temsilidir. İleride ona ait görsel, grade, iç içe aşılama ve combat VFX sistemi ayrıca tasarlanacak; **her olası kombinasyon için elle ayrı model üretilemez**.
