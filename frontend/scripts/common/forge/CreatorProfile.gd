extends RefCounted
class_name CreatorProfile
# PROFIL CRÉATEUR local : nom + couleur d'avatar. Pur I/O (JSON user://).
# L'identité est injectée dans chaque sauvegarde/export (.spark) par ForgeApp
# → "le créateur est VU" sur le feed WORKSHOP et l'écran titre.

const PATH := "user://forge_profile.json"
const DEFAULT_NAME := "Créateur"

# palette d'avatars (cercle coloré + initiale) — index stocké dans le profil
const AVATAR_COLORS: Array[Color] = [
	Color("f39c12"), Color("2ecc71"), Color("4fc3f7"), Color("b388ff"),
	Color("e74c3c"), Color("ff8a65"), Color("26c6da"), Color("f06292"),
]


static func load_profile(path := PATH) -> Dictionary:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa != null:
		var data = JSON.parse_string(fa.get_as_text())
		fa.close()
		if typeof(data) == TYPE_DICTIONARY:
			return {"name": String((data as Dictionary).get("name", DEFAULT_NAME)),
				"color": clampi(int((data as Dictionary).get("color", 0)), 0, AVATAR_COLORS.size() - 1)}
	return {"name": DEFAULT_NAME, "color": 0}


static func save_profile(p: Dictionary, path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify({"name": String(p.get("name", DEFAULT_NAME)),
		"color": int(p.get("color", 0))}))
	f.close()
	return true


static func avatar_color(p: Dictionary) -> Color:
	return AVATAR_COLORS[clampi(int(p.get("color", 0)), 0, AVATAR_COLORS.size() - 1)]


# initiale affichée dans le cercle d'avatar ("Kilian" -> "K")
static func initial(pname: String) -> String:
	var s := pname.strip_edges()
	return s.substr(0, 1).to_upper() if s != "" else "?"
