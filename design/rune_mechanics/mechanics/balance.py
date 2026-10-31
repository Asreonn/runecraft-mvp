"""Fit each rune's damage stats to the target power curve, using the simulation.

Target: throughput DPS on the reference pack (6 enemies, high HP so nobody dies)
  target(g) = g1_dps * per_grade^(g-1) * role_factor(rune)
Only the rune's listed damage stats are scaled; control stats, durations,
counts and radii stay as designed. Every damage stat must GROW grade to grade
(user rule: grades without a new ability still get stat growth).

  python3 balance.py          -> measure only, print table
  python3 balance.py --fit    -> fit, write tuned stats back into the spec, write report
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import resolver
import sim

ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "spec" / "rune_mechanics_v1.json"
REPORT = ROOT / "reports" / "mechanics_balance.md"
BAL_HP = 1000
GRAFT_COMBOS = [("fire3", "burn", "electric3"), ("fire3", "fire_hit", "electric3"), ("fire3", "burn", "electric1"),
                ("volcano3", "lava_blob", "electric3"), ("volcano3", "lava_blob", "ice2"), ("water3", "water_hit", "blood1"),
                ("golem3", "golem_punch", "fire3"), ("hive3", "beetle_bite", "poison2"), ("light3", "pierce", "poison1"),
                ("poison2", "poison_tick", "fire2"), ("electric3", "chain", "fire3"), ("meteor3", "meteor_fragments", "electric3"),
                ("stone3", "fragments", "electric3"), ("ice3", "freeze", "electric3"), ("fire5", "fire_hit", "electric5")]


def measure(spec_runes=None):
    out = {}
    for rid in resolver.SPEC["runes"]:
        out[rid] = [sim.simulate(f"{rid}{g}", hp=BAL_HP)["dps"] for g in range(1, 6)]
    return out


def control_metrics(rid, g):
    s = sim.simulate(f"{rid}{g}", hp=BAL_HP)
    return {k: s[k] for k in ("frozen", "pushed_tiles", "statuses") if s.get(k)}


def targets(spec):
    b = spec["balance"]
    return {rid: [b["g1_dps"] * b["per_grade"] ** (g - 1) * b["roles"][r["balance"]["role"]]
                  for g in range(1, 6)] for rid, r in spec["runes"].items()}


def _round(v):
    if v >= 10:
        return float(round(v))
    return round(v * 2) / 2


def _reload(spec):
    SPEC_PATH.write_text(json.dumps(spec, ensure_ascii=False, indent=1), encoding="utf-8")
    fresh = resolver.load_spec()
    resolver.SPEC.clear()
    resolver.SPEC.update(fresh)


def fit(rounds=6):
    spec = json.loads(SPEC_PATH.read_text(encoding="utf-8"))
    tg = targets(spec)
    for it in range(rounds):
        cur = measure()
        worst = 0.0
        for rid, r in spec["runes"].items():
            keys = r["balance"]["damage_stats"]
            for g in range(1, 6):
                k = tg[rid][g - 1] / max(cur[rid][g - 1], 0.01)
                worst = max(worst, abs(k - 1))
                st = r["grades"][str(g)]
                for key in keys:
                    if key in st:
                        st[key] = st[key] * (k ** 0.85)
            # monotonic growth + rounding
            for key in keys:
                prev = None
                for g in range(1, 6):
                    st = r["grades"][str(g)]
                    if key not in st:
                        continue
                    v = _round(st[key])
                    if prev is not None and v < prev * 1.05:
                        v = max(_round(prev * 1.08), prev + 0.5)
                    st[key] = v
                    prev = v
        _reload(spec)
        print(f"round {it + 1}: worst deviation {worst:.2%}")
    return spec


def report(spec):
    cur = measure()
    tg = targets(spec)
    lines = ["# RuneCraft — rün dengesi (otomatik ölçüm)", "",
             f"Kaynak: `spec/rune_mechanics_v1.json` · araç: `mechanics/balance.py` · referans: 6 düşman paketi, "
             f"can {BAL_HP} (ölüm yok, saf hasar akışı), tek kule, {resolver.SPEC['reference']['sim_seconds']} sn, atış aralığı "
             f"{resolver.SPEC['reference']['attack_period_s']} sn.", "",
             f"Hedef eğri: G1 = {spec['balance']['g1_dps']} DPS × rol katsayısı, her grade ×{spec['balance']['per_grade']}. "
             "Kontrol rünlerinin hasar hedefi düşüktür; değerleri yavaşlatma, donma ve itiştir.", "",
             "| Rün | Rol | G1 | G2 | G3 | G4 | G5 | G5/G1 | en büyük sapma |", "|---|---|---|---|---|---|---|---|---|"]
    for rid, r in spec["runes"].items():
        v, t = cur[rid], tg[rid]
        dev = max(abs(v[i] / t[i] - 1) for i in range(5))
        lines.append(f"| {r['tr']} | {r['balance']['role']} | " + " | ".join(f"{v[i]:.1f}" for i in range(5))
                     + f" | {v[4] / v[0]:.1f}× | {dev:.0%} |")
    lines += ["", "Hedef DPS satırı (rol katsayısı 1): " + " · ".join(
        f"G{g} {spec['balance']['g1_dps'] * spec['balance']['per_grade'] ** (g - 1):.1f}" for g in range(1, 6)), "",
        "## Grade başına statlar (dengelendikten sonra)", ""]
    for rid, r in spec["runes"].items():
        keys = r["balance"]["damage_stats"]
        lines.append(f"**{r['tr']}** — " + " · ".join(
            f"G{g}: " + ", ".join(f"{k} {r['grades'][str(g)][k]:g}" for k in keys if k in r["grades"][str(g)])
            for g in range(1, 6)))
        lines.append("")
    lines += ["## Aşı verimi", "",
              "Verim = tek kulede aşılı rünün DPS'i ÷ (ana rün + verici iki ayrı kulede). Aşı bir kule (mana taşı) "
              "tasarrufu sağladığı için geniş yuvalarda ~1,0–1,3× hedeflenir; dar yuvalar (donma anı, parçalar) seyrek "
              "tetiklenir ve daha düşük kalır — bu bilinçli bir seçimdir.", "",
              "| Ana rün · yuva ← verici | iki kule toplam | aşılı tek kule | verim |", "|---|---|---|---|"]
    for h, a, d in GRAFT_COMBOS:
        hh = sim.simulate(h, hp=BAL_HP)["dps"]
        dd = sim.simulate(d, hp=BAL_HP)["dps"]
        cc = sim.simulate(f"{h}{{{a}:[{d}]}}", hp=BAL_HP)["dps"]
        lines.append(f"| `{h}` · {a} ← `{d}` | {hh + dd:.1f} | {cc:.1f} | {cc / (hh + dd):.2f}× |")
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines[6:6 + 2 + len(spec["runes"])]))


if __name__ == "__main__":
    if "--fit" in sys.argv:
        spec = fit()
    else:
        spec = json.loads(SPEC_PATH.read_text(encoding="utf-8"))
    report(spec)
