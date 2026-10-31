# RuneCraft — mekanik senaryoları (otomatik)

Kaynak: `spec/rune_mechanics_v1.json`, `mechanics/scenarios.json`. Üreten: `mechanics/report.py`. Doğrulama: `python3 mechanics/test_mechanics.py`.

Referans: düz yol, 6 düşman (can 120, hız 1 karo/sn, aralık 0,6 karo, zırh %10), kule yoldan 2 karo uzakta, menzil 4 karo, 14 sn. Açıklama metni, craft sonrası **çıktı rünün açıklamasıdır**; craft öncesi önizleme yoktur.

## v4-01 — Yanma tikine Elektrik G1: yalnızca elektrik hasarı, sekme yok.

Tarif: `fire3{burn:[electric1]}`

```text
Ateş G3  · 1 aşı, derinlik 1
• Ateş isabeti: 12 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3/sn × 3 sn.
    ↳ Elektrik G1 — her tikte: 2,2 elektrik hasarı
        ✗ Elektrik G1: 'Sekme' yok (Elektrik G2'de açılır)
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.
```

Maliyet: 260 mana (rünler 240 + aşı ücreti 20), 2 düğüm.

Simülasyon (`fire3{burn:[electric1]}`): DPS: 12.46 · en derin kuşak: 2 · en çok uygulama/olay: 1 · durumlar: yanma ×7 · hasar: elektrik 28, ateş 147

## v4-02 — Ateş isabetine Elektrik G3: mermi seker, sekilen hedef de yanar.

Tarif: `fire3{fire_hit:[electric3]}`

```text
Ateş G3  · 1 aşı, derinlik 1
• Ateş isabeti: 12 ateş hasarlı mermi.
    ↳ Elektrik G3 — her isabette: 7 elektrik hasarı; mermi sekerek: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
• Yanma: İsabet yakar: 3/sn × 3 sn.
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.
```

Maliyet: 420 mana (rünler 400 + aşı ücreti 20), 2 düğüm.

Simülasyon (`fire3{fire_hit:[electric3]}`): DPS: 27.07 · sekme/zıplama: mermi sekerek 14 · yayılan durum: 14 · en derin kuşak: 2 · en çok uygulama/olay: 5 · durumlar: yanma ×21 · hasar: elektrik 73, ateş 306

## v4-03 — Yanma tikine Elektrik G3: yanma yandakine atlar, mermi sekmez.

Tarif: `fire3{burn:[electric3]}`

```text
Ateş G3  · 1 aşı, derinlik 1
• Ateş isabeti: 12 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3/sn × 3 sn.
    ↳ Elektrik G3 — her tikte: 2,4 elektrik hasarı; durum yandakine atlayarak: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.
```

Maliyet: 420 mana (rünler 400 + aşı ücreti 20), 2 düğüm.

Simülasyon (`fire3{burn:[electric3]}`): DPS: 23.7 · sekme/zıplama: durum yandakine atlayarak 16 · yayılan durum: 16 · en derin kuşak: 2 · en çok uygulama/olay: 5 · durumlar: yanma ×23 · hasar: elektrik 89, ateş 243

## v4-04 — İç içe: atlayan yanma Buz G2 yavaşlatması taşır, donma yok.

Tarif: `fire3{burn:[electric3{chain:[ice2]}]}`

```text
Ateş G3  · 2 aşı, derinlik 2
• Ateş isabeti: 12 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3/sn × 3 sn.
    ↳ Elektrik G3 — her tikte: 2,4 elektrik hasarı; durum yandakine atlayarak: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
        [Elektrik · Sekme]
        ↳ Buz G2 — ulaşılan her yeni hedefte: 2,6 buz hasarı; %18,1 yavaşlatma (1,8 sn)
            ✗ Buz G2: 'Donma' yok (Buz G3'te açılır)
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.
```

Maliyet: 536 mana (rünler 490 + aşı ücreti 46), 3 düğüm.

Simülasyon (`fire3{burn:[electric3{chain:[ice2]}]}`): DPS: 23.0 · sekme/zıplama: durum yandakine atlayarak 16 · yayılan durum: 32 · en derin kuşak: 2 · en çok uygulama/olay: 5 · durumlar: yanma ×23, yavaşlatma ×16 · hasar: elektrik 89, ateş 220, buz 13

## v4-05 — Yanma tikine üç kardeş: yayılır, zehir ve kanama uygular; tikten yeni alan doğmaz.

Tarif: `fire5{burn:[electric3,poison2,blood1]}`

```text
Ateş G5  · 3 aşı, derinlik 1
• Ateş isabeti: 17 ateş hasarlı mermi.
• Yanma: İsabet yakar: 4,5/sn × 4 sn.
    ↳ Elektrik G3 — her tikte: 2,4 elektrik hasarı; durum yandakine atlayarak: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
    ↳ Zehir G2 — her tikte: zehir 3,8/sn × 4 sn, 3 yığına kadar
        ✗ Zehir G2: 'İyileşme baskısı' yok (Zehir G3'te açılır)
    ↳ Kan G1 — her tikte: kanama 3,5/karo (3 sn)
        ✗ Kan G1: 'Yoğunluk' yok (Kan G2'de açılır)
• Ateş izi: Yanan düşman arkasında 2 sn yanan iz bırakır; izdeki düşmanlar 2/sn ateş hasarı alır.
```

Maliyet: 1310 mana (rünler 1230 + aşı ücreti 80), 4 düğüm.

