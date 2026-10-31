# RuneCraft — rün kartları G1–G5 (otomatik)

Her grade tek bir rün kartıdır; kilitli yetenekler 🔒 ile gösterilir. Aşı yuvası = açık yetenek sayısı. Statlar `mechanics/balance.py` ile dengelendi (bkz. `mechanics_balance.md`).

## Ateş — Doğrudan ısı → yanma → yanan düşmanın arkasında ateş izi.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Ateş isabeti | 40 |
| G2 | Yanma | 90 |
| G3 | Ateş izi | 200 |
| G4 | stat artışı | 430 |
| G5 | stat artışı | 900 |

```text
Ateş G1
• Ateş isabeti: 10 ateş hasarlı mermi.
  🔒 Yanma (G2'de açılır)
  🔒 Ateş izi (G3'te açılır)

Ateş G2
• Ateş isabeti: 11 ateş hasarlı mermi.
• Yanma: İsabet yakar: 2,5/sn × 3 sn.
  🔒 Ateş izi (G3'te açılır)

Ateş G3
• Ateş isabeti: 12 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3/sn × 3 sn.
• Ateş izi: Yanan düşman arkasında 1 sn yanan iz bırakır; izdeki düşmanlar 1/sn ateş hasarı alır.

Ateş G4
• Ateş isabeti: 13 ateş hasarlı mermi.
• Yanma: İsabet yakar: 3,5/sn × 3 sn.
• Ateş izi: Yanan düşman arkasında 1,5 sn yanan iz bırakır; izdeki düşmanlar 1,5/sn ateş hasarı alır.

Ateş G5
• Ateş isabeti: 17 ateş hasarlı mermi.
• Yanma: İsabet yakar: 4,5/sn × 4 sn.
• Ateş izi: Yanan düşman arkasında 2 sn yanan iz bırakır; izdeki düşmanlar 2/sn ateş hasarı alır.

```

## Buz — Buz vuruşu → yavaşlatma → donma → donmuş ölümde parçalar → çevreyi dondurma.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Buz isabeti | 40 |
| G2 | Yavaşlatma | 90 |
| G3 | Donma | 200 |
| G4 | Buz parçaları | 430 |
| G5 | Çevreyi dondurma | 900 |

```text
Buz G1
• Buz isabeti: 6 buz hasarı.
  🔒 Yavaşlatma (G2'de açılır)
  🔒 Donma (G3'te açılır)
  🔒 Buz parçaları (G4'te açılır)
  🔒 Çevreyi dondurma (G5'te açılır)

Buz G2
• Buz isabeti: 9 buz hasarı.
• Yavaşlatma: %25 yavaşlatır (1,8 sn).
  🔒 Donma (G3'te açılır)
  🔒 Buz parçaları (G4'te açılır)
  🔒 Çevreyi dondurma (G5'te açılır)

Buz G3
• Buz isabeti: 12 buz hasarı.
• Yavaşlatma: %30 yavaşlatır (2 sn).
• Donma: Her isabet 1 soğuk; 3 soğukta 1 sn donar.
  🔒 Buz parçaları (G4'te açılır)
  🔒 Çevreyi dondurma (G5'te açılır)

Buz G4
• Buz isabeti: 18 buz hasarı.
• Yavaşlatma: %35 yavaşlatır (2,2 sn).
• Donma: Her isabet 1 soğuk; 3 soğukta 1,1 sn donar.
• Buz parçaları: Donmuşken ölen düşman 3 parçaya ayrılır; yakındakilere 10 buz hasarı.
  🔒 Çevreyi dondurma (G5'te açılır)

Buz G5
• Buz isabeti: 26 buz hasarı.
• Yavaşlatma: %40 yavaşlatır (2,5 sn).
• Donma: Her isabet 1 soğuk; 3 soğukta 1,2 sn donar.
• Buz parçaları: Donmuşken ölen düşman 3 parçaya ayrılır; yakındakilere 17 buz hasarı.
• Çevreyi dondurma: Bir düşman donunca 0,7 karo içindekiler de yarı süre donar.

```

## Elektrik — Elektrik vuruşu → sekme → aşırı yük (boşalma + şok).

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Elektrik isabeti | 40 |
| G2 | Sekme | 90 |
| G3 | stat artışı | 200 |
| G4 | Aşırı yük | 430 |
| G5 | stat artışı | 900 |

