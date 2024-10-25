@tool
extends EditorPlugin
const util = preload("util.gd")

const LINK_FILE_NAME = ".external_files"

func find_external_links(root_path: String) -> Array[String]:
	var dirs: Array[String] = []
	var link_file = root_path.path_join(LINK_FILE_NAME)

	if FileAccess.file_exists(link_file):
		dirs.append(link_file)
	for dir in util.DirIter.new(root_path).iter():
		dirs.append_array(find_external_links(root_path.path_join(dir)))
	return dirs

func get_globs(pattern_file: String) -> Array:
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
			glob = util.compile_hg_glob(line, mode == "rootglob")
		else:
			glob = RegEx.new()
			glob.compile("(^|/)%s" % line)
		result.append([dir, glob])
	return result

func scan_and_update_project() -> void:
	var globs: Array = []
	for file in find_external_links("res://"):
		globs.append_array(get_globs(file))

	prints(ProjectSettings.globalize_path("res://../../renpy"), globs)

func _enter_tree():
	add_tool_menu_item("Re-import external files", scan_and_update_project)
	scan_and_update_project()

func _exit_tree():
	# Clean-up of the plugin goes here.
	pass