Simülasyon (`fire5{burn:[electric3,poison2,blood1]}`): DPS: 46.51 · öldürme: 5 · sekme/zıplama: durum yandakine atlayarak 6 · yayılan durum: 58 · en derin kuşak: 2 · en çok uygulama/olay: 5 · durumlar: kanama ×27, yanma ×11, zehir ×27 · hasar: kan 96, elektrik 51, ateş 319, zehir 185

## v4-06 — Donmuşken ölümde parçalar Elektrik ile hedef arayıp seker.

Tarif: `ice4{ice_shards:[electric3]}`

```text
Buz G4  · 1 aşı, derinlik 1
• Buz isabeti: 18 buz hasarı.
• Yavaşlatma: %35 yavaşlatır (2,2 sn).
• Donma: Her isabet 1 soğuk; 3 soğukta 1,1 sn donar.
• Buz parçaları: Donmuşken ölen düşman 3 parçaya ayrılır; yakındakilere 10 buz hasarı.
    ↳ Elektrik G3 — ulaşılan her yeni hedefte: 4,2 elektrik hasarı; parça sekerek: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
  🔒 Çevreyi dondurma (G5'te açılır)
```

Maliyet: 650 mana (rünler 630 + aşı ücreti 20), 2 düğüm.

Simülasyon (`ice4{ice_shards:[electric3]}` + `stone3`): DPS: 22.73 · öldürme: 1 · sekme/zıplama: parça 9 · yayılan durum: 9 · donma: 1 · en derin kuşak: 1 · en çok uygulama/olay: 5 · durumlar: soğuk ×6, zırh aşınması ×14, yavaşlatma ×6 · hasar: buz 122, fiziksel 196

## v4-07 — Tek kule: önce kanama, sonra itiş; itiş mesafesi kanama hasarı üretir.

Tarif: `water3{water_hit:[blood1]}`

```text
Su G3  · 1 aşı, derinlik 1
• Su isabeti: 13 su hasarı.
    ↳ Kan G1 — her isabette: kanama 3,5/karo (3 sn)
        ✗ Kan G1: 'Yoğunluk' yok (Kan G2'de açılır)
• Islatma: 3 sn ıslatır (ıslak: elektrikten ×1,5, daha çabuk donar, yanma kısalır).
• Geri itiş: Hedefi yol boyunca 0,3 karo geri iter (yanan hedef ×1,5).
  🔒 Dalga (G5'te açılır)
```

Maliyet: 260 mana (rünler 240 + aşı ücreti 20), 2 düğüm.

Simülasyon (`water3{water_hit:[blood1]}`): DPS: 8.57 · öldürme: 1 · itiş (karo): 2.45 · itişten kanama: 8.57 · en çok uygulama/olay: 1 · durumlar: kanama ×7, ıslaklık ×7 · hasar: kan 38, su 82

## v4-08 — Kan ana rün, Su G3 kanama yuvasında: kanama yürünen her karoda tetiklenir; itiş orada döngü yaratacağı için reddedilir, su hasarı ve ıslatma taşınır (v4: 'uyumlu taşıyıcı olmalı').

Tarif: `blood1{bleed:[water3]}`

```text
Kan G1  · 1 aşı, derinlik 1
• Kanama: Kanayan düşman yürüdüğü her karo için 5 hasar alır (3 sn). İtiş de sayılır.
    ↳ Su G3 — yürüdüğü her karoda: 3,6 su hasarı; ıslaklık 3 sn
        ✗ itiş taşınmadı: itiş 'yürüdüğü her karoda' taşıyıcısında anlamsız (uyumsuz)
        ✗ Su G3: 'Dalga' yok (Su G5'te açılır)
  🔒 Yoğunluk (G2'de açılır)
  🔒 Yırtılma (G4'te açılır)
```

Maliyet: 260 mana (rünler 240 + aşı ücreti 20), 2 düğüm.

Simülasyon (`blood1{bleed:[water3]}`): DPS: 7.92 · en çok uygulama/olay: 1 · durumlar: kanama ×7, ıslaklık ×14 · hasar: kan 65, su 46

## v4-09 — Başka kulenin yanması Su itişini ×1,5 yapar; kanama daha çok hasar alır.

Tarif: `fire3`

```text
Ateş G3
• Ateş isabeti: 12 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3/sn × 3 sn.
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.
```

Maliyet: 200 mana (rünler 200 + aşı ücreti 0), 1 düğüm.

Simülasyon (`fire3` + `water4{water_hit:[blood1]}`): DPS: 19.92 · öldürme: 2 · itiş (karo): 3.83 · itişten kanama: 13.39 · en derin kuşak: 2 · en çok uygulama/olay: 1 · durumlar: kanama ×6, yanma ×6, ıslaklık ×6 · hasar: kan 40, ateş 112, su 126
Karşılaştırma (`water4{water_hit:[blood1]}`): DPS: 12.58 · öldürme: 1 · itiş (karo): 3.15 · itişten kanama: 11.02 · en çok uygulama/olay: 1 · durumlar: kanama ×7, ıslaklık ×7 · hasar: kan 50, su 126

## v4-10 — Buz yavaşlatması Kan'ın yürüme hasarını düşürür (karşıtlık).

Tarif: `ice2`

```text
Buz G2
• Buz isabeti: 9 buz hasarı.
• Yavaşlatma: %25 yavaşlatır (1,8 sn).
  🔒 Donma (G3'te açılır)
  🔒 Buz parçaları (G4'te açılır)
  🔒 Çevreyi dondurma (G5'te açılır)
```

Maliyet: 90 mana (rünler 90 + aşı ücreti 0), 1 düğüm.