```text
Elektrik G1
• Elektrik isabeti: 9 elektrik hasarı.
  🔒 Sekme (G2'de açılır)
  🔒 Aşırı yük (G4'te açılır)

Elektrik G2
• Elektrik isabeti: 9,5 elektrik hasarı.
• Sekme: Saldırı 1 yakın hedefe seker (her sekmede güç ×0,6).
  🔒 Aşırı yük (G4'te açılır)

Elektrik G3
• Elektrik isabeti: 10 elektrik hasarı.
• Sekme: Saldırı 2 yakın hedefe seker (her sekmede güç ×0,7).
  🔒 Aşırı yük (G4'te açılır)

Elektrik G4
• Elektrik isabeti: 11 elektrik hasarı.
• Sekme: Saldırı 2 yakın hedefe seker (her sekmede güç ×0,7).
• Aşırı yük: Her elektrik isabeti 1 yük; 3 yükte boşalır: +7,5 elektrik ve 0,3 sn şok.

Elektrik G5
• Elektrik isabeti: 12 elektrik hasarı.
• Sekme: Saldırı 3 yakın hedefe seker (her sekmede güç ×0,8).
• Aşırı yük: Her elektrik isabeti 1 yük; 3 yükte boşalır: +12 elektrik ve 0,4 sn şok.

```

## Zehir — Zehir DoT → yığılma → iyileşme baskısı → ölümde bulaşma. Patlamaz, yerde alan bırakmaz (v4).

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Zehir tiki | 40 |
| G2 | Yığılma | 90 |
| G3 | İyileşme baskısı | 200 |
| G4 | Bulaşma | 430 |
| G5 | stat artışı | 900 |

```text
Zehir G1
• Zehir tiki: İsabet zehirler: 5/sn × 3 sn.
  🔒 Yığılma (G2'de açılır)
  🔒 İyileşme baskısı (G3'te açılır)
  🔒 Bulaşma (G4'te açılır)

Zehir G2
• Zehir tiki: İsabet zehirler: 5,5/sn × 4 sn.
• Yığılma: Zehir 3 yığına kadar birikir (yığın başına +%50).
  🔒 İyileşme baskısı (G3'te açılır)
  🔒 Bulaşma (G4'te açılır)

Zehir G3
• Zehir tiki: İsabet zehirler: 7/sn × 4 sn.
• Yığılma: Zehir 3 yığına kadar birikir (yığın başına +%50).
• İyileşme baskısı: Zehirli düşmanın iyileşmesi %30 azalır.
  🔒 Bulaşma (G4'te açılır)

Zehir G4
• Zehir tiki: İsabet zehirler: 8/sn × 5 sn.
• Yığılma: Zehir 4 yığına kadar birikir (yığın başına +%50).
• İyileşme baskısı: Zehirli düşmanın iyileşmesi %30 azalır.
• Bulaşma: Zehirli ölen düşmanın yığınlarının %50'si en yakın düşmana geçer (patlama yok).

Zehir G5
• Zehir tiki: İsabet zehirler: 11/sn × 5 sn.
• Yığılma: Zehir 5 yığına kadar birikir (yığın başına +%50).
• İyileşme baskısı: Zehirli düşmanın iyileşmesi %40 azalır.
• Bulaşma: Zehirli ölen düşmanın yığınlarının %50'si en yakın düşmana geçer (patlama yok).

```

## Su — Su vuruşu → ıslatma → geri itiş → dalga.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Su isabeti | 40 |
| G2 | Islatma | 90 |
| G3 | Geri itiş | 200 |
| G4 | stat artışı | 430 |
| G5 | Dalga | 900 |

