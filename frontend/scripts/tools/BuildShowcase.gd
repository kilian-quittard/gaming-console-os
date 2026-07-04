extends SceneTree
# OUTIL headless : construit les JEUX VITRINES (pack-in) et les publie au WORKSHOP.
# Usage : Godot --headless --path forge --script res://scripts/tools/BuildShowcase.gd
# Écrit user://forge_workshop/*.spark + régénère index.json (préserve l'existant).
# Données pures — aucun code de gameplay ici, tout passe par le format projet.

const T = preload("res://scripts/common/templates/TemplateBase.gd")   # ids de tuiles (enum append-only)
const GY := 12            # rangée du sol (le monde joue au-dessus)


# ---------------------------------------------------------------- helpers data
func L(lname: String, cols: int, bg: int) -> Dictionary:
	return {"name": lname, "cols": cols, "bg": bg, "tiles": {}, "cfg": {}, "bg_deco": [], "rooms": []}


func put(lv: Dictionary, x: int, y: int, id: int) -> void:
	lv["tiles"]["%d,%d" % [x, y]] = id


func run(lv: Dictionary, x0: int, x1: int, y: int, id: int) -> void:
	for x in range(x0, x1 + 1): put(lv, x, y, id)


func cfg(lv: Dictionary, x: int, y: int, c: Dictionary) -> void:
	lv["cfg"]["%d,%d" % [x, y]] = c


func stairs_up(lv: Dictionary, x0: int, steps: int) -> void:
	# escalier en pentes 45° qui monte vers la droite depuis le sol
	for i in steps:
		put(lv, x0 + i, GY - 1 - i, T.SLOPE_R)
		for fy in range(GY - i, GY):   # remplissage sous la pente
			put(lv, x0 + i, fy, T.GROUND)


func stairs_down(lv: Dictionary, x0: int, steps: int) -> void:
	for i in steps:
		put(lv, x0 + i, GY - steps + i, T.SLOPE_L)
		for fy in range(GY - steps + i + 1, GY):
			put(lv, x0 + i, fy, T.GROUND)


