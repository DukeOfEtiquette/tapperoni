extends "res://tests/test_case.gd"
## Game.format_number: commas, suffixes, scientific notation, and the edges between them.

const GameScript := preload("res://scripts/game.gd")   ## static functions only; not the autoload


func test_small_numbers_get_commas() -> void:
	expect_eq(GameScript.format_number(0), "0")
	expect_eq(GameScript.format_number(999), "999")
	expect_eq(GameScript.format_number(1000), "1,000")
	expect_eq(GameScript.format_number(1234.9), "1,234", "fractions are floored")
	expect_eq(GameScript.format_number(999_999), "999,999")


func test_suffixes() -> void:
	expect_eq(GameScript.format_number(1e6), "1.00M")
	expect_eq(GameScript.format_number(1_234_567), "1.23M")
	expect_eq(GameScript.format_number(45_600_000_000), "45.60B")
	expect_eq(GameScript.format_number(999_994_000), "999.99M")


## A value that rounds up to 1000 of a suffix is shown as 1.00 of the next one.
func test_rounding_up_moves_to_the_next_suffix() -> void:
	for tier: int in range(3, GameScript.SUFFIXES.size()):   # from B: 999,999 stays 999,999
		var n := 0.999999 * pow(1000.0, tier)
		expect_eq(GameScript.format_number(n), "1.00" + GameScript.SUFFIXES[tier], "0.999999e%d" % (tier * 3))
	expect_eq(GameScript.format_number(0.999999e15), "1.00e15", "past the last suffix (T)")


## Every power of ten from 1e6 up, at the exact value and just below it.
func test_powers_of_ten() -> void:
	for e: int in range(6, 309):
		var tier := e / 3
		var expected: String = ("%.2f" % pow(10.0, e % 3)) + GameScript.SUFFIXES[tier] if tier < GameScript.SUFFIXES.size() else "1.00e%d" % e
		expect_eq(GameScript.format_number(pow(10.0, e)), expected, "1e%d" % e)
		if e > 6:   # just below rounds up to the same text (999,999 doesn't: it's under 1e6)
			expect_eq(GameScript.format_number(pow(10.0, e) * 0.999999), expected, "0.999999e%d" % e)


func test_scientific() -> void:
	expect_eq(GameScript.format_number(999.99e12), "999.99T", "last suffixed value")
	expect_eq(GameScript.format_number(1e15), "1.00e15", "first scientific value")
	expect_eq(GameScript.format_number(4.56e21), "4.56e21")
	expect_eq(GameScript.format_number(1.5e40), "1.50e40")
	expect_eq(GameScript.format_number(1.79e308), "1.79e308")


func test_not_finite_or_negative() -> void:
	expect_eq(GameScript.format_number(INF), "Infinity")
	expect_eq(GameScript.format_number(-INF), "-Infinity")
	expect_eq(GameScript.format_number(NAN), "?")
	expect_eq(GameScript.format_number(-1234), "-1,234")
	expect_eq(GameScript.format_number(-123), "-123")
	expect_eq(GameScript.format_number(-2.5e6), "-2.50M")
