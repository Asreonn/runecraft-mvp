extends RefCounted

func run(game, t) -> void:
	if t.require_api(game, ["rune_cost", "buy_rune", "tower_cost", "try_build", "sell_tower"]):
		# First purchases are below any plausible documented cap. Check all rune IDs.
		for rid in game.spec.runes:
			t.context = "shop/" + rid
			game = await t.fresh_game()
			t.fill(game, false)
			for purchase in 3:
				var price = t.invoke(game, "rune_cost", [rid])
				if not t.check(price is int and price > 0, "rune_cost positive int", str(price)):
					break
				var before: Array = t.items(game)
				var mana: float = game.mana
				var stones: int = game.stones
				t.operation(game, "buy_rune", [rid], true)
				t.check(absf(mana - game.mana - price) < 0.01 and game.stones == stones, "charges quoted rune price #%d" % purchase)
				t.check(t.items(game) == t.expected_items(game, [], [t.node(rid)], before), "purchase adds exactly one G1")
				var next = t.invoke(game, "rune_cost", [rid])
				t.check(next is int and next > price, "multiplicative rune price increases #%d" % purchase, "%s -> %s; first three purchases must be below a documented cap" % [price, next])
		for full in [false, true]:
			t.context = "shop/rejected_purchase/full=" + str(full)
			game = await t.fresh_game()
			t.fill(game, full)
			if not full:
				game.mana = 0.0
			t.operation(game, "buy_rune", ["fire"], false)
		# Repeated buy/sell must spend stones, and selling must not reset pricing.
		game = await t.fresh_game()
		for cycle in 4:
			t.context = "shop/tower_cycle=" + str(cycle)
			var paid = t.invoke(game, "tower_cost")
			if not t.check(paid is int and paid > 0, "tower_cost positive int", str(paid)):
				break
			var stones: int = game.stones
			var mana: float = game.mana
			var before: Array = t.items(game)
			var tower = t.build(game)
			if tower == null:
				continue
			t.check(stones - game.stones == paid and game.mana == mana, "build charges exact quoted stones")
			var after_build = t.invoke(game, "tower_cost")
			t.check(after_build is int and after_build > paid, "building increases next tower price")
			var after_payment: int = game.stones
			t.operation(game, "sell_tower", [tower], true)
			var refund: int = game.stones - after_payment
			t.check(refund >= 0 and refund < paid and game.stones < stones, "refund below purchase; buy/sell loses stones", "paid=%s refund=%s" % [paid, refund])
			var after_sale = t.invoke(game, "tower_cost")
			t.check(after_sale is int and after_sale >= paid, "selling never makes next tower cheaper than price paid", "%s -> %s" % [paid, after_sale])
			t.conserved(game, before)
		await _sale_order(t)
	t.finish()

func _sale_order(t) -> void:
	t.context = "shop/multiple_towers"
	var game = await t.fresh_game()
	var purchases: Array = []
	for i in 5:
		var quoted = t.invoke(game, "tower_cost")
		var tower = t.build(game)
		if tower != null and quoted is int:
			purchases.append({"tower": tower, "paid": quoted})
	# Sell oldest/cheapest first: a count-based refund can overpay this tower
	# even when a single-tower buy/sell cycle looks safe.
	for purchase in purchases:
		var stones: int = game.stones
		t.operation(game, "sell_tower", [purchase.tower], true)
		var refund: int = game.stones - stones
		t.check(refund >= 0 and refund < purchase.paid, "each refund is below that tower's actual paid price", "paid=%d refund=%d" % [purchase.paid, refund])
		var after_sale = t.invoke(game, "tower_cost")
		# Tower price follows the number of towers owned, so it may drop below an old purchase price after sales;
		# what must hold is that no sell -> rebuy cycle gains stones (rebuy costs more than the refund).
		t.check(after_sale is int and after_sale > refund, "sell -> rebuy never gains stones", "refund=%d next=%s" % [refund, after_sale])
