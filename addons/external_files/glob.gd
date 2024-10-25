extends Node

# (?aP) is PCRE2_EXTRA_ASCII_POSIX, which guarantees ASCII processing
const _ALNUM = "(?aP)^[:alnum:]$"
static var alnum_regex: RegEx

static func regex_escape(char: String) -> String:
	# *sigh*, GDScript is baaaaaaaaaad
	if not alnum_regex:
		alnum_regex = RegEx.new()
		alnum_regex.compile(_ALNUM)

	if alnum_regex.search(char):
		return char
	return "\\" + char

## Compile a hg-style glob to a regex
static func compile_hg_glob(glob: String, rooted: bool = true) -> RegEx:
	var patterns: Array[String] = []
	var looking_at_wildcard = {"": false}

	var add_pattern = func (pat):
		if looking_at_wildcard[""]:
			patterns.append("[^/]*")
			looking_at_wildcard[""] = false
		patterns.append(pat)

	var in_escape = false
	var in_alternative = false
	var current_alternative = ""
	var alternatives: Array[String] = []

	for char: String in glob:
		match char:
			"\\" when not in_escape:
				in_escape = true
			var c when in_escape:
				in_escape = false
				patterns.append(regex_escape(c))
			"{" when not in_alternative:
				in_alternative = true
			"," when in_alternative:
				alternatives.append(current_alternative)
				current_alternative = ""
			# NB: guard applies to multiple patterns if specified, not just the
			# one it's closest to (tested on 4.3)
			"{", "?", "*" when in_alternative:
				printerr("Invalid glob, unescaped special character inside '{}': %s" % glob)
				return null
			"}" when in_alternative:
				alternatives.append(current_alternative)
				patterns.append("({0})".format(["|".join(alternatives)]))
				current_alternative = ""
				alternatives = []
			var c when in_alternative:
				current_alternative += c
			"?":
				add_pattern.call(".")
			"*" when not looking_at_wildcard[""]:
				looking_at_wildcard[""] = true
			"*":
				patterns.append(".*")
				looking_at_wildcard[""] = false
			var c:
				add_pattern.call(c)
	# In case the pattern ends in a *
	add_pattern.call("")
	var regex = RegEx.new()
	regex.compile("{0}{1}$".format([
		"^" if rooted else "(^|/)",
		"".join(patterns)
	]))
	return regex

static func _test_hg_globs():
	for rooted in [true, false]:
		prints("rooted" if rooted else "not rooted:")
		for test in [
			["asd", ["asd", "asd.png", "foo", "foo/asd", "foo/bar", "foo/aaasd", "foo/bar.txt"]],
			["???", ["asd", "asd.png", "foo", "foo/asd", "foo/bar", "foo/quux", "foo/bar.txt"]],
			["???.txt", ["asd", "asd.png", "foo.txt", "foo/bar", "foo/bar.txt"]],
			["*.png", ["asd", "asd.png", "foo.png", "*?.png", "bar.tar.png", "baz.txt", "foo/bar.png", "foo/bar/baz.png"]],
			["*.{png,txt}", ["asd", "asd.png", "foo.png", "*?.png", "bar.tar.png", "baz.txt", "foo/bar.png", "foo/bar/baz.png"]],
			["*.{tar,gz}", ["asd", "asd.png", "foo.png", "*?.png", "bar.tar.png", "baz.txt", "foo/bar.png", "foo/bar/baz.png"]],
			["foo/*/*.png", ["asd", "asd.png", "foo/bar.png", "foo/bar/baz/quux.png", "foo/bar/baz.png", "foo/bar/*?.png", "foo/bar/bar.tar.png", "foo/bar/baz.txt"]],
			["foo/**/*.png", ["asd", "asd.png", "foo/bar.png", "foo/bar/baz/quux.png", "foo/bar/baz.png", "foo/bar/*?.png", "foo/bar/bar.tar.png", "foo/bar/baz.txt"]],
			["foo/**.png", ["asd", "asd.png", "foo/bar.png", "foo/bar/baz/quux.png", "foo/bar/baz.png", "foo/bar/*?.png", "foo/bar/bar.tar.png", "foo/bar/baz.txt"]],
			["foo/**.{png,txt}", ["asd", "asd.png", "foo/bar.png", "foo/bar/baz/quux.png", "foo/bar/foo/quux.png", "foo/bar/baz.png", "foo/bar/*?.png", "foo/bar/bar.tar.png", "foo/bar/baz.txt"]],
			["foo/**.{tar,gz}", ["asd", "asd.png", "foo/bar.png", "foo/bar/baz/quux.png", "foo/bar/foo/quux.png", "foo/bar/baz.png", "foo/bar/*?.png", "foo/bar/bar.tar.png", "foo/bar/baz.txt"]],
		]:
			var glob = test[0]
			var cands = test[1]
			var compiled = compile_hg_glob(glob, rooted)
			for cand in cands:
				prints("  ", "%-18s" % glob, "|", "%-25s" % cand, "|", "%-20s" % compiled.get_pattern(), "|", compiled.search(cand) != null)
			prints()

static func get_globs(pattern_file: String) -> Array:
	var result: Array = []
	var file = FileAccess.open(pattern_file, FileAccess.READ)
	var dir: String = ""
	var mode_regex = RegEx.new()
	mode_regex.compile(r"^syntax: *(\w+)$")
	var root_regex = RegEx.new()
	root_regex.compile(r"## *root: *(.*)$")
	var mode: String = "regexp"

	var line: String
	var lineno: int = 0
	while not file.eof_reached():
		line = file.get_line().strip_edges()
		lineno += 1
		if not line:
			continue

		var _match = mode_regex.search(line)
		if _match:
			mode = _match.get_string(1)
			if mode not in ["glob", "rootglob", "regexp"]:
				printerr("Invalid syntax choice '%s' in '%s':%d" % [mode, pattern_file, lineno])
				return []
			continue

		_match = root_regex.search(line)
		if _match:
			if not _match.get_string(1):
				printerr("No path given in root directive in '%s':%d" % [pattern_file, lineno])
				return []
			dir = "/".join(
				ProjectSettings.globalize_path("res://").split("/").slice(0, -1)
			).path_join(
				_match.get_string(1)
			)
			continue

		if line.begins_with("#"):
			continue
		if not dir:
			printerr("Missing root directive in '%s':%d" % [pattern_file, lineno])
			return []

		var glob: RegEx
		if mode in ["glob", "rootglob"]:
			glob = compile_hg_glob(line, mode == "rootglob")
		else:
			glob = RegEx.new()
			glob.compile("(^|/)%s" % line)
		result.append([dir, glob])
	return result
