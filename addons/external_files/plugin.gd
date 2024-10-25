@tool
extends EditorPlugin
const util = preload("util.gd")

const LINK_FILE_NAME = ".external_files"

class DirIter:
	var path: String
	var dir: DirAccess
	var children: Array[String] = []
	var _idx: int = 0

	# Work around bugs in 4.2
	func iter():
		return self

	func _init(_path):
		path = _path

	func _iter_init(arg):
		dir = DirAccess.open(path)
		if not dir:
			printerr("Could not open directory %s: %s" % [path, DirAccess.get_open_error()])
			return false
		dir.include_hidden = true
		_idx = 0
		children.assign(dir.get_directories())
		return children.size() > 0

	func _iter_next(arg):
		_idx += 1
		return _idx < children.size()

	func _iter_get(arg):
		return children[_idx]

func find_external_links(root_path: String) -> Array[String]:
	var dirs: Array[String] = []
	var link_file = root_path.path_join(LINK_FILE_NAME)

	if FileAccess.file_exists(link_file):
		dirs.append(link_file)
	for dir in DirIter.new(root_path).iter():
		dirs.append_array(find_external_links(root_path.path_join(dir)))
	return dirs

func _test_hg_globs():
	for rooted in [true, false]:
		prints("rooted" if rooted else "not rooted:")
		for test in [
			["asd", ["asd", "asd.png", "foo", "foo/asd", "foo/bar", "foo/bar.txt"]],
			["???", ["asd", "asd.png", "foo", "foo/asd", "foo/bar", "foo/bar.txt"]],
			["???.txt", ["asd", "asd.png", "foo.txt", "foo/bar", "foo/bar.txt"]],
			["*.png", ["asd", "asd.png", "foo.png", "*?.png", "bar.tar.png", "baz.txt", "foo/bar.png", "foo/bar/baz.png"]],
			["foo/*/*.png", ["asd", "asd.png", "foo/bar.png", "foo/bar/baz/quux.png", "foo/bar/baz.png", "foo/bar/*?.png", "foo/bar/bar.tar.png", "foo/bar/baz.txt"]],
			["foo/**/*.png", ["asd", "asd.png", "foo/bar.png", "foo/bar/baz/quux.png", "foo/bar/baz.png", "foo/bar/*?.png", "foo/bar/bar.tar.png", "foo/bar/baz.txt"]],
			["foo/**.png", ["asd", "asd.png", "foo/bar.png", "foo/bar/baz/quux.png", "foo/bar/baz.png", "foo/bar/*?.png", "foo/bar/bar.tar.png", "foo/bar/baz.txt"]],
		]:
			var glob = test[0]
			var cands = test[1]
			var compiled = util.compile_hg_glob(glob, rooted)
			for cand in cands:
				prints("  ", "%-15s" % glob, "|", "%-25s" % cand, "|", compiled.search(cand) != null)
			prints()

func scan_and_update_project() -> void:
	for file in find_external_links("res://"):
		prints("found file", file)

	_test_hg_globs()

func _enter_tree():
	add_tool_menu_item("Rescan external files", scan_and_update_project)
	scan_and_update_project()

func _exit_tree():
	# Clean-up of the plugin goes here.
	pass
