"""Checks the rune mechanics against scenarios.json + structural invariants.

  python3 test_mechanics.py        -> prints PASS/FAIL per check, exit 1 on any failure
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import resolver
import sim
from resolver import RecipeError, SPEC

HERE = Path(__file__).resolve().parent
SCEN = json.loads((HERE / "scenarios.json").read_text(encoding="utf-8"))["scenarios"]
results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))


def stat(s: dict, key: str):
    if "~" in key:                       # hops~substring
        k, sub = key.split("~", 1)
        return sum(v for kk, v in s.get(k, {}).items() if sub in kk)
    cur = s
    for part in key.split("."):
        if not isinstance(cur, dict):
            return 0
        cur = cur.get(part, 0)
    if isinstance(cur, dict):
        return sum(cur.values()) if cur else 0
    return cur or 0


def families(ops):
    return {o.family for o in resolver._walk(ops)}


def slot_has(ops, slot, family):
    return any(slot in o.slots and any(x.family == family for x in resolver._walk(o.slots[slot]))
               for o in resolver._walk(ops))


def run_scenarios():
    for sc in SCEN:
        sid, ex = sc["id"], sc["expect"]
        try:
            if "graft" in sc:
                ok, why = resolver.check_graft(*sc["graft"])
                check(f"{sid} graft_ok={ex['graft_ok']}", ok == ex["graft_ok"], "; ".join(why))
                continue
            recipe = sc.get("recipe") or sc["towers"][0]
            try:
                c = resolver.compile_recipe(recipe)
            except RecipeError as e:
                check(f"{sid} error={ex.get('error')}", e.code == ex.get("error"), str(e))
                continue
            if "error" in ex:
                check(f"{sid} error={ex['error']}", False, "compiled without error")
                continue
            fams = families(c.ops)
            for f in ex.get("compile_lacks", []):
                check(f"{sid} compile lacks {f}", f not in fams)
            for f in ex.get("compile_has", []):
                check(f"{sid} compile has {f}", f in fams)
            if "compile_slot_has" in ex:
                d = ex["compile_slot_has"]
                check(f"{sid} slot {d['slot']} has {d['family']}", slot_has(c.ops, d["slot"], d["family"]))
            if "compile_lacks_under" in ex:
                d = ex["compile_lacks_under"]
                check(f"{sid} slot {d['slot']} lacks {d['family']}", not slot_has(c.ops, d["slot"], d["family"]))
            if "rejected_family" in ex:
                check(f"{sid} rejects {ex['rejected_family']}", any(r.family == ex["rejected_family"] for r in c.rejected),
                      str([r.family for r in c.rejected]))
            if "nodes" in ex:
                check(f"{sid} nodes={ex['nodes']}", c.root.size() == ex["nodes"], str(c.root.size()))
            if "root_rune" in ex:
                check(f"{sid} root rune {ex['root_rune']}", c.root.rune == ex["root_rune"])
            if "towers" not in sc:
                continue
            s = sim.simulate(sc["towers"])
            for k in ex.get("sim_pos", []):
                check(f"{sid} {k} > 0", stat(s, k) > 0, str(stat(s, k)))
            for k in ex.get("sim_zero", []):
                check(f"{sid} {k} == 0", stat(s, k) == 0, str(stat(s, k)))
            for k, mx in ex.get("sim_max", {}).items():
                check(f"{sid} {k} <= {mx}", stat(s, k) <= mx, str(stat(s, k)))
            if "summons_only" in ex:
                check(f"{sid} summons only {ex['summons_only']}", set(s["summons"]) <= set(ex["summons_only"]), str(s["summons"]))
            if "compare_to" in sc:
                b = sim.simulate(sc["compare_to"])
                for k in ex.get("greater", []):
                    check(f"{sid} {k} greater than alone", stat(s, k) > stat(b, k), f"{stat(s, k)} vs {stat(b, k)}")
                for k in ex.get("less_per_tower", []):
                    check(f"{sid} {k} less with the other tower", stat(s, k) < stat(b, k), f"{stat(s, k)} vs {stat(b, k)}")
        except Exception as e:  # a crash is a failure, not an abort
            check(f"{sid} crashed", False, repr(e))


def run_invariants():
    # 1. sibling order independence: same canonical, same simulation
    a = "volcano5{lava_blob:[fire3,electric3,ice2]}"
    b = "volcano5{lava_blob:[ice2,electric3,fire3]}"
    check("siblings: canonical equal", resolver.canonical(resolver.parse(a)) == resolver.canonical(resolver.parse(b)))
    check("siblings: simulation equal", sim.simulate(a) == sim.simulate(b))
    # 2. determinism: identical runs, identical compile json
    r = "fire3{burn:[electric3{chain:[ice2]}]}"
    check("determinism: simulate twice", sim.simulate(r) == sim.simulate(r))
    j1 = json.dumps(resolver.compile_recipe(r).to_json(), sort_keys=True)
    j2 = json.dumps(resolver.compile_recipe(r).to_json(), sort_keys=True)
    check("determinism: compile json", j1 == j2)
    # 3. nesting changes behaviour: Yanma <- (Elektrik <- Buz) != Yanma <- Elektrik
    n1 = sim.simulate("fire3{burn:[electric3{chain:[ice2]}]}")
    n2 = sim.simulate("fire3{burn:[electric3]}")
    check("nesting differs (slow only when nested)", stat(n1, "statuses.slow") > 0 and stat(n2, "statuses.slow") == 0)
    # 4. no locked ability leaks: every donor op belongs to an ability open at the donor's grade
    leaks = []
    for rid, rr in SPEC["runes"].items():
        for g in range(1, 6):
            c = resolver.compile_recipe(f"stone1{{stone_hit:[{rid}{g}]}}")
            for o in resolver._walk(c.ops):
                if o.depth == 1:
                    for ab in o.abilities:
                        if rr["ability_by_id"][ab]["grade"] > g:
                            leaks.append(f"{rid}{g}:{ab}")
    check("no locked ability leaks from donors (60 donors)", not leaks, ", ".join(leaks))
    # 5. every rune: hit + at least 2 abilities; stats grow every grade
    for rid, rr in SPEC["runes"].items():
        check(f"{rid}: ≥3 abilities (hit + ≥2)", len(rr["abilities"]) >= 3, str(len(rr["abilities"])))
        for key in rr["balance"]["damage_stats"]:
            vals = [rr["grades"][str(g)].get(key) for g in range(1, 6)]
            vals = [v for v in vals if v is not None]
            check(f"{rid}.{key} grows each grade", all(b > a for a, b in zip(vals, vals[1:])), str(vals))
    # 6. cost formula example (plan §7)
    c = resolver.cost("fire3{burn:[electric3{chain:[ice1]}]}")
    check("cost example 200+200+40+46=486 mana", c["total_mana"] == 486, str(c))
    # 7. every rune G1..G5 compiles, describes, simulates
    for rid in SPEC["runes"]:
        for g in range(1, 6):
            try:
                resolver.describe(f"{rid}{g}")
                sim.simulate(f"{rid}{g}")
            except Exception as e:
                check(f"{rid}{g} runs", False, repr(e))
    check("all 60 runes compile/describe/simulate", True)
    # 8. hand-computed numbers from the plan (formula check with current stats)
    c = resolver.compile_recipe("fire3{burn:[electric1]}")
    el = [o for o in resolver._walk(c.ops) if o.family == "Damage" and o.params["element"] == "electric"][0]
    exp = resolver.grade_stats(SPEC["runes"]["electric"], 1)["hit"] * 0.7 * 0.35
    check(f"graft damage = hit×0.7×0.35 ({exp:.2f})", abs(el.params["amount"] - exp) < 1e-9, str(el.params["amount"]))



def run_economy():
    """Mana rune economy rules (2026-10-31): lethal hits still siphon, overkill never becomes mana,
    income is soft-capped per producing Mana node, several marks crystallise once."""
    siph = resolver.grade_stats(SPEC["runes"]["mana"], 1)["siphon"]
    s = sim.simulate("mana1", hp=1, count=1)
    check("lethal hit still pays its siphon", s["mana_siphon"] > 0, str(s))
    check("siphon never pays for overkill (<= hp x siphon)", s["mana_siphon"] <= 1.0 * siph + 1e-6, str(s["mana_siphon"]))
    w = sim.World(["mana1"], count=1)
    cap = SPEC["runes"]["mana"]["grades"]["1"]["income_cap"]
    eff = SPEC["economy"]["mana_income"]["over_cap_eff"]
    g1 = w.mana_income(100.0, ("t", "x"), 1)
    g2 = w.mana_income(100.0, ("t", "x"), 1)
    check("income soft cap: first second", abs(g1 - (cap + (100 - cap) * eff)) < 1e-9, str(g1))
    check("income soft cap: same second fully over cap", abs(g2 - 100 * eff) < 1e-9, str(g2))
    caps = [SPEC["runes"]["mana"]["grades"][str(g)]["income_cap"] for g in range(1, 6)]
    check("income cap grows with grade", all(a < b for a, b in zip(caps, caps[1:])), str(caps))
    c = resolver.compile_recipe("mana5")
    mark = [o for o in resolver._walk(c.ops) if o.family == "ApplyStatus" and o.params.get("status") == "mana_mark" and o.params.get("crystal")][0]
    w = sim.World(["mana1"], count=2)
    e = w.enemies[0]
    e.st[("mana_mark", "a")] = {"op": mark, "left": 5}
    e.st[("mana_mark", "b")] = {"op": mark, "left": 5}
    before = w.stats["stones"]
    w.kill(e, sim.Ctx(gen=0, budget={"left": 16}))
    check("two crystal marks on one enemy crystallise once", w.stats["stones"] - before == 1 + int(mark.params["crystal"]), str(w.stats["stones"] - before))
    # one income cap per producing Mana node (parity findings N1-N3)
    c = resolver.compile_recipe("mana3")
    ops = list(resolver._walk(c.ops))
    sip = [o for o in ops if o.family == "ManaSiphon"][0]
    mk = [o for o in ops if o.family == "ApplyStatus" and o.params.get("status") == "mana_mark"][0]
    check("N3: siphon and mark of one Mana node share one cap", sim.mana_node_key(0, sip.uid) == sim.mana_node_key(0, mk.uid), f"{sip.uid} {mk.uid}")
    check("N1: equal recipes on two towers have separate caps", sim.mana_node_key(0, mk.uid) != sim.mana_node_key(1, mk.uid))
    c = resolver.compile_recipe("fire1{fire_hit:[mana1,mana1]}")
    sips = [o for o in resolver._walk(c.ops) if o.family == "ManaSiphon"]
    check("N2: two Mana donors are two producing nodes (two caps)", len(sips) == 2 and sim.mana_node_key(0, sips[0].uid) != sim.mana_node_key(0, sips[1].uid), str([o.uid for o in sips]))


if __name__ == "__main__":
    run_scenarios()
    run_invariants()
    run_economy()
    fails = [r for r in results if not r[1]]
    for name, ok, detail in results:
        if not ok or "-v" in sys.argv:
            print(("PASS " if ok else "FAIL ") + name + (f"   [{detail}]" if detail and not ok else ""))
    print(f"\n{len(results) - len(fails)}/{len(results)} passed")
    sys.exit(1 if fails else 0)
