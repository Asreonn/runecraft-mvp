# RuneCraft — Rün Sistemi ve Görsel Tasarım Gereksinimleri
**MVP tasarım belgesi · Sürüm 3.0 · 30 Ekim 2026**

> **Bu bir oyun tasarımı belgesidir.** Godot implementasyonu, kod mimarisi, kesin denge kararı veya üretime alınmış görsel set değildir. İstenen sonuç: Bir görsel tasarım ajanının rün sisteminin nasıl çalıştığını eksiksiz anlayıp **kendi görsel dilini ve otomatik görsel üretim kurallarını önermesi**. Bu aşamada asset, `.vox`, texture, shader, VFX veya nihai render **üretme**.
>
> **Sayısal değerler** oynanış prototipi için ilk denge varsayımlarıdır; testten sonra değişebilir. **Mekanik ilkeler ve MVP kapsamı** ise bu belge için esas alınmalıdır.

---

## 1. Oyun ve tasarım hedefi

RuneCraft, yüksek açıdan ortografik kamerayla oynanan, minimalist/kübik 3D estetiğe sahip bir **roguelike tower defense** oyunudur. Oyuncu kuleler inşa eder; kulelerin saldırı kimliğini üzerlerinde süzülen **ana rün** belirler. Saldırı yapma, dalga savunma, düşman rotası, grup kontrolü, alan hasarı, çağırılan savunma birimleri, Mana verimliliği ve farklı kulelerin birbirini tamamlaması önceliklidir. Bir aksiyon-RPG değildir: oyuncu bir karakterin saldırı kombosunu veya tuş dizisini yönetmez.

Oyun için istenen crafting hissi:

1. Oyuncu bir **ana rün** seçer ve o rünün kimliğini koruyarak geliştirir.
2. Başka rünleri **ana rünün mevcut/açılmış özelliklerine aşılar**.
3. Aşılanan rün de önceden işlenmiş olabilir; iç içe crafting sınırsız bir tarif ağacı gibi derinleşebilir (uygulama performansı ve denge sınırları saklıdır).
4. Oyuncu saldırı algoritması, zamanlama grafiği, tetikleyici listesi veya Noita tarzı büyü sırası programlamaz. **Rün + hedef özellik** seçer; otomatik ve öngörülebilir bir sonuç görür.
5. Aynı ana rünün farklı grade'i ve farklı aşılama geçmişi, hem savaştaki rolünü hem de dış görünüşünü etkiler.
6. Binlerce kombinasyon için **ayrı model, ayrı elle hazırlanmış skin veya ayrı özel tarif** yapılamaz. Temel modellerden prosedürel/görsel bileşim gerekir.

### Değişmeyecek kapsam

**12 ana rün:** Ateş, Buz, Elektrik, Zehir, Su, Taş, Işık, Kan, Meteor, Volkan, Golem, Kovan.

- Rüzgâr, Gölge, Aura, Portal, Minyon adlı ayrı rün, Zihin ve diğer önceki 30'luk listedeki rünler **MVP dışında**.
- Minyon çağırma bir mekaniktir; bağımsız bir **Minyon rünü** MVP'de yoktur. Golem ve Kovan kendi kimlikleriyle birim çağırabilir.
- **Summon, DoT, patlama, sekme, fiziksel parça, geri itme, periyodik saldırı, kör etme** birer *mekanik*; ayrı support rün sınıfları değildir.
- Işık bir ründür; hem savaşta kullanılacak hem **gelecekte sisli haritayı tarama/keşif** mekaniği için adaydır. Keşif işlevi MVP'de etkin olmak zorunda değil.
- Oyuncunun üç ayrı support yuvası yok. Tek ana rün ve onun üzerine aşılanmış rünlerden oluşan çok katmanlı bir rün eseri var.

---

## 2. Grade tasarımı: yalnızca beş seviye

**G1, G2, G3, G4, G5**. Bu tasarımda G8/G12/G20 yoktur. Önceki tasarımlardaki yetenekler beş kademeye yeniden dağıtıldı.

| Grade | Genel niyet | Zorunluluk |
|---|---|---|
| **G1** | Rünün temel saldırısı veya temel davranışı | Her ründe var |
| **G2** | İlk gerçek mekanik genişleme ya da mevcut davranışın farklılaşması | Çoğunda yeni yetenek |
| **G3** | Karakteristik ana mekanik açılır; oynanışta fark edilir | Çoğunda yeni yetenek |
| **G4** | Daha güçlü statlar; uygun ründe yeni durum/reaksiyon da açılabilir | Her ründe yeni özellik zorunlu değil |
| **G5** | En yüksek statlar, bazı rünlerde özel ileri yetenek | Her ründe yeni özellik zorunlu değil |

