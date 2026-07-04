extends RefCounted
class_name WorkshopStats
# STATS locales des créations : nb de parties par création (clé = nom de fichier).
# Pur I/O (JSON user://). v0 = local uniquement ; v1 (backend) = synchroniser ces
# compteurs vers le serveur → le créateur verra "ton jeu a été joué N fois".

const PATH := "user://forge_stats.json"


static func load_stats(path := PATH) -> Dictionary:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null: return {}
	var data = JSON.parse_string(fa.get_as_text())
	fa.close()
	return data.get("plays", {}) if typeof(data) == TYPE_DICTIONARY else {}


static func save_stats(plays: Dictionary, path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify({"version": 1, "plays": plays}))
	f.close()
	return true


# +1 partie pour cette création ; renvoie le nouveau total (persisté immédiatement)
static func add_play(key: String, path := PATH) -> int:
	var plays := load_stats(path)
	var n := int(plays.get(key, 0)) + 1
	plays[key] = n
	save_stats(plays, path)
	return n


static func plays_of(plays: Dictionary, key: String) -> int:
	return int(plays.get(key, 0))
