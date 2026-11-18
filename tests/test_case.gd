extends RefCounted
## Base for test files: extend this, write test_*() methods, and check with expect_eq().
## run_tests.gd finds and runs them.

var failures: Array[String] = []   ## what failed in the current test; the runner clears it


func expect_eq(actual: Variant, expected: Variant, what: String = "") -> void:
	if actual != expected:
		failures.append("%sexpected %s, got %s" % [what + ": " if what else "", var_to_str(expected), var_to_str(actual)])