```text
Su G1
• Su isabeti: 6 su hasarı.
  🔒 Islatma (G2'de açılır)
  🔒 Geri itiş (G3'te açılır)
  🔒 Dalga (G5'te açılır)

Su G2
• Su isabeti: 9 su hasarı.
• Islatma: 3 sn ıslatır (ıslak: elektrikten ×1,5, daha çabuk donar, yanma kısalır).
  🔒 Geri itiş (G3'te açılır)
  🔒 Dalga (G5'te açılır)

Su G3
• Su isabeti: 13 su hasarı.
• Islatma: 3 sn ıslatır (ıslak: elektrikten ×1,5, daha çabuk donar, yanma kısalır).
• Geri itiş: Hedefi yol boyunca 0,3 karo geri iter (yanan hedef ×1,5).
  🔒 Dalga (G5'te açılır)

Su G4
• Su isabeti: 20 su hasarı.
• Islatma: 3 sn ıslatır (ıslak: elektrikten ×1,5, daha çabuk donar, yanma kısalır).
• Geri itiş: Hedefi yol boyunca 0,5 karo geri iter (yanan hedef ×1,5).
  🔒 Dalga (G5'te açılır)

Su G5
• Su isabeti: 22 su hasarı.
• Islatma: 4 sn ıslatır (ıslak: elektrikten ×1,5, daha çabuk donar, yanma kısalır).
• Geri itiş: Hedefi yol boyunca 0,6 karo geri iter (yanan hedef ×1,5).
• Dalga: Su isabeti dalga olur: 0,4 karo içindekilere %25 hasar, ıslaklık ve itiş.

```

## Taş — Ağır darbe → zırh aşındırma → parçalar → sarsıntı.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Ağır darbe | 40 |
| G2 | Zırh aşındırma | 90 |
| G3 | Taş parçaları | 200 |
| G4 | stat artışı | 430 |
| G5 | Sarsıntı | 900 |

```text
Taş G1
• Ağır darbe: 14 fiziksel hasar.
  🔒 Zırh aşındırma (G2'de açılır)
  🔒 Taş parçaları (G3'te açılır)
  🔒 Sarsıntı (G5'te açılır)

Taş G2
• Ağır darbe: 20 fiziksel hasar.
• Zırh aşındırma: Zırhı 3 sn %8 azaltır.
  🔒 Taş parçaları (G3'te açılır)
  🔒 Sarsıntı (G5'te açılır)

Taş G3
• Ağır darbe: 22 fiziksel hasar.
• Zırh aşındırma: Zırhı 3 sn %12 azaltır.
• Taş parçaları: Çarpmada 2 parça yakındakilere isabetin %50'sini taşır.
  🔒 Sarsıntı (G5'te açılır)

Taş G4
• Ağır darbe: 28 fiziksel hasar.
• Zırh aşındırma: Zırhı 3 sn %16 azaltır.
• Taş parçaları: Çarpmada 2 parça yakındakilere isabetin %50'sini taşır.
  🔒 Sarsıntı (G5'te açılır)

Taş G5
• Ağır darbe: 30 fiziksel hasar.
• Zırh aşındırma: Zırhı 3 sn %20 azaltır.
• Taş parçaları: Çarpmada 3 parça yakındakilere isabetin %50'sini taşır.
• Sarsıntı: İsabet 0,4 sn sersemletir (aynı hedefe 2 sn'de bir).

```

## Işık — Işın → kamaşma → delme → aydınlatma işareti.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Işın | 40 |
| G2 | Kamaşma | 90 |
| G3 | Delme | 200 |
| G4 | stat artışı | 430 |
| G5 | Aydınlatma | 900 |

```text
Işık G1
• Işın: 8 ışık hasarlı ışın.
  🔒 Kamaşma (G2'de açılır)
  🔒 Delme (G3'te açılır)
  🔒 Aydınlatma (G5'te açılır)

Işık G2
• Işın: 12 ışık hasarlı ışın.
• Kamaşma: 1,5 sn kamaştırır: düşman saldırılarının isabeti %30 düşer.
  🔒 Delme (G3'te açılır)
  🔒 Aydınlatma (G5'te açılır)

Işık G3
• Işın: 13 ışık hasarlı ışın.
• Kamaşma: 1,5 sn kamaştırır: düşman saldırılarının isabeti %30 düşer.
• Delme: Işın 1 hedefi daha deler (her delişte ×0,6).
  🔒 Aydınlatma (G5'te açılır)

Işık G4
• Işın: 16 ışık hasarlı ışın.
• Kamaşma: 2 sn kamaştırır: düşman saldırılarının isabeti %30 düşer.
• Delme: Işın 2 hedefi daha deler (her delişte ×0,6).
  🔒 Aydınlatma (G5'te açılır)

Işık G5
• Işın: 21 ışık hasarlı ışın.
• Kamaşma: 2 sn kamaştırır: düşman saldırılarının isabeti %30 düşer.
• Delme: Işın 2 hedefi daha deler (her delişte ×0,6).
• Aydınlatma: Vurulan düşman 3 sn aydınlanır: tüm kulelerden +%15 hasar alır.

```