**Önemli:** Rünün G3'te sahip olduğu özellik G4/G5'te kaybolmaz; yalnızca güçlenebilir. Grade açılımları **kapalı/açık** mantığına sahiptir. Oyuncu üst grade özelliğini kapatamaz. G1 veya G2 verici kullanmak, örneğin yalnızca Elektrik hasarı taşıyıp zincirleme aktarmamak için bilinçli bir craft tercihidir.

### Sayısal tabloları okuma

- `Vuruş`: Tek bir normal saldırının, savunma ve direnç öncesi örnek hasarı.
- `DoT`: Hedef başına, belirtilen zaman birimi içindeki örnek hasar; bazılarında biriken yüklerle artar.
- `Mesafe`: Düşman üzerinde gerçekleşen gerçek yol alma; **zorunlu geri itme de dahildir**, ışınlanma dahil değildir.
- `Ömür`: Çağrılan geçici birimin/yapının varlık süresi.
- Tablolar **rün saflığı** içindir. Graft edilmiş bir ründe aktarım/etkileşim katsayıları ayrıca uygulanır. Buradaki istatistikler başka bir eşleşmeye özel algoritma değildir.
- Temel kule menzili, standart atış periyodu ve dalga ekonomisi henüz kesinleşmedi; tabloların değerlerini bunların yokluğunda mutlak oyun dengesi diye değerlendirme.

---

## 3. MVP rün kataloğu: her rünün G1–G5 gelişimi

Rünlerde **tek tip 'ölünce patlama / yerde iz / aura' şablonu yok**. Her biri kendi kimliğine göre değerlendirilir. Aşılamanın hedefleyebildiği özellikler ayrıca listelenmiştir. Tek bir rünün birkaç doğal davranışı aynı anda çalışabilir; grade ile açılan davranışlar zorunlu olarak aktiftir.

### 01 — Ateş · Doğrudan ısı → yanma → iz

**TD rolü:** Uzun süre hasar; bir arada tutulan düşmanlara karşı etkili.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Vuruş **10** | Yalnızca ısı mermisi; **yanma yok** |
| G2 | Vuruş **12**; ısı yükü **2/vuruş** | Isı yükü biriktirme açılır; henüz DoT yok |
| G3 | Vuruş **14**; yanma **3/sn × 3 sn** | **Yanma** açılır, tikler vardır |
| G4 | Vuruş **16**; yanma **4/sn × 3 sn** | Stat gelişimi; yeni büyük mekanik yok |
| G5 | Vuruş **19**; yanma **5/sn × 4 sn** | İleri yetenek: isabet hattında **kısa ateş izi** bırakabilme |

**Aşılama hedefleri:** `ateş isabeti` (G1), `ısı yükü` (G2), `yanma/tik` (G3), `ateş izi` (G5).

### 02 — Buz · Yavaşlatma → dondurma → buz parçaları

**TD rolü:** Rotada tutma, düşman gruplarını diğer kulelerin önünde bekletme.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Vuruş **7**; yavaşlatma **%20 / 1,5 sn** | Yavaşlatma var; donma yok |
| G2 | Vuruş **9**; yavaşlatma **%25 / 1,8 sn** | **Soğuk yükü** birikmeye başlar |
| G3 | Vuruş **11**; yavaşlatma **%30 / 2 sn** | Yük eşiği aşılınca **1,0 sn donma** açılır |
| G4 | Vuruş **13**; yavaşlatma **%35 / 2,3 sn** | Donma **1,2 sn**; yalnızca etkinlik gelişimi |
| G5 | Vuruş **15**; yavaşlatma **%40 / 2,5 sn** | **Donmuşken ölen düşman buz parçası saçar**; parçalar normalde yere düşer |

**Aşılama hedefleri:** `buz isabeti`, `yavaşlatma`, `soğuk yükü` (G2), `donma` (G3), `donmuş ölümünde buz parçaları` (G5). **Buz G5'te dondurma kapatılamaz.**

### 03 — Elektrik · Yük → sekme

**TD rolü:** Grup hasarı, bir etkiyi birkaç hedefe aktarabilme.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Vuruş **8**; sekme **0** | Elektrik hasarı ve yük; henüz aktarım yok |
| G2 | Vuruş **10**; sekme **0** | Hedefte **elektrik yükü** biriktirme güçlenir |
| G3 | Vuruş **12**; sekme **1** | **Zincir/sekme** açılır; komşu uygun hedefe aktarım |
| G4 | Vuruş **14**; sekme **2** | Zincir sayısı artar, aktarım gücü gelişir |
| G5 | Vuruş **17**; sekme **3** | İleri düzey çoklu aktarım; ayrı 'patlama' mekanizması doğmaz |

