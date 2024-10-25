@tool
extends EditorPlugin
const util = preload("util.gd")
const glob = preload("glob.gd")

const MENU_ITEM = "Re-import external files"
const LINK_FILE_NAME = ".external_files"

func find_external_links(root_path: String) -> Array[String]:
	var dirs: Array[String] = []
	var link_file = root_path.path_join(LINK_FILE_NAME)

	if FileAccess.file_exists(link_file):
		dirs.append(link_file)
	for dir in util.DirIter.new(root_path).iter():
		dirs.append_array(find_external_links(root_path.path_join(dir)))
	return dirs

func scan_and_update_project() -> void:
	var globs: Array = []
	for file in find_external_links("res://"):
		globs.append_array(glob.get_globs(file))

func _enter_tree():
	add_tool_menu_item(MENU_ITEM, scan_and_update_project)
	scan_and_update_project()

func _exit_tree():
	remove_tool_menu_item(MENU_ITEM)
