"""RuneCraft rune recipe resolver: parse -> canonical -> compile -> describe -> cost.

Reference implementation of spec/rune_mechanics_v1.json. Pure stdlib, deterministic.
Recipe grammar:  rune<grade>{ability:[recipe, recipe], ability:[...]}
  e.g.  fire3{burn:[electric3{chain:[ice1]}]}

Nothing here knows about specific rune pairs: every result comes from the
generic families + the carrier compatibility table in the spec.
"""
from __future__ import annotations

import json
import math
import re
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "spec" / "rune_mechanics_v1.json"


def load_spec(path: Path = SPEC_PATH) -> dict:
    spec = json.loads(path.read_text(encoding="utf-8"))
    for rid, r in spec["runes"].items():
        r["id"] = rid
        r["ability_by_id"] = {a["id"]: a for a in r["abilities"]}
    return spec


SPEC = load_spec()
HOST_ONLY = {"SummonVolcano", "SummonGolem", "SummonHive", "MeteorCall"}
PAYLOAD = {"Damage", "ApplyStatus", "ForceMove", "CreateGroundField", "ModifyIncomingDamage", "ManaSiphon"}
PROPAGATORS = {"ChainTransfer", "Pierce", "AreaImpact", "SpawnFragments", "MultiImpact"}


class RecipeError(ValueError):
    def __init__(self, code: str, msg: str):
        super().__init__(f"{code}: {msg}")
        self.code = code


# ---------------------------------------------------------------- parse

@dataclass
class Node:
    rune: str
    grade: int
    grafts: dict = field(default_factory=dict)  # ability_id -> [Node]

    def size(self) -> int:
        return 1 + sum(c.size() for cs in self.grafts.values() for c in cs)

    def depth(self) -> int:
        return 1 + max((c.depth() for cs in self.grafts.values() for c in cs), default=0)


_TOKEN = re.compile(r"\s*([a-z_]+\d|[a-z_]+|[{}\[\]:,])")


def parse(text: str, spec: dict = SPEC) -> Node:
    toks = [m.group(1) for m in _TOKEN.finditer(text)]
    if "".join(toks) != re.sub(r"\s+", "", text):
        raise RecipeError("syntax", f"unparsable recipe: {text!r}")
    pos = 0

    def peek():
        return toks[pos] if pos < len(toks) else None

    def take(expect=None):
        nonlocal pos
        t = peek()
        if t is None or (expect and t != expect):
            raise RecipeError("syntax", f"expected {expect!r} at token {pos} in {text!r}")
        pos += 1
        return t

    def node() -> Node:
        t = take()
        m = re.fullmatch(r"([a-z_]+)(\d)", t)
        if not m:
            raise RecipeError("syntax", f"expected rune+grade, got {t!r}")
        rid, g = m.group(1), int(m.group(2))
        if rid not in spec["runes"]:
            raise RecipeError("unknown_rune", rid)
        if not 1 <= g <= 5:
            raise RecipeError("bad_grade", t)
        n = Node(rid, g)
        if peek() == "{":
            take("{")
            while peek() != "}":
                ab = take()
                take(":")
                take("[")
                kids = []
                while peek() != "]":
                    kids.append(node())
                    if peek() == ",":
                        take(",")
                take("]")
                n.grafts.setdefault(ab, []).extend(kids)
                if peek() == ",":
                    take(",")
            take("}")
        return n

    root = node()
    if pos != len(toks):
        raise RecipeError("syntax", f"trailing tokens in {text!r}")
    validate(root, spec)
    return root


def validate(n: Node, spec: dict = SPEC) -> None:
    r = spec["runes"][n.rune]
    for ab, kids in n.grafts.items():
        a = r["ability_by_id"].get(ab)
        if a is None:
            raise RecipeError("unknown_ability", f"{n.rune} has no ability {ab!r}")
        if a["grade"] > n.grade:
            raise RecipeError("locked_on_receiver",
                              f"{r['tr']} G{n.grade}: '{a['tr']}' {gde(a['grade'])} açılır")
        for k in kids:
            validate(k, spec)


def canonical(n: Node, spec: dict = SPEC) -> str:
    r = spec["runes"][n.rune]
    s = f"{n.rune}{n.grade}"
    parts = []
    for a in r["abilities"]:  # ability order = grade order, fixed by spec
        kids = n.grafts.get(a["id"])
        if kids:
            parts.append(f"{a['id']}:[{','.join(canonical(k, spec) for k in sorted_kids(kids, spec))}]")
    return s + ("{" + ",".join(parts) + "}" if parts else "")