**Aşılama hedefleri:** `elektrik isabeti`, `yük` (G2), `sekme/aktarılma` (G3). **Elektrik G1 bir yanma tikine eklendiğinde yalnızca ek elektrik hasarı verir; sekme vermez.**

### 04 — Zehir · DoT → yığın → baskı

**TD rolü:** Zırhlı/yüksek canlı düşmana uzun süreli aşınma; bekleme süresini cezalandırma.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Zehir **2/sn × 3 sn** | DoT açılır |
| G2 | Zehir **3/sn × 3 sn** | Tekrar uygulamada **yük biriktirme** (en çok 2 yığın) |
| G3 | Zehir **4/sn × 4 sn** | En çok **3 yığın**; yüksek yığındaki hedefin iyileşmesini **%20** azaltır |
| G4 | Zehir **5/sn × 4 sn** | En çok **4 yığın**; yeni efekt yok |
| G5 | Zehir **6/sn × 5 sn** | En çok **5 yığın**; iyileşme baskısı **%30** |

**Aşılama hedefleri:** `zehir uygulaması`, `zehir tiki`, `yük birikimi` (G2), `iyileşme baskısı` (G3). Zehirin her grade'de patlaması veya yerde iz bırakması **şart değildir**.

### 05 — Su · Islaklık → zorunlu hareket → yanmaya karşı güçlü itiş

**TD rolü:** Düşmanı rotada geri püskürtme; Kan'ın hareket hasarıyla sinerji.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Vuruş **8**; itiş **0** | Yalnızca su hasarı; zorunlu geri püskürtme **yok** |
| G2 | Vuruş **10**; ıslaklık **3 sn** | **Islaklık** açılır; elektrik ve diğer çevresel olaylarla etkileşim potansiyeli |
| G3 | Vuruş **12**; itiş **0,35 karo** | **Zorunlu geri itme** açılır |
| G4 | Vuruş **14**; itiş **0,45 karo** | **Yanan hedefe +%50 itme** açılır (durumsal ileri yetenek) |
| G5 | Vuruş **17**; itiş **0,60 karo** | Yanan hedefe +%50 itiş sürer; stat gelişimi |

**Aşılama hedefleri:** `su isabeti`, `ıslatma` (G2), `geri itme` (G3), `yanan hedefe güçlendirilmiş itme` (G4). G3 Su + G1 Kan aynı ründe birleşirse geri itme, kanamanın **hareket mesafesine göre** hasar hesabına girebilir; ikinci kule gerektirmez.

### 06 — Taş · Ağır darbe → zırh aşındırma → parçalı darbe

**TD rolü:** Zırhlı düşmanlar ve yüksek tek hedef hasarı.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Vuruş **15** | Ağır taş mermisi |
| G2 | Vuruş **18**; zırh azaltma **%8 / 3 sn** | **Zırh aşındırma** açılır |
| G3 | Vuruş **21**; zırh azaltma **%12** | Sert çarpışmada **2 küçük taş parçası** oluşur |
| G4 | Vuruş **25**; zırh azaltma **%16** | Stat gelişimi; parça hasarı artar |
| G5 | Vuruş **30**; zırh azaltma **%20** | Parçalar **3 adet**; yeni zorunlu mekanik yok |

**Aşılama hedefleri:** `ağır çarpma`, `zırh aşındırma` (G2), `taş parçaları` (G3).

### 07 — Işık · Işın → kamaştırma → delme

**TD rolü:** Doğrusal hedefleme, saldıran düşmanları bozma; gelecek keşif sistemi için uygun.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Işın hasarı **9** | Tek hedef kısa ışın |
| G2 | Hasar **11**; kamaşma **1,5 sn** | **Kamaşma/kör etme** açılır; saldırı yapan düşmanın isabeti düşer |
| G3 | Hasar **13**; delme **1 ek hedef** | **Delici ışın** açılır |
| G4 | Hasar **15**; delme **1 ek hedef** | Kamaşma **2,0 sn**, stat artışı |
| G5 | Hasar **18**; delme **2 ek hedef** | Stat gelişimi, yeni ana mekanik şart değil |

**Aşılama hedefleri:** `ışın`, `kamaşma` (G2), `delme` (G3). **İleride** Fog of War'da haritayı tarama/keşif potansiyeli var; MVP combat grade tablosunda bunu aktif yetenek gibi sayma.

### 08 — Kan · Hareketle hasar → kanama yükü