# ---------------------------------------------------------------- jeu 1 : platformer
func build_hills() -> Dictionary:
	# ============ ZONE 1 — L'Envol (apprendre : sauter, pièces, ressort)
	var z1 := L("L'Envol", 56, 0)
	run(z1, 0, 55, GY, T.GROUND)
	put(z1, 2, GY - 1, T.SPAWN)
	run(z1, 5, 7, GY - 1, T.COIN)                 # 1res pièces au sol
	run(z1, 10, 12, GY - 3, T.GROUND)             # 1re plateforme
	run(z1, 10, 12, GY - 4, T.COIN)
	put(z1, 15, GY - 1, T.ENEMY)                  # 1er ennemi (marcheur)
	stairs_up(z1, 18, 3)                          # colline
	run(z1, 21, 22, GY - 4, T.GROUND)             # sommet plein (pas de trou sous le plateau)
	for x in range(21, 23):
		for fy in range(GY - 3, GY):
			put(z1, x, fy, T.GROUND)
	put(z1, 21, GY - 5, T.COIN); put(z1, 22, GY - 5, T.COIN)
	stairs_down(z1, 23, 3)
	put(z1, 27, GY - 1, T.CHECKPOINT)
	run(z1, 29, 31, GY, T.SPIKE)                  # fosse de piques...
	put(z1, 29, GY - 4, T.MOVPLAT)                # ...traversée en plateforme mobile
	put(z1, 35, GY - 1, T.SPRING)                 # ressort → corniche bonus
	run(z1, 36, 38, GY - 6, T.GROUND)
	run(z1, 36, 38, GY - 7, T.COIN)
	put(z1, 41, GY - 1, T.ENEMY)
	run(z1, 44, 46, GY - 1, T.COIN)
	put(z1, 48, GY - 1, T.HOPPER)                 # nouveauté juste avant la fin
	put(z1, 53, GY - 1, T.GOAL)

	# ============ ZONE 2 — Vertige (plateformes, interrupteur, friable)
	var z2 := L("Vertige", 64, 2)
	run(z2, 0, 8, GY, T.GROUND)
	put(z2, 2, GY - 1, T.SPAWN)
	run(z2, 9, 12, GY, T.SPIKE)                   # 1er vide piquant
	put(z2, 10, GY - 3, T.ONEWAY); put(z2, 12, GY - 5, T.ONEWAY)   # montée 1-sens
	run(z2, 13, 18, GY, T.GROUND)
	put(z2, 15, GY - 1, T.FLYER)                  # volant au-dessus du chemin
	run(z2, 14, 16, GY - 5, T.GROUND)             # corniche à pièces
	run(z2, 14, 16, GY - 6, T.COIN)
	put(z2, 19, GY - 1, T.SWITCH)                 # interrupteur rose...
	cfg(z2, 19, GY - 1, {"color": "rose"})
	run(z2, 19, 24, GY, T.GROUND)
	put(z2, 22, GY - 1, T.HOPPER)
	put(z2, 25, GY - 1, T.GATE)                   # ...ouvre la grille du raccourci
	cfg(z2, 25, GY - 1, {"color": "rose"})
	put(z2, 25, GY - 2, T.GATE)
	cfg(z2, 25, GY - 2, {"color": "rose"})
	run(z2, 25, 30, GY, T.GROUND)
	run(z2, 27, 29, GY - 1, T.COIN)               # récompense derrière la grille
	put(z2, 30, GY - 1, T.CHECKPOINT)
	run(z2, 31, 36, GY, T.SPIKE)                  # traversée en mobile
	put(z2, 31, GY - 4, T.MOVPLAT)
	run(z2, 37, 42, GY, T.GROUND)
	put(z2, 39, GY - 1, T.BOUNCER)
	run(z2, 43, 47, GY, T.SPIKE)                  # pont friable : cours !
	run(z2, 43, 47, GY - 2, T.CRUMBLE)
	run(z2, 48, 63, GY, T.GROUND)
	put(z2, 50, GY - 1, T.ENEMY)
	run(z2, 53, 55, GY - 3, T.GROUND)             # dernières marches
	run(z2, 53, 55, GY - 4, T.COIN)
	put(z2, 60, GY - 1, T.GOAL)

	# ============ ZONE 3 — La Fournaise (lave, triggers, boss)
	var z3 := L("La Fournaise", 72, 3)
	run(z3, 0, 6, GY, T.GROUND)
	put(z3, 2, GY - 1, T.SPAWN)
	run(z3, 7, 10, GY, T.LAVA)                    # 1re coulée de lave
	put(z3, 7, GY - 3, T.ONEWAY); put(z3, 9, GY - 4, T.ONEWAY)
	run(z3, 11, 18, GY, T.GROUND)
	put(z3, 13, GY - 1, T.SHOOTER)                # tourelle
	put(z3, 16, GY - 4, T.FIREBAR)                # barre de feu au-dessus du chemin
	run(z3, 15, 17, GY - 1, T.COIN)
	put(z3, 19, GY - 1, T.TRIGGER)                # trigger : message d'ambiance
	cfg(z3, 19, GY - 1, {"when": "entre", "do": "message", "msg": "Ça chauffe par ici..."})
	run(z3, 19, 26, GY, T.GROUND)
	put(z3, 21, GY - 1, T.CHASER)                 # fantôme
	run(z3, 23, 25, GY - 5, T.GROUND)             # corniche : 5 pièces du défi
	run(z3, 23, 25, GY - 6, T.COIN)
	put(z3, 24, GY - 1, T.COIN); put(z3, 26, GY - 1, T.COIN)
	put(z3, 27, GY - 1, T.CHECKPOINT)
	run(z3, 28, 33, GY, T.LAVA)                   # grande coulée + blocs tombants
	put(z3, 28, GY - 4, T.MOVPLAT)
	put(z3, 30, GY - 7, T.FALLBLOCK); put(z3, 32, GY - 7, T.FALLBLOCK)
	run(z3, 34, 45, GY, T.GROUND)
	put(z3, 36, GY - 1, T.SHOOTER)
	put(z3, 40, GY - 1, T.TRIGGER)                # trigger pièces : bonus caché
	cfg(z3, 40, GY - 1, {"when": "pièces", "n": 12, "do": "message", "msg": "Collectionneur ! ★"})
	put(z3, 43, GY - 1, T.TRIGGER)                # trigger : ouvre l'arène du boss
	cfg(z3, 43, GY - 1, {"when": "entre", "do": "ouvre", "color": "rouge"})
	put(z3, 46, GY - 1, T.GATE)
	cfg(z3, 46, GY - 1, {"color": "rouge"})
	put(z3, 46, GY - 2, T.GATE)
	cfg(z3, 46, GY - 2, {"color": "rouge"})
	put(z3, 46, GY - 3, T.GATE)
	cfg(z3, 46, GY - 3, {"color": "rouge"})
	run(z3, 46, 71, GY, T.GROUND)                 # ============ arène du boss
	put(z3, 58, GY - 4, T.BOSS)
	put(z3, 52, GY - 1, T.COIN); put(z3, 64, GY - 1, T.COIN)
	put(z3, 69, GY - 1, T.GOAL)

	return {
		"name": "Les Collines de SPARK", "dim": "2D", "template": "platformer",
		"author": "SPARK", "author_color": 0,
		"props": {},
		"screens": {"title": {"accent": "e67e22", "bg": 0, "bg_grad": true,
			"grid": 1, "grid_show": true,
			"subtitle": "3 zones · pièces · un boss t'attend",
			"deco": {}, "stamps": [], "panels": [], "texts": {}}},
		"levels": {"1": z1, "2": z2, "3": z3},
		"cur_level": "1",
		"progress": {"unlocked": 1},
	}