def sorted_kids(kids, spec: dict = SPEC):
    return sorted(kids, key=lambda k: (spec["runes"][k.rune]["order"], -k.grade, canonical(k, spec)))


# ---------------------------------------------------------------- compile

@dataclass
class Op:
    uid: str
    family: str
    params: dict
    rune: str
    grade: int
    depth: int
    abilities: list            # ability ids of the source rune that use this op
    slots: dict = field(default_factory=dict)       # slot -> [Op]
    slot_meta: dict = field(default_factory=dict)   # slot -> {carrier, ability, verb}
    carrier: str = ""          # carrier where this op was attached (host: '')
    verb: str = ""             # chain verb inherited from the receiving ability

    def to_json(self) -> dict:
        return {"uid": self.uid, "family": self.family, "params": _round(self.params),
                "src": f"{self.rune}{self.grade}", "depth": self.depth, "abilities": self.abilities,
                "carrier": self.carrier,
                "slots": {k: [o.to_json() for o in v] for k, v in sorted(self.slots.items())}}


@dataclass
class Rejection:
    path: str
    donor: str
    family: str
    reason: str


@dataclass
class Compiled:
    root: Node
    canonical: str
    ops: list                  # root event list (host natives + merged event-slot grafts)
    rejected: list
    notes: list                # locked-ability notes for donors

    def to_json(self) -> dict:
        return {"canonical": self.canonical, "ops": [o.to_json() for o in self.ops],
                "rejected": [r.__dict__ for r in self.rejected], "notes": self.notes}


def grade_stats(rune: dict, g: int) -> dict:
    out = {}
    for k in range(1, g + 1):
        out.update(rune["grades"].get(str(k), {}))
    return out


def _resolve(v, stats):
    if isinstance(v, str) and v.startswith("$"):
        return stats.get(v[1:], 0)
    if isinstance(v, dict):
        return {k: _resolve(x, stats) for k, x in v.items()}
    if isinstance(v, list):
        return [_resolve(x, stats) for x in v]
    return v


def _scale(params: dict, depth: int, spec: dict) -> dict:
    c = spec["coefficients"]
    kd, kc = c["depth_damage"] ** depth, c["depth_control"] ** depth
    out = {}
    for k, v in params.items():
        if isinstance(v, (int, float)) and not isinstance(v, bool):
            if k in c["damage_params"]:
                v = v * kd
            elif k in c["control_params"]:
                v = v * kc
        elif k == "native" and isinstance(v, list):
            v = [dict(o, **_scale({kk: vv for kk, vv in o.items()}, depth, spec)) for o in v]
        out[k] = v
    return out


def _round(x):
    if isinstance(x, float):
        return round(x, 3)
    if isinstance(x, dict):
        return {k: _round(v) for k, v in x.items()}
    if isinstance(x, list):
        return [_round(v) for v in x]
    return x


def compile_recipe(recipe, spec: dict = SPEC) -> Compiled:
    root = parse(recipe, spec) if isinstance(recipe, str) else recipe
    rejected, notes = [], []
    ops = _compile_node(root, 0, 1.0, None, "", "r", rejected, notes, spec)
    return Compiled(root, canonical(root, spec), ops, rejected, notes)