**TD rolü:** Hareket eden ve **zorla hareket ettirilen** düşmanları cezalandırma; Buz ile anlamlı karşıtlık.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Kanama **3 hasar / karo hareket**; süre **3 sn** | Mesafe bazlı kanama; normal hareket ve geri itilme sayılır |
| G2 | Kanama **4 / karo**; süre **4 sn** | Tekrar isabette **kanama yoğunluğu** birikir |
| G3 | Kanama **5 / karo**; süre **4 sn** | Yoğun kanama, biriken toplam mesafede **+%20** hasar sağlar |
| G4 | Kanama **6 / karo**; süre **5 sn** | Stat gelişimi |
| G5 | Kanama **8 / karo**; süre **5 sn** | Birikim bonusu **+%30**; stat gelişimi |

**Aşılama hedefleri:** `kanama uygulaması`, `hareket mesafesi hasarı`, `kanama yoğunluğu` (G2). Buzun yavaşlatması düşmanın normal yürüyüşünden gelen kanama hasarını azaltabilir; Su G3 ile geri itme zorlanmış hareket sayıldığı için telafi eder. **Işınlanma hareket mesafesi değildir.**

### 09 — Meteor · Gökten çağırılan ağır cisim

**TD rolü:** Aralıklı yüksek çarpma hasarı; genişleyen darbe alanı.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Çarpma hasarı **24**; alan **tek hedef** | Gökten **meteor çağırma**; hareketli minyon değildir |
| G2 | Hasar **29**; alan yarıçapı **0,45 karo** | **Çevresel çarpma hasarı** açılır |
| G3 | Hasar **34**; **2 taş parçası** | **Çarpma parçaları** açılır |
| G4 | Hasar **40**; alan **0,65 karo** | Stat/alan gelişimi |
| G5 | Hasar **48**; alan **0,8 karo** | **3 parça**; stat gelişimi |

**Aşılama hedefleri:** `gökten düşen cisim`, `çarpma`, `alan darbesi` (G2), `çarpma parçaları` (G3). Patlama, bu tür çarpmanın **ortak alan-hasar mekanizmasıdır**; ayrı Patlama rünü yoktur.

### 10 — Volkan · Sabit, geçici periyodik saldırı yapısı

**TD rolü:** Yol kenarında kısa ömürlü alan baskısı; birden fazla hedefi uzun süre tehdit etme.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Volkan ömrü **6 sn**; lav vuruşu **7**; atım aralığı **2,5 sn** | **Sabit volkan çağırılır**, otomatik lav atar |
| G2 | Ömür **7 sn**; lav **9**; aralık **2,2 sn** | Atım döngüsünde **küçük çevresel sıçrama** açılır |
| G3 | Ömür **8 sn**; lav **11**; aralık **2,0 sn** | **Geniş püskürme** açılır, uygun yakın hedefleri kapsar |
| G4 | Ömür **10 sn**; lav **13**; aralık **1,8 sn** | Stat gelişimi |
| G5 | Ömür **12 sn**; lav **16**; aralık **1,6 sn** | Stat gelişimi; artan birikimle uzun süreli alan kontrolü |

**Aşılama hedefleri:** `volkanın oluşturulması`, `periyodik lav atımı`, `lav isabeti`, `küçük sıçrama` (G2), `geniş püskürme` (G3). **Ateş G3 graft edilmediyse**, volkanın ısı hasarı kendi başına otomatik *yanma DoT* anlamına gelmez.

### 11 — Golem · Hareketli dost savunma birimi

**TD rolü:** Düşmanların önünü kesmeden savunmaya eşlik eden yakından saldıran çağrı.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | HP **60**; vuruş **8**; ömür **10 sn** | Tek **hareketli golem** çağırır; düşmana vurur |
| G2 | HP **75**; vuruş **10**; ömür **11 sn** | **Zırhlı gövde**; gelen hasara direnç |
| G3 | HP **90**; vuruş **12**; ömür **12 sn** | **Zemin darbesi** açılır; yakın birden çok hedefe hasar |
| G4 | HP **110**; vuruş **14**; ömür **14 sn** | Stat gelişimi |
| G5 | HP **135**; vuruş **17**; ömür **15 sn** | Zemin darbesi güçlenir; yeni summon türü zorunlu değil |

**Aşılama hedefleri:** `golem çağırma`, `normal golem vuruşu`, `zırhlı gövde` (G2), `zemin darbesi` (G3). Yol tıkanması/çarpışma kuralları ayrıca dengelenir.

### 12 — Kovan · Sabit yuva ve böcek sürüsü

**TD rolü:** Birim sayısıyla baskı, zaman içinde büyüyen yerel savunma.

