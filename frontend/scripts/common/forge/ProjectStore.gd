extends RefCounted
class_name ProjectStore
# PERSISTANCE des projets FORGE : chemins, scan, lecture, écriture (JSON).
# Pur I/O — aucune connaissance de l'éditeur ni des templates.

const DIR := "user://forge_projects/"
const SHARED_DIR := "user://forge_shared/"   # créations exportées/à importer (.spark)
const WORKSHOP_DIR := "user://forge_workshop/"   # WORKSHOP v0 : "serveur" factice (dossier local)


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


static func ensure_shared() -> void:
	DirAccess.make_dir_recursive_absolute(SHARED_DIR)


static func path(pname: String) -> String:
	return DIR + pname.replace(" ", "_") + ".json"


# liste les projets d'une dimension : [{name, dim, template, path}, ...]
static func list(dim: String) -> Array:
	var out := []
	var d := DirAccess.open(DIR)
	if d == null: return out
	for fn in d.get_files():
		if not fn.ends_with(".json"): continue
		var data = load_file(DIR + fn)
		if typeof(data) == TYPE_DICTIONARY and String(data.get("dim", "2D")) == dim:
			out.append({"name": String(data.get("name", fn)), "dim": dim,
				"template": String(data.get("template", "platformer")), "path": DIR + fn})
	return out


static func load_file(fpath: String):
	var fa := FileAccess.open(fpath, FileAccess.READ)
	if fa == null: return null
	var data = JSON.parse_string(fa.get_as_text())
	fa.close()
	return data


static func save(data: Dictionary) -> bool:
	var f := FileAccess.open(path(String(data.get("name", "projet"))), FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(data)); f.close()
	return true


static func exists(pname: String) -> bool:
	return FileAccess.file_exists(path(pname))


# nom libre le plus proche de base : "X", "X (2)", "X (3)", ...
static func unique_name(base: String) -> String:
	var nm := base
	var i := 2
	while exists(nm):
		nm = "%s (%d)" % [base, i]; i += 1
	return nm


# ================================================ PARTAGE (.spark)
# Un .spark = le projet complet emballé { "spark": 1, "project": {...} }.
# Format autonome et portable : clé USB, Discord, plus tard WORKSHOP en ligne.
static func spark_path(pname: String) -> String:
	return SHARED_DIR + pname.replace(" ", "_") + ".spark"


static func export_spark(data: Dictionary) -> String:
	ensure_shared()
	var fp := spark_path(String(data.get("name", "creation")))
	var f := FileAccess.open(fp, FileAccess.WRITE)
	if f == null: return ""
	f.store_string(JSON.stringify({"spark": 1, "project": data}))
	f.close()
	return fp


# déballe un .spark (ou tolère un .json brut de projet) → dict projet, ou null
static func _unwrap(w) -> Variant:
	if typeof(w) != TYPE_DICTIONARY: return null
	if (w as Dictionary).has("project"): return (w as Dictionary)["project"]
	return w   # tolérance : fichier projet brut sans enveloppe


static func list_spark() -> Array:
	ensure_shared()
	var out := []
	var d := DirAccess.open(SHARED_DIR)
	if d == null: return out
	for fn in d.get_files():
		if not fn.ends_with(".spark"): continue
		var proj = _unwrap(load_file(SHARED_DIR + fn))
		if typeof(proj) == TYPE_DICTIONARY:
			out.append({"name": String((proj as Dictionary).get("name", fn)),
				"dim": String((proj as Dictionary).get("dim", "2D")),
				"template": String((proj as Dictionary).get("template", "platformer")),
				"path": SHARED_DIR + fn})
	return out


static func import_spark(fpath: String) -> Dictionary:
	var proj = _unwrap(load_file(fpath))
	return proj if typeof(proj) == TYPE_DICTIONARY else {}


# transforme une création en REMIX : nouveau projet À MOI, crédit à l'original.
# Pure donnée (pas d'I/O) — le nom unique et la sauvegarde restent au caller.
static func make_remix(proj: Dictionary, my_name: String, my_color: int) -> Dictionary:
	var out := proj.duplicate(true)
	out["remix_of"] = String(proj.get("name", "Création"))
	out["remix_by"] = String(proj.get("author", "?"))
	out["name"] = unique_name("Remix de %s" % String(proj.get("name", "Création")))
	out["author"] = my_name
	out["author_color"] = my_color
	out["progress"] = {"unlocked": 1}   # la progression du joueur original ne suit pas
	return out


# ================================================ WORKSHOP v0
# Source PLUGGABLE : v0 lit un index.json LOCAL (le "serveur factice").
# v1 = remplacer ce read par un HTTPRequest vers une URL (même format index.json).
# index.json : { "version": 1, "creations": [ {name, author, template, dim, file}, ... ] }
static func ensure_workshop() -> void:
	DirAccess.make_dir_recursive_absolute(WORKSHOP_DIR)


static func workshop_list(dir := WORKSHOP_DIR) -> Array:
	DirAccess.make_dir_recursive_absolute(dir)
	var out := []
	var idx = load_file(dir + "index.json")
	if typeof(idx) == TYPE_DICTIONARY and (idx as Dictionary).has("creations"):
		for c in (idx as Dictionary)["creations"]:
			if typeof(c) != TYPE_DICTIONARY: continue
			var file := String((c as Dictionary).get("file", ""))
			if file == "" or not FileAccess.file_exists(dir + file): continue
			out.append(_workshop_entry(dir + file, load_file(dir + file), c))
		return out
	# pas d'index : tolère un simple dossier rempli de .spark
	var d := DirAccess.open(dir)
	if d == null: return out
	for fn in d.get_files():
		if not fn.ends_with(".spark"): continue
		var w = load_file(dir + fn)
		if typeof(_unwrap(w)) == TYPE_DICTIONARY:
			out.append(_workshop_entry(dir + fn, w, {}))
	return out


# entrée du feed : métadonnées du .spark (autorité) complétées par l'index (fallback)
static func _workshop_entry(fpath: String, wrapped, idx_c: Dictionary) -> Dictionary:
	var proj = _unwrap(wrapped)
	var p: Dictionary = proj if typeof(proj) == TYPE_DICTIONARY else {}
	return {"name": String(p.get("name", idx_c.get("name", fpath.get_file()))),
		"author": String(p.get("author", idx_c.get("author", "?"))),
		"author_color": int(p.get("author_color", 0)),
		"remix_of": String(p.get("remix_of", "")),
		"template": String(p.get("template", idx_c.get("template", "platformer"))),
		"dim": String(p.get("dim", idx_c.get("dim", "2D"))),
		"path": fpath,
		"mtime": int(FileAccess.get_modified_time(fpath))}