Simülasyon (`ice2` + `blood1`): DPS: 6.87 · en çok uygulama/olay: 1 · durumlar: kanama ×7, yavaşlatma ×7 · hasar: kan 39, buz 57
Karşılaştırma (`blood1`): DPS: 4.64 · en çok uygulama/olay: 1 · durumlar: kanama ×7 · hasar: kan 65

## v4-11 — Lav topları zıplar ve yavaşlatır; donma ve yanma yok.

Tarif: `volcano3{lava_blob:[ice2,electric3]}`

```text
Volkan G3  · 2 aşı, derinlik 1
• Lav topu: Yol kenarına 8 sn'lik volkan çağırır; her 2 sn kraterden 1,5 karo içine lav topu fışkırır: 23 lav hasarı.
    ↳ Buz G2 — çağrının her vuruşunda: 6,3 buz hasarı; %21,2 yavaşlatma (1,8 sn)
        ✗ Buz G2: 'Donma' yok (Buz G3'te açılır)
    ↳ Elektrik G3 — çağrının her vuruşunda: 7 elektrik hasarı; lav topu düşmandan düşmana zıplayarak: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
• Lav sıçraması: Top düştüğü yerde 0,3 karo sıçrar (%60).
• Geniş püskürme: Her fışkırmada 2 top farklı hedeflere.
  🔒 Lav birikintisi (G4'te açılır)
```

Maliyet: 616 mana (rünler 570 + aşı ücreti 46), 3 düğüm.

Simülasyon (`volcano3{lava_blob:[electric3,ice2]}`): DPS: 33.34 · sekme/zıplama: lav topu düşmandan düşmana zıplayarak 15 · yayılan durum: 17 · en derin kuşak: 1 · en çok uygulama/olay: 8 · durumlar: yavaşlatma ×25 · hasar: elektrik 90, buz 81, lav 296

## v4-12 — Zıplayan lav, zıpladığı hedefi yakar; yanma tikleri yavaşlatır; gizli meteor yok.

Tarif: `volcano3{lava_blob:[electric3{chain:[fire3{burn:[ice2]}]}]}`

```text
Volkan G3  · 3 aşı, derinlik 3
• Lav topu: Yol kenarına 8 sn'lik volkan çağırır; her 2 sn kraterden 1,5 karo içine lav topu fışkırır: 23 lav hasarı.
    ↳ Elektrik G3 — çağrının her vuruşunda: 7 elektrik hasarı; lav topu düşmandan düşmana zıplayarak: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
        [Elektrik · Sekme]
        ↳ Ateş G3 — ulaşılan her yeni hedefte: 3,5 ateş hasarı; yanma 1,5/sn × 3 sn, arkasında ateş izi 0,5/sn (1 sn)
            [Ateş · Yanma]
            ↳ Buz G2 — her tikte: 1,1 buz hasarı; %15,4 yavaşlatma (1,8 sn)
                ✗ Buz G2: 'Donma' yok (Buz G3'te açılır)
• Lav sıçraması: Top düştüğü yerde 0,3 karo sıçrar (%60).
• Geniş püskürme: Her fışkırmada 2 top farklı hedeflere.
  🔒 Lav birikintisi (G4'te açılır)
```

Maliyet: 850 mana (rünler 770 + aşı ücreti 80), 4 düğüm.

Simülasyon (`volcano3{lava_blob:[electric3{chain:[fire3{burn:[ice2]}]}]}`): DPS: 33.49 · öldürme: 1 · sekme/zıplama: lav topu düşmandan düşmana zıplayarak 15 · yayılan durum: 41 · en derin kuşak: 2 · en çok uygulama/olay: 8 · durumlar: yanma ×15, yavaşlatma ×26 · hasar: elektrik 86, ateş 74, buz 25, lav 283

## v4-13 — Çarpma alanı zehirler; zehir patlamaz.

Tarif: `meteor2{meteor_area:[poison1]}`

```text
Meteor G2  · 1 aşı, derinlik 1
• Meteor çarpması: Her 3 sn hedefe gökten meteor düşer: 26 çarpma hasarı.
• Alan darbesi: Çarpma 0,5 karo içindekilere %60 hasar verir.
    ↳ Zehir G1 — alandaki her hedefte: zehir 3,5/sn × 3 sn
        ✗ Zehir G1: 'Yığılma' yok (Zehir G2'de açılır)
  🔒 Çarpma parçaları (G3'te açılır)
  🔒 Meteor yağmuru (G5'te açılır)
```

Maliyet: 190 mana (rünler 170 + aşı ücreti 20), 2 düğüm.

Simülasyon (`meteor2{meteor_area:[poison1]}`): DPS: 8.94 · yayılan durum: 4 · en derin kuşak: 2 · en çok uygulama/olay: 2 · durumlar: zehir ×4 · hasar: çarpma 94, zehir 32

## v4-14 — Meteor parçaları seker.

Tarif: `meteor3{meteor_fragments:[electric3]}`

```text
Meteor G3  · 1 aşı, derinlik 1
• Meteor çarpması: Her 3 sn hedefe gökten meteor düşer: 28 çarpma hasarı.
• Alan darbesi: Çarpma 0,6 karo içindekilere %60 hasar verir.
• Çarpma parçaları: 2 parça yakındakilere %50 taşır.
    ↳ Elektrik G3 — ulaşılan her yeni hedefte: 4,2 elektrik hasarı; parça sekerek: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
  🔒 Meteor yağmuru (G5'te açılır)
```

Maliyet: 500 mana (rünler 480 + aşı ücreti 20), 2 düğüm.

Simülasyon (`meteor3{meteor_fragments:[electric3]}`): DPS: 12.82 · sekme/zıplama: parça 5, parça sekerek 10 · en derin kuşak: 2 · en çok uygulama/olay: 14 · hasar: elektrik 16, çarpma 164