def _compile_node(n: Node, depth: int, coef: float, carrier, verb: str, path: str,
                  rejected, notes, spec) -> list:
    r = spec["runes"][n.rune]
    stats = grade_stats(r, n.grade)
    open_abs = [a for a in r["abilities"] if a["grade"] <= n.grade]
    if depth > 0:
        locked = [a for a in r["abilities"] if a["grade"] > n.grade]
        if locked:
            nxt = locked[0]
            notes.append({"path": path, "text": f"✗ {r['tr']} G{n.grade}: '{nxt['tr']}' yok ({r['tr']} {gde(nxt['grade'])} açılır)"})
    # one Op per op key, in ability order
    built: dict[str, Op] = {}
    order = []
    for a in open_abs:
        for key in a["ops"]:
            if key not in built:
                d = r["ops"][key]
                params = _resolve({k: v for k, v in d.items() if k != "family"}, stats)
                params = _scale(params, depth, spec)
                if depth > 0 and d["family"] == "Damage":
                    params["amount"] = params["amount"] * coef
                op = Op(uid=f"{path}.{n.rune}{n.grade}.{key}", family=d["family"], params=params,
                        rune=n.rune, grade=n.grade, depth=depth, abilities=[], carrier=carrier or "",
                        verb=verb)
                built[key] = op
                order.append(op)
            built[key].abilities.append(a["id"])
    # compatibility filter (only for grafted contributions)
    out = []
    for op in order:
        if depth > 0:
            reason = None
            if op.family in spec["never_exported"]:
                reason = spec["never_exported"][op.family]
            elif op.family not in spec["carriers"][carrier]["allows"]:
                reason = f"{spec['family_tr'][op.family]} '{spec['carriers'][carrier]['tr']}' taşıyıcısında anlamsız (uyumsuz)"
            if reason:
                rejected.append(Rejection(path, f"{r['tr']} G{n.grade}", op.family, reason))
                continue
        out.append(op)
    kept = {id(o) for o in out}
    # attach this node's own grafts
    for a in open_abs:
        kids = n.grafts.get(a["id"])
        if not kids:
            continue
        car = a["carrier"]
        ccoef = spec["carriers"][car]["coef"]
        cverb = a.get("chain_verb") or spec["carriers"][car]["chain_verb"]
        children = []
        for i, k in enumerate(sorted_kids(kids, spec)):
            children += _compile_node(k, depth + 1, ccoef if a["slot"] != "event" or depth == 0 else coef,
                                      car, cverb, f"{path}.{a['id']}{i}", rejected, notes, spec)
        _diminish(children, depth + 1, spec)
        if a["slot"] == "event":
            out += children
        else:
            # attach to the (first kept) op of this ability
            host_ops = [built[k] for k in a["ops"] if id(built[k]) in kept]
            if not host_ops:
                continue
            tgt = host_ops[-1]
            tgt.slots.setdefault(a["slot"], []).extend(children)
            tgt.slot_meta[a["slot"]] = {"carrier": car, "ability": a["id"], "verb": cverb}
    if depth == 0 and not out:
        raise RecipeError("empty", canonical(n, spec))
    if depth > 0 and not out and n.grafts:
        pass
    return out


def _diminish(ops: list, depth: int, spec: dict) -> None:
    """Same-element grafted Damage at one event: biggest x1, next x0.5, ..."""
    mult = spec["coefficients"]["sibling_same_damage"]
    by_el: dict = {}
    for o in ops:
        if o.family == "Damage" and o.depth == depth:
            by_el.setdefault(o.params["element"], []).append(o)
    for lst in by_el.values():
        lst.sort(key=lambda o: (-o.params["amount"], o.uid))
        for i, o in enumerate(lst):
            o.params["amount"] *= mult[min(i, len(mult) - 1)]


def check_graft(host_recipe: str, ability: str, donor_recipe: str, spec: dict = SPEC):
    """Craft-table check: is the donor accepted on that slot? Returns (ok, reasons)."""
    host = parse(host_recipe, spec)
    donor = parse(donor_recipe, spec)
    r = spec["runes"][host.rune]
    a = r["ability_by_id"].get(ability)
    if a is None:
        return False, [f"unknown_ability: {ability}"]
    if a["grade"] > host.grade:
        return False, [f"locked_on_receiver: '{a['tr']}' {r['tr']} {gde(a['grade'])} açılır"]
    probe = Node(host.rune, host.grade, {ability: [donor]})
    c = compile_recipe(probe, spec)
    donor_ops = [o for o in _walk(c.ops) if o.depth == 1]
    if not donor_ops:
        return False, [f"uyumsuz: {x.reason}" for x in c.rejected] or ["uyumsuz"]
    return True, [x.reason for x in c.rejected]


def _walk(ops):
    for o in ops:
        yield o
        for v in o.slots.values():
            yield from _walk(v)


# ---------------------------------------------------------------- describe (output rune text)

def gde(g) -> str:
    """'G3'te' / 'G2'de' with Turkish vowel harmony + consonant assimilation."""
    return f"G{g}'{ {1: 'de', 2: 'de', 3: 'te', 4: 'te', 5: 'te'}[int(g)] }"


def _f(x) -> str:
    s = f"{x:.1f}" if abs(x - round(x)) > 1e-6 else f"{int(round(x))}"
    return s.replace(".", ",")


def _pct(x) -> str:
    return _f(x * 100)


