"""Deterministic 1D-path combat simulation for compiled rune recipes.

The path is the x axis (tiles); enemies walk +x. Towers stand beside the path.
Every behaviour is a generic family handler driven by the compiled op lists from
resolver.compile_recipe -- there is no rune-pair code anywhere in this file.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

from resolver import SPEC, HOST_ONLY, PAYLOAD, PROPAGATORS, compile_recipe

REF = SPEC["reference"]
BUD = SPEC["budgets"]
INTER = {i["id"]: i for i in SPEC["interactions"]}


# ---------------------------------------------------------------- world objects

@dataclass
class Enemy:
    id: int
    x: float
    hp: float
    max_hp: float
    alive: bool = True
    leaked: bool = False
    st: dict = field(default_factory=dict)      # (status, uid) -> dict
    frozen_until: float = -1.0
    frozen_by: object = None
    stun_until: float = -1.0
    stun_icd: dict = field(default_factory=dict)

    def has(self, status: str) -> bool:
        return any(k[0] == status for k in self.st)

    def get(self, status: str):
        return [v for k, v in self.st.items() if k[0] == status]


@dataclass
class Field:
    x: float
    r: float
    left: float
    native: list
    subs: list
    gen: int
    kind: str
    tower: int
    next_tick: float = 0.0


@dataclass
class Ctx:
    gen: int
    budget: dict
    power: float = 1.0
    carried: list = field(default_factory=list)   # payload carried by propagation (e.g. the ticking status)
    tag: str = "hit"
    tower: int = 0
    event_damage: float = 0.0     # damage the event itself already dealt (e.g. a DoT tick) - siphon converts it too


class World:
    def __init__(self, recipes, hp=None, count=None, tower_xs=None, seconds=None):
        w = REF["wave"]
        self.t = 0.0
        self.dt = REF["dt"]
        self.seconds = seconds or REF["sim_seconds"]
        hp = hp or w["hp"]
        n = count or w["count"]
        self.enemies = [Enemy(i, -i * w["spacing_tiles"], hp, hp) for i in range(n)]
        self.fields: list[Field] = []
        self.timers = []          # (time, seq, fn)
        self._seq = 0
        self.towers = []
        tower_xs = tower_xs or [6.0 + 0.0 * i for i in range(len(recipes))]
        for i, rec in enumerate(recipes):
            c = compile_recipe(rec)
            self.towers.append(Tower(self, i, tower_xs[i], c))
        s = self.stats = {
            "damage": 0.0, "damage_capped": 0.0, "by_element": {}, "by_cause": {}, "by_tower": {},
            "kills": 0, "leaked": 0, "hops": {}, "max_gen": 0, "max_budget_used": 0,
            "applications": 0, "frozen": 0, "nova_frozen": 0, "pushed_tiles": 0.0,
            "bleed_walk": 0.0, "bleed_forced": 0.0, "fields": {}, "fields_from": {},
            "statuses": {}, "summons": {}, "shards": 0, "contagion": 0, "discharges": 0,
            "ruptures": 0, "max_beetles": 0, "spread_status": 0, "rejected_events": 0,
            "mana": 0.0, "mana_siphon": 0.0, "mana_mark": 0.0, "stones": 0,
        }
        s["first_kill"] = None
        s["clear_time"] = None
        self._income = {}      # mana income soft cap: source -> [second, amount]

    # -- scheduling
    def later(self, delay, fn):
        self._seq += 1
        self.timers.append((self.t + delay, self._seq, fn))

    def alive(self):
        return [e for e in self.enemies if e.alive and not e.leaked]

    def nearest(self, x, exclude=(), within=99.0, prefer=None):
        best = None
        for e in self.alive():
            if e.id in exclude:
                continue
            d = abs(e.x - x)
            if d > within:
                continue
            key = (0 if prefer and e.has(prefer) else 1, d, e.id)
            if best is None or key < best[0]:
                best = (key, e)
        return best[1] if best else None

    # -- main loop
    def run(self):
        steps = int(round(self.seconds / self.dt))
        for _ in range(steps):
            self.step()
            if not self.alive() and self.stats["clear_time"] is None:
                self.stats["clear_time"] = round(self.t, 2)
                break
        return self.stats

    def step(self):
        dt = self.dt
        self.t += dt
        # timers
        due = sorted([x for x in self.timers if x[0] <= self.t + 1e-9])
        self.timers = [x for x in self.timers if x[0] > self.t + 1e-9]
        for _, _, fn in due:
            fn()
        # enemies: statuses + movement
        for e in list(self.alive()):
            self.tick_statuses(e, dt)
            if not e.alive:
                continue
            spd = REF["wave"]["speed_tiles_s"]
            if self.t < e.frozen_until or self.t < e.stun_until:
                spd = 0.0
            else:
                slow = max([v["pct"] for v in e.get("slow")] + [0.0])
                spd *= max(0.2, 1.0 - slow)
            if spd > 0:
                self.move(e, spd * dt, forced=False)
            if e.x > 18.0 and e.alive:
                e.leaked = True
                self.stats["leaked"] += 1
        # fields (overlapping fields of the same kind+tower do not stack: one hit per enemy per tick)
        touched = set()
        for f in list(self.fields):
            f.left -= dt
            if f.left <= 0:
                self.fields.remove(f)
                continue
            if f.kind == "whirlpool":
                pass
            if self.t + 1e-9 >= f.next_tick:
                f.next_tick = self.t + REF["field_tick_s"]
                for e in self.alive():
                    if abs(e.x - f.x) <= f.r and (e.id, f.kind, f.tower) not in touched:
                        touched.add((e.id, f.kind, f.tower))
                        ctx = Ctx(gen=f.gen, budget={"left": BUD["applications_per_root_event"]}, tag="field", tower=f.tower)
                        self.run_event(f.native + f.subs, e, e.x, ctx, carrier="field")
        # towers
        for tw in self.towers:
            tw.update(dt)

    # -- core: one event at one target
    def run_event(self, ops, target, pos, ctx: Ctx, carrier="hit"):
        payload = [o for o in ops if o.family in PAYLOAD]
        props = [o for o in ops if o.family in PROPAGATORS]
        self.stats["max_gen"] = max(self.stats["max_gen"], ctx.gen)
        if target is not None:
            self.apply_payload(payload, target, ctx)
        if ctx.gen < BUD["max_generation"]:
            carry = [o for o in payload if o.family != "CreateGroundField"] + ctx.carried
            for p in props:
                self.propagate(p, carry, target, pos, ctx)
        used = BUD["applications_per_root_event"] - ctx.budget["left"]
        self.stats["max_budget_used"] = max(self.stats["max_budget_used"], used)

    def apply_payload(self, payload, e: Enemy, ctx: Ctx, carried_status_ops=()):
        if not e.alive or ctx.budget["left"] <= 0:
            if ctx.budget["left"] <= 0:
                self.stats["rejected_events"] += 1
            return
        ctx.budget["left"] -= 1
        self.stats["applications"] += 1
        order = {"Damage": 0, "ApplyStatus": 1, "CreateGroundField": 2, "ForceMove": 3, "ModifyIncomingDamage": 4, "ManaSiphon": 5}
        before = self.stats["damage_capped"]
        for o in sorted(payload, key=lambda o: order[o.family]):
            if not e.alive:
                break          # a lethal hit still pays its siphon below (matches the Godot runtime)
            f = o.family
            if f == "Damage":
                self.deal(e, o.params["amount"] * ctx.power, o.params["element"], ctx, cause=o.uid)
            elif f == "ApplyStatus":
                self.apply_status(e, o, ctx)
            elif f == "CreateGroundField":
                self.make_field(e.x, o, ctx)
            elif f == "ForceMove":
                self.push(e, o, ctx)
        siphons = [o for o in payload if o.family == "ManaSiphon"]
        if siphons:
            siph = sum(o.params["siphon"] for o in siphons)
            raw = (self.stats["damage_capped"] - before + ctx.event_damage) * siph   # overkill never becomes mana
            src = siphons[0]
            gained = self.mana_income(raw, (ctx.tower, src.uid), src.grade)
            self.stats["mana"] += gained
            self.stats["mana_siphon"] += gained

    def mana_income(self, amount, src, grade):
        """Soft cap per producing Mana node: above income_cap mana/s only over_cap_eff of the excess counts."""
        if amount <= 0:
            return 0.0
        cap = SPEC["runes"]["mana"]["grades"][str(max(1, min(5, grade)))].get("income_cap", 1e9)
        eff = SPEC["economy"].get("mana_income", {}).get("over_cap_eff", 0.25)
        sec = int(self.t)
        b = self._income.get(src)
        if b is None or b[0] != sec:
            b = [sec, 0.0]
        room = max(0.0, cap - b[1])
        gained = min(amount, room) + max(0.0, amount - room) * eff
        b[1] += amount
        self._income[src] = b
        return gained

    # -- damage
    def deal(self, e: Enemy, amount, element, ctx: Ctx, cause=""):
        if not e.alive or amount <= 0:
            return
        armor = REF["wave"]["armor_pct"] - sum(v["pct"] for v in e.get("shred"))
        amount *= 1.0 - max(0.0, armor)
        for v in e.get("lit"):
            amount *= 1.0 + v["pct"]
        if element == "electric" and e.has("wet"):
            amount *= INTER["wet_conducts"]["effect"]["damage_mult"]
        s = self.stats
        real = min(amount, e.hp)
        s["damage"] += amount
        s["damage_capped"] += real
        marks = [v for m in self.alive() for k, v in m.st.items()
                 if k[0] == "mana_mark" and abs(m.x - e.x) <= v["op"].params["r"]]
        if marks:
            best = max(marks, key=lambda v: v["op"].params["mark_pct"])
            g = self.mana_income(real * best["op"].params["mark_pct"], ("mark", best["op"].uid), best["op"].grade)
            s["mana"] += g
            s["mana_mark"] += g
        s["by_element"][element] = s["by_element"].get(element, 0) + amount
        s["by_tower"][ctx.tower] = s["by_tower"].get(ctx.tower, 0) + amount
        ck = cause.split(".")[-1] if cause else "?"
        s["by_cause"][ck] = s["by_cause"].get(ck, 0) + amount
        e.hp -= amount
        if e.hp <= 0:
            self.kill(e, ctx)

    def kill(self, e: Enemy, ctx: Ctx):
        e.alive = False
        self.stats["kills"] += 1
        self.stats["stones"] += 1
        self.stats["mana"] += SPEC["economy"]["mana_per_kill"]
        crystal_marks = [v for v in e.get("mana_mark") if v["op"].params.get("crystal")]
        if crystal_marks:      # several marks on one enemy still crystallise once (the best one)
            v = max(crystal_marks, key=lambda v: v["op"].params["crystal"])
            self.stats["stones"] += int(v["op"].params["crystal"])
            subs = v["op"].slots.get("crystal", [])
            tgt = self.nearest(e.x, exclude={e.id}, within=1.0)
            if subs and tgt is not None:
                self.run_event(subs, tgt, tgt.x, Ctx(gen=1, budget={"left": BUD["applications_per_root_event"]}, tower=ctx.tower), carrier="death")
        if self.stats["first_kill"] is None:
            self.stats["first_kill"] = round(self.t, 2)
        root = Ctx(gen=0, budget={"left": BUD["applications_per_root_event"]}, tag="death", tower=ctx.tower)
        # frozen death shards (source authority: the freezing op must carry shards)
        if self.t < e.frozen_until and e.frozen_by is not None and e.frozen_by.params.get("shards"):
            op = e.frozen_by
            self.stats["shards"] += 1
            subs = op.slots.get("shards", [])
            seek = any(s.family == "ChainTransfer" for s in subs)
            hit = set()
            for i in range(int(op.params["shards"])):
                tgt = self.nearest(e.x, exclude=hit | {e.id}, within=1.5 if seek else 0.6)
                if tgt is None:
                    break
                hit.add(tgt.id)
                c = Ctx(gen=1, budget=root.budget, tag="shard", tower=ctx.tower)
                self.deal(tgt, op.params["shard_dmg"], "ice", c, cause="shard")
                self.run_event(subs, tgt, tgt.x, c, carrier="retarget")
                self._hop("buz parçası " + ("hedef arayıp seker" if seek else "düşer"))
        # poison contagion
        for v in e.get("poison"):
            if v["op"].params.get("contagion"):
                tgt = self.nearest(e.x, exclude={e.id}, within=1.5)
                if tgt is not None:
                    self.stats["contagion"] += 1
                    stacks = max(1, math.ceil(v["stacks"] * v["op"].params["contagion"]))
                    self.apply_status(tgt, v["op"], Ctx(gen=1, budget=root.budget, tower=ctx.tower), stacks=stacks)
                    self.run_event(v["op"].slots.get("infect", []), tgt, tgt.x, Ctx(gen=1, budget=root.budget, tower=ctx.tower), carrier="death")

    # -- statuses
    def apply_status(self, e: Enemy, o, ctx: Ctx, stacks=1):
        p, s = o.params, o.params["status"]
        key = (s, o.uid)
        self.stats["statuses"][s] = self.stats["statuses"].get(s, 0) + 1
        if ctx.gen > 0:
            self.stats["spread_status"] += 1
        cur = e.st.get(key)
        if s == "burn":
            dur = p["dur"]
            if e.has("wet"):
                dur *= INTER["wet_douses_burn"]["effect"]["duration_mult"]
                for k in [k for k in e.st if k[0] == "wet"]:
                    del e.st[k]
            if cur:
                cur["left"] = max(cur["left"], dur)
                cur["dps"] = max(cur["dps"], p["dps"])
                cur["gen"] = min(cur["gen"], ctx.gen)
            else:
                e.st[key] = {"op": o, "dps": p["dps"], "left": dur, "next": 1.0, "gen": ctx.gen,
                             "last_drop": e.x, "tower": ctx.tower}
        elif s == "mana_mark":
            e.st[key] = {"op": o, "left": p["dur"]}
            subs = o.slots.get("mark", [])
            if subs:
                self.run_event(subs, e, e.x, Ctx(gen=ctx.gen, budget=ctx.budget, tag="apply", tower=ctx.tower), carrier="status_apply")
        elif s in ("slow", "wet", "shred", "blind", "lit"):
            e.st[key] = {"op": o, "pct": p.get("pct", 0.0), "left": p["dur"]}
            subs = o.slots.get("apply", []) + o.slots.get("lit", [])
            if subs:
                self.run_event(subs, e, e.x, Ctx(gen=ctx.gen, budget=ctx.budget, tag="apply", tower=ctx.tower), carrier="status_apply")
        elif s == "stun":
            if self.t >= e.stun_icd.get(o.uid, -1):
                e.stun_until = max(e.stun_until, self.t + p["dur"])
                e.stun_icd[o.uid] = self.t + p.get("icd", 0)
                subs = o.slots.get("stun", [])
                if subs:
                    self.run_event(subs, e, e.x, Ctx(gen=ctx.gen, budget=ctx.budget, tower=ctx.tower), carrier="status_apply")
        elif s == "cold":
            v = cur or e.st.setdefault(key, {"op": o, "stacks": 0, "left": 4.0})
            v["stacks"] += p["per_hit"]
            v["left"] = 4.0
            thr = p["threshold"] - (INTER["wet_freezes_faster"]["effect"]["threshold_minus"] if e.has("wet") else 0)
            if p.get("freeze") and v["stacks"] >= max(1, thr):
                v["stacks"] = 0
                self.freeze(e, o, p["freeze"], ctx)
                if p.get("nova_r"):
                    for n in self.alive():
                        if n.id != e.id and abs(n.x - e.x) <= p["nova_r"]:
                            self.stats["nova_frozen"] += 1
                            self.freeze(n, o, p["freeze"] * 0.5, ctx, nova=True)
                            nsubs = o.slots.get("nova", [])
                            if nsubs:
                                self.run_event(nsubs, n, n.x, Ctx(gen=ctx.gen, budget=ctx.budget, tower=ctx.tower), carrier="impact_area")
        elif s == "charge":
            v = cur or e.st.setdefault(key, {"op": o, "stacks": 0, "left": 4.0})
            v["stacks"] += 1
            v["left"] = 4.0
            if v["stacks"] >= p["max"]:
                v["stacks"] = 0
                self.stats["discharges"] += 1
                self.deal(e, p["burst"], "electric", ctx, cause="discharge")
                if e.alive and p.get("stun"):
                    e.stun_until = max(e.stun_until, self.t + p["stun"])
                subs = o.slots.get("discharge", [])
                if subs and e.alive:
                    self.run_event(subs, e, e.x, Ctx(gen=ctx.gen, budget=ctx.budget, tower=ctx.tower), carrier="threshold")
        elif s == "poison":
            mx = int(p.get("max_stacks", 1))
            if cur:
                was = cur["stacks"]
                cur["stacks"] = min(mx, cur["stacks"] + stacks)
                cur["left"] = p["dur"]
                if mx > 1 and was < mx <= cur["stacks"]:
                    subs = o.slots.get("threshold", [])
                    if subs:
                        self.run_event(subs, e, e.x, Ctx(gen=ctx.gen, budget=ctx.budget, tower=ctx.tower), carrier="threshold")
            else:
                e.st[key] = {"op": o, "stacks": min(mx, stacks), "left": p["dur"], "next": 1.0, "gen": ctx.gen, "tower": ctx.tower}
        elif s == "bleed":
            mx = int(p.get("max_int", 1))
            if cur:
                was = cur["int"]
                cur["int"] = min(mx, cur["int"] + 1)
                cur["left"] = p["dur"]
                if mx > 1 and was < mx <= cur["int"]:
                    subs = o.slots.get("threshold", [])
                    if subs:
                        self.run_event(subs, e, e.x, Ctx(gen=ctx.gen, budget=ctx.budget, tower=ctx.tower), carrier="threshold")
                    if p.get("rupture"):
                        self.stats["ruptures"] += 1
                        cur["int"] = 1
                        self.deal(e, p["rupture"], "blood", ctx, cause="rupture")
                        rs = o.slots.get("rupture", [])
                        if rs and e.alive:
                            self.run_event(rs, e, e.x, Ctx(gen=ctx.gen, budget=ctx.budget, tower=ctx.tower), carrier="impact_hit")
            else:
                e.st[key] = {"op": o, "int": 1, "left": p["dur"], "acc": 0.0, "gen": ctx.gen, "tower": ctx.tower}

    def freeze(self, e: Enemy, o, dur, ctx: Ctx, nova=False):
        e.frozen_until = max(e.frozen_until, self.t + dur)
        e.frozen_by = o
        self.stats["frozen"] += 1
        subs = o.slots.get("freeze", [])
        if subs and not nova:
            self.run_event(subs, e, e.x, Ctx(gen=ctx.gen, budget=ctx.budget, tag="freeze", tower=ctx.tower), carrier="threshold")

    def tick_statuses(self, e: Enemy, dt):
        for key in list(e.st.keys()):
            if key not in e.st:
                continue
            v = e.st[key]
            v["left"] -= dt
            s = key[0]
            if s in ("burn", "poison"):
                v["next"] -= dt
                if v["next"] <= 1e-9 and v["left"] > -dt:
                    v["next"] += REF["tick_s"]
                    op = v["op"]
                    if s == "burn":
                        dmg, el = v["dps"], "fire"
                    else:
                        dmg, el = op.params["dps"] * (1 + op.params.get("stack_bonus", 0.5) * (v["stacks"] - 1)), "poison"
                    # a status instance propagates at most once (its first tick); later ticks only pay out
                    gen = v["gen"] if not v.get("spread") else BUD["max_generation"]
                    v["spread"] = True
                    root = Ctx(gen=gen, budget={"left": BUD["applications_per_root_event"]}, tag="tick",
                               carried=[op], tower=v["tower"])
                    d0 = self.stats["damage"]
                    self.deal(e, dmg, el, root, cause=f"{s}_tick")
                    root.event_damage = self.stats["damage"] - d0
                    if e.alive:
                        self.run_event(op.slots.get("tick", []), e, e.x, root, carrier="dot_tick")
                    if not e.alive:
                        return
            if v["left"] <= 0 and key in e.st:
                del e.st[key]

    # -- movement
    def move(self, e: Enemy, dist, forced: bool, ctx=None):
        e.x += dist if not forced else -dist
        for key, v in list(e.st.items()):
            if key[0] == "bleed" and e.alive:
                p = v["op"].params
                dmg = p["per_tile"] * dist * (1 + p.get("int_step", 0.25) * (v["int"] - 1))
                self.stats["bleed_forced" if forced else "bleed_walk"] += dmg
                c = Ctx(gen=v["gen"], budget={"left": BUD["applications_per_root_event"]}, tag="move", tower=v["tower"])
                self.deal(e, dmg, "blood", c, cause="bleed_move")
                v["acc"] += dist
                while v["acc"] >= 1.0 and e.alive:
                    v["acc"] -= 1.0
                    subs = v["op"].slots.get("move", [])
                    if subs:
                        self.run_event(subs, e, e.x, c, carrier="movement")
            if key[0] == "burn" and e.alive and not forced:
                p = v["op"].params
                if p.get("trail_dps") and abs(e.x - v["last_drop"]) >= p.get("trail_r", 0.35):
                    v["last_drop"] = e.x
                    self.add_field(Field(e.x - 0.15, p["trail_r"], p["trail_dur"],
                                         [_dmg_op(p["trail_dps"], "fire", "trail")], v["op"].slots.get("trail", []),
                                         v["gen"], "fire_trail", v["tower"], next_tick=self.t + 0.3), "burn")

    def push(self, e: Enemy, o, ctx: Ctx):
        d = o.params["dist"] * min(1.0, ctx.power)
        if e.has("burn"):
            d *= INTER["burning_push"]["effect"]["dist_mult"]
        if self.t < e.frozen_until:
            d *= INTER["frozen_pushed_short"]["effect"]["dist_mult"]
        self.stats["pushed_tiles"] += d
        self.move(e, d, forced=True, ctx=ctx)
        subs = o.slots.get("push", [])
        if subs and e.alive:
            self.run_event(subs, e, e.x, Ctx(gen=ctx.gen, budget=ctx.budget, tower=ctx.tower), carrier="forced_move")

    # -- fields
    def make_field(self, x, o, ctx: Ctx):
        p = o.params
        nat = [_inline_op(n, o) for n in p.get("native", [])]
        self.add_field(Field(x, p["r"], p["dur"], nat, o.slots.get("field", []), ctx.gen, p["kind"], ctx.tower,
                             next_tick=self.t), "hit")

    def add_field(self, f: Field, origin: str):
        mine = [x for x in self.fields if x.tower == f.tower]
        if len(mine) >= BUD["fields_per_tower"]:
            self.fields.remove(mine[0])
        self.fields.append(f)
        self.stats["fields"][f.kind] = self.stats["fields"].get(f.kind, 0) + 1
        self.stats["fields_from"][origin] = self.stats["fields_from"].get(origin, 0) + 1

    # -- propagators (carry the event payload to new targets)
    def propagate(self, p, carry, target, pos, ctx: Ctx):
        fam, P = p.family, p.params
        visited = {target.id} if target else set()
        nxt = lambda power: Ctx(gen=ctx.gen + 1, budget=ctx.budget, power=power, tower=ctx.tower)
        if fam == "ChainTransfer":
            cur = target
            for k in range(1, int(P["hops"]) + 1):
                if cur is None:
                    break
                rng = BUD["chain_range_tiles"] * (INTER["wet_conducts"]["effect"]["chain_range_mult"] if cur.has("wet") else 1)
                n = self.nearest(cur.x, exclude=visited, within=rng, prefer="wet")
                if n is None:
                    break
                visited.add(n.id)
                c = nxt(ctx.power * P["power"] ** k)
                self.apply_payload(carry, n, c)
                self.run_event(p.slots.get("jump", []), n, n.x, c, carrier="retarget")
                self._hop(p.verb or "seker")
                cur = n
        elif fam == "Pierce":
            for k in range(1, int(P["n"]) + 1):
                n = self.nearest(target.x if target else pos, exclude=visited, within=0.9)
                if n is None:
                    break
                visited.add(n.id)
                c = nxt(ctx.power * P["power"] ** k)
                self.apply_payload(carry, n, c)
                self.run_event(p.slots.get("pierce", []), n, n.x, c, carrier="retarget")
                self._hop("ışın deler")
        elif fam == "AreaImpact":
            # carried payload hits the others; the area's own grafts hit everyone inside (main target too)
            c = nxt(ctx.power * P["frac"])
            for n in self.alive():
                if abs(n.x - pos) > P["r"] and n.id not in visited:
                    continue
                if n.id not in visited:
                    self.apply_payload(carry, n, c)
                self.run_event(p.slots.get("area", []), n, n.x, c, carrier="impact_area")
        elif fam == "SpawnFragments":
            for i in range(int(P["n"])):
                n = self.nearest(pos, exclude=visited, within=1.0)
                if n is None:
                    break
                visited.add(n.id)
                c = nxt(ctx.power * P["frac"])
                self.apply_payload(carry, n, c)
                self.run_event(p.slots.get("fragment", []), n, n.x, c, carrier="retarget")
                self._hop("parça")
        elif fam == "MultiImpact":
            for i in range(int(P["n"])):
                px = pos + P["spread"] * (1 if i % 2 == 0 else -1) * (1 + i // 2)
                n = self.nearest(px, exclude=visited, within=0.35)
                if n is None:
                    continue
                visited.add(n.id)
                c = nxt(ctx.power * P["frac"])
                self.apply_payload(carry, n, c)
                self.run_event(p.slots.get("mini", []), n, n.x, c, carrier="impact_hit")

    def _hop(self, verb):
        self.stats["hops"][verb] = self.stats["hops"].get(verb, 0) + 1


def _dmg_op(amount, element, tag):
    from resolver import Op
    return Op(uid=f"native.{tag}", family="Damage", params={"amount": amount, "element": element},
              rune="native", grade=0, depth=0, abilities=[])


def _inline_op(d, parent):
    from resolver import Op
    return Op(uid=f"{parent.uid}.native.{d['family']}", family=d["family"],
              params={k: v for k, v in d.items() if k != "family"}, rune=parent.rune, grade=parent.grade,
              depth=parent.depth, abilities=[])


# ---------------------------------------------------------------- towers (host runtimes)

class Tower:
    def __init__(self, world: World, tid: int, x: float, c):
        self.w, self.id, self.x, self.c = world, tid, x, c
        self.rune = SPEC["runes"][c.root.rune]
        self.kind = self.rune["kind"]
        self.hit_ops = [o for o in c.ops if o.family not in HOST_ONLY and o.family != "ModifyIncomingDamage"]
        self.summon = next((o for o in c.ops if o.family in HOST_ONLY), None)
        self.timer = 0.3
        self.entity = None
        self.beetles = []
        self.verb_tag = self.kind
        self.target = None

    def pick(self):
        """Sticky 'first' targeting: keep the current target while it stays in range."""
        tg = self.in_range()
        if self.target is not None and self.target in tg:
            return self.target
        self.target = tg[0] if tg else None
        return self.target

    def in_range(self):
        r = REF["tower_range_tiles"]
        off = REF["tower_offset_from_path_tiles"]
        es = [e for e in self.w.alive() if math.hypot(e.x - self.x, off) <= r]
        return sorted(es, key=lambda e: (-e.x, e.id))

    def root_ctx(self, tag="hit"):
        return Ctx(gen=0, budget={"left": BUD["applications_per_root_event"]}, tag=tag, tower=self.id)

    def update(self, dt):
        w = self.w
        self.timer -= dt
        if self.kind in ("projectile", "beam"):
            if self.timer <= 0:
                t = self.pick()
                if t is not None:
                    self.timer = self.rune.get("attack_s", REF["attack_period_s"])
                    w.run_event(self.hit_ops, t, t.x, self.root_ctx(), carrier="projectile_hit")
        elif self.kind == "meteor":
            P = self.summon.params
            if self.timer <= 0:
                t = self.pick()
                if t is not None:
                    self.timer = P["period"]
                    land = t.x + REF["wave"]["speed_tiles_s"] * P["delay"] * 0.9
                    w.stats["summons"]["meteor"] = w.stats["summons"].get("meteor", 0) + 1

                    def impact(land=land):
                        n = w.nearest(land, within=0.35)
                        w.run_event(self.hit_ops, n, land, self.root_ctx(), carrier="impact_hit")
                    w.later(P["delay"], impact)
        elif self.kind == "volcano":
            self.update_volcano(dt)
        elif self.kind == "golem":
            self.update_golem(dt)
        elif self.kind == "hive":
            self.update_hive(dt)

    # volcano: a mountain spouting lava blobs around itself
    def update_volcano(self, dt):
        w, P = self.w, self.summon.params
        v = self.entity
        if v is None:
            if self.timer <= 0:
                tg = self.in_range()
                if tg:
                    self.entity = {"x": tg[0].x + 1.0, "left": P["life"], "next": 0.5}
                    w.stats["summons"]["volcano"] = w.stats["summons"].get("volcano", 0) + 1
            return
        v["left"] -= dt
        v["next"] -= dt
        if v["left"] <= 0:
            self.entity = None
            self.timer = 1.0
            return
        if v["next"] <= 0:
            v["next"] = P["period"]
            near = sorted([e for e in w.alive() if abs(e.x - v["x"]) <= P["reach"]], key=lambda e: (abs(e.x - v["x"]), e.id))
            if not near:
                return
            extra = self.summon.slots.get("extra_blobs", [])
            for i in range(int(P["blobs"])):
                tgt = near[i % len(near)]
                ops = self.hit_ops + (extra if i > 0 else [])

                def land(tgt=tgt, ops=ops):
                    if tgt.alive:
                        w.run_event(ops, tgt, tgt.x, self.root_ctx("lava"), carrier="entity_attack")
                w.later(P["flight"], land)

    # golem: walks to the nearest enemy and punches
    def update_golem(self, dt):
        w, P = self.w, self.summon.params
        g = self.entity
        if g is None:
            if self.timer <= 0 and self.in_range():
                self.entity = {"x": self.x, "left": P["life"], "cd": 0.0, "n": 0, "target": None}
                w.stats["summons"]["golem"] = w.stats["summons"].get("golem", 0) + 1
            return
        g["left"] -= dt
        g["cd"] -= dt
        if g["left"] <= 0:
            self.entity = None
            self.timer = 1.5
            return
        t = g["target"]
        if t is None or not t.alive or t.leaked:
            t = g["target"] = w.nearest(g["x"], within=4.0)
        if t is None:
            return
        dx = t.x - g["x"]
        if abs(dx) > 0.3:
            g["x"] += math.copysign(min(abs(dx) - 0.25, P["speed"] * dt), dx)
        if abs(t.x - g["x"]) <= 0.5 and g["cd"] <= 0:
            g["cd"] = P["attack_s"]
            g["n"] += 1
            if P.get("slam_r") and P.get("slam_every") and g["n"] % int(P["slam_every"]) == 0:
                dmg = [o for o in self.hit_ops if o.family == "Damage" and o.depth == 0]
                subs = self.summon.slots.get("slam", [])
                for e in [e for e in w.alive() if abs(e.x - g["x"]) <= P["slam_r"]]:
                    w.run_event(dmg + subs, e, e.x, self.root_ctx("slam"), carrier="impact_area")
            else:
                w.run_event(self.hit_ops, t, t.x, self.root_ctx("punch"), carrier="entity_attack")

    # hive: nest + beetles
    def update_hive(self, dt):
        w, P = self.w, self.summon.params
        h = self.entity
        if h is None:
            if self.timer <= 0:
                tg = self.in_range()
                if tg:
                    self.entity = {"x": tg[0].x + 1.5, "left": P["life"], "spawn": 0.0, "extra": 0, "mark": None}
                    self.beetles = []
                    w.stats["summons"]["hive"] = w.stats["summons"].get("hive", 0) + 1
            return
        h["left"] -= dt
        h["spawn"] -= dt
        if h["left"] <= 0:
            self.entity, self.beetles = None, []
            self.timer = 1.5
            return
        cap = int(P["beetles"]) + h["extra"]
        if h["spawn"] <= 0 and len(self.beetles) < cap:
            h["spawn"] = P["spawn_s"]
            self.spawn_beetle(h)
        w.stats["max_beetles"] = max(w.stats["max_beetles"], len(self.beetles))
        mark = None
        if P.get("focus"):
            mark = h["mark"]
            if mark is None or not mark.alive or mark.leaked:
                mark = h["mark"] = w.nearest(h["x"], within=2.5)
                if mark is not None:
                    subs = self.summon.slots.get("mark", [])
                    if subs:
                        w.run_event(subs, mark, mark.x, self.root_ctx("mark"), carrier="mark")
        for b in self.beetles:
            b["cd"] -= dt
            t = mark if mark is not None else (b["t"] if b["t"] and b["t"].alive and not b["t"].leaked else w.nearest(b["x"], within=2.5))
            b["t"] = t
            if t is None:
                continue
            dx = t.x - b["x"]
            if abs(dx) > 0.15:
                b["x"] += math.copysign(min(abs(dx) - 0.1, P["speed"] * dt), dx)
            if abs(t.x - b["x"]) <= 0.3 and b["cd"] <= 0:
                b["cd"] = P["bite_s"]
                was = t.alive
                w.run_event(self.hit_ops, t, t.x, self.root_ctx("bite"), carrier="entity_attack")
                if was and not t.alive and P.get("brood") and h["extra"] < BUD["extra_beetles_from_brood"]:
                    h["extra"] += 1
                    self.spawn_beetle(h)

    def spawn_beetle(self, h):
        w = self.w
        self.beetles.append({"x": h["x"], "cd": 0.0, "t": None})
        subs = self.summon.slots.get("birth", [])
        if subs:
            for e in [e for e in w.alive() if abs(e.x - h["x"]) <= 0.3]:
                w.run_event(subs, e, e.x, self.root_ctx("birth"), carrier="spawn")


def simulate(recipes, **kw) -> dict:
    if isinstance(recipes, str):
        recipes = [recipes]
    w = World(recipes, **kw)
    s = w.run()
    s["seconds"] = round(w.t, 2)
    s["dps"] = round(s["damage"] / w.t, 2)
    s["dps_capped"] = round(s["damage_capped"] / w.t, 2)
    return _round(s)


def _round(x):
    if isinstance(x, float):
        return round(x, 2)
    if isinstance(x, dict):
        return {k: _round(v) for k, v in sorted(x.items(), key=lambda kv: str(kv[0]))}
    return x


if __name__ == "__main__":
    import json
    import sys
    recs = sys.argv[1:] or ["fire3{burn:[electric3{chain:[ice2]}]}"]
    print(json.dumps(simulate(recs), ensure_ascii=False, indent=1))