# ---------------------------------------------------------------- jeu 2 : donjon top-down
func build_dungeon() -> Dictionary:
	# 3 salles Zelda-like : épée → clé/porte → énigme dalle → boss → sortie
	var H := 13
	var z := L("Le Donjon", 42, 1)
	# enceinte + murs de séparation (portes au centre)
	run(z, 0, 41, 0, T.GROUND)
	run(z, 0, 41, H - 1, T.GROUND)
	for y in range(1, H - 1):
		put(z, 0, y, T.GROUND); put(z, 41, y, T.GROUND)
		put(z, 13, y, T.GROUND); put(z, 27, y, T.GROUND)
	put(z, 13, 6, T.DOOR)                          # salle 1 → 2 : clé
	cfg(z, 13, 6, {"color": "or"})
	put(z, 27, 6, T.DOOR)                          # salle 2 → 3 : clé
	cfg(z, 27, 6, {"color": "rouge"})
	# --- salle 1 : apprendre l'épée, clé gardée
	put(z, 3, 6, T.SPAWN)
	put(z, 6, 4, T.ENEMY); put(z, 8, 9, T.ENEMY)
	for y in range(2, 5): put(z, 9, y, T.GROUND)   # alcôve de la clé
	put(z, 10, 3, T.KEY)
	cfg(z, 10, 3, {"color": "or"})
	put(z, 10, 4, T.CHASER)                        # gardien
	put(z, 3, 3, T.BUSH); put(z, 4, 10, T.TREE); put(z, 10, 10, T.FLOWER)
	put(z, 6, 10, T.COIN); put(z, 11, 8, T.COIN)
	# --- salle 2 : énigme dalle + bloc, tourelle, clé rouge derrière la grille
	put(z, 17, 3, T.PLATE)
	put(z, 19, 6, T.PUSHBLOCK)
	for y in range(1, 5): put(z, 22, y, T.GROUND)  # enclos de la clé rouge
	put(z, 22, 5, T.GATE)                          # ouverte par la dalle (grille générique)
	put(z, 24, 2, T.KEY)
	cfg(z, 24, 2, {"color": "rouge"})
	put(z, 20, 9, T.SHOOTER); put(z, 16, 8, T.HOPPER)
	put(z, 25, 10, T.COIN); put(z, 15, 2, T.COIN)
	put(z, 18, 11, T.BUSH)
	# --- salle 3 : boss + sortie
	put(z, 34, 6, T.BOSS)
	put(z, 30, 3, T.COIN); put(z, 30, 9, T.COIN)
	put(z, 39, 6, T.GOAL)
	put(z, 29, 2, T.FLOWER); put(z, 38, 10, T.TREE)
	z["rooms"] = [[0, 0, 14, H], [14, 0, 14, H], [28, 0, 14, H]]
	return {
		"name": "Le Donjon d'Émeraude", "dim": "2D", "template": "topdown",
		"author": "SPARK", "author_color": 1,
		"props": {"player_hp": 3},
		"screens": {"title": {"accent": "2ecc71", "bg": 1, "bg_grad": true,
			"grid": 1, "grid_show": true,
			"subtitle": "3 salles · 2 clés · 1 gardien",
			"deco": {}, "stamps": [], "panels": [], "texts": {}}},
		"levels": {"1": z},
		"cur_level": "1",
		"progress": {"unlocked": 1},
	}