def op_text(o: Op, spec: dict = SPEC) -> str:
    p, el = o.params, spec["element_tr"]
    f = o.family
    if f == "Damage":
        return f"{_f(p['amount'])} {el[p['element']]} hasarı"
    if f == "ApplyStatus":
        s = p["status"]
        if s == "burn":
            t = f"yanma {_f(p['dps'])}/sn × {_f(p['dur'])} sn"
            if p.get("trail_dps"):
                t += f", arkasında ateş izi {_f(p['trail_dps'])}/sn ({_f(p['trail_dur'])} sn)"
            return t
        if s == "slow":
            return f"%{_pct(p['pct'])} yavaşlatma ({_f(p['dur'])} sn)"
        if s == "cold":
            t = f"{_f(p['threshold'])} soğukta {_f(p['freeze'])} sn donma"
            if p.get("shards"):
                t += f", donmuş ölümde {_f(p['shards'])} parça × {_f(p['shard_dmg'])}"
            if p.get("nova_r"):
                t += f", donunca {_f(p['nova_r'])} karo çevre de donar"
            return t
        if s == "charge":
            return f"{_f(p['max'])} yükte boşalma +{_f(p['burst'])} elektrik, {_f(p['stun'])} sn şok"
        if s == "poison":
            t = f"zehir {_f(p['dps'])}/sn × {_f(p['dur'])} sn"
            if p.get("max_stacks", 1) > 1:
                t += f", {_f(p['max_stacks'])} yığına kadar"
            if p.get("heal_supp"):
                t += f", iyileşme −%{_pct(p['heal_supp'])}"
            if p.get("contagion"):
                t += f", ölünce %{_pct(p['contagion'])} bulaşma"
            return t
        if s == "wet":
            return f"ıslaklık {_f(p['dur'])} sn"
        if s == "shred":
            return f"zırh −%{_pct(p['pct'])} ({_f(p['dur'])} sn)"
        if s == "blind":
            return f"kamaşma {_f(p['dur'])} sn"
        if s == "lit":
            return f"aydınlatma: +%{_pct(p['pct'])} alınan hasar ({_f(p['dur'])} sn)"
        if s == "mana_mark":
            t = f"mana işareti {_f(p['dur'])} sn: {_f(p['r'])} karo çevresindeki hasarın %{_pct(p['mark_pct'])}'i mana"
            if p.get("crystal"):
                t += f", ölünce +{_f(p['crystal'])} mana taşı"
            return t
        if s == "stun":
            return f"{_f(p['dur'])} sn sersemletme"
        if s == "bleed":
            t = f"kanama {_f(p['per_tile'])}/karo ({_f(p['dur'])} sn)"
            if p.get("max_int", 1) > 1:
                t += f", yoğunluk {_f(p['max_int'])} kata kadar"
            if p.get("rupture"):
                t += f", tavanda yırtılma {_f(p['rupture'])}"
            return t
        return s
    if f == "ForceMove":
        return f"{_f(p['dist'])} karo geri itiş"
    if f == "ManaSiphon":
        return f"bu olaydaki hasarın %{_pct(p['siphon'])}'i mana"
    if f == "ChainTransfer":
        return f"{o.verb or 'seker'}: {_f(p['hops'])} hedef (her sekmede ×{_f(p['power'])})"
    if f == "Pierce":
        return f"{_f(p['n'])} hedef delme (×{_f(p['power'])})"
    if f == "AreaImpact":
        return f"{_f(p['r'])} karo alan (%{_pct(p['frac'])})"
    if f == "SpawnFragments":
        return f"{_f(p['n'])} parça (%{_pct(p['frac'])})"
    if f == "MultiImpact":
        return f"{_f(p['n'])} küçük meteor (%{_pct(p['frac'])})"
    if f == "CreateGroundField":
        nat = ", ".join(op_text(Op("", x["family"], x, o.rune, o.grade, o.depth, []), spec) for x in p.get("native", []))
        kind = {"lava_pool": "lav birikintisi"}.get(p["kind"], p["kind"])
        return f"{kind} {_f(p['dur'])} sn ({nat}/sn)"
    if f == "ModifyIncomingDamage":
        return f"golem %{_pct(p['pct'])} az hasar alır"
    return f