## Kan — Yürüdükçe kanama → yoğunluk → yırtılma.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Kanama | 40 |
| G2 | Yoğunluk | 90 |
| G3 | stat artışı | 200 |
| G4 | Yırtılma | 430 |
| G5 | stat artışı | 900 |

```text
Kan G1
• Kanama: Kanayan düşman yürüdüğü her karo için 5 hasar alır (3 sn). İtiş de sayılır.
  🔒 Yoğunluk (G2'de açılır)
  🔒 Yırtılma (G4'te açılır)

Kan G2
• Kanama: Kanayan düşman yürüdüğü her karo için 5,5 hasar alır (4 sn). İtiş de sayılır.
• Yoğunluk: Tekrar isabet yoğunluğu artırır (en çok 3, her kat +%25).
  🔒 Yırtılma (G4'te açılır)

Kan G3
• Kanama: Kanayan düşman yürüdüğü her karo için 7,5 hasar alır (4 sn). İtiş de sayılır.
• Yoğunluk: Tekrar isabet yoğunluğu artırır (en çok 3, her kat +%25).
  🔒 Yırtılma (G4'te açılır)

Kan G4
• Kanama: Kanayan düşman yürüdüğü her karo için 10 hasar alır (5 sn). İtiş de sayılır.
• Yoğunluk: Tekrar isabet yoğunluğu artırır (en çok 3, her kat +%25).
• Yırtılma: Yoğunluk tavana ulaşınca yırtılır: 26 kan hasarı, yoğunluk sıfırlanır.

Kan G5
• Kanama: Kanayan düşman yürüdüğü her karo için 16 hasar alır (5 sn). İtiş de sayılır.
• Yoğunluk: Tekrar isabet yoğunluğu artırır (en çok 4, her kat +%25).
• Yırtılma: Yoğunluk tavana ulaşınca yırtılır: 41 kan hasarı, yoğunluk sıfırlanır.

```

## Meteor — Gökten meteor → alan darbesi → parçalar → meteor yağmuru.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Meteor çarpması | 60 |
| G2 | Alan darbesi | 130 |
| G3 | Çarpma parçaları | 280 |
| G4 | stat artışı | 590 |
| G5 | Meteor yağmuru | 1220 |

```text
Meteor G1
• Meteor çarpması: Her 3 sn hedefe gökten meteor düşer: 18 çarpma hasarı.
  🔒 Alan darbesi (G2'de açılır)
  🔒 Çarpma parçaları (G3'te açılır)
  🔒 Meteor yağmuru (G5'te açılır)

Meteor G2
• Meteor çarpması: Her 3 sn hedefe gökten meteor düşer: 26 çarpma hasarı.
• Alan darbesi: Çarpma 0,5 karo içindekilere %60 hasar verir.
  🔒 Çarpma parçaları (G3'te açılır)
  🔒 Meteor yağmuru (G5'te açılır)

Meteor G3
• Meteor çarpması: Her 3 sn hedefe gökten meteor düşer: 28 çarpma hasarı.
• Alan darbesi: Çarpma 0,6 karo içindekilere %60 hasar verir.
• Çarpma parçaları: 2 parça yakındakilere %50 taşır.
  🔒 Meteor yağmuru (G5'te açılır)

Meteor G4
• Meteor çarpması: Her 2,8 sn hedefe gökten meteor düşer: 30 çarpma hasarı.
• Alan darbesi: Çarpma 0,7 karo içindekilere %60 hasar verir.
• Çarpma parçaları: 2 parça yakındakilere %50 taşır.
  🔒 Meteor yağmuru (G5'te açılır)

Meteor G5
• Meteor çarpması: Her 2,6 sn hedefe gökten meteor düşer: 32 çarpma hasarı.
• Alan darbesi: Çarpma 0,8 karo içindekilere %60 hasar verir.
• Çarpma parçaları: 3 parça yakındakilere %50 taşır.
• Meteor yağmuru: Ana meteorun çevresine 2 küçük meteor düşer (%40).

```

