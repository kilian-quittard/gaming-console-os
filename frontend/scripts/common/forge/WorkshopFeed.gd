extends RefCounted
class_name WorkshopFeed
# VUE du feed WORKSHOP : filtre (template) + recherche (nom) + tri.
# Pure logique de données — aucun I/O, aucune connaissance de l'UI → testable.

const SORTS: Array[String] = ["recent", "joués", "nom"]   # ordres de tri cyclables


# items = sortie de ProjectStore.workshop_list() ; plays = WorkshopStats.load_stats()
static func view(items: Array, tmpl_filter: String, sort_mode: String, query: String, plays: Dictionary) -> Array:
	var out := []
	var q := query.strip_edges().to_lower()
	for it in items:
		if typeof(it) != TYPE_DICTIONARY: continue
		if tmpl_filter != "" and String((it as Dictionary).get("template", "")) != tmpl_filter: continue
		if q != "" and not String((it as Dictionary).get("name", "")).to_lower().contains(q): continue
		out.append(it)
	match sort_mode:
		"joués":
			out.sort_custom(func(a, b) -> bool:
				return _plays_key(a, plays) > _plays_key(b, plays))
		"nom":
			out.sort_custom(func(a, b) -> bool:
				return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0)
		_:   # "recent" = plus récemment modifié d'abord
			out.sort_custom(func(a, b) -> bool:
				return int(a.get("mtime", 0)) > int(b.get("mtime", 0)))
	return out


# templates présents dans les items → cycle de filtres ["" (tous), "platformer", ...]
static func filters_of(items: Array) -> Array:
	var seen := {}
	var out := [""]
	for it in items:
		if typeof(it) != TYPE_DICTIONARY: continue
		var t := String((it as Dictionary).get("template", ""))
		if t != "" and not seen.has(t):
			seen[t] = true
			out.append(t)
	return out


static func _plays_key(it: Dictionary, plays: Dictionary) -> int:
	return int(plays.get(String(it.get("path", "")).get_file(), 0))
