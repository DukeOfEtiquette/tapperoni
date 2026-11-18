extends "res://tests/test_case.gd"
## Winning: points stop at Game.MAX_POINTS, and after that nothing earns or spends.

const GameScript := preload("res://scripts/game.gd")   ## instanced off the tree: no _ready, no save


## A fresh game outside the scene tree, so it never loads or writes the save. Free it when done.
func _new_game() -> Node:
	var game: Node = GameScript.new()
	for id: String in GameScript.UPGRADES:
		game.owned[id] = 0
	return game


func test_earning_stops_at_the_cap() -> void:
	var game := _new_game()
	game.points = GameScript.MAX_POINTS / 2.0   # halving is exact, so the expected gain is too
	expect_eq(game.has_won(), false, "short of the cap")
	expect_eq(game._earn(GameScript.MAX_POINTS), GameScript.MAX_POINTS / 2.0, "only what fits under the cap is earned")
	expect_eq(game.points, GameScript.MAX_POINTS, "points stop at the cap")
	expect_eq(game.has_won(), true, "at the cap")
	expect_eq(game._earn(1e305), 0.0, "nothing more is earned")
	expect_eq(game.tap(), 0.0, "taps earn nothing")
	game.free()


## per_second() can overflow to INF with enough upgrades; that still stops at the cap.
func test_infinite_income_stops_at_the_cap() -> void:
	var game := _new_game()
	game._earn(INF)
	expect_eq(game.points, GameScript.MAX_POINTS)
	expect_eq(game.total_earned, GameScript.MAX_POINTS)
	game.free()


func test_nothing_can_be_bought_once_won() -> void:
	var game := _new_game()
	game.points = GameScript.MAX_POINTS
	for id: String in GameScript.UPGRADES:
		expect_eq(game.can_buy(id), false, id)
		expect_eq(game.buy(id), false, id)
		expect_eq(game.time_to_afford(id, 5.0), INF, id + " countdown")
	expect_eq(game.points, GameScript.MAX_POINTS, "points unspent")
	game.free()


func test_time_to_win() -> void:
	var game := _new_game()
	expect_eq(game.time_to_win(0.0), INF, "no income")
	game.points = GameScript.MAX_POINTS / 2.0
	expect_eq(game.time_to_win(1.0), GameScript.MAX_POINTS / 2.0, "1 per tap at 1 tap/sec")
	game.owned["singularity"] = 1
	var income: float = GameScript.UPGRADES.singularity.per_second + 2.0   # 1 per tap at 2 taps/sec
	expect_eq(game.time_to_win(2.0), (GameScript.MAX_POINTS / 2.0) / income, "passive plus taps")
	game.points = GameScript.MAX_POINTS
	expect_eq(game.time_to_win(2.0), 0.0, "won")
	game.free()


## The win is just points == MAX_POINTS, so the save must give that exact value back.
func test_the_cap_survives_a_save() -> void:
	var saved = JSON.parse_string(JSON.stringify({"points": GameScript.MAX_POINTS}))
	expect_eq(float(saved.points), GameScript.MAX_POINTS)
	expect_eq(is_finite(GameScript.MAX_POINTS), true, "MAX_POINTS is finite")
	expect_eq(is_inf(GameScript.MAX_POINTS * 2.0), true, "MAX_POINTS is the largest float")