## Volkan — Yol kenarına çağrılan dağ kraterinden çevresine lav topları fışkırtır → sıçrama → geniş püskürme → lav birikintisi.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Lav topu | 60 |
| G2 | Lav sıçraması | 130 |
| G3 | Geniş püskürme | 280 |
| G4 | Lav birikintisi | 590 |
| G5 | stat artışı | 1220 |

```text
Volkan G1
• Lav topu: Yol kenarına 6 sn'lik volkan çağırır; her 2,5 sn kraterden 1,5 karo içine lav topu fışkırır: 17 lav hasarı.
  🔒 Lav sıçraması (G2'de açılır)
  🔒 Geniş püskürme (G3'te açılır)
  🔒 Lav birikintisi (G4'te açılır)

Volkan G2
• Lav topu: Yol kenarına 7 sn'lik volkan çağırır; her 2,2 sn kraterden 1,5 karo içine lav topu fışkırır: 21 lav hasarı.
• Lav sıçraması: Top düştüğü yerde 0,3 karo sıçrar (%60).
  🔒 Geniş püskürme (G3'te açılır)
  🔒 Lav birikintisi (G4'te açılır)

Volkan G3
• Lav topu: Yol kenarına 8 sn'lik volkan çağırır; her 2 sn kraterden 1,5 karo içine lav topu fışkırır: 23 lav hasarı.
• Lav sıçraması: Top düştüğü yerde 0,3 karo sıçrar (%60).
• Geniş püskürme: Her fışkırmada 2 top farklı hedeflere.
  🔒 Lav birikintisi (G4'te açılır)

Volkan G4
• Lav topu: Yol kenarına 10 sn'lik volkan çağırır; her 1,8 sn kraterden 1,5 karo içine lav topu fışkırır: 34 lav hasarı.
• Lav sıçraması: Top düştüğü yerde 0,3 karo sıçrar (%60).
• Geniş püskürme: Her fışkırmada 2 top farklı hedeflere.
• Lav birikintisi: Top düştüğü yerde 1,5 sn lav birikintisi: 3/sn.

Volkan G5
• Lav topu: Yol kenarına 12 sn'lik volkan çağırır; her 1,6 sn kraterden 1,5 karo içine lav topu fışkırır: 39 lav hasarı.
• Lav sıçraması: Top düştüğü yerde 0,3 karo sıçrar (%60).
• Geniş püskürme: Her fışkırmada 2 top farklı hedeflere.
• Lav birikintisi: Top düştüğü yerde 1,5 sn lav birikintisi: 3,5/sn.

```

## Golem — Yürüyen dost birim → taş deri → zemin darbesi.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Golem yumruğu | 60 |
| G2 | Taş deri | 130 |
| G3 | Zemin darbesi | 280 |
| G4 | stat artışı | 590 |
| G5 | stat artışı | 1220 |

```text
Golem G1
• Golem yumruğu: 10 sn'lik golem çağırır; en yakın düşmana yürür, saniyede bir 8 fiziksel vurur.
  🔒 Taş deri (G2'de açılır)
  🔒 Zemin darbesi (G3'te açılır)

Golem G2
• Golem yumruğu: 11 sn'lik golem çağırır; en yakın düşmana yürür, saniyede bir 10 fiziksel vurur.
• Taş deri: Golem %10 az hasar alır.
  🔒 Zemin darbesi (G3'te açılır)

Golem G3
• Golem yumruğu: 12 sn'lik golem çağırır; en yakın düşmana yürür, saniyede bir 11 fiziksel vurur.
• Taş deri: Golem %10 az hasar alır.
• Zemin darbesi: Her 3. vuruş 0,6 karo zemin darbesidir.

Golem G4
• Golem yumruğu: 14 sn'lik golem çağırır; en yakın düşmana yürür, saniyede bir 17 fiziksel vurur.
• Taş deri: Golem %10 az hasar alır.
• Zemin darbesi: Her 3. vuruş 0,6 karo zemin darbesidir.

Golem G5
• Golem yumruğu: 15 sn'lik golem çağırır; en yakın düşmana yürür, saniyede bir 25 fiziksel vurur.
• Taş deri: Golem %10 az hasar alır.
• Zemin darbesi: Her 3. vuruş 0,7 karo zemin darbesidir.

```