def describe(recipe, spec: dict = SPEC) -> str:
    """Text shown on the OUTPUT rune after crafting (no preview before)."""
    c = recipe if isinstance(recipe, Compiled) else compile_recipe(recipe, spec)
    n = c.root
    r = spec["runes"][n.rune]
    by_path: dict = {}
    for o in _walk(c.ops):
        by_path.setdefault(o.uid.rsplit(".", 2)[0], []).append(o)
    rej: dict = {}
    for x in c.rejected:
        rej.setdefault(x.path, []).append(x)
    notes = {x["path"]: x["text"] for x in c.notes}
    lines = [f"{r['tr']} G{n.grade}" + (f"  · {n.size() - 1} aşı, derinlik {n.depth() - 1}" if n.size() > 1 else "")]
    lines += _node_lines(n, "r", 0, by_path, rej, notes, spec)
    return "\n".join(lines)


def _tmpl(r: dict, g: int) -> dict:
    stats = grade_stats(r, g)
    t = {}
    for k, v in stats.items():
        t[k] = _f(v) if isinstance(v, (int, float)) else v
        if isinstance(v, (int, float)):
            t[k + "_pct"] = _pct(v)
    return _Default(t)


def _node_lines(n: Node, path: str, depth: int, by_path, rej, notes, spec) -> list:
    r = spec["runes"][n.rune]
    out = []
    ind = "    " * depth
    if depth == 0:
        t = _tmpl(r, n.grade)
        for a in r["abilities"]:
            if a["grade"] > n.grade:
                out.append(f"  🔒 {a['tr']} ({gde(a['grade'])} açılır)")
                continue
            out.append(f"• {a['tr']}: {a['desc_tr'].format_map(t)}")
            out += _kid_lines(n, a, path, depth, by_path, rej, notes, spec)
        return out
    return out


def _kid_lines(n: Node, a: dict, path: str, depth: int, by_path, rej, notes, spec) -> list:
    out = []
    kids = n.grafts.get(a["id"], [])
    car = spec["carriers"][a["carrier"]]["tr"]
    ind = "    " * (depth + 1)
    for i, k in enumerate(sorted_kids(kids, spec)):
        kp = f"{path}.{a['id']}{i}"
        kr = spec["runes"][k.rune]
        own = [o for o in by_path.get(kp, []) if o.depth == depth + 1]
        body = "; ".join(op_text(o, spec) for o in own) or "katkı yok"
        out.append(f"{ind}↳ {kr['tr']} G{k.grade} — {car}: {body}")
        for x in rej.get(kp, []):
            out.append(f"{ind}    ✗ {spec['family_tr'][x.family]} taşınmadı: {x.reason}")
        if kp in notes:
            out.append(f"{ind}    {notes[kp]}")
        for ka in kr["abilities"]:
            if ka["grade"] <= k.grade and k.grafts.get(ka["id"]):
                out.append(f"{ind}    [{kr['tr']} · {ka['tr']}]")
                out += _kid_lines(k, ka, kp, depth + 1, by_path, rej, notes, spec)
    return out


class _Default(dict):
    def __missing__(self, k):
        return "?"


# ---------------------------------------------------------------- cost

def rune_value(rid: str, g: int, spec: dict = SPEC) -> float:
    e = spec["economy"]
    v = e["rune_buy_g1_mana"][spec["runes"][rid]["buy"]]
    for k in range(2, g + 1):
        v = 2 * v + e["combine"]["fee_mana_per_target_grade_minus_1"] * (k - 1)
    return v


def graft_fee(n_after: int) -> float:
    return 20 * 1.3 ** (n_after - 2)


def cost(recipe, spec: dict = SPEC) -> dict:
    root = parse(recipe, spec) if isinstance(recipe, str) else recipe

    def build(n: Node):
        runes = rune_value(n.rune, n.grade, spec)
        fees, size, steps = 0.0, 1, 0
        r = spec["runes"][n.rune]
        for a in r["abilities"]:
            for k in sorted_kids(n.grafts.get(a["id"], []), spec):
                kr, kf, ks, kst = build(k)
                runes += kr
                fees += kf
                size += ks
                steps += kst + 1
                fees += graft_fee(size)
        return runes, fees, size, steps

    runes, fees, size, steps = build(root)
    return {"runes_mana": round(runes), "graft_fees_mana": round(fees), "total_mana": round(runes + fees),
            "mana_stone": 0, "nodes": size, "graft_steps": steps,
            "note": "Rünler mana ile alınır ve birleştirilir; kuleler mana taşıyla kurulur."}


if __name__ == "__main__":
    import sys
    rec = sys.argv[1] if len(sys.argv) > 1 else "fire3{burn:[electric3{chain:[ice1]}]}"
    c = compile_recipe(rec)
    print(c.canonical)
    print(describe(c))
    print(cost(rec))
