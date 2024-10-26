@tool
extends Node

static func iter_dir(path: String, files: bool = false) -> PackedStringArray:
	var dir := DirAccess.open(path)
	if not dir:
		printerr("Could not open directory %s: %s" % [path, DirAccess.get_open_error()])
		return []
	dir.include_hidden = true
	var idx := 0
	if files:
		return dir.get_files()
	else:
		return dir.get_directories()

class DirWalk:
	var path: String
	var dir_stack: Array[Dictionary]
	var dirs: bool = false
	var skip_dirs: Array[String] = []
	var files: bool = false
	var next: String

	# Work around bugs in 4.2
	func iter():
		return self

	func _init(_path: String, _files: bool = false, _skip_dirs: Array[String] = [".godot"]):
		path = _path
		files = _files
		skip_dirs.assign(_skip_dirs.map(func (x): return path.path_join(x)))

	func _subdir(curr: Dictionary) -> String:
		if not curr["didx"] < curr["dirs"].size():
			return ""
		return curr["path"].path_join(curr["dirs"][curr["didx"]])

	func _get_next() -> String:
		var i := 0
		# In case of an error, we want to skip and continue with the next item
		while true:
			i += 1
			if not dir_stack:
				return ""
			var curr: Dictionary = dir_stack[-1]
			# Try to get the next item. First, if we haven't visited the current
			# subdir yet, do that (breadth-first walk)
			if not curr["descended"]:
				curr["descended"] = true
				if _subdir(curr) in skip_dirs:
					continue
				var child_path := _subdir(curr)
				if not child_path:
					continue
				var child: = _open_dir(child_path, path)
				# If the child is empty, it means we ran into an error;
				# skip it and try again
				if not child:
					continue
				dir_stack.append(child)
				return child["path"]
			else:
				# Otherwise, if we still have more subdirs, grab the next one
				curr["didx"] += 1
				if curr["didx"] < curr["dirs"].size():
					if _subdir(curr) in skip_dirs:
						continue
					curr["descended"] = false
					continue

				# If we ran out of subdirs, check if we have files we haven't
				# returned yet
				curr["fidx"] += 1
				if curr["fidx"] < curr["files"].size():
					return curr["path"].path_join(curr["files"][curr["fidx"]])

				# At this point, we've seen everything in the current dir, so
				# pop it off the stack and try to find the next item again
				dir_stack.pop_back()
				continue
		assert(false, "should not be reached")
		return ""


	func _open_dir(path: String, relative_to: String = "") -> Dictionary:
		# This is a little clunky, but we need this to keep track of relative
		# paths. Unfortunately GDScript's path-handling functionality is
		# extremely poor and unwieldy
		var to_open := path
		if not path and relative_to:
			to_open = relative_to
		elif relative_to:
			to_open = relative_to.path_join(path)
		var dir = DirAccess.open(to_open)
		if not dir:
			printerr("Could not open directory %s: %s" % [path, DirAccess.get_open_error()])
			return {}
		dir.include_hidden = true
		var subdirs = dir.get_directories()
		return {
			"path": path,
			"dirs": subdirs,
			"files": dir.get_files() if files else [],
			"descended": subdirs.is_empty(),
			"didx": 0,
			"fidx": 0
		}

	func _iter_init(arg):
		var root_dir = _open_dir("", path)
		if not root_dir:
			return false
		dir_stack.append(root_dir)
		next = root_dir["path"]
		return true

	func _iter_next(arg):
		next = _get_next()
		return next != ""

	func _iter_get(arg):
		return next