## v4-15 — Golem yumrukları yakar; golem golem olarak kalır.

Tarif: `golem3{golem_punch:[fire3]}`

```text
Golem G3  · 1 aşı, derinlik 1
• Golem yumruğu: 12 sn'lik golem çağırır; en yakın düşmana yürür, saniyede bir 11 fiziksel vurur.
    ↳ Ateş G3 — çağrının her vuruşunda: 8,4 ateş hasarı; yanma 2,1/sn × 3 sn, arkasında ateş izi 0,7/sn (1 sn)
• Taş deri: Golem %10 az hasar alır.
• Zemin darbesi: Her 3. vuruş 0,6 karo zemin darbesidir.
```

Maliyet: 500 mana (rünler 480 + aşı ücreti 20), 2 düğüm.

Simülasyon (`golem3{golem_punch:[fire3]}`): DPS: 16.74 · öldürme: 1 · en derin kuşak: 2 · en çok uygulama/olay: 1 · durumlar: yanma ×8 · hasar: ateş 96, fiziksel 139

## v4-16 — Zemin darbesi yavaşlatır, dondurmaz.

Tarif: `golem3{ground_slam:[ice2]}`

```text
Golem G3  · 1 aşı, derinlik 1
• Golem yumruğu: 12 sn'lik golem çağırır; en yakın düşmana yürür, saniyede bir 11 fiziksel vurur.
• Taş deri: Golem %10 az hasar alır.
• Zemin darbesi: Her 3. vuruş 0,6 karo zemin darbesidir.
    ↳ Buz G2 — alandaki her hedefte: 3,8 buz hasarı; %21,2 yavaşlatma (1,8 sn)
        ✗ Buz G2: 'Donma' yok (Buz G3'te açılır)
```

Maliyet: 390 mana (rünler 370 + aşı ücreti 20), 2 düğüm.

Simülasyon (`golem3{ground_slam:[ice2]}`): DPS: 13.26 · en çok uygulama/olay: 1 · durumlar: yavaşlatma ×8 · hasar: buz 27, fiziksel 158

## v4-17 — Böcek ısırığı kanatır; ek böcek doğurmaz (Üreme dışında).

Tarif: `hive3{beetle_bite:[blood1]}`

```text
Kovan G3  · 1 aşı, derinlik 1
• Böcek ısırığı: 12 sn'lik kovan kurar; en çok 3 böcek, ısırık başına 5 hasar.
    ↳ Kan G1 — çağrının her vuruşunda: kanama 3,5/karo (3 sn)
        ✗ Kan G1: 'Yoğunluk' yok (Kan G2'de açılır)
• Üreme: Öldüren böcek yeni böcek doğurur (en çok +2).
• Sürü odağı: Böcekler işaretlenen tek hedefe birlikte saldırır.
```

Maliyet: 340 mana (rünler 320 + aşı ücreti 20), 2 düğüm.

Simülasyon (`hive3{beetle_bite:[blood1]}`): DPS: 12.12 · öldürme: 1 · en çok uygulama/olay: 1 · durumlar: kanama ×30 · hasar: kan 35, fiziksel 135

## v4-18 — Böcek ısırıkları zehir yığar; sürü odağıyla tek hedefte.

Tarif: `hive3{beetle_bite:[poison2]}`

```text
Kovan G3  · 1 aşı, derinlik 1
• Böcek ısırığı: 12 sn'lik kovan kurar; en çok 3 böcek, ısırık başına 5 hasar.
    ↳ Zehir G2 — çağrının her vuruşunda: zehir 3,8/sn × 4 sn, 3 yığına kadar
        ✗ Zehir G2: 'İyileşme baskısı' yok (Zehir G3'te açılır)
• Üreme: Öldüren böcek yeni böcek doğurur (en çok +2).
• Sürü odağı: Böcekler işaretlenen tek hedefe birlikte saldırır.
```

Maliyet: 390 mana (rünler 370 + aşı ücreti 20), 2 düğüm.

Simülasyon (`hive3{beetle_bite:[poison2]}`): DPS: 14.84 · öldürme: 1 · en derin kuşak: 2 · en çok uygulama/olay: 1 · durumlar: zehir ×30 · hasar: fiziksel 135, zehir 73

## v4-19 — Delinen hedefler zehirlenir.

Tarif: `light3{pierce:[poison1]}`

```text
Işık G3  · 1 aşı, derinlik 1
• Işın: 13 ışık hasarlı ışın.
• Kamaşma: 1,5 sn kamaştırır: düşman saldırılarının isabeti %30 düşer.
• Delme: Işın 1 hedefi daha deler (her delişte ×0,6).
    ↳ Zehir G1 — ulaşılan her yeni hedefte: zehir 3,5/sn × 3 sn
        ✗ Zehir G1: 'Yığılma' yok (Zehir G2'de açılır)
  🔒 Aydınlatma (G5'te açılır)
```

Maliyet: 260 mana (rünler 240 + aşı ücreti 20), 2 düğüm.

Simülasyon (`light3{pierce:[poison1]}`): DPS: 15.18 · sekme/zıplama: ışın deler 9 · yayılan durum: 18 · en derin kuşak: 2 · en çok uygulama/olay: 3 · durumlar: kamaşma ×18, zehir ×9 · hasar: ışık 168, zehir 44

## v4-20 — Taş parçaları seker.

Tarif: `stone3{fragments:[electric3]}`