# ---------------------------------------------------------------- jeu 3 : metroid
func build_caverns() -> Dictionary:
	# exploration : tir → double-saut (déblocage) → missile → morph → sortie
	var z := L("Les Cavernes", 76, 1)
	run(z, 0, 75, GY, T.GROUND)
	put(z, 2, GY - 1, T.SPAWN)
	# couloir d'entrée : tir sur volant, pièces
	put(z, 8, GY - 3, T.FLYER)
	run(z, 5, 7, GY - 1, T.COIN)
	# porte à tir (mur + DOOR_BEAM)
	for y in range(GY - 5, GY): put(z, 14, y, T.GROUND)
	put(z, 14, GY - 1, T.DOOR_BEAM)
	put(z, 14, GY - 2, T.DOOR_BEAM)
	# salle 2 : corniches + piquant + réservoir d'énergie
	run(z, 18, 20, GY - 3, T.GROUND)
	run(z, 18, 20, GY - 4, T.COIN)
	put(z, 23, GY - 1, T.SPIKER)
	run(z, 25, 27, GY - 6, T.GROUND)
	put(z, 26, GY - 7, T.ENERGY)                   # +1 réservoir
	put(z, 29, GY - 1, T.CHECKPOINT)
	# fosse du double-saut : on y descend, on ne remonte qu'avec l'item
	run(z, 31, 39, GY, T.LAVA)                     # sol de la fosse = lave sauf îlot
	run(z, 34, 36, GY, T.GROUND)                   # îlot central
	put(z, 35, GY - 1, T.ITEM_DJUMP)               # ★ le déblocage
	for y in range(GY - 5, GY): put(z, 40, y, T.GROUND)   # mur de sortie (haut : double-saut)
	put(z, 31, GY - 4, T.ONEWAY); put(z, 33, GY - 2, T.ONEWAY)   # descente contrôlée
	# après le mur : gauntlet tourelle + fantôme
	run(z, 41, 55, GY, T.GROUND)
	put(z, 44, GY - 1, T.SHOOTER)
	put(z, 48, GY - 1, T.CHASER)
	run(z, 46, 48, GY - 5, T.GROUND)
	put(z, 47, GY - 6, T.ITEM_MISSILE)             # munitions pour la porte rouge
	put(z, 51, GY - 1, T.CHECKPOINT)
	# porte à missile (mur)
	for y in range(GY - 5, GY): put(z, 56, y, T.GROUND)
	put(z, 56, GY - 1, T.DOOR_MISSILE)
	put(z, 56, GY - 2, T.DOOR_MISSILE)
	# salle finale : morph ball → conduit bas → sortie
	run(z, 57, 75, GY, T.GROUND)
	put(z, 59, GY - 3, T.ONEWAY)
	run(z, 58, 60, GY - 5, T.GROUND)
	put(z, 59, GY - 6, T.ITEM_MORPH)               # ★ la morph ball
	for x in range(63, 67):                        # plafond bas : passage en boule
		for y in range(GY - 4, GY - 1): put(z, x, y, T.GROUND)
		put(z, x, GY - 1, T.MORPH_TUBE)
	run(z, 68, 70, GY - 1, T.COIN)
	put(z, 73, GY - 1, T.GOAL)
	return {
		"name": "Les Cavernes d'Écho", "dim": "2D", "template": "metroid",
		"author": "SPARK", "author_color": 6,
		"props": {},
		"screens": {"title": {"accent": "ff8a65", "bg": 1, "bg_grad": true,
			"grid": 1, "grid_show": true,
			"subtitle": "explore · débloque · reviens plus fort",
			"deco": {}, "stamps": [], "panels": [], "texts": {}}},
		"levels": {"1": z},
		"cur_level": "1",
		"progress": {"unlocked": 1},
	}


