extends "res://tests/test_case.gd"
## Game.format_duration: the countdown on upgrade buttons.

const GameScript := preload("res://scripts/game.gd")   ## static functions only; not the autoload


func test_zero_only_at_zero() -> void:
	expect_eq(GameScript.format_duration(0.0), "0.0s")
	expect_eq(GameScript.format_duration(-3.0), "0.0s", "negative")
	expect_eq(GameScript.format_duration(0.04), "0.1s", "rounds up, so never 0.0s with time left")


func test_seconds() -> void:
	expect_eq(GameScript.format_duration(12.34), "12.4s")
	expect_eq(GameScript.format_duration(59.85), "59.9s")
	expect_eq(GameScript.format_duration(59.95), "1m 00s", "rounds up into minutes")


func test_minutes_hours_days() -> void:
	expect_eq(GameScript.format_duration(125.2), "2m 06s")
	expect_eq(GameScript.format_duration(3599.5), "1h 00m", "rounds up into hours")
	expect_eq(GameScript.format_duration(2 * 3600 + 13 * 60), "2h 13m")
	expect_eq(GameScript.format_duration(3 * 86400 + 4 * 3600), "3d 04h")
	expect_eq(GameScript.format_duration(364 * 86400 + 23.5 * 3600), "1.0y", "rounds up into years")


func test_years() -> void:
	var year := 365.25 * 86400
	expect_eq(GameScript.format_duration(12.5 * year), "12.5y")
	expect_eq(GameScript.format_duration(4500 * year), "4,500y")
	expect_eq(GameScript.format_duration(1.8e11 * year), "180.00By")


func test_never() -> void:
	expect_eq(GameScript.format_duration(INF), "—")
	expect_eq(GameScript.format_duration(NAN), "—")