```text
Taş G3  · 1 aşı, derinlik 1
• Ağır darbe: 22 fiziksel hasar.
• Zırh aşındırma: Zırhı 3 sn %12 azaltır.
• Taş parçaları: Çarpmada 2 parça yakındakilere isabetin %50'sini taşır.
    ↳ Elektrik G3 — ulaşılan her yeni hedefte: 4,2 elektrik hasarı; parça sekerek: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
  🔒 Sarsıntı (G5'te açılır)
```

Maliyet: 420 mana (rünler 400 + aşı ücreti 20), 2 düğüm.

Simülasyon (`stone3{fragments:[electric3]}`): DPS: 13.48 · sekme/zıplama: parça 6, parça sekerek 12 · yayılan durum: 6 · en derin kuşak: 2 · en çok uygulama/olay: 13 · durumlar: zırh aşınması ×11 · hasar: elektrik 20, fiziksel 168

## v4-21 — Ateş izine basan zehirlenir; DoT'tan yeni alan doğmaz.

Tarif: `fire5{fire_trail:[poison1]}`

```text
Ateş G5  · 1 aşı, derinlik 1
• Ateş isabeti: 17 ateş hasarlı mermi.
• Yanma: İsabet yakar: 4,5/sn × 4 sn.
• Ateş izi: Yanan düşman arkasında 2 sn yanan iz bırakır; izdeki düşmanlar 2/sn ateş hasarı alır.
    ↳ Zehir G1 — alanın içindekilere (her sn): zehir 3,5/sn × 3 sn
        ✗ Zehir G1: 'Yığılma' yok (Zehir G2'de açılır)
```

Maliyet: 960 mana (rünler 940 + aşı ücreti 20), 2 düğüm.

Simülasyon (`fire5{fire_trail:[poison1]}`): DPS: 28.54 · en derin kuşak: 2 · en çok uygulama/olay: 1 · durumlar: yanma ×7, zehir ×78 · hasar: ateş 308, zehir 91

## v4-22 — Volkan kimliği korunur: lav yakar, zıplar, yavaşlatır.

Tarif: `volcano5{lava_blob:[fire3,ice2,electric3]}`

```text
Volkan G5  · 3 aşı, derinlik 1
• Lav topu: Yol kenarına 12 sn'lik volkan çağırır; her 1,6 sn kraterden 1,5 karo içine lav topu fışkırır: 39 lav hasarı.
    ↳ Ateş G3 — çağrının her vuruşunda: 8,4 ateş hasarı; yanma 2,1/sn × 3 sn, arkasında ateş izi 0,7/sn (1 sn)
    ↳ Buz G2 — çağrının her vuruşunda: 6,3 buz hasarı; %21,2 yavaşlatma (1,8 sn)
        ✗ Buz G2: 'Donma' yok (Buz G3'te açılır)
    ↳ Elektrik G3 — çağrının her vuruşunda: 7 elektrik hasarı; lav topu düşmandan düşmana zıplayarak: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
• Lav sıçraması: Top düştüğü yerde 0,3 karo sıçrar (%60).
• Geniş püskürme: Her fışkırmada 2 top farklı hedeflere.
• Lav birikintisi: Top düştüğü yerde 1,5 sn lav birikintisi: 3,5/sn.
```

Maliyet: 1790 mana (rünler 1710 + aşı ücreti 80), 4 düğüm.

Simülasyon (`volcano5{lava_blob:[fire3,electric3,ice2]}`): DPS: 54.34 · öldürme: 5 · sekme/zıplama: lav topu düşmandan düşmana zıplayarak 15 · yayılan durum: 26 · en derin kuşak: 2 · en çok uygulama/olay: 7 · durumlar: yanma ×19, yavaşlatma ×19 · hasar: elektrik 69, ateş 126, buz 63, lav 503

## v4-23 — Su G1'de itiş yok; kanama yalnızca yürümeden.

Tarif: `water1{water_hit:[blood1]}`

```text
Su G1  · 1 aşı, derinlik 1
• Su isabeti: 6 su hasarı.
    ↳ Kan G1 — her isabette: kanama 3,5/karo (3 sn)
        ✗ Kan G1: 'Yoğunluk' yok (Kan G2'de açılır)
  🔒 Islatma (G2'de açılır)
  🔒 Geri itiş (G3'te açılır)
  🔒 Dalga (G5'te açılır)
```

Maliyet: 100 mana (rünler 80 + aşı ücreti 20), 2 düğüm.

Simülasyon (`water1{water_hit:[blood1]}`): DPS: 5.95 · en çok uygulama/olay: 1 · durumlar: kanama ×7 · hasar: kan 46, su 38

## v4-24 — Kamaşmaya Elektrik G1: hasar katkısı, zincir yok.

Tarif: `light2{dazzle:[electric1]}`

```text
Işık G2  · 1 aşı, derinlik 1
• Işın: 12 ışık hasarlı ışın.
• Kamaşma: 1,5 sn kamaştırır: düşman saldırılarının isabeti %30 düşer.
    ↳ Elektrik G1 — durum her uygulandığında: 3,1 elektrik hasarı
        ✗ Elektrik G1: 'Sekme' yok (Elektrik G2'de açılır)
  🔒 Delme (G3'te açılır)
  🔒 Aydınlatma (G5'te açılır)
```

Maliyet: 150 mana (rünler 130 + aşı ücreti 20), 2 düğüm.

Simülasyon (`light2{dazzle:[electric1]}`): DPS: 8.77 · en çok uygulama/olay: 2 · durumlar: kamaşma ×9 · hasar: elektrik 26, ışık 97

## user-trail-ice — Kullanıcı örneği: ateş izine Buz → izdeki düşmanlar yavaşlar.

Tarif: `fire3{fire_trail:[ice2]}`