| Grade | Somut stat | Bu kademede değişen şey |
|---|---|---|
| G1 | Yuva ömrü **10 sn**; böcek hasarı **3**; aktif böcek **2** | **Kovan** çağırır; küçük böcekler üretir |
| G2 | Ömür **11 sn**; böcek hasarı **4**; aktif böcek **3** | Daha yoğun üretim açılır |
| G3 | Ömür **12 sn**; böcek hasarı **5**; aktif böcek **3** | **Sürü odaklanması**: böcekler aynı işaretli hedefe koordineli yönelir |
| G4 | Ömür **14 sn**; böcek hasarı **6**; aktif böcek **4** | Stat gelişimi |
| G5 | Ömür **16 sn**; böcek hasarı **7**; aktif böcek **5** | Stat gelişimi, uzun soluklu sürü baskısı |

**Aşılama hedefleri:** `kovan oluşturma`, `böcek üretimi`, `böceğin normal vuruşu`, `sürü hedefleme` (G3). Her böceğin ölünce patlaması veya iz bırakması gibi otomatik zorunlu mekanik yok.

---

## 4. Crafting ve grafting: oyuncunun yaptığı tek şey

### A. Ana rün, verici rün, hedef özellik

- **Ana rün:** Kuledeki saldırının veya çağrının kimliğini belirler; görünüşte baskın kalır. Örn. ana rün Volkan ise tower hâlâ volkan çağırır.
- **Verici rün:** Kendi grade'inde **gerçekten açık olan** özelliklerle katkı verir. Örn. Elektrik G1 yalnızca hasar; G3 sekme de getirir.
- **Hedef özellik:** Ana rünün açılmış bir özelliği (`lav atımı`, `yanma tiki`, `buz parçaları`, `golem vuruşu` vb.). Oyuncu yalnızca bunu seçer. Tetiklenme zamanı, programlama sırası veya manuel koşul tanımlamaz.
- **Birleşim sonucu:** Tek rün eseri; ana rünün kendi açılmış yetenekleri korunur; vericinin uyumlu katkıları eklenir. İlgili katkı uyumsuzsa sonuç açıklanır ve hedef seçeneği engellenebilir.
- **Grade bağımsızlığı:** Ana rün G5, altına eklenen Elektrik G3, onun altındaki Buz G1 olabilir. Hepsi kendi açılım eşiğini korur. Birleşim, alt rüne bedava G5 yeteneklerini açmaz.
- **Ana özellikleri kapatma yok:** Buz G3 ve üzeri dondurur; G5 buz parçaları salar. İstenmeyen ileri yetenekten kaçınmak için uygun düşük grade verici/ana rün tercih edilir.

### B. Her özelliğe birden fazla graft; her graft'ın da graft'ı olabilir

Bu oyun **tek satırlık birleştirmelerle sınırlanmaz**:

```text
Ana rün: ATEŞ G5
└── Yanma (ATEŞ'in G3'te açılan doğal özelliği)
    ├── ELEKTRİK G3  → Yanmanın başka hedefe yayılmasını sağlar
    │   └── BUZ G1   → Yayılan hedeflerde yavaşlatma ekler
    ├── ZEHİR G2     → Yanma uygulamasıyla zehir yükü taşır
    └── KAN G1       → Etkilenenlerde hareket kaynaklı kanama uygular

└── Ateş izi (ATEŞ'in G5'te açılan doğal özelliği)
    └── SU G2         → Islaklık katkısı: etkileşim sonucu, uyumluluk ve güç
                        önizlemesiyle belirlenir; otomatik 'buhar patlaması'
                        uydurulmaz.
```

- **Aynı özelliğe 1 verici sınırı yoktur.** Birden fazla verici ve alt-verici desteklenir.
- Rün ağacının teorik derinliği craft bakımından açık tutulur; gerçek savaşta etki/yansıma/aktif varlık bütçeleri uygulanır.
- **Kardeş graft'lar:** Aynı özelliğe takılı bağımsız vericilerin sırası sonucunu keyfi değiştirmez; sistem ortak ve deterministik katkı kurallarıyla çözer.
- **İç içe graft'lar:** Elektriğe aşılanan Buz, Elektriğin aktardığı davranışı değiştirir; bu yüzden `Ateş.Yanma ← (Elektrik ← Buz)` ile `Ateş.Yanma ← Elektrik` farklıdır.
- Mekanik davranışı **özellik kapsamına bağlıdır**: Elektrik G3 `ateş mermisine` eklenirse mermi sekebilir; `yanma tikine` eklenirse yanmanın etkisi yakın hedefe aktarılabilir. Her durumda sınırsız üreme yoktur.
- Oyuncuya sonuç **önizlemesi** gösterilir. Ayrı form/trigger/support rün slotları veya kodlama grafiği sunulmaz.

