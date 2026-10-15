class_name CitySnapshot
extends RefCounted
## Saves a generated CityData to a compressed file and loads it back, so the city
## (same seed = same city) is generated once at export time instead of on every start.
## Every script variable of CityData and of the objects it holds (fog island, continent)
## is stored; the CityConfig they point to is replaced by the running one on load.
## Only exported builds read it; tools/bake_city.gd writes it (deploy.ps1 runs it before every export).

const PATH := "res://baked/city.bin"
## Bumped when the file layout changes; a mismatch makes the game generate instead.
const VERSION := 1


static func save(data: CityData, cfg: CityConfig, path: String = PATH) -> Error:
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var({"version": VERSION, "key": key(cfg), "root": _dump(data, data)})
	f.close()
	return OK


## Returns the stored city, or null when there is none or it was made with other settings.
static func load_city(cfg: CityConfig, path: String = PATH) -> CityData:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return null
	var top: Variant = f.get_var()
	f.close()
	if not (top is Dictionary) or top.get("version") != VERSION or top.get("key") != key(cfg):
		print("[Snapshot] stored city does not match the settings, generating")
		return null
	MapLayout.set_scale(cfg.map_scale)
	var ctx := {"cfg": cfg, "root": null}
	return _make(top["root"], ctx) as CityData


## The settings that change the city (a different value = a different city).
static func key(cfg: CityConfig) -> String:
	return var_to_str([cfg.city_name, cfg.seed, cfg.map_scale, cfg.map_size, cfg.core_size, cfg.tree_share,
			cfg.chunk_size, cfg.island_radius, cfg.coast_noise, cfg.beach_width, cfg.shallow_width])


# --- Writing -------------------------------------------------------------------------
static func _dump(o: Object, root: CityData) -> Dictionary:
	var out := {"@script": (o.get_script() as Script).resource_path}
	for p in o.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[p["name"]] = _value(o.get(p["name"]), root)
	return out


static func _value(v: Variant, root: CityData) -> Variant:
	if v is Object:
		if v == null:
			return null
		if v == root:
			return {"@ref": "root"}
		if v is CityConfig:
			return {"@ref": "cfg"}
		if v.get_script() != null:
			return _dump(v, root)
		# Native helpers (noise, random generators): class + stored properties.
		var out := {"@class": v.get_class()}
		for p in v.get_property_list():
			if p["usage"] & PROPERTY_USAGE_STORAGE:
				out[p["name"]] = v.get(p["name"])
		return out
	if v is Array:
		var a := []
		for x in v:
			a.append(_value(x, root))
		return a
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _value(v[k], root)
		return d
	return v


# --- Reading -------------------------------------------------------------------------
static func _make(d: Dictionary, ctx: Dictionary) -> Object:
	# Built with _init() without arguments (an empty object), then filled.
	var o: Object = (load(d["@script"]) as GDScript).new()
	if ctx["root"] == null:
		ctx["root"] = o
	for name: String in d:
		if name == "@script":
			continue
		var v: Variant = _read(d[name], ctx)
		var cur: Variant = o.get(name)
		if cur is Array and v is Array and cur.is_typed():
			cur.assign(v)
		elif cur is Dictionary and v is Dictionary and cur.is_typed():
			cur.assign(v)
		else:
			o.set(name, v)
	return o


static func _read(v: Variant, ctx: Dictionary) -> Variant:
	if v is Dictionary:
		if v.has("@ref"):
			return ctx[v["@ref"]]
		if v.has("@script"):
			return _make(v, ctx)
		if v.has("@class"):
			var o: Object = ClassDB.instantiate(v["@class"])
			for k: String in v:
				if k != "@class":
					o.set(k, v[k])
			return o
		var d := {}
		for k in v:
			d[k] = _read(v[k], ctx)
		return d
	if v is Array:
		var a := []
		for x in v:
			a.append(_read(x, ctx))
		return a
	return v