```text
Ateş G3  · 1 aşı, derinlik 1
• Ateş isabeti: 12 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3/sn × 3 sn.
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.
    ↳ Buz G2 — alanın içindekilere (her sn): 1,3 buz hasarı; %21,2 yavaşlatma (1,8 sn)
        ✗ Buz G2: 'Donma' yok (Buz G3'te açılır)
```

Maliyet: 310 mana (rünler 290 + aşı ücreti 20), 2 düğüm.

Simülasyon (`fire3{fire_trail:[ice2]}`): DPS: 9.26 · en derin kuşak: 2 · en çok uygulama/olay: 1 · durumlar: yanma ×7, yavaşlatma ×8 · hasar: ateş 121, buz 9

## user-lava-hop — Kullanıcı örneği: Elektrik aşılı volkanın lav topları düşmandan düşmana zıplar.

Tarif: `volcano3{lava_blob:[electric3]}`

```text
Volkan G3  · 1 aşı, derinlik 1
• Lav topu: Yol kenarına 8 sn'lik volkan çağırır; her 2 sn kraterden 1,5 karo içine lav topu fışkırır: 23 lav hasarı.
    ↳ Elektrik G3 — çağrının her vuruşunda: 7 elektrik hasarı; lav topu düşmandan düşmana zıplayarak: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
• Lav sıçraması: Top düştüğü yerde 0,3 karo sıçrar (%60).
• Geniş püskürme: Her fışkırmada 2 top farklı hedeflere.
  🔒 Lav birikintisi (G4'te açılır)
```

Maliyet: 500 mana (rünler 480 + aşı ücreti 20), 2 düğüm.

Simülasyon (`volcano3{lava_blob:[electric3]}`): DPS: 25.64 · sekme/zıplama: lav topu düşmandan düşmana zıplayarak 16 · en derin kuşak: 1 · en çok uygulama/olay: 6 · hasar: elektrik 84, lav 275

## mana-graft — Yanma tikine Mana G1: yanma hasarının bir kısmı mana olur.

Tarif: `fire3{burn:[mana1]}`

```text
Ateş G3  · 1 aşı, derinlik 1
• Ateş isabeti: 12 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3/sn × 3 sn.
    ↳ Mana G1 — her tikte: 1,1 mana hasarı; bu olaydaki hasarın %42'i mana
        ✗ Mana G1: 'Mana işareti' yok (Mana G3'te açılır)
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.
```

Maliyet: 260 mana (rünler 240 + aşı ücreti 20), 2 düğüm.

Simülasyon (`fire3{burn:[mana1]}`): DPS: 11.47 · en derin kuşak: 2 · en çok uygulama/olay: 1 · durumlar: yanma ×7 · hasar: mana 14, ateş 147

## mana-mark — Mana işareti: başka kulenin işaretli düşman çevresindeki hasarı da mana olur.

Tarif: `mana3`

```text
Mana G3
• Mana sifonu: 10 mana hasarı; bu olaydaki hasarın %75'i mana olur. Aşılandığı yetenekte ana rünün hasarını da manaya çevirir.
• Mana işareti: Vurulan düşman 4 sn işaretlenir: çevresindeki 1 karo içinde hangi kuleden gelirse gelsin tüm hasarın %20'i mana olur.
  🔒 Kristalleşme (G5'te açılır)
```

Maliyet: 200 mana (rünler 200 + aşı ücreti 0), 1 düğüm.

Simülasyon (`mana3` + `stone3`): DPS: 17.59 · öldürme: 1 · sekme/zıplama: parça 6 · yayılan durum: 6 · en derin kuşak: 1 · en çok uygulama/olay: 5 · durumlar: mana işareti ×8, zırh aşınması ×10 · hasar: mana 78, fiziksel 168
Karşılaştırma (`stone3`): DPS: 12.02 · sekme/zıplama: parça 6 · yayılan durum: 6 · en derin kuşak: 1 · en çok uygulama/olay: 5 · durumlar: zırh aşınması ×11 · hasar: fiziksel 168

## mana-crystal — Kristalleşme: işaretli düşman ölünce ek mana taşı.

Tarif: `mana5`

```text
Mana G5
• Mana sifonu: 22 mana hasarı; bu olaydaki hasarın %100'i mana olur. Aşılandığı yetenekte ana rünün hasarını da manaya çevirir.
• Mana işareti: Vurulan düşman 5 sn işaretlenir: çevresindeki 1,4 karo içinde hangi kuleden gelirse gelsin tüm hasarın %30'i mana olur.
• Kristalleşme: İşaretli düşman ölünce +2 mana taşı düşer.
```

Maliyet: 900 mana (rünler 900 + aşı ücreti 0), 1 düğüm.

Simülasyon (`mana5` + `fire5` + `stone5`): DPS: 53.01 · öldürme: 4 · sekme/zıplama: parça 11 · yayılan durum: 22 · en derin kuşak: 2 · en çok uygulama/olay: 7 · durumlar: yanma ×8, mana işareti ×8, zırh aşınması ×12, sersemleme ×12 · hasar: mana 174, ateş 264, fiziksel 304

## wet-electric — Etkileşim: ıslak hedef elektrikten ×1,5 hasar alır.

Tarif: `water2`

```text
Su G2
• Su isabeti: 9 su hasarı.
• Islatma: 3 sn ıslatır (ıslak: elektrikten ×1,5, daha çabuk donar, yanma kısalır).
  🔒 Geri itiş (G3'te açılır)
  🔒 Dalga (G5'te açılır)
```

Maliyet: 90 mana (rünler 90 + aşı ücreti 0), 1 düğüm.

