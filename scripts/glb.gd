extends RefCounted
## Runtime GLB cache. Assets live under res://assets (ignored by the importer) and are
## loaded with GLTFDocument once, then duplicated per instance (meshes/materials shared).

static var _cache: Dictionary = {}


static func instance(rel: String) -> Node3D:
	var proto: Node3D = _cache.get(rel)
	if proto == null:
		var path := ProjectSettings.globalize_path("res://assets/" + rel)
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		var err := doc.append_from_file(path, st)
		if err != OK:
			push_error("GLB load failed: %s (%d)" % [path, err])
			return Node3D.new()
		proto = doc.generate_scene(st)
		_cache[rel] = proto
	return proto.duplicate() as Node3D


