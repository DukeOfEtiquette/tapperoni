extends SceneTree
## Runs the test_*() methods of every tests/test_*.gd file, headless, and exits non-zero if any
## fail. bin/phone check runs it; locally:
##   godot --headless --path . -s res://tests/run_tests.gd [-- <filter>]
## With a filter, only tests whose "file.method" name contains it run.
## Everything runs in _initialize, before autoloads like Game process a frame or touch the save.

const TESTS_DIR := "res://tests"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var filter: String = args[0] if not args.is_empty() else ""
	var ran := 0
	var failed := 0
	for file: String in DirAccess.get_files_at(TESTS_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(TESTS_DIR.path_join(file))
		if script == null or not script.can_instantiate():   # e.g. a parse error, printed above
			failed += 1
			print("FAIL %s: doesn't load" % file)
			continue
		var suite: Object = script.new()
		for method: Dictionary in suite.get_method_list():
			var test_name := "%s.%s" % [file.get_basename(), method.name]
			if not method.name.begins_with("test_") or (filter != "" and not test_name.contains(filter)):
				continue
			ran += 1
			suite.failures.clear()
			suite.call(method.name)
			if not suite.failures.is_empty():
				failed += 1
				print("FAIL %s" % test_name)
				for f: String in suite.failures:
					print("     %s" % f)
	print("tests: %d run, %d failed" % [ran, failed])
	quit(1 if failed > 0 or ran == 0 else 0)