### C. GemCraft'tan alınan derinlik

- Grade ve birleşim geçmişi önemlidir; aynı kaynakla farklı güç dağılımları mümkün olabilir.
- Aynı özellik birkaç kez beslenip güçlendirilebilir; karmaşık craft **kaydedilebilir ve tekrarlanabilir** olmalıdır.
- Bu tasarımda **ana rünün sabit beş gradesini korumak** birinci önceliktir. İkili birleştirmelerin kaynak maliyeti ve eş-grade upgrade formülü ayrı balans çalışmasıdır; tasarım ajanı bunları kesin varsaymamalıdır.
- Oyuncu graft hedefini seçer, olayların ne zaman oluşacağına dair manuel zaman çizelgesi tasarlamaz.

### D. Otomatik mekanik birleştirme ilkesi (tasarım seviyesi)

Oyun, rünlerin önceden var olan yeteneklerinin **genel işlevlerini** kullanarak sonucu oluşturur. Her kombinasyon için elle `fire+water` veya `volcano+ice` kodu **yazılmaz**.

- `Damage`, `ApplyStatus`, `PeriodicEffect`, `ForceMove`, `ChainTransfer`, `SummonEntity`, `ImpactArea`, `SpawnPhysicalFragments`, `BeamHit`, `AttackAsUnit` gibi **ortak yetenek aileleri** bulunabilir. Bunlar rün isimleri değildir.
- Rün kendi grade'inde hangi gerçek yeteneklerin açıldığını taşır.
- Graft hedefinin taşıyabildiği katkılar kullanılır. *Ne mekanik ne nesne mevcutsa, hiçbir sonuç oradan türetilmez.*
- Etki zinciri sonsuza büyümesin diye içten uygulanan etki bütçesi ve güç azalması vardır. Oyuncu bunları programlamaz.
- Başka kulelerin bıraktığı durumlar da doğal etkileşir: Kanama + zorunlu hareket; Buz yavaşlatması + Kan'ın hareket zararı gibi.

---

## 5. En az 10 anlaşılır kombinasyon senaryosu

Bunlar **tasarım doğrulama örnekleridir**; birleşimler için ayrı özel model/özel hardcoded tarif istendiği anlamına gelmez.

| # | Ana rün + verici(ler) | Hedeflenen özellik | Oyun içindeki sonuç |
|---|---|---|---|
| 1 | **Ateş G3 ← Elektrik G1** | Yanma tiki | Yanma tikine **ek elektrik hasarı** eklenir; zincirleme **yok** |
| 2 | **Ateş G3 ← Elektrik G3** | Ateş mermisi | Mermi uygun hedeflere **seker** ve isabet ettiği hedeflerde yanma başlatır |
| 3 | **Ateş G3 ← Elektrik G3** | Yanma tiki | Her yanma tikinde aktarım koşulu oluşabilir; yanma yakın hedefe taşınır; mermi sekmez |
| 4 | **Ateş G3 ← (Elektrik G3 ← Buz G1)** | Yanma tiki üzerinde iç içe aşı | Aktarılan yanma etkisinin ulaştığı yeni düşman **yavaşlatılır**; Buz G1 olduğu için **donma olmaz** |
| 5 | **Buz G5 ← Elektrik G3** | Donmuşken ölüm: buz parçaları | Parçalar normalde yere düşerken artık yakın hedefe **sekerek ulaşabilir** |
| 6 | **Su G3 ← Kan G1** | Su isabeti / geri itme | Aynı birleşik rün su vuruşuyla **kanama uygular ve geri iter**; zorunlu hareket kanama hasarına sayılır |
| 7 | **Kan G1 ← Su G3** | Kanama uygulayan saldırı | Kan ana rün kimliği korunur, suyun açılmış geri itme katkısı atışa eklenebilir; hareket hasarı hemen işler |
| 8 | **Volkan G3 ← Elektrik G3 + Buz G1** | Periyodik lav atımı | Lav saldırısı zincirlenebilir ve vurduğu hedeflere yavaşlatma uygular; **buzun donması aktarılmaz** |
| 9 | **Volkan G3 ← (Elektrik G3 ← Ateş G3 ← Buz G1)** | Periyodik lav atımı | Zincirlenen lav saldırılarında **yanma ve yavaşlatma** taşınabilir; bunu ayrı tekil 'buzlu elektrikli volkan' kodu olmadan kurmalıyız |
| 10 | **Meteor G3 ← Zehir G2** | Çarpma alanı / parçaları | Meteor çarpması **zehir uygular**; açılmış parçaları da uygun aktarım kapsamında zehir taşıyabilir |
| 11 | **Golem G3 ← Ateş G3** | Golemin normal vuruşu | Golem aynı Golem olarak kalır; vuruşları **yanma** uygular |
| 12 | **Kovan G3 ← Kan G1** | Böceklerin vuruşu | Böcekler hedefi hareket bazlı **kanamayla** işaretler; çevredeki zorunlu hareket bundan yararlanır |
| 13 | **Işık G3 ← Zehir G1** | Delici ışın isabeti | Delip geçtiği hedeflerde zehir etkisi uygular; yeni patlama yok |
| 14 | **Su G4 + Ateş G3** | Aynı hedefin yanma durumu | Yanan hedef **normalden daha güçlü itilir**; bir başka kule de bu işbirliğini yaratabilir |
| 15 | **Buz G3 + Kan G1** | İki farklı kule aynı hedefi vurur | Buz normal hareketi yavaşlatır, dolayısıyla Kan'ın **mesafe bazlı** hasarı azalabilir; Su ile geri püskürtme bu karşıtlığı tersine çevirebilir |

