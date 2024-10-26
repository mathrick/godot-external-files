@tool
extends EditorPlugin
const util = preload("util.gd")
const glob = preload("glob.gd")

const MENU_ITEM = "External files"
const LINK_FILE_NAME = ".external_files"

var menu: PopupMenu
const RESCAN_ID = 1
const FORCE_ID = 2

func find_external_links(root_path: String) -> Array[String]:
	var links: Array[String] = []
	var candidate: String

	for dir in util.DirWalk.new(root_path).iter():
		candidate = dir.path_join(LINK_FILE_NAME)
		if FileAccess.file_exists(candidate):
			links.append(candidate)

	return links

func ensure_updated(src: String, dest: String, strict: bool = false):
	var need_copy: bool = (
		not FileAccess.file_exists(dest)
		or FileAccess.get_modified_time(src) > FileAccess.get_modified_time(src)
	)
	if not need_copy:
		var src_file := FileAccess.open(src, FileAccess.READ)
		var dest_file := FileAccess.open(dest, FileAccess.READ)
		if src_file.get_length() != dest_file.get_length():
			need_copy = true
		elif strict and FileAccess.get_md5(src) != FileAccess.get_md5(dest):
			need_copy = true

	if need_copy:
		print("File %s is outdated, copying from %s" % [dest, src])
		DirAccess.copy_absolute(src, dest)

func scan_and_update_project(strict: bool = false) -> void:
	var globs: Array = []
	for file in find_external_links("res://"):
		globs.append([file.get_base_dir(), glob.get_globs(file)])

	var cache := {}

	for group in globs:
		var dest: String = group[0]
		for glob in group[1]:
			var src: String = glob[0]
			var pat: RegEx = glob[1]
			if src not in cache:
				var files = []
				# Sigh, GDScript can't make an array out of an iterator...
				for file in util.DirWalk.new(src, true).iter():
					files.append(file)
				cache[src] = files
			for file in cache[src]:
				if pat.search(file):
					ensure_updated(src.path_join(file), "res://" + dest.path_join(file), strict)

func _enter_tree():
	if menu == null:
		menu = PopupMenu.new()
		menu.add_item("Re-scan", RESCAN_ID)
		menu.add_item("Force full re-scan", FORCE_ID)
		menu.id_pressed.connect(_on_menu_id_pressed)
	add_tool_submenu_item(MENU_ITEM, menu)
	scan_and_update_project()

func _exit_tree():
	remove_tool_menu_item(MENU_ITEM)

func _on_menu_id_pressed(id):
	prints("Re-scanning external files...")
	scan_and_update_project(id == FORCE_ID)
	prints("Done.")