Simülasyon (`water2` + `electric3`): DPS: 17.38 · öldürme: 1 · sekme/zıplama: seker 16 · en derin kuşak: 1 · en çok uygulama/olay: 5 · durumlar: ıslaklık ×7 · hasar: elektrik 187, su 57
Karşılaştırma (`electric3`): DPS: 10.66 · sekme/zıplama: seker 16 · en derin kuşak: 1 · en çok uygulama/olay: 5 · hasar: elektrik 149

## rej-locked-shards — Buz parçaları G4'te açılır: alıcıda kilitli.

`ice3{ice_shards:[electric3]}` → **craft reddedilir**: locked_on_receiver: Buz G3: 'Buz parçaları' G4'te açılır

## rej-locked-push — Su itişi G3'te açılır.

`water2{push:[blood1]}` → **craft reddedilir**: locked_on_receiver: Su G2: 'Geri itiş' G3'te açılır

## rej-armor-chain — Taş deriye Elektrik: tüm katkı uyumsuz, aşı reddedilir.

Craft masası: `golem2` · yuva `stone_skin` ← `electric3` → **ret**

- uyumsuz: hasar 'golem hasar aldığında' taşıyıcısında anlamsız (uyumsuz)
- uyumsuz: sekme 'golem hasar aldığında' taşıyıcısında anlamsız (uyumsuz)

## rej-summon — Volkan verici: çağrı taşınmaz, lav hasarı taşınır.

Tarif: `fire3{burn:[volcano3]}`

```text
Ateş G3  · 1 aşı, derinlik 1
• Ateş isabeti: 12 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3/sn × 3 sn.
    ↳ Volkan G3 — her tikte: 5,6 lav hasarı
        ✗ volkan çağrısı taşınmadı: Çağırma aşıyla taşınmaz; volkan yalnızca ana rün Volkan iken çağrılır (v4 §17.2).
        ✗ alan darbesi taşınmadı: alan darbesi 'her tikte' taşıyıcısında anlamsız (uyumsuz)
        ✗ Volkan G3: 'Lav birikintisi' yok (Volkan G4'te açılır)
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.
```

Maliyet: 500 mana (rünler 480 + aşı ücreti 20), 2 düğüm.

## rej-pierce-tick — Delme yanma tikinde anlamsız; ışık hasarı yine taşınır.

Tarif: `fire3{burn:[light3]}`

```text
Ateş G3  · 1 aşı, derinlik 1
• Ateş isabeti: 12 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3/sn × 3 sn.
    ↳ Işık G3 — her tikte: 3,2 ışık hasarı; kamaşma 1,5 sn
        ✗ delme taşınmadı: delme 'her tikte' taşıyıcısında anlamsız (uyumsuz)
        ✗ Işık G3: 'Aydınlatma' yok (Işık G5'te açılır)
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.
```

Maliyet: 420 mana (rünler 400 + aşı ücreti 20), 2 düğüm.

## stress-24 — 24 düğümlü stres tarifi: bütçe ve kuşak sınırı korunur.

Tarif: `fire5{fire_hit:[electric5{chain:[ice5{chill:[poison5,blood5]},stone3]},meteor3],burn:[electric3{chain:[ice2,water3]},poison4{poison_tick:[blood2]}],fire_trail:[ice3{freeze:[light3]},stone2{armor_shred:[light2]},blood1,volcano2{lava_blob:[fire2,water2{wet:[electric2,poison1]}]},golem1,hive1]}`