> **Denetim örneği:** Ateş G3 ← Elektrik G3 ile yanma yayılımı varken Elektrik içine Buz G1 aşılanırsa taşınan durumun yavaşlatması anlamlıdır. Ama Buz G1'den **donma**, Elektrik G1'den **zincir**, Zehir G1'den kendiliğinden **patlama** üretilmez.

---

## 6. Oyuncunun gördüğü sistem ve görsel gereksinimleri

### Gerçek oyun bağlamı

- Her kulede **görülebilir tek bir ana rün eseri**, kulenin üstünde süzülür. Rün kendi üzerinde değişir; kulenin şasisi her tarif için yeniden modellenmez.
- Rün, oyunda yüksekten görüldüğü için **temel kimliği küçük ölçekte okunmalıdır**; envanter/crafting yakın görünümünde daha karmaşık hâli incelenebilir.
- G1, G2, G3, G4, G5 **birbirinden hissedilir şekilde ayrılmalı**, ama her kademede yeniden elle model yapmayı gerektirmemeli.
- Aynı ana rüne bir veya birkaç rün aşılandığı fark edilebilmeli. **Birleşim 4, 12, 40 veya daha fazla alt rün içerdiğinde de** sonuç okunabilir ve ölçeklenebilir olmalı.
- Aşılama görselleri, yalnızca ana rün etrafındaki küçük ek unsurlar şeklinde *olabilir*; rüne işlenmiş bilgiler başka şekillerde de temsil edilebilir. **Ek rünlerin kendi grade'i ve iç içe işlenmiş hâli de görsel sistem tarafından temsil edilebilir olmalı.**
- Bir rünün **tek özelliğine birden fazla rün**, rün ağacında farklı derinlikte alt-rün ve farklı özelliklerde ayrı aşılar bulunabilir. Görsel çözüm bunları tek bir sabit 3-yuvalı düzenle sınırlamamalı.
- **Her crafting kombinasyonu için ayrı elle yapılmış mesh, texture, skin, model veya ikon istenmiyor.** Sistem bileşimden otomatik ve tekrarlanabilir bir sunum üretmeli.
- Yüksek grade ve derin craft, hem normal kule görünümünde gelişmiş olduğu anlaşılacak kadar farklı, hem de minimalist, temiz ve kalabalık olmayan bir sonuca sahip olmalı.
- Savaş VFX'leri rünün görüntüsünden ayrıdır: görüntüde her alt mekanik tek tek dev VFX olarak çalışmak zorunda değil. Oyuncu büyü oynandığında zincir, yanma, yavaşlatma, summon gibi etkileri anlar.

### **Görsel tasarım ajanına özgür bırakılanlar**

Aşağıdakileri **bu belge karar vermiyor**: kesin küp/poligon geometrisi, rün kabuğunun yapısı, sembolün oyma veya kaplama yöntemi, kaç parça döneceği, ek parçaların neye benzeyeceği, grade'lerin fiziksel farkları, renk geçişleri, animasyon dili, yüzey malzemeleri, VFX yoğunluğu, mini-rünlerin gösterim şekli, bileşimin hangi kanallara bölüneceği, ekran yerleşimi veya tekil bir görsel kombinasyon formülü.

Önceki referans resimler yalnızca **oynanış ölçeği, kübik/minimalist yön ve çok katmanlı rün fikri** için bağlamdır; bire bir şablon değildir. Görsel tasarımcı/ajan **kendi üretilebilir sistemini gerekçeleriyle önermelidir**.