## Kovan — Yuva ve böcekler → üreme → sürü odağı.

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Böcek ısırığı | 60 |
| G2 | Üreme | 130 |
| G3 | Sürü odağı | 280 |
| G4 | stat artışı | 590 |
| G5 | stat artışı | 1220 |

```text
Kovan G1
• Böcek ısırığı: 10 sn'lik kovan kurar; en çok 2 böcek, ısırık başına 3,5 hasar.
  🔒 Üreme (G2'de açılır)
  🔒 Sürü odağı (G3'te açılır)

Kovan G2
• Böcek ısırığı: 11 sn'lik kovan kurar; en çok 3 böcek, ısırık başına 4 hasar.
• Üreme: Öldüren böcek yeni böcek doğurur (en çok +2).
  🔒 Sürü odağı (G3'te açılır)

Kovan G3
• Böcek ısırığı: 12 sn'lik kovan kurar; en çok 3 böcek, ısırık başına 5 hasar.
• Üreme: Öldüren böcek yeni böcek doğurur (en çok +2).
• Sürü odağı: Böcekler işaretlenen tek hedefe birlikte saldırır.

Kovan G4
• Böcek ısırığı: 14 sn'lik kovan kurar; en çok 4 böcek, ısırık başına 6,5 hasar.
• Üreme: Öldüren böcek yeni böcek doğurur (en çok +2).
• Sürü odağı: Böcekler işaretlenen tek hedefe birlikte saldırır.

Kovan G5
• Böcek ısırığı: 16 sn'lik kovan kurar; en çok 5 böcek, ısırık başına 9 hasar.
• Üreme: Öldüren böcek yeni böcek doğurur (en çok +2).
• Sürü odağı: Böcekler işaretlenen tek hedefe birlikte saldırır.

```

## Mana — Ekonomi rünü: verdiği hasarı manaya çevirir → işaretlediği düşmanın çevresindeki tüm hasarı manaya çevirir → işaretli düşman ölünce kristal (mana taşı).

| Grade | Açılan | Değer (mana) |
|---|---|---|
| G1 | Mana sifonu | 40 |
| G2 | stat artışı | 90 |
| G3 | Mana işareti | 200 |
| G4 | stat artışı | 430 |
| G5 | Kristalleşme | 900 |

```text
Mana G1
• Mana sifonu: 4,5 mana hasarı; bu olaydaki hasarın %60'i mana olur. Aşılandığı yetenekte ana rünün hasarını da manaya çevirir.
  🔒 Mana işareti (G3'te açılır)
  🔒 Kristalleşme (G5'te açılır)

Mana G2
• Mana sifonu: 6,5 mana hasarı; bu olaydaki hasarın %70'i mana olur. Aşılandığı yetenekte ana rünün hasarını da manaya çevirir.
  🔒 Mana işareti (G3'te açılır)
  🔒 Kristalleşme (G5'te açılır)

Mana G3
• Mana sifonu: 10 mana hasarı; bu olaydaki hasarın %75'i mana olur. Aşılandığı yetenekte ana rünün hasarını da manaya çevirir.
• Mana işareti: Vurulan düşman 4 sn işaretlenir: çevresindeki 1 karo içinde hangi kuleden gelirse gelsin tüm hasarın %20'i mana olur.
  🔒 Kristalleşme (G5'te açılır)

Mana G4
• Mana sifonu: 15 mana hasarı; bu olaydaki hasarın %85'i mana olur. Aşılandığı yetenekte ana rünün hasarını da manaya çevirir.
• Mana işareti: Vurulan düşman 4 sn işaretlenir: çevresindeki 1,2 karo içinde hangi kuleden gelirse gelsin tüm hasarın %25'i mana olur.
  🔒 Kristalleşme (G5'te açılır)

Mana G5
• Mana sifonu: 22 mana hasarı; bu olaydaki hasarın %100'i mana olur. Aşılandığı yetenekte ana rünün hasarını da manaya çevirir.
• Mana işareti: Vurulan düşman 5 sn işaretlenir: çevresindeki 1,4 karo içinde hangi kuleden gelirse gelsin tüm hasarın %30'i mana olur.
• Kristalleşme: İşaretli düşman ölünce +2 mana taşı düşer.

```