```text
Ateş G5  · 23 aşı, derinlik 3
• Ateş isabeti: 17 ateş hasarlı mermi.
    ↳ Elektrik G5 — her isabette: 8,4 elektrik hasarı; mermi sekerek: 3 hedef (her sekmede ×0,5); 3 yükte boşalma +8,4 elektrik, 0,4 sn şok
        [Elektrik · Sekme]
        ↳ Buz G5 — ulaşılan her yeni hedefte: 7,6 buz hasarı; %28,9 yavaşlatma (2,5 sn); 3 soğukta 1,2 sn donma, donmuş ölümde 3 parça × 8,3, donunca 0,7 karo çevre de donar
            [Buz · Yavaşlatma]
            ↳ Zehir G5 — durum her uygulandığında: zehir 3,8/sn × 5 sn, 5 yığına kadar, iyileşme −%40, ölünce %50 bulaşma
            ↳ Kan G5 — durum her uygulandığında: kanama 5,5/karo (5 sn), yoğunluk 4 kata kadar, tavanda yırtılma 14,1
        ↳ Taş G3 — ulaşılan her yeni hedefte: 6,5 fiziksel hasarı; zırh −%8,7 (3 sn)
            ✗ parça taşınmadı: parça 'ulaşılan her yeni hedefte' taşıyıcısında anlamsız (uyumsuz)
            ✗ Taş G3: 'Sarsıntı' yok (Taş G5'te açılır)
    ↳ Meteor G3 — her isabette: 19,6 çarpma hasarı; 0,6 karo alan (%42); 2 parça (%35)
        ✗ meteor çağrısı taşınmadı: Gökten meteor çağrısı aşıyla taşınmaz; yalnızca çarpma hasarı taşınır.
        ✗ Meteor G3: 'Meteor yağmuru' yok (Meteor G5'te açılır)
• Yanma: İsabet yakar: 4,5/sn × 4 sn.
    ↳ Elektrik G3 — her tikte: 2,4 elektrik hasarı; durum yandakine atlayarak: 2 hedef (her sekmede ×0,5)
        ✗ Elektrik G3: 'Aşırı yük' yok (Elektrik G4'te açılır)
        [Elektrik · Sekme]
        ↳ Buz G2 — ulaşılan her yeni hedefte: 2,6 buz hasarı; %18,1 yavaşlatma (1,8 sn)
            ✗ Buz G2: 'Donma' yok (Buz G3'te açılır)
        ↳ Su G3 — ulaşılan her yeni hedefte: 3,8 su hasarı; ıslaklık 3 sn; 0,3 karo geri itiş
            ✗ Su G3: 'Dalga' yok (Su G5'te açılır)
    ↳ Zehir G4 — her tikte: zehir 5,6/sn × 5 sn, 4 yığına kadar, iyileşme −%30, ölünce %50 bulaşma
        [Zehir · Zehir tiki]
        ↳ Kan G2 — her tikte: kanama 2,7/karo (4 sn), yoğunluk 3 kata kadar
            ✗ Kan G2: 'Yırtılma' yok (Kan G4'te açılır)
• Ateş izi: Yanan düşman arkasında 2 sn yanan iz bırakır; izdeki düşmanlar 2/sn ateş hasarı alır.
    ↳ Buz G3 — alanın içindekilere (her sn): 1,7 buz hasarı; %25,5 yavaşlatma (2 sn); 3 soğukta 1 sn donma
        ✗ Buz G3: 'Buz parçaları' yok (Buz G4'te açılır)
        [Buz · Donma]
        ↳ Işık G3 — eşik dolduğu an: 6,4 ışık hasarı; kamaşma 1,5 sn
            ✗ delme taşınmadı: delme 'eşik dolduğu an' taşıyıcısında anlamsız (uyumsuz)
            ✗ Işık G3: 'Aydınlatma' yok (Işık G5'te açılır)
    ↳ Taş G2 — alanın içindekilere (her sn): 2,8 fiziksel hasarı; zırh −%6,8 (3 sn)
        ✗ Taş G2: 'Taş parçaları' yok (Taş G3'te açılır)
        [Taş · Zırh aşındırma]
        ↳ Işık G2 — durum her uygulandığında: 2,9 ışık hasarı; kamaşma 1,5 sn
            ✗ Işık G2: 'Delme' yok (Işık G3'te açılır)
    ↳ Kan G1 — alanın içindekilere (her sn): kanama 3,5/karo (3 sn)
        ✗ Kan G1: 'Yoğunluk' yok (Kan G2'de açılır)
    ↳ Volkan G2 — alanın içindekilere (her sn): 2,9 lav hasarı
        ✗ volkan çağrısı taşınmadı: Çağırma aşıyla taşınmaz; volkan yalnızca ana rün Volkan iken çağrılır (v4 §17.2).
        ✗ alan darbesi taşınmadı: alan darbesi 'alanın içindekilere (her sn)' taşıyıcısında anlamsız (uyumsuz)
        ✗ Volkan G2: 'Geniş püskürme' yok (Volkan G3'te açılır)
        [Volkan · Lav topu]
        ↳ Ateş G2 — çağrının her vuruşunda: 1,1 ateş hasarı; yanma 1,2/sn × 3 sn
            ✗ Ateş G2: 'Ateş izi' yok (Ateş G3'te açılır)
        ↳ Su G2 — çağrının her vuruşunda: 0,9 su hasarı; ıslaklık 3 sn
            ✗ Su G2: 'Geri itiş' yok (Su G3'te açılır)
            [Su · Islatma]
            ↳ Elektrik G2 — durum her uygulandığında: 1,6 elektrik hasarı; durum yandakine geçerek: 1 hedef (her sekmede ×0,2)
                ✗ Elektrik G2: 'Aşırı yük' yok (Elektrik G4'te açılır)
            ↳ Zehir G1 — durum her uygulandığında: zehir 1,7/sn × 3 sn
                ✗ Zehir G1: 'Yığılma' yok (Zehir G2'de açılır)
    ↳ Golem G1 — alanın içindekilere (her sn): 0,6 fiziksel hasarı
        ✗ golem çağrısı taşınmadı: Çağırma aşıyla taşınmaz (v4 §17.2).
        ✗ Golem G1: 'Taş deri' yok (Golem G2'de açılır)
    ↳ Kovan G1 — alanın içindekilere (her sn): 0,1 fiziksel hasarı
        ✗ kovan çağrısı taşınmadı: Çağırma aşıyla taşınmaz (v4 §17.2).
        ✗ Kovan G1: 'Üreme' yok (Kovan G2'de açılır)
```

Maliyet: 25523 mana (rünler 7170 + aşı ücreti 18353), 24 düğüm.

Simülasyon (`fire5{fire_hit:[electric5{chain:[ice5{chill:[poison5,blood5]},stone3]},meteor3],burn:[electric3{chain:[ice2,water3]},poison4{poison_tick:[blood2]}],fire_trail:[ice3{freeze:[light3]},hive1,golem1,volcano2{lava_blob:[fire2,water2{wet:[electric2,poison1]}]},stone2{armor_shred:[light2]},blood1]}`): DPS: 130.86 · öldürme: 6 · sekme/zıplama: durum yandakine atlayarak 8, durum yandakine geçerek 9, mermi sekerek 6, parça 1 · yayılan durum: 216 · donma: 5 · itiş (karo): 1.0 · itişten kanama: 7.65 · en derin kuşak: 2 · en çok uygulama/olay: 13 · durumlar: kanama ×24, kamaşma ×18, yanma ×30, elektrik yükü ×9, soğuk ×20, zehir ×52, zırh aşınması ×20, yavaşlatma ×28, ıslaklık ×21 · hasar: kan 44, elektrik 114, ateş 175, buz 45, çarpma 77, lav 43, ışık 71, fiziksel 61, zehir 87, su 22

