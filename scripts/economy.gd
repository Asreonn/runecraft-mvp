extends RefCounted
## Shop pricing and mana income.
## Shop (spec economy.shop — PROVISIONAL values, not balance-proven):
##  - rune price = base × growth^k, k = recent purchases of that rune, capped at max_mult; every cleared wave
##    halves k (the market cools down), so prices recover and late waves stay affordable.
##  - tower price = base × growth^n, n = towers currently owned; selling refunds a share of min(price paid,
##    price to rebuild), so buy/sell loops always lose stones.
## Mana income (spec runes.mana.grades[g].income_cap): mana from siphon / mana marks is attributed to the Mana
## rune node that produced it; above that node's per-second cap only `over_cap_eff` of the excess is gained.
## Overkill damage never becomes mana. The HUD shows the real income rate (regen + recent rune income).

var game
var rune_buys: Dictionary = {}          # rune id -> float purchase count (decays per cleared wave)
var _bucket: Dictionary = {}            # source key -> {t, amt} income within the current second
var _income_log: Array = []             # [time, amount] of rune mana income (for the displayed rate)
var tower_income: Dictionary = {}       # tower id -> Array[[time, amount]] (last 10 s, for display)
var total_rune_income := 0.0            # cumulative mana from siphon / marks (reports, tests)


func _init(g) -> void:
	game = g


func _shop() -> Dictionary:
	return game.spec.economy.get("shop", {})


func rune_cost(rid: String) -> int:
	var s := _shop()
	var base := float(game.spec.economy.rune_buy_g1_mana[game.spec.runes[rid].buy])
	var k := float(rune_buys.get(rid, 0.0))
	var mult := minf(pow(float(s.get("rune_price_growth", 1.0)), k), float(s.get("rune_price_max_mult", 1.0)))
	return roundi(base * mult)


func on_rune_bought(rid: String) -> void:
	rune_buys[rid] = float(rune_buys.get(rid, 0.0)) + 1.0


func on_wave_cleared() -> void:
	var keep := float(_shop().get("rune_price_decay_keep", 1.0))
	for rid in rune_buys.keys():
		var k: float = floorf(float(rune_buys[rid]) * keep)
		if k <= 0.0:
			rune_buys.erase(rid)
		else:
			rune_buys[rid] = k


func tower_cost(owned: int = -1) -> int:
	var s := _shop()
	var n: int = owned if owned >= 0 else game.towers.size()
	return roundi(float(s.get("tower_cost_base", 4)) * pow(float(s.get("tower_cost_growth", 1.0)), n))


## Refund = share of min(price paid, price to rebuild after the sale), so a sell -> rebuy cycle always costs stones.
func tower_refund(t) -> int:
	var rebuild := tower_cost(maxi(0, game.towers.size() - 1))
	var paid := int(t.get_meta("paid", rebuild))
	return int(floor(mini(paid, rebuild) * float(_shop().get("tower_sell_refund", 0.5))))


# ------------------------------------------------------------------ mana income

func _cap(grade: int) -> float:
	var g: Dictionary = game.spec.runes.mana.grades.get(str(clampi(grade, 1, 5)), {})
	return float(g.get("income_cap", 1e9))


## Rune mana income (siphon / mark). `src` identifies the producing Mana node (tower + op uid), `grade` its grade.
## Returns the mana actually gained after the soft cap.
func rune_income(amount: float, src: String, grade: int, tower_id: int, at: Vector3, why: String) -> float:
	if amount <= 0.0:
		return 0.0
	var now: float = game.now
	var b: Dictionary = _bucket.get(src, {"t": floorf(now), "amt": 0.0})
	if b.t != floorf(now):
		b = {"t": floorf(now), "amt": 0.0}
	var cap := _cap(grade)
	var room := maxf(0.0, cap - float(b.amt))
	var gained := minf(amount, room) + maxf(0.0, amount - room) * float(game.spec.economy.get("mana_income", {}).get("over_cap_eff", 0.25))
	b.amt = float(b.amt) + amount
	_bucket[src] = b
	_income_log.append([now, gained])
	total_rune_income += gained
	if not tower_income.has(tower_id):
		tower_income[tower_id] = []
	tower_income[tower_id].append([now, gained])
	game.add_mana(gained, at, why)
	return gained


func _rate(lst: Array, window := 10.0) -> float:
	var now: float = game.now
	while not lst.is_empty() and lst[0][0] < now - window:
		lst.pop_front()
	var s := 0.0
	for x in lst:
		s += x[1]
	return s / window


## Mana per second shown to the player: passive regen + rune income over the last 10 s.
func mana_rate() -> float:
	return game.mana_regen + _rate(_income_log)


func tower_mana_rate(t) -> float:
	return _rate(tower_income.get(t.tid, []))


func serialize() -> Dictionary:
	return {"rune_buys": rune_buys.duplicate()}


func restore(d: Dictionary) -> void:
	rune_buys = {}
	for k in d.get("rune_buys", {}):
		rune_buys[k] = float(d.rune_buys[k])
