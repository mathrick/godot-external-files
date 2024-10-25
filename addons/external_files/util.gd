@tool
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
				patterns.append("({})".format(["|".join(alternatives)]))
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
		"^" if rooted else "",
		"".join(patterns)
	]))
	return regex