### Görsel çözümün karşılamak zorunda olduğu test vakaları

1. 12 farklı temel rünün G1 hâli, renk farkı kapatılsa bile mümkün olduğunca ayırt edilebilmeli.
2. **Aynı ana rünün G1 → G5** ilerleyişi anlaşılmalı.
3. Ana rün ile **bir adet düşük-grade graft** ve **bir adet yüksek-grade graft** görünüm olarak ayrılabilmeli.
4. Aynı ana ründe **3–4 açık özellik**, bunlardan birinde **2–3 kardeş graft** bulunabilmeli.
5. `Ateş G3.Yanma ← (Elektrik G3 ← Buz G1)` gibi **iç içe graft** görsel olarak temsil edilebilmeli.
6. `Volkan G5.Lav Atımı ← Elektrik G5 + Ateş G3 + Buz G1` gibi birden fazla katkı içeren karmaşık craft görselleştirilebilmeli.
7. En az **20+ graft düğümlü** ileri craft'ta çözüm, her küçük düğüme tam boy ayrı parça eklemek zorunda kalmamalı.
8. Yüksek açıdan kule üstündeki rün, düşman/mermi/harita okunabilirliğini bozmamalı.
9. Tekrar aynı craft tarifi işlendiğinde **aynı oyun içi sonuç ve tutarlı görünüm** elde edilmeli; rastgele şekil patlaması olmamalı.
10. Görsel katmanlar oyuncuya 'bu rün çok gelişmiş' duygusu vermeli; ancak kaç etkinin ve hangi grade'in görünür olması gerektiğine **ajan önerisiyle** karar verilmeli.

---

## 7. Karar verilmesi gereken tasarım soruları (henüz açık)

Bunları görsel sistem ajanı çözmeli veya alternatifleri tartışmalı; bu belgede görsel teknik dikte edilmez:

1. Birkaç yüz bin olası craft görünümü, **kaç temel el yapımı asset** ile temsil edilebilir?
2. Her rünün G1–G5 gelişimi **tek model üzerinden otomatik** nasıl algılanır?
3. **Ana rün baskınlığı** ile çok sayıda verici renginin/kimliğinin okunması nasıl dengelenir?
4. Aynı özelliğe birden fazla graft ve **nested graft** görselde nasıl gösterilir?
5. Graft'ın altındaki rün de G4/G5 ise ne ölçüde detay görünür?
6. Kule kamerasında ayrıntı düşürme / envanterde ayrıntı artırma nasıl tasarlanır?
7. Rün eseri, tower şasisi, summon birimleri, mermiler ve VFX ayrı nerelerde ele alınır?
8. Hangi bilgiler dış görünüşte, hangileri hover/inspect arayüzünde kalmalıdır?
9. Savaş sırasında okunabilirliği bozmadan çok karmaşık craft'lara nasıl statü hissi verilir?
10. Tüm bunlar **prosedürel / kurallı** üretilebilirken nasıl sade, tutarlı ve hoş görünür?

---

## 8. Bu aşamanın sınırları ve teslimi

**Şu an istenen şey görsel modeli oluşturmak değil, rün oyununun tasarımının anlaşılması ve buna uygun görsel sistem konseptinin hazırlanmasıdır.**

Görsel tasarım ajanından istenecek ilk çıktı:

- Rünleri nasıl algıladığına dair **kısa, doğru gameplay özeti**.
- Grade ve graft derinliğinin yarattığı **tasarım problemleri**.
- **En az iki alternatif, üretilebilir görsel tasarım yaklaşımı** ve karşılaştırması.
- Kendi önerdiği tek bir görsel dil / modüler üretim mantığı, teknik riskler ve okunabilirlik kuralları.
- 12 rün ve beş grade için **görsel çeşitlilik matrisi** (sözel / şematik tasarım, henüz asset değil).
- Basit, orta ve çok karmaşık craft'lar için **görsel davranış tasarım dokümanı**.
- Önce hangi **küçük ve ölçülebilir pilot** hazırlanmalı sorusuna cevap.

**Yapılmayacaklar:** MagicaVoxel/Blender/Godot üzerinden üretim, `.vox`/mesh/texture/shader yazma, görsel render alma, yeni baştan bambaşka rune mekanikleri uydurma, MVP'ye rün ekleme veya çıkartma, karmaşık crafting yerine sabit üç support yuvası getirme.

**Tasarım tamamlanıp onaylandığında** MagicaVoxel kaynak modelleri ve Godot'ta otomatik görsel bileşim üretimi ayrı üretim fazına geçebilir.
