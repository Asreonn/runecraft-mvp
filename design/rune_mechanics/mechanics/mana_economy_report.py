#!/usr/bin/env python3
"""Build reports/mana_economy.md from Godot economy-probe logs.

    for v in none mana1 mana3 mana5 fire3+mana5; do
      godot --headless --fixed-fps 60 --path <game> -- --econ $v [--front] --seed 3 --waves 8 > <dir>/$v.log
    done
    python3 mechanics/mana_economy_report.py <front_dir> <back_dir>
"""
import re
import sys
from pathlib import Path

VARIANTS = ["none", "mana1", "mana3", "mana5", "fire3+mana5"]


def load(d):
    rows = {}
    for v in VARIANTS:
        for line in (Path(d) / f"{v}.log").read_text().splitlines():
            m = re.match(r"ECON (\S+) wave=(\d+) rune_mana=([\d.]+) total_mana_gain=([\d.]+) hp=(\d+)", line)
            if m:
                rows.setdefault(v, []).append((int(m[2]), float(m[3]), float(m[4]), int(m[5])))
    return rows


def table(rows):
    base = sum(x[2] for x in rows["none"])
    out = ["| Variant | " + " | ".join(f"W{w}" for w in range(1, 9)) + " | Σ rune mana | Σ total | vs none | castle HP |",
           "|---|" + "---|" * 8 + "---|---|---|---|"]
    for v, r in rows.items():
        tot = sum(x[2] for x in r)
        out.append(f"| {v} | " + " | ".join(f"{x[1]:.0f} / {x[2]:.0f}" for x in r)
                   + f" | {sum(x[1] for x in r):.0f} | {tot:.0f} | {((tot / base) - 1) * 100:+.0f}% | {r[-1][3]} |")
    return out


def main(front, back):
    out = ["# RuneCraft — Mana rune economy, measured in the Godot game", "",
           "Probe: `godot --headless --fixed-fps 60 --path . -- --econ <variant> [--front] --seed 3 --waves 8` (map seed 3, 3×).",
           "Three fixed towers (Fire G3, Ice G3, Electric G3) plus one variant tower near the path; mana is never spent.",
           "Cells: rune mana / total mana gained in that wave (passive +3/s, +2 per kill, rune mana). Wave 5 has a boss.",
           "Rules: overkill excluded, one soft income cap per producing Mana node (2.5 / 4 / 6 / 8 / 11 mana/s, 25 % above).",
           "Values are **provisional** (see `design/DECISIONS.md`).", "",
           "## Variant tower first on the path (`--front`) — it meets every enemy", ""] + table(load(front)) + [
           "", "## Variant tower last on the path — earlier towers kill most enemies first", ""] + table(load(back)) + [
           "", "## Reading", "",
           "- The Mana rune's value grows clearly with grade (front placement over 8 waves: see the `vs none` column).",
           "- Grafting Mana G5 onto a Fire G3 hit gives most of the dedicated tower's rune mana while keeping Fire's damage.",
           "- Placement matters: a Mana tower behind strong towers earns little (it only damages what survives).",
           "- No runaway loop: per-node caps and overkill exclusion bound the income."]
    Path(__file__).resolve().parents[1].joinpath("reports/mana_economy.md").write_text("\n".join(out) + "\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