# ---------------------------------------------------------------- publication
func publish(proj: Dictionary) -> String:
	ProjectStore.ensure_workshop()
	var fp: String = ProjectStore.WORKSHOP_DIR + String(proj["name"]).replace(" ", "_") + ".spark"
	var f := FileAccess.open(fp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"spark": 1, "project": proj}))
	f.close()
	return fp


# régénère l'index depuis TOUS les .spark du dossier ; un .spark sans champ
# author garde l'auteur que l'ANCIEN index lui connaissait (pas d'écrasement en "?")
func rebuild_index() -> int:
	var dir := ProjectStore.WORKSHOP_DIR
	var old_by_file := {}
	var old = ProjectStore.load_file(dir + "index.json")
	if typeof(old) == TYPE_DICTIONARY:
		for c in (old as Dictionary).get("creations", []):
			if typeof(c) == TYPE_DICTIONARY:
				old_by_file[String((c as Dictionary).get("file", ""))] = c
	var creations := []
	var d := DirAccess.open(dir)
	for fn in d.get_files():
		if not fn.ends_with(".spark"): continue
		var p := ProjectStore.import_spark(dir + fn)
		if p.is_empty(): continue
		var prev: Dictionary = old_by_file.get(fn, {})
		creations.append({"name": String(p.get("name", prev.get("name", fn))),
			"author": String(p.get("author", prev.get("author", "?"))),
			"template": String(p.get("template", prev.get("template", "platformer"))),
			"dim": String(p.get("dim", prev.get("dim", "2D"))),
			"file": fn})
	var idx := FileAccess.open(dir + "index.json", FileAccess.WRITE)
	idx.store_string(JSON.stringify({"version": 1, "creations": creations}))
	idx.close()
	return creations.size()


func check(proj: Dictionary) -> String:
	# validation façon _validate_for_share : spawn + goal quelque part
	var has_spawn := false
	var has_goal := false
	var nt := 0
	for id in proj["levels"]:
		var tiles: Dictionary = proj["levels"][id]["tiles"]
		nt += tiles.size()
		for k in tiles:
			if int(tiles[k]) == T.SPAWN: has_spawn = true
			elif int(tiles[k]) == T.GOAL: has_goal = true
	if not has_spawn: return "SPAWN MANQUANT"
	if not has_goal: return "GOAL MANQUANT"
	return "ok (%d tuiles, %d zones)" % [nt, proj["levels"].size()]


func _initialize() -> void:
	var games := [build_hills(), build_dungeon(), build_caverns()]
	for g in games:
		var v := check(g)
		print("[vitrine] %s : %s" % [String(g["name"]), v])
		if not v.begins_with("ok"):
			quit(1); return
		var fp := publish(g)
		print("[vitrine] publié → %s" % fp)
	print("[vitrine] index : %d créations" % rebuild_index())
	quit()
