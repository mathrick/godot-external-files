@tool
extends EditorPlugin
const util = preload("util.gd")
const glob = preload("glob.gd")

const MENU_ITEM = "Re-import external files"
const LINK_FILE_NAME = ".external_files"

func find_external_links(root_path: String) -> Array[String]:
	var links: Array[String] = []
	var candidate: String

	for dir in util.DirWalk.new(root_path).iter():
		candidate = dir.path_join(LINK_FILE_NAME)
		if FileAccess.file_exists(candidate):
			links.append(candidate)

	return links

func scan_and_update_project() -> void:
	var globs: Array = []
	for file in find_external_links("res://"):
		globs.append_array(glob.get_globs(file))

	var cache := {}

	for glob in globs:
		var dir: String = glob[0]
		var pat: RegEx = glob[1]
		if dir not in cache:
			var files = []
			# Sigh, GDScript can't make an array out of an iterator...
			for file in util.DirWalk.new(dir, true).iter():
				files.append(file)
			cache[dir] = files
		for file in cache[dir]:
			if pat.search(file):
				prints("found", dir, file)

func _enter_tree():
	add_tool_menu_item(MENU_ITEM, scan_and_update_project)
	scan_and_update_project()

func _exit_tree():
	remove_tool_menu_item(MENU_ITEM)
