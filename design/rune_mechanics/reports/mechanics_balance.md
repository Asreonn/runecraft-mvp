# RuneCraft — rün dengesi (otomatik ölçüm)

Kaynak: `spec/rune_mechanics_v1.json` · araç: `mechanics/balance.py` · referans: 6 düşman paketi, can 1000 (ölüm yok, saf hasar akışı), tek kule, 14.0 sn, atış aralığı 1.5 sn.

Hedef eğri: G1 = 4.5 DPS × rol katsayısı, her grade ×1.5. Kontrol rünlerinin hasar hedefi düşüktür; değerleri yavaşlatma, donma ve itiştir.

| Rün | Rol | G1 | G2 | G3 | G4 | G5 | G5/G1 | en büyük sapma |
|---|---|---|---|---|---|---|---|---|
| Ateş | dot | 4.5 | 7.2 | 10.5 | 16.8 | 22.0 | 4.9× | 11% |
| Buz | control | 2.7 | 4.0 | 6.2 | 9.3 | 13.4 | 5.0× | 2% |
| Elektrik | damage | 4.6 | 7.8 | 10.7 | 15.3 | 23.1 | 5.0× | 16% |
| Zehir | dot | 4.5 | 8.1 | 10.3 | 14.7 | 21.9 | 4.9× | 20% |
| Su | control | 2.7 | 4.0 | 5.8 | 9.0 | 14.8 | 5.5× | 9% |
| Taş | damage | 4.5 | 6.8 | 12.0 | 15.3 | 22.9 | 5.1× | 19% |
| Işık | damage | 4.6 | 6.9 | 12.0 | 15.6 | 22.6 | 4.9× | 19% |
| Kan | dot | 4.6 | 7.2 | 9.8 | 15.0 | 23.0 | 5.0× | 6% |
| Meteor | area | 4.6 | 6.7 | 11.7 | 18.3 | 23.7 | 5.1× | 21% |
| Volkan | summon | 4.4 | 6.8 | 11.8 | 15.0 | 22.5 | 5.2× | 17% |
| Golem | summon | 4.6 | 6.4 | 9.9 | 15.3 | 22.5 | 4.9× | 5% |
| Kovan | summon | 4.3 | 7.5 | 9.6 | 15.0 | 22.6 | 5.3× | 11% |
| Mana | economy | 2.3 | 3.3 | 5.1 | 7.7 | 11.3 | 4.9× | 3% |

Hedef DPS satırı (rol katsayısı 1): G1 4.5 · G2 6.8 · G3 10.1 · G4 15.2 · G5 22.8

## Grade başına statlar (dengelendikten sonra)

**Ateş** — G1: hit 10 · G2: hit 11, burn_dps 2.5 · G3: hit 12, burn_dps 3 · G4: hit 13, burn_dps 3.5 · G5: hit 17, burn_dps 4.5

**Buz** — G1: hit 6 · G2: hit 9 · G3: hit 12 · G4: hit 18, shard_dmg 10 · G5: hit 26, shard_dmg 17

**Elektrik** — G1: hit 9 · G2: hit 9.5 · G3: hit 10 · G4: hit 11, discharge 7.5 · G5: hit 12, discharge 12

**Zehir** — G1: dps 5 · G2: dps 5.5 · G3: dps 7 · G4: dps 8 · G5: dps 11

**Su** — G1: hit 6 · G2: hit 9 · G3: hit 13 · G4: hit 20 · G5: hit 22

**Taş** — G1: hit 14 · G2: hit 20 · G3: hit 22 · G4: hit 28 · G5: hit 30

**Işık** — G1: hit 8 · G2: hit 12 · G3: hit 13 · G4: hit 16 · G5: hit 21

**Kan** — G1: per_tile 5 · G2: per_tile 5.5 · G3: per_tile 7.5 · G4: per_tile 10, rupture 26 · G5: per_tile 16, rupture 41

**Meteor** — G1: hit 18 · G2: hit 26 · G3: hit 28 · G4: hit 30 · G5: hit 32

**Volkan** — G1: lava 17 · G2: lava 21 · G3: lava 23 · G4: lava 34, pool_dps 3 · G5: lava 39, pool_dps 3.5

**Golem** — G1: punch 8 · G2: punch 10 · G3: punch 11 · G4: punch 17 · G5: punch 25

**Kovan** — G1: bite 3.5 · G2: bite 4 · G3: bite 5 · G4: bite 6.5 · G5: bite 9

**Mana** — G1: hit 4.5 · G2: hit 6.5 · G3: hit 10 · G4: hit 15 · G5: hit 22

## Aşı verimi

Verim = tek kulede aşılı rünün DPS'i ÷ (ana rün + verici iki ayrı kulede). Aşı bir kule (mana taşı) tasarrufu sağladığı için geniş yuvalarda ~1,0–1,3× hedeflenir; dar yuvalar (donma anı, parçalar) seyrek tetiklenir ve daha düşük kalır — bu bilinçli bir seçimdir.

| Ana rün · yuva ← verici | iki kule toplam | aşılı tek kule | verim |
|---|---|---|---|
| `fire3` · burn ← `electric3` | 21.1 | 23.7 | 1.12× |
| `fire3` · fire_hit ← `electric3` | 21.1 | 27.1 | 1.28× |
| `fire3` · burn ← `electric1` | 15.1 | 12.5 | 0.82× |
| `volcano3` · lava_blob ← `electric3` | 22.5 | 25.6 | 1.14× |
| `volcano3` · lava_blob ← `ice2` | 15.9 | 19.6 | 1.23× |
| `water3` · water_hit ← `blood1` | 10.5 | 9.0 | 0.86× |
| `golem3` · golem_punch ← `fire3` | 20.4 | 16.7 | 0.82× |
| `hive3` · beetle_bite ← `poison2` | 17.8 | 14.8 | 0.84× |
| `light3` · pierce ← `poison1` | 16.5 | 15.2 | 0.92× |
| `poison2` · poison_tick ← `fire2` | 15.3 | 12.2 | 0.80× |
| `electric3` · chain ← `fire3` | 21.1 | 20.1 | 0.95× |
| `meteor3` · meteor_fragments ← `electric3` | 22.4 | 12.8 | 0.57× |
| `stone3` · fragments ← `electric3` | 22.7 | 13.5 | 0.59× |
| `ice3` · freeze ← `electric3` | 16.8 | 7.7 | 0.46× |
| `fire5` · fire_hit ← `electric5` | 45.1 | 57.8 | 1.28× |
