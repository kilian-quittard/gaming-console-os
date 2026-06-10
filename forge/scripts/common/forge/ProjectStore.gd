extends RefCounted
class_name ProjectStore
# PERSISTANCE des projets FORGE : chemins, scan, lecture, écriture (JSON).
# Pur I/O — aucune connaissance de l'éditeur ni des templates.

const DIR := "user://forge_projects/"


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


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
