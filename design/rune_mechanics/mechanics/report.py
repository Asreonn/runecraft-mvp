"""Writes reports/mechanics_scenarios.md and reports/rune_cards.md from the spec + scenarios.

  python3 report.py
"""
from __future__ import annotations

import json
from pathlib import Path

import resolver
import sim
from resolver import RecipeError, SPEC

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
SCEN = json.loads((HERE / "scenarios.json").read_text(encoding="utf-8"))["scenarios"]

KEYS = [("dps", "DPS"), ("kills", "öldürme"), ("hops", "sekme/zıplama"), ("spread_status", "yayılan durum"),
        ("frozen", "donma"), ("pushed_tiles", "itiş (karo)"), ("bleed_forced", "itişten kanama"),
        ("max_gen", "en derin kuşak"), ("max_budget_used", "en çok uygulama/olay")]


def fmt_stats(s):
    out = []
    for k, label in KEYS:
        v = s.get(k)
        if isinstance(v, dict):
            v = ", ".join(f"{kk} {vv}" for kk, vv in v.items()) if v else 0
        if v:
            out.append(f"{label}: {v}")
    st = s.get("statuses", {})
    if st:
        out.append("durumlar: " + ", ".join(f"{SPEC['statuses'][k]['tr']} ×{v}" for k, v in st.items()))
    el = s.get("by_element", {})
    if el:
        out.append("hasar: " + ", ".join(f"{SPEC['element_tr'][k]} {v:.0f}" for k, v in el.items()))
    return " · ".join(out)


def scenarios_md():
    L = ["# RuneCraft — mekanik senaryoları (otomatik)", "",
         "Kaynak: `spec/rune_mechanics_v1.json`, `mechanics/scenarios.json`. Üreten: `mechanics/report.py`. "
         "Doğrulama: `python3 mechanics/test_mechanics.py`.", "",
         "Referans: düz yol, 6 düşman (can 120, hız 1 karo/sn, aralık 0,6 karo, zırh %10), kule yoldan 2 karo uzakta, "
         "menzil 4 karo, 14 sn. Açıklama metni, craft sonrası **çıktı rünün açıklamasıdır**; craft öncesi önizleme yoktur.", ""]
    for sc in SCEN:
        L.append(f"## {sc['id']} — {sc['tr']}")
        L.append("")
        if "graft" in sc:
            ok, why = resolver.check_graft(*sc["graft"])
            L += [f"Craft masası: `{sc['graft'][0]}` · yuva `{sc['graft'][1]}` ← `{sc['graft'][2]}` → "
                  f"**{'kabul' if ok else 'ret'}**", ""] + [f"- {w}" for w in why] + [""]
            continue
        recipe = sc.get("recipe") or sc["towers"][0]
        try:
            c = resolver.compile_recipe(recipe)
        except RecipeError as e:
            L += [f"`{recipe}` → **craft reddedilir**: {e}", ""]
            continue
        L += [f"Tarif: `{c.canonical}`", "", "```text", resolver.describe(c), "```", ""]
        co = resolver.cost(c.root)
        L.append(f"Maliyet: {co['total_mana']} mana (rünler {co['runes_mana']} + aşı ücreti {co['graft_fees_mana']}), "
                 f"{co['nodes']} düğüm.")
        if "towers" in sc:
            s = sim.simulate(sc["towers"])
            L.append("")
            L.append(f"Simülasyon ({' + '.join(f'`{t}`' for t in sc['towers'])}): {fmt_stats(s)}")
            if "compare_to" in sc:
                b = sim.simulate(sc["compare_to"])
                L.append(f"Karşılaştırma ({' + '.join(f'`{t}`' for t in sc['compare_to'])}): {fmt_stats(b)}")
        L.append("")
    (ROOT / "reports" / "mechanics_scenarios.md").write_text("\n".join(L) + "\n", encoding="utf-8")


def cards_md():
    L = ["# RuneCraft — rün kartları G1–G5 (otomatik)", "",
         "Her grade tek bir rün kartıdır; kilitli yetenekler 🔒 ile gösterilir. Aşı yuvası = açık yetenek sayısı. "
         "Statlar `mechanics/balance.py` ile dengelendi (bkz. `mechanics_balance.md`).", ""]
    for rid, r in SPEC["runes"].items():
        L += [f"## {r['tr']} — {r['identity_tr']}", ""]
        L.append("| Grade | Açılan | Değer (mana) |")
        L.append("|---|---|---|")
        for g in range(1, 6):
            new = [a["tr"] for a in r["abilities"] if a["grade"] == g]
            L.append(f"| G{g} | {', '.join(new) if new else 'stat artışı'} | {resolver.rune_value(rid, g):.0f} |")
        L += ["", "```text"]
        for g in range(1, 6):
            L.append(resolver.describe(f"{rid}{g}"))
            L.append("")
        L += ["```", ""]
    (ROOT / "reports" / "rune_cards.md").write_text("\n".join(L) + "\n", encoding="utf-8")


if __name__ == "__main__":
    scenarios_md()
    cards_md()
    print("wrote reports/mechanics_scenarios.md, reports/rune_cards.md")
