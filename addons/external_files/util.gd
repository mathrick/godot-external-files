@tool
extends Node

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
