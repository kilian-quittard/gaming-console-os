extends Node2D
# SPARK FORGE — coquille générique : shell (écrans XSM), éditeur de niveau, chrome (UI),
# caméra/vue, fx, audio, sauvegarde de projets. Le GENRE (tuiles + simulation + rendu du
# monde + personnage XSM) vit dans un template à part (scripts/common/templates/...).

const CELL := 48
const TOPBAR := 52
const BOTTOM := 34
const LEVEL_COLS_DEF := 40
const TEMPLATES := {
	"2D": [{"id": "platformer", "name": "Plateformer"}, {"id": "topdown", "name": "Vue de dessus"}, {"id": "metroid", "name": "Metroidvania"}],
	"3D": [{"id": "plat3d", "name": "Plateformer 3D"}]
}
const CURSOR_DELAY := 0.25
const RATE_SLOW := 0.12
const RATE_FAST := 0.035
const DEADZONE := 0.35
const BG_THEMES := [
	[Color("1b2838"), Color("223349")], [Color("2c1b38"), Color("3a2349")],
	[Color("1b3826"), Color("224935")], [Color("382b1b"), Color("493a23")]
]
const PLATFORMER_PLAY := preload("res://scenes/game/PlatformerPlay.tscn")
# scènes de gameplay par genre (template). Ajoute ici un nouveau genre.
const TEMPLATE_SCENES := {
	"platformer": preload("res://scenes/game/PlatformerPlay.tscn"),
	"topdown": preload("res://scenes/game/TopDownPlay.tscn"),
	"metroid": preload("res://scenes/game/MetroidPlay.tscn"),
	"plat3d": preload("res://scenes/game/Plat3DPlay.tscn"),
}
var tmpl_kind := ""

# état éditeur
var grid := {}
var level_props := {}          # propriétés du niveau (autorun, ...) lues par le template
var cell_cfg := {}             # config par instance : Vector2i -> Dictionary (ex: plateforme mobile)
# panneau de configuration d'objet (case sous le curseur)
var cfg_open := false
var cfg_cell := Vector2i.ZERO
var cfg_idx := 0
var cfg_fields := []           # [{key,label,options,...}] selon la tuile
# mode "édition du fond" : vue parallax seule + placement de formes décoratives
var show_fps := false          # overlay FPS (debug)
var bg_edit := false
var bg_deco := []              # formes placées : [{shape,...,factor,col}]
var bg_ed: BgEditor = null     # module d'édition du fond
var cols := LEVEL_COLS_DEF
var rows := 14
var cursor := Vector2i(4, 8)
var pal := 0        # legacy: index palette plate (non utilisé si catégories actives)
var cat := 0        # catégorie active (0-4)
var cat_pal := [0, 0, 0, 0, 0, 0, 0]  # tuile sélectionnée par catégorie
var mode := "edit"             # "edit" | "play"
var cursor_cd := 0.0
var hold_time := 0.0
var last_dir := Vector2i.ZERO
var cursor_mode := "rapide"
var place_held := false
var erase_held := false
var bg_theme := 0

# pointeur libre (stick + souris) + déplacement de bloc
const AIM_SPEED := 950.0    # vitesse du pointeur au stick (px/s)
const EDGE_MARGIN := 150.0  # marge bord d'écran → pan caméra
const PAN_SPEED := 2400.0   # vitesse max de défilement caméra au bord (px/s)
var aim := Vector2(-1, -1)  # pointeur en pixels écran ; -1 = non initialisé
var cam_focus := Vector2.ZERO  # point monde affiché au centre de la zone d'édition
var cam_init := false
var grabbing := false       # un bloc posé est "ramassé" et suit le pointeur
var grab_tile := 0
var grab_from := Vector2i.ZERO
var grab_cfg := {}          # config de l'objet ramassé (déplacée avec lui)

# undo / redo
var undo_stack := []
var redo_stack := []

# menu radial / éditeur
var radial_open := false
var radial_pick := 0
var menu_open := false
var menu_idx := 0
var menu_items := []   # libellés affichés (dérivés de menu_def)
var menu_def := []     # entrées data-driven : {label, act: Callable, modal: bool}
var toast := ""
var toast_t := 0.0

# panneau IA
var ai_open := false
var ai_prompt := ""
var ai_cursor := 0
var ai_state := "idle"   # "idle" | "thinking" | "done" | "error"
var ai_result := ""

# sélection / copier-coller
var sel_mode := false
var sel_anchor := Vector2i(-1, -1)
var clipboard := {}
var clip_size := Vector2i.ZERO

# vue (partagée avec le template pour le rendu du monde)
var view_origin := Vector2.ZERO
var view_scale := 1.0
var dezoom := false

# fx
var particles := []
var shake_t := 0.0
var shake_mag := 0.0
var squash := Vector2.ONE

# shell
var screen := "dim"
var cur_dim := "2D"
var cur_template := "platformer"
var cur_project := ""
var proj_list := []
var sel := 0
# import de créations (.spark) : modal par-dessus l'écran liste
var import_open := false
var import_list := []
var import_sel := 0
# WORKSHOP v0 : feed des créations (écran propre, via screen="workshop")
var workshop_items := []
var workshop_sel := 0
var from_workshop := false   # le jeu a été lancé depuis le WORKSHOP → y retourner en quittant
var workshop_all := []       # liste brute (source) ; workshop_items = vue filtrée/triée
var workshop_filter := ""    # filtre template ("" = tous)
var workshop_sort := "recent"   # tri courant (cycle WorkshopFeed.SORTS)
var workshop_query := ""     # recherche par nom (clavier)
var workshop_search := false # true = la saisie clavier édite la recherche
var workshop_plays := {}     # stats locales {fichier: nb parties} (WorkshopStats)
var creator := {}            # profil créateur local {name, color} (CreatorProfile)
var shell_workshop := false  # booté par la tuile WORKSHOP du shell → B au feed = retour home
var profile_open := false    # modal d'édition du profil (écran Projets)
var cur_author := ""         # identité du projet ouvert (affichée à l'écran titre)
var cur_author_color := 0
var cur_remix_of := ""       # crédit remix : nom de la création originale
var cur_remix_by := ""       # crédit remix : auteur de l'originale

# game config (couleurs, sous-titre — partagé avec GameShell)
var anim_t := 0.0
var ui_sel_f := 0.0   # position lissée du sélecteur (écrans shell : liste/dim/templates)

# ---- MODE JEU COMPLET (campagne) : écran titre → zones enchaînées → fin ----
var game_mode := false      # true = on joue le jeu (pas un test d'éditeur)
var game_stage := ""        # title | select | complete | over | end
var game_sel := 0           # sélection dans l'écran de zones
var game_lives := 3         # vies de la zone en cours
var game_zone_i := 0        # index de la zone jouée (dans level_ids())
var game_unlocked := 1      # zones débloquées (persisté dans le projet)
var game_win_t := 0.0       # délai de fête avant l'écran "zone terminée"
var game_over_t := 0.0      # délai avant l'écran game over (laisse l'anim de mort)
var game_total_time := 0.0  # stats cumulées du run
var game_total_coins := 0
var game_zone_time := 0.0   # stats de la zone qui vient d'être finie (écran complete)
var game_zone_coins := 0
var game_zone_ctotal := 0

# gamedash / screenedit (vue d'ensemble projet + éditeur d'écrans)
var dash_sel := 0
var edit_screen_key := ""
var edit_prop_sel := 0
var text_edit_mode := false
var text_edit_cursor := 0

# données des écrans (déco/tampons/textes), par clé d'écran
var screens := {}

# éditeur canvas d'écran
enum { TOOL_PINCEAU, TOOL_GOMME, TOOL_TAMPON, TOOL_PANNEAU, TOOL_TEXTE, TOOL_STYLE }
const TOOL_NAMES := ["Pinceau", "Gomme", "Tampon", "Panneau", "Texte", "Style"]
var se_tool := TOOL_PINCEAU
var se_cursor := Vector2i(8, 4)         # case grille (résolution variable)
var se_color := 0                       # index palette déco
var se_shape := 0                       # index forme tampon
var se_stamp_size := 0.12               # taille tampon (fraction de hauteur)
var se_stamp_alpha := 1.0
var se_stamp_outline := false
var se_text_sel := 1                    # élément texte sélectionné (0=brand..3=prompt)
var se_place_held := false
var se_erase_held := false
# panneau (création par 2 coins)
var se_panel_anchor := Vector2i(-1, -1)
var se_panel_radius := 0.25
var se_panel_alpha := 0.9
var se_panel_outline := false

# tuiles groupées par catégorie (IDs depuis l'enum PlatformerTemplate)
# palette de l'éditeur : fournie PAR LE TEMPLATE (genre) via tmpl.categories()
func _cats() -> Array:
	return tmpl.categories() if tmpl else []

const UI_ACCENT := Color("f39c12")    # accent du chrome FORGE (≠ accent des écrans de jeu)
const ACCENT_PALETTE := [
	Color("3498db"), Color("e74c3c"), Color("2ecc71"), Color("f39c12"),
	Color("9b59b6"), Color("1abc9c"), Color("e67e22"), Color("ecf0f1")
]
const DASH_ITEMS := ["Éditeur de niveaux", "Écran titre", "Sélection niveaux", "Pause", "Niveau terminé", "Game Over"]
const DASH_KEYS  := ["editor",             "title",       "select",            "pause", "complete",        "gameover"]
const TEXT_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !'?-."

# audio
var audio: ForgeAudio

# template de jeu actif (le genre) + machine d'écrans (XSM)
var tmpl: TemplateBase = null
@onready var states: State = $States

# style graphique rétro : délégué au module GfxStyles
var gfx: GfxStyles = null
var rooms := []                  # salles (style Celeste) : Array[Rect2i] en cases
var cur_room := -1               # salle courante (le joueur dedans)
# multi-niveaux : un projet = N niveaux interconnectés par des tuiles WARP.
# Le niveau ACTIF vit dans grid/cell_cfg/bg_deco/rooms/cols/bg_theme ;
# les autres sont rangés (format natif) dans levels[id].
var levels := {}                 # id (String) -> niveau rangé (format natif)
var cur_level := "1"
var cur_level_name := ""         # nom de la ZONE active ("Cavernes"...)
var lvl_rename := false          # saisie du nom de zone en cours
var map_open := false            # minimap affichée (en test)
var insp_cell := Vector2i(-999, -999)   # objet épinglé par l'inspecteur
var insp_panel := Rect2()               # rect du panneau (hit-test pointeur)
var insp_rows := []                     # rects des lignes (hit-test pointeur)
var erase_last := Vector2i(-999, -999)  # dernière case effacée du stroke (1 couche/case)
var visited_rooms := {}          # "niveau:salle" -> true (brouillard de la minimap, par run)
var warp_cd := 0.0               # anti re-déclenchement du warp à l'arrivée
var play_backup := {}            # id -> état AUTEUR des niveaux visités pendant le test
								 # (le jeu mute la grille : pièces/objets pris, portes ouvertes ;
								 #  restauré en sortant du test ou en relançant — mais PAS au
								 #  retour dans une zone pendant la même partie)
var room_edit := false           # mode édition des salles
var room_ed: RoomEditor = null   # module d'édition des salles


func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	gfx = GfxStyles.new(self)
	_compute_grid()
	_build_audio()
	room_ed = RoomEditor.new(self)
	bg_ed = BgEditor.new(self)
	ProjectStore.ensure_dir()
	creator = CreatorProfile.load_profile()
	# instancie le template du genre courant (rendu du monde + simulation)
	_load_template(cur_template)
	queue_redraw()
	if OS.get_cmdline_args().has("--selftest"):
		call_deferred("_self_test")
	# lancé par le shell console (même fenêtre, meta) ou en standalone (--args)
	if OS.get_cmdline_args().has("--shell") and not _embedded():
		get_window().mode = Window.MODE_FULLSCREEN   # standalone lancé par un shell externe
	if OS.get_cmdline_args().has("--workshop") or bool(get_tree().root.get_meta("spark_open_workshop", false)):
		call_deferred("_boot_workshop")   # après l'entrée du state machine (Dim)


# true = FORGE tourne DANS l'app shell (même fenêtre, chargé par changement de scène)
func _embedded() -> bool:
	return get_tree().root.has_meta("spark_shell")


# rend la main au shell : retour à la scène home (embarqué) ou fin de process
func _exit_to_shell() -> void:
	if _embedded():
		var root := get_tree().root
		root.remove_meta("spark_shell")
		if root.has_meta("spark_open_workshop"): root.remove_meta("spark_open_workshop")
		root.set_meta("spark_return", true)   # le home saute le splash
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		get_tree().quit()


# HOME : suspend (façon Switch) — la scène FORGE est DÉTACHÉE de l'arbre sans
# être libérée (état/vars/partie intacts, plus aucun process), le home revient.
# La reprise (Main._resume_forge) ré-attache ce même nœud tel quel.
func _suspend_to_shell() -> void:
	# pas de _stop_play : détaché = plus de _process → une partie en cours GÈLE
	# telle quelle et reprend exactement là où elle était (façon Switch)
	var tree := get_tree()
	var root := tree.root
	root.set_meta("spark_suspended", self)
	root.set_meta("spark_return", true)
	root.remove_child(self)
	var m: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	tree.current_scene = m


# lancé par le shell console (--workshop) : direct sur le feed de la commu
func _boot_workshop() -> void:
	cur_dim = "2D"
	shell_workshop = true
	_scan_projects(cur_dim)   # B depuis le feed → liste projets déjà remplie
	_open_workshop()


func _load_template(kind: String) -> void:
	# (re)charge la scène de gameplay du genre demandé ; swap si différent du courant
	if kind == tmpl_kind and tmpl != null:
		return
	if tmpl != null:
		tmpl.queue_free()
		tmpl = null
	var scene = TEMPLATE_SCENES.get(kind, TEMPLATE_SCENES["platformer"])
	tmpl_kind = kind if TEMPLATE_SCENES.has(kind) else "platformer"
	tmpl = scene.instantiate()
	add_child(tmpl)
	gfx.attach_world(tmpl)   # skin + pixelisation par-dessus le monde
	tmpl.setup(self)
	# mode jeu : chaque mort réelle coûte une vie (reconnecté à chaque swap de genre)
	tmpl.player_died.connect(func() -> void:
		if game_mode: _game_player_died())
	gfx.apply()
	# adapte cat_pal au nombre de catégories du genre
	cat_pal = []
	for _i in tmpl.categories().size(): cat_pal.append(0)
	cat = clampi(cat, 0, maxi(0, cat_pal.size() - 1))


# cache les marges autour de la salle courante (on ne voit QUE la salle)
func _draw_room_mask(vp: Vector2) -> void:
	var r: Rect2i = rooms[cur_room]
	var p0 := _w2s(Vector2(r.position) * CELL)
	var sz := Vector2(r.size) * CELL * view_scale
	var area_top := float(TOPBAR)
	var area_bot := vp.y - BOTTOM
	var col := Color("0a0d12")
	# bandes haut / bas / gauche / droite (limitées à la zone de jeu)
	if p0.y > area_top:
		draw_rect(Rect2(Vector2(0, area_top), Vector2(vp.x, p0.y - area_top)), col)
	if p0.y + sz.y < area_bot:
		draw_rect(Rect2(Vector2(0, p0.y + sz.y), Vector2(vp.x, area_bot - (p0.y + sz.y))), col)
	if p0.x > 0:
		draw_rect(Rect2(Vector2(0, p0.y), Vector2(p0.x, sz.y)), col)
	if p0.x + sz.x < vp.x:
		draw_rect(Rect2(Vector2(p0.x + sz.x, p0.y), Vector2(vp.x - (p0.x + sz.x), sz.y)), col)


func _self_test() -> void:
	var dt := 1.0 / 60.0
	rows = 14
	cols = 24
	grid.clear()
	for x in range(cols):
		grid[Vector2i(x, rows - 1)] = tmpl.GROUND
	for i in range(5):
		grid[Vector2i(6 + i, rows - 2 - i)] = tmpl.SLOPE_R
		for fy in range(rows - 1 - i, rows - 1):
			grid[Vector2i(6 + i, fy)] = tmpl.GROUND
	grid[Vector2i(2, rows - 2)] = tmpl.SPAWN
	tmpl.testing = true
	mode = "play"
	screen = "edit"
	tmpl.start_play(false)
	print("=== CLIMB (vers la droite, y doit DIMINUER) ===")
	tmpl.test_dir = 1
	for f in range(170):
		tmpl._physics_process(dt)
		if f % 17 == 0:
			print("f%3d x=%4.0f y=%4.0f floor=%s" % [f, tmpl.ppos.x, tmpl.ppos.y, str(tmpl.on_floor)])
	print("=== DESCEND (vers la gauche, y doit AUGMENTER) ===")
	var pt: PlatformerTemplate = tmpl   # accès aux champs sonic (debug)
	tmpl.test_dir = -1
	for f in range(170):
		tmpl._physics_process(dt)
		if f % 17 == 0:
			print("f%3d x=%4.0f y=%4.0f floor=%s" % [f, tmpl.ppos.x, tmpl.ppos.y, str(tmpl.on_floor)])

	print("=== SONIC CLIMB (sonic ON, vers la droite, y doit DIMINUER, sgr=true) ===")
	level_props = {"sonic": true}
	tmpl.start_play(false)
	tmpl.ppos.y -= 4.0
	tmpl.test_dir = 1
	for f in range(220):
		tmpl._physics_process(dt)
		if f % 20 == 0:
			print("f%3d x=%4.0f y=%4.0f sgr=%s gsp=%5.0f ang=%+.2f" % [f, tmpl.ppos.x, tmpl.ppos.y, str(pt.sonic_grounded), pt.gsp, pt.gangle])
	level_props = {}

	print("=== TRIGGERS (entre→ouvre grille ; chrono→message ; pièces→apparait) ===")
	grid.clear(); cell_cfg.clear()
	for x in range(cols):
		grid[Vector2i(x, rows - 1)] = tmpl.GROUND
	grid[Vector2i(2, rows - 2)] = tmpl.SPAWN
	grid[Vector2i(5, rows - 2)] = tmpl.TRIGGER
	cell_cfg[Vector2i(5, rows - 2)] = {"when": "entre", "do": "ouvre", "color": "rouge"}
	grid[Vector2i(8, rows - 2)] = tmpl.GATE
	cell_cfg[Vector2i(8, rows - 2)] = {"color": "rouge"}
	grid[Vector2i(10, rows - 2)] = tmpl.TRIGGER
	cell_cfg[Vector2i(10, rows - 2)] = {"when": "chrono", "n": 1, "do": "message", "msg": "CHRONO OK"}
	grid[Vector2i(12, rows - 2)] = tmpl.TRIGGER
	cell_cfg[Vector2i(12, rows - 2)] = {"when": "pièces", "n": 1, "do": "apparait"}
	tmpl.start_play(false)
	tmpl.test_dir = 1
	var seen_gate := false
	for f in range(240):
		tmpl._physics_process(dt)
		if not tmpl.open_gate_cells.is_empty(): seen_gate = true
		if f == 120: tmpl.coins_got = 1   # simule un ramassage → trigger "pièces"
	print("gate ouverte par trigger: %s (attendu true)" % str(seen_gate))
	print("toast chrono: '%s' (attendu CHRONO OK)" % toast)
	print("ennemis spawned: %d (attendu 1)" % tmpl.enemies.size())
	print("triggers tirés: %d / 3" % tmpl.trig_fired.size())

	print("=== CO-OP P2 (spawn, gravité→sol, leash) ===")
	level_props = {"coop": true}
	cols = 40   # map large : le leash (800) doit se déclencher avant le clamp du bord
	grid.clear(); cell_cfg.clear()
	for x in range(cols):
		grid[Vector2i(x, rows - 1)] = tmpl.GROUND
	grid[Vector2i(2, rows - 2)] = tmpl.SPAWN
	tmpl.test_dir = 0   # P1 immobile pendant ce test
	tmpl.start_play(false)
	print("p2 actif: %s (attendu true)" % str(not tmpl.p2.is_empty()))
	tmpl.p2.pos = Vector2(tmpl.p2.pos.x, tmpl.p2.pos.y - 150.0)   # lâché en l'air
	for f in range(90):
		tmpl._physics_process(dt)
	var on_ground: bool = bool(tmpl.p2.floor)
	var resting_y: float = float(tmpl.p2.pos.y)
	print("p2 au sol: %s (attendu true)  y=%.0f (attendu %.0f)" % [str(on_ground), resting_y, float((rows - 1) * 48) - tmpl.PSIZE.y])
	tmpl.p2.pos = Vector2(tmpl.ppos.x + 900.0, tmpl.ppos.y)       # décroché (> seuil leash 800)
	tmpl._physics_process(dt)
	var dist: float = (Vector2(tmpl.p2.pos) - tmpl.ppos).length()
	print("p2 ramené près de P1: %s (dist=%.0f, attendu < 200)" % [str(dist < 200.0), dist])
	level_props = {}

	print("=== IDENTITÉ (profil créateur → signature du save) ===")
	var ppath := "user://_selftest_profile.json"
	CreatorProfile.save_profile({"name": "Kilian", "color": 3}, ppath)
	creator = CreatorProfile.load_profile(ppath)
	print("profil round-trip : %s / %d (attendu Kilian / 3)" % [String(creator["name"]), int(creator["color"])])

	print("=== PARTAGE (.spark export → import → round-trip) ===")
	cur_dim = "2D"; cur_template = "platformer"; cur_project = "SelftestShare"
	grid.clear(); cell_cfg.clear(); levels = {}; cur_level = "1"; screens = {}; level_props = {}
	game_unlocked = 1
	for x in range(cols): grid[Vector2i(x, rows - 1)] = tmpl.GROUND
	grid[Vector2i(2, rows - 2)] = tmpl.SPAWN
	grid[Vector2i(10, rows - 2)] = tmpl.GOAL
	print("validation (spawn+goal) : '%s' (attendu vide)" % _validate_for_share())
	var sp := ProjectStore.export_spark(_build_save_dict())
	print("export : %s" % ("ok " + sp.get_file() if sp != "" else "ECHEC"))
	var back := ProjectStore.import_spark(sp)
	var nt: int = int((back.get("levels", {}).get("1", {}).get("tiles", {}) as Dictionary).size()) if back.has("levels") else -1
	print("import : name='%s', tiles zone1=%d (attendu >0)" % [String(back.get("name", "")), nt])
	print("signature : author='%s' (attendu Kilian)" % String(back.get("author", "")))
	grid.erase(Vector2i(10, rows - 2))   # plus de goal
	print("validation sans goal : '%s' (attendu non vide)" % _validate_for_share())

	print("=== WORKSHOP v0 (index local → liste) ===")
	# dossier temp ISOLÉ : ne pas écraser le vrai forge_workshop de l'utilisateur
	var wdir := "user://_selftest_workshop/"
	DirAccess.make_dir_recursive_absolute(wdir)
	var rd := FileAccess.open(sp, FileAccess.READ)   # sp = .spark valide exporté plus haut
	var content := rd.get_as_text(); rd.close()
	var wf := FileAccess.open(wdir + "selftest.spark", FileAccess.WRITE)
	wf.store_string(content); wf.close()
	var idxf := FileAccess.open(wdir + "index.json", FileAccess.WRITE)
	idxf.store_string(JSON.stringify({"version": 1, "creations": [
		{"name": "Niveau Démo", "author": "SPARK", "template": "platformer", "dim": "2D", "file": "selftest.spark"}]}))
	idxf.close()
	var wl := ProjectStore.workshop_list(wdir)
	print("workshop entries : %d (attendu >=1)" % wl.size())
	if wl.size() > 0:
		print("  -> '%s' par %s (%s)  mtime>0:%s" % [String(wl[0]["name"]), String(wl[0]["author"]),
			String(wl[0]["dim"]), str(int(wl[0]["mtime"]) > 0)])

	print("=== REMIX (make_remix : nouveau nom + crédit à l'original) ===")
	var rx := ProjectStore.make_remix(back, "Rival", 5)
	print("remix name='%s' (attendu commence par 'Remix de')" % String(rx.get("name", "")))
	print("remix_of='%s' / remix_by='%s' (attendu SelftestShare / Kilian)" % [String(rx.get("remix_of", "")), String(rx.get("remix_by", ""))])
	print("remix author='%s' (attendu Rival)  progress reset:%s" % [String(rx.get("author", "")),
		str(int(rx.get("progress", {}).get("unlocked", -1)) == 1)])

	print("=== STATS (compteur de parties local) ===")
	var spath := "user://_selftest_stats.json"
	WorkshopStats.save_stats({}, spath)   # reset isolé
	WorkshopStats.add_play("demo.spark", spath)
	var n2 := WorkshopStats.add_play("demo.spark", spath)
	print("plays demo.spark = %d (attendu 2)" % n2)
	print("plays inconnu = %d (attendu 0)" % WorkshopStats.plays_of(WorkshopStats.load_stats(spath), "autre.spark"))

	print("=== FEED (filtre + recherche + tri) ===")
	var fake := [
		{"name": "Château Rouge", "template": "platformer", "path": "a.spark", "mtime": 30},
		{"name": "Donjon Sombre", "template": "topdown", "path": "b.spark", "mtime": 20},
		{"name": "Château Bleu", "template": "platformer", "path": "c.spark", "mtime": 10},
	]
	var pl := {"c.spark": 9, "a.spark": 1}
	print("filtre topdown : %d (attendu 1)" % WorkshopFeed.view(fake, "topdown", "recent", "", pl).size())
	print("recherche 'château' : %d (attendu 2)" % WorkshopFeed.view(fake, "", "recent", "château", pl).size())
	print("tri joués 1er = '%s' (attendu Château Bleu)" % String((WorkshopFeed.view(fake, "", "joués", "", pl)[0] as Dictionary)["name"]))
	print("tri récent 1er = '%s' (attendu Château Rouge)" % String((WorkshopFeed.view(fake, "", "recent", "", pl)[0] as Dictionary)["name"]))
	print("filtres présents : %s (attendu ['', platformer, topdown])" % str(WorkshopFeed.filters_of(fake)))

	level_props = {}
	get_tree().quit()


func _compute_grid() -> void:
	var vp := get_viewport_rect().size
	rows = max(6, int((vp.y - TOPBAR - BOTTOM) / CELL))


# ============================================================= AUDIO
# audio délégué au module ForgeAudio (SFX synthétisés + musique)
func _build_audio() -> void:
	audio = ForgeAudio.new()
	add_child(audio)


func _play(sname: String) -> void:
	audio.play(sname)



# ============================================================= INPUT
func _press(e: InputEvent, keys: Array, btns: Array) -> bool:
	if e is InputEventKey and e.pressed and not e.echo:
		return keys.has(e.keycode)
	if e is InputEventJoypadButton and e.pressed:
		return btns.has(e.button_index)
	return false


func _is_btn(e: InputEvent, keys: Array, btns: Array, pressed: bool) -> bool:
	if e is InputEventKey and not e.echo and e.pressed == pressed:
		return keys.has(e.keycode)
	if e is InputEventJoypadButton and e.pressed == pressed:
		return btns.has(e.button_index)
	return false


func _unhandled_input(e: InputEvent) -> void:
	# bouton HOME (façon Switch) : suspend la session FORGE et retourne au menu —
	# l'état complet reste vivant, la tuile du shell propose « reprendre »
	if _embedded() and _press(e, [KEY_HOME, KEY_F1], [JOY_BUTTON_GUIDE]):
		_suspend_to_shell(); return
	if screen == "dim":        _dim_input(e); return
	if screen == "list":       _list_input(e); return
	if screen == "template":   _tmpl_input(e); return
	if screen == "gamedash":   _gamedash_input(e); return
	if screen == "screenedit": _screenedit_input(e); return
	if screen == "game":       _game_input(e); return
	if screen == "workshop":   _workshop_input(e); return
	if lvl_rename: _rename_input(e); return
	if ai_open:    _ai_panel_input(e); return
	if cfg_open:   _config_input(e); return
	if bg_edit:    bg_ed.input(e); return
	if room_edit:  room_ed.input(e); return
	if menu_open:
		_menu_input(e); return
	if mode == "edit":
		_edit_input(e)
	else:
		_play_input(e)


func _dim_input(e: InputEvent) -> void:
	# lancé par le shell console : B sur l'écran racine = rendre la main au shell
	if (_embedded() or OS.get_cmdline_args().has("--shell")) and _press(e, [KEY_ESCAPE], [JOY_BUTTON_B]):
		_exit_to_shell(); return
	if _press(e, [KEY_LEFT, KEY_UP], [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP]):
		sel = 0; queue_redraw()
	elif _press(e, [KEY_RIGHT, KEY_DOWN], [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]):
		sel = 1; queue_redraw()
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		cur_dim = "2D" if sel == 0 else "3D"
		states.change_state("ListState")


func _list_input(e: InputEvent) -> void:
	if import_open:
		_import_input(e); return
	if profile_open:
		_profile_input(e); return
	if _press(e, [KEY_P], [JOY_BUTTON_Y]):
		profile_open = true; queue_redraw(); return
	# entrées = projets + "Nouveau" + "Importer" + "WORKSHOP"
	var np := proj_list.size()
	var n := np + 3
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		sel = (sel + 1) % n; queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		sel = (sel - 1 + n) % n; queue_redraw()
	elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		states.change_state("DimState")
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		if sel < np:
			_open_project(proj_list[sel])
		elif sel == np:
			states.change_state("TemplateState")
		elif sel == np + 1:
			_open_import()
		else:
			_open_workshop()


func _open_import() -> void:
	import_list = ProjectStore.list_spark().filter(func(s): return String(s["dim"]) == cur_dim)
	import_sel = 0
	import_open = true
	queue_redraw()


func _import_input(e: InputEvent) -> void:
	if _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		import_open = false; queue_redraw(); return
	if import_list.is_empty():
		return
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		import_sel = (import_sel + 1) % import_list.size(); queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		import_sel = (import_sel - 1 + import_list.size()) % import_list.size(); queue_redraw()
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		_do_import(import_list[import_sel])


func _do_import(entry: Dictionary) -> void:
	var proj := ProjectStore.import_spark(String(entry["path"]))
	if proj.is_empty():
		_set_toast("Import impossible (fichier illisible)"); return
	# nom unique : ne pas écraser un projet existant
	var nm := ProjectStore.unique_name(String(proj.get("name", "Création importée")))
	proj["name"] = nm
	ProjectStore.save(proj)
	proj_list = ProjectStore.list(cur_dim)
	import_open = false
	sel = 0
	_set_toast("Importé : %s" % nm)
	queue_redraw()


# ============================================================= PROFIL CRÉATEUR
# modal simple : clavier = nom, ◄► = couleur d'avatar, A/Entrée = valider
func _profile_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		var k := e as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_ESCAPE:
			_profile_close(); return
		if k.keycode == KEY_BACKSPACE:
			creator["name"] = String(creator["name"]).substr(0, maxi(0, String(creator["name"]).length() - 1))
			queue_redraw(); return
		if k.keycode == KEY_LEFT:
			_profile_color(-1); return
		if k.keycode == KEY_RIGHT:
			_profile_color(1); return
		if k.unicode > 31 and String(creator["name"]).length() < 16:
			creator["name"] = String(creator["name"]) + char(k.unicode)
			queue_redraw()
		return
	if _press(e, [], [JOY_BUTTON_DPAD_LEFT]):
		_profile_color(-1); return
	if _press(e, [], [JOY_BUTTON_DPAD_RIGHT]):
		_profile_color(1); return
	if _press(e, [], [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]):
		_profile_close(); return


func _profile_color(dir: int) -> void:
	var n := CreatorProfile.AVATAR_COLORS.size()
	creator["color"] = (int(creator.get("color", 0)) + dir + n) % n
	queue_redraw()


func _profile_close() -> void:
	if String(creator.get("name", "")).strip_edges() == "":
		creator["name"] = CreatorProfile.DEFAULT_NAME
	CreatorProfile.save_profile(creator)
	profile_open = false
	_set_toast("Profil : %s" % String(creator["name"]))
	queue_redraw()


# ============================================================= WORKSHOP v0
func _open_workshop(reset := true) -> void:
	workshop_all = ProjectStore.workshop_list()   # v0 = dossier local ; v1 = HTTPRequest
	for it in workshop_all:                        # mini-rendu mis en cache (1 fois à l'ouverture)
		it["thumb"] = _spark_thumb(String(it["path"]))
	workshop_plays = WorkshopStats.load_stats()
	if reset:
		workshop_filter = ""; workshop_query = ""; workshop_search = false
	_workshop_refresh(reset)
	screen = "workshop"
	queue_redraw()


# reconstruit la vue (filtre + recherche + tri) depuis la liste brute
func _workshop_refresh(reset_sel := false) -> void:
	workshop_items = WorkshopFeed.view(workshop_all, workshop_filter, workshop_sort, workshop_query, workshop_plays)
	if reset_sel: workshop_sel = 0
	else: workshop_sel = clampi(workshop_sel, 0, maxi(0, workshop_items.size() - 1))


func _workshop_cycle_filter(dir: int) -> void:
	var fl := WorkshopFeed.filters_of(workshop_all)
	var i := fl.find(workshop_filter)
	if i < 0: i = 0
	workshop_filter = String(fl[(i + dir + fl.size()) % fl.size()])
	_workshop_refresh(true)
	queue_redraw()


# parse une fois un .spark → cellules colorées de sa 1re zone (pour la miniature du feed)
func _spark_thumb(path: String) -> Dictionary:
	var out := {"cells": [], "mx": 16, "my": 10}
	var proj := ProjectStore.import_spark(path)
	if proj.is_empty(): return out
	var lvls = proj.get("levels", {})
	if typeof(lvls) != TYPE_DICTIONARY or (lvls as Dictionary).is_empty(): return out
	var firstid := String((lvls as Dictionary).keys()[0])
	var cur := String(proj.get("cur_level", ""))
	if (lvls as Dictionary).has(cur): firstid = cur
	var tiles = (lvls as Dictionary)[firstid].get("tiles", {})
	var mx := 16; var my := 10
	var cells := []
	for k in tiles:
		var parts: PackedStringArray = String(k).split(",")
		if parts.size() < 2: continue
		var x := int(parts[0]); var y := int(parts[1])
		mx = maxi(mx, x + 1); my = maxi(my, y + 1)
		cells.append([x, y, tmpl.COLORS.get(int(tiles[k]), Color.GRAY)])
	return {"cells": cells, "mx": mx, "my": my}


func _draw_thumb(r: Rect2, thumb: Dictionary) -> void:
	draw_rect(r, Color("0d1117"))
	var cells: Array = thumb.get("cells", [])
	if cells.is_empty():
		_ctext(ThemeDB.fallback_font, r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.58, "(vide)", Color(1, 1, 1, 0.3), 11)
		return
	var mx: float = float(thumb.get("mx", 16))
	var my: float = float(thumb.get("my", 10))
	var sc: float = minf((r.size.x - 4.0) / mx, (r.size.y - 4.0) / my)
	var ox: float = r.position.x + (r.size.x - mx * sc) * 0.5
	var oy: float = r.position.y + (r.size.y - my * sc) * 0.5
	for c in cells:
		draw_rect(Rect2(ox + float(c[0]) * sc, oy + float(c[1]) * sc, maxf(sc, 1.0), maxf(sc, 1.0)), c[2])


func _workshop_input(e: InputEvent) -> void:
	# mode recherche : la saisie clavier édite la requête (filtre live)
	if workshop_search:
		if e is InputEventKey and (e as InputEventKey).pressed:
			var k := e as InputEventKey
			if k.keycode == KEY_ENTER:
				workshop_search = false; queue_redraw(); return
			if k.keycode == KEY_ESCAPE:
				workshop_query = ""; workshop_search = false; _workshop_refresh(true); queue_redraw(); return
			if k.keycode == KEY_BACKSPACE:
				workshop_query = workshop_query.substr(0, maxi(0, workshop_query.length() - 1))
				_workshop_refresh(true); queue_redraw(); return
			if k.unicode > 31 and workshop_query.length() < 24:
				workshop_query += char(k.unicode)
				_workshop_refresh(true); queue_redraw()
		return
	if _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		if workshop_query != "" or workshop_filter != "":   # 1er B = enlever filtres, 2e = sortir
			workshop_query = ""; workshop_filter = ""; _workshop_refresh(true); queue_redraw(); return
		if shell_workshop and _embedded():   # venu de la tuile WORKSHOP → retour home direct
			_exit_to_shell(); return
		screen = "list"; queue_redraw(); return
	if _press(e, [KEY_S, KEY_SLASH], []):
		workshop_search = true; queue_redraw(); return
	if _press(e, [KEY_T], [JOY_BUTTON_Y]):   # tri suivant (récent → joués → nom)
		var i := WorkshopFeed.SORTS.find(workshop_sort)
		workshop_sort = String(WorkshopFeed.SORTS[(i + 1) % WorkshopFeed.SORTS.size()])
		_workshop_refresh(true); queue_redraw(); return
	if _press(e, [KEY_RIGHT, KEY_F], [JOY_BUTTON_RIGHT_SHOULDER]):
		_workshop_cycle_filter(1); return
	if _press(e, [KEY_LEFT], [JOY_BUTTON_LEFT_SHOULDER]):
		_workshop_cycle_filter(-1); return
	if workshop_items.is_empty():
		return
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		workshop_sel = (workshop_sel + 1) % workshop_items.size(); queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		workshop_sel = (workshop_sel - 1 + workshop_items.size()) % workshop_items.size(); queue_redraw()
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		_workshop_play(workshop_items[workshop_sel])
	elif _press(e, [KEY_R], [JOY_BUTTON_X]):
		_workshop_remix(workshop_items[workshop_sel])


# tape une création → on la JOUE direct (chargement éphémère, écran titre de l'auteur)
func _workshop_play(entry: Dictionary) -> void:
	var proj := ProjectStore.import_spark(String(entry["path"]))
	if proj.is_empty():
		_set_toast("Création illisible"); return
	# +1 partie locale (v1 backend : ce compteur remontera au créateur)
	WorkshopStats.add_play(String(entry["path"]).get_file())
	workshop_plays = WorkshopStats.load_stats()
	_apply_project_data(proj, String(proj.get("dim", "2D")), String(proj.get("template", "platformer")),
		"▶ " + String(proj.get("name", "Création")), false)   # go_dash=false : pas de dash, on enchaîne le jeu
	_game_start()           # → écran titre de SA création, puis on joue
	from_workshop = true    # après _game_start (qui le remet à false) → retour feed en quittant


# X : REMIXER — copie la création comme NOUVEAU projet éditable À MOI, crédit à l'original.
# Tue la page blanche : on part d'un jeu qui marche, on le bidouille, on repartage.
func _workshop_remix(entry: Dictionary) -> void:
	var proj := ProjectStore.import_spark(String(entry["path"]))
	if proj.is_empty():
		_set_toast("Création illisible"); return
	var rx := ProjectStore.make_remix(proj, String(creator.get("name", "")), int(creator.get("color", 0)))
	if not ProjectStore.save(rx):
		_set_toast("Remix impossible (sauvegarde)"); return
	from_workshop = false
	proj_list = ProjectStore.list(cur_dim)
	_apply_project_data(rx, String(rx.get("dim", "2D")), String(rx.get("template", "platformer")),
		String(rx.get("name", "Remix")))   # go_dash=true → dash du nouveau projet
	_set_toast("Remix créé : %s — à toi de jouer !" % String(rx.get("name", "")))


func _tmpl_input(e: InputEvent) -> void:
	var list: Array = TEMPLATES.get(cur_dim, [])
	if _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		states.change_state("ListState")
	elif list.is_empty():
		return
	elif _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		sel = (sel + 1) % list.size(); queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		sel = (sel - 1 + list.size()) % list.size(); queue_redraw()
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		_new_project(String(list[sel]["id"]))


func _edit_input(e: InputEvent) -> void:
	if _press(e, [KEY_ESCAPE], [JOY_BUTTON_BACK]):
		_open_menu(); return
	# --- souris : déplace le pointeur + place/ramasse (gauche) / efface (droite) ---
	if e is InputEventMouseMotion:
		aim = (e as InputEventMouseMotion).position
		_sync_cursor_from_aim(); queue_redraw(); return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		aim = mb.position
		# bande de styles graphiques (gauche) : clic = sélection, ne pose pas de tuile
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and gfx.click(mb.position):
			return
		# barre du haut (palette) puis inspecteur : prioritaires sur la pose
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _topbar_click(): return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _insp_click(1): return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and _insp_click(-1): return
		_sync_cursor_from_aim()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not radial_open and not sel_mode: _begin_stroke(true)
			elif not mb.pressed:
				if grabbing: _drop_grab()
				place_held = false
			return
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed and not sel_mode: _begin_stroke(false)
			elif not mb.pressed: erase_held = false
			return
	if sel_mode:
		if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]): _sel_click()
		elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]): _sel_cancel()
		return
	if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], true):
		if _topbar_click(): return
		if _insp_click(1): return
		if not radial_open: _begin_stroke(true)
		return
	if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], false):
		if grabbing: _drop_grab()
		place_held = false; return
	if _is_btn(e, [KEY_DELETE, KEY_D], [JOY_BUTTON_B], true):
		_begin_stroke(false); return
	if _is_btn(e, [KEY_DELETE, KEY_D], [JOY_BUTTON_B], false):
		erase_held = false; return
	if _press(e, [KEY_Z], [JOY_BUTTON_X]): _undo()
	elif _press(e, [KEY_Y], [JOY_BUTTON_Y]): _redo()
	elif _press(e, [KEY_BRACKETLEFT, KEY_A], [JOY_BUTTON_LEFT_SHOULDER]): _cycle(-1)
	elif _press(e, [KEY_BRACKETRIGHT, KEY_E], [JOY_BUTTON_RIGHT_SHOULDER]): _cycle(1)
	elif _press(e, [KEY_TAB], [JOY_BUTTON_START]): _start_play(false)
	elif _press(e, [KEY_T], [JOY_BUTTON_RIGHT_STICK]): _start_play(true)
	elif _press(e, [KEY_C], [JOY_BUTTON_LEFT_STICK]): _open_config()
	elif _press(e, [KEY_V], []): _toggle_cursor_mode()   # vitesse curseur (clavier)
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_7:
		cat = mini(e.keycode - KEY_1, _cats().size() - 1); queue_redraw()
	if radial_open:
		if _press(e, [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]):
			var n: int = _cats()[cat]["tiles"].size()
			radial_pick = (radial_pick - 1 + n) % n; queue_redraw()
		elif _press(e, [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]):
			var n: int = _cats()[cat]["tiles"].size()
			radial_pick = (radial_pick + 1) % n; queue_redraw()


func _play_input(e: InputEvent) -> void:
	if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		tmpl.jump_pressed()
	elif _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], false):
		tmpl.jump_released()
	elif _press(e, [KEY_TAB], [JOY_BUTTON_START, JOY_BUTTON_B]):
		if game_mode: _game_quit()        # en mode jeu : retour au tableau de bord
		else: _stop_play()
	elif _press(e, [KEY_M], [JOY_BUTTON_BACK]):
		map_open = not map_open; queue_redraw()
	elif _press(e, [KEY_R], [JOY_BUTTON_Y]):
		if game_mode:
			_game_launch_zone(game_zone_i)   # recommence la zone (vies remises)
			return
		# rejouer = nouvelle partie : restaure l'état auteur puis re-snapshot
		_restore_play_world()
		_backup_level_for_play(cur_level)
		visited_rooms.clear()
		tmpl.start_play(tmpl.last_from_cursor)


# cartes du dash : JOUER + un NIVEAU par carte + "+ Nouveau" + les écrans de jeu
func _dash_entries() -> Array:
	var out := []
	out.append({"label": "▶  Jouer le jeu", "key": "playgame"})
	for id in level_ids():
		out.append({"label": level_name(id), "key": "level", "id": id})
	out.append({"label": "+ Nouvelle zone", "key": "newlevel"})
	for i in range(1, DASH_KEYS.size()):
		out.append({"label": DASH_ITEMS[i], "key": DASH_KEYS[i]})
	return out


func _gamedash_input(e: InputEvent) -> void:
	var entries := _dash_entries()
	var n := entries.size()
	dash_sel = clampi(dash_sel, 0, n - 1)
	if _press(e, [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]):
		if dash_sel % 2 == 0 and dash_sel + 1 < n: dash_sel += 1; queue_redraw()
	elif _press(e, [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]):
		if dash_sel % 2 == 1: dash_sel -= 1; queue_redraw()
	elif _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		if dash_sel + 2 < n: dash_sel += 2; queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		if dash_sel - 2 >= 0: dash_sel -= 2; queue_redraw()
	elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		states.change_state("ListState")
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		var ent: Dictionary = entries[dash_sel]
		match str(ent["key"]):
			"playgame":
				_game_start()
			"level":
				_switch_level(str(ent["id"]))
				states.change_state("EditorState")
			"newlevel":
				_add_level()
				states.change_state("EditorState")
			_:
				edit_screen_key = str(ent["key"]); edit_prop_sel = 0; text_edit_mode = false
				states.change_state("ScreenEditState")


# ============================================================ MODE JEU COMPLET
# Le projet se JOUE comme un vrai jeu : titre → sélection de zone (progression
# débloquée au fil des victoires) → zones enchaînées → game over / écran de fin.
func _game_start() -> void:
	if mode == "play": _stop_play()
	from_workshop = false   # lancé depuis le dash par défaut ; _workshop_play le repasse à true
	game_mode = false
	game_stage = "title"
	game_sel = 0
	game_total_time = 0.0; game_total_coins = 0
	screen = "game"
	queue_redraw()


func _game_input(e: InputEvent) -> void:
	match game_stage:
		"title":
			if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A, JOY_BUTTON_START]):
				game_stage = "select"; game_sel = 0; _play("coin"); queue_redraw()
			elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
				_game_quit()
		"select":
			var ids := level_ids()
			if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
				game_sel = mini(game_sel + 1, mini(game_unlocked, ids.size()) - 1); queue_redraw()
			elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
				game_sel = maxi(game_sel - 1, 0); queue_redraw()
			elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
				_game_launch_zone(game_sel)
			elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
				game_stage = "title"; queue_redraw()
		"complete":
			if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A, JOY_BUTTON_START]):
				if game_zone_i + 1 < level_ids().size():
					_game_launch_zone(game_zone_i + 1)
				else:
					game_stage = "end"; _play("win"); queue_redraw()
		"over":
			if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
				_game_launch_zone(game_zone_i)      # réessaye la même zone
			elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
				game_stage = "select"; queue_redraw()
		"end":
			if _press(e, [KEY_SPACE, KEY_ENTER, KEY_ESCAPE], [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]):
				_game_quit()


func _game_launch_zone(i: int) -> void:
	var ids := level_ids()
	if i < 0 or i >= ids.size(): return
	game_zone_i = i
	game_lives = 3
	game_win_t = 0.0; game_over_t = 0.0
	if mode == "play": _stop_play()
	_switch_level(str(ids[i]))
	screen = "edit"          # le monde/HUD se dessinent via le chemin play normal
	_start_play(false)
	game_mode = true
	_set_toast("Zone %d/%d — %s" % [i + 1, ids.size(), level_name(cur_level)])
	queue_redraw()


# appelé par _process quand la zone est gagnée en mode jeu (après la fête)
func _game_zone_won() -> void:
	game_zone_time = tmpl.play_time
	game_zone_coins = tmpl.coins_got
	game_zone_ctotal = tmpl.coins_total
	game_total_time += tmpl.play_time
	game_total_coins += tmpl.coins_got
	if game_zone_i + 1 >= game_unlocked:
		game_unlocked = mini(game_zone_i + 2, level_ids().size() + 1)
		_save_current()      # la progression débloquée est persistée
	_stop_play(); game_mode = false
	screen = "game"; game_stage = "complete"
	queue_redraw()


func _game_player_died() -> void:
	game_lives -= 1
	if game_lives <= 0:
		game_over_t = 0.8    # laisse l'anim de mort se jouer avant l'écran
	queue_redraw()


func _game_quit() -> void:
	if mode == "play": _stop_play()
	game_mode = false
	game_stage = ""
	if from_workshop:
		from_workshop = false
		_open_workshop(false)   # retour au feed (sans perdre la position)
	else:
		states.change_state("GameDashState")


func _rename_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		var k := e as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_ESCAPE:
			lvl_rename = false; queue_redraw(); return
		if k.keycode == KEY_BACKSPACE:
			cur_level_name = cur_level_name.substr(0, maxi(0, cur_level_name.length() - 1))
			queue_redraw(); return
		var ch := char(k.unicode)
		if k.unicode > 31 and cur_level_name.length() < 18:
			cur_level_name += ch
			queue_redraw()
	elif _press(e, [], [JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_A]):
		lvl_rename = false; queue_redraw()


func _cur_screen() -> Dictionary:
	if not screens.has(edit_screen_key):
		screens[edit_screen_key] = ScreenArt.empty_screen()
	var d: Dictionary = screens[edit_screen_key]
	if not d.has("accent"): d["accent"] = "3498db"
	if not d.has("bg"): d["bg"] = 0
	if not d.has("bg_grad"): d["bg_grad"] = false
	if not d.has("grid"): d["grid"] = 1
	if not d.has("grid_show"): d["grid_show"] = true
	if not d.has("subtitle"): d["subtitle"] = ""
	if not d.has("deco"): d["deco"] = {}
	if not d.has("stamps"): d["stamps"] = []
	if not d.has("panels"): d["panels"] = []
	if not d.has("texts"): d["texts"] = {}
	return d


func _se_dims() -> Vector2:
	return ScreenArt.grid_dims(_cur_screen())


# style propre à un écran (accent/fond/sous-titre), avec valeurs par défaut
func _screen_style(key: String) -> Dictionary:
	var d: Dictionary = screens.get(key, {})
	var ah := String(d.get("accent", "3498db"))
	return {
		"accent": Color(ah) if ah.length() == 6 else Color("3498db"),
		"bg": int(d.get("bg", 0)) % BG_THEMES.size(),
		"subtitle": String(d.get("subtitle", "")),
	}


func _screenedit_input(e: InputEvent) -> void:
	if text_edit_mode:
		_text_edit_input(e); return
	# B : sauvegarder + retour ; LB/RB : changer d'outil (commun à tous)
	if _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		_save_current(); states.change_state("GameDashState"); return
	if _press(e, [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER]):
		se_tool = (se_tool - 1 + TOOL_NAMES.size()) % TOOL_NAMES.size(); queue_redraw(); return
	if _press(e, [KEY_E], [JOY_BUTTON_RIGHT_SHOULDER]):
		se_tool = (se_tool + 1) % TOOL_NAMES.size(); queue_redraw(); return

	match se_tool:
		TOOL_PINCEAU:
			if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], true):
				se_place_held = true; _paint_deco_cell(); return
			if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], false):
				se_place_held = false; return
			if _press(e, [KEY_X], [JOY_BUTTON_X]):
				se_color = (se_color + 1) % ScreenArt.DECO.size(); queue_redraw()
			elif _press(e, [KEY_C], [JOY_BUTTON_Y]):
				se_color = (se_color - 1 + ScreenArt.DECO.size()) % ScreenArt.DECO.size(); queue_redraw()
		TOOL_GOMME:
			if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], true):
				se_erase_held = true; _erase_deco_cell(); return
			if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], false):
				se_erase_held = false; return
		TOOL_TAMPON:
			if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
				_place_stamp()
			elif _press(e, [KEY_X], [JOY_BUTTON_X]):
				se_shape = (se_shape + 1) % ScreenArt.SHAPE_COUNT; queue_redraw()
			elif _press(e, [KEY_C], [JOY_BUTTON_Y]):
				se_color = (se_color + 1) % ScreenArt.DECO.size(); queue_redraw()
			elif _press(e, [KEY_O], [JOY_BUTTON_RIGHT_STICK]):
				se_stamp_outline = not se_stamp_outline; queue_redraw()
			elif _press(e, [KEY_PAGEUP], []):
				se_stamp_size = minf(se_stamp_size + 0.02, 1.0); queue_redraw()
			elif _press(e, [KEY_PAGEDOWN], []):
				se_stamp_size = maxf(se_stamp_size - 0.02, 0.02); queue_redraw()
			elif _press(e, [KEY_BACKSPACE], [JOY_BUTTON_LEFT_STICK]):
				if not _cur_screen()["stamps"].is_empty():
					_cur_screen()["stamps"].pop_back(); queue_redraw()
		TOOL_PANNEAU:
			if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
				_panel_click()
			elif _press(e, [KEY_X], [JOY_BUTTON_X]):
				se_color = (se_color + 1) % ScreenArt.DECO.size(); queue_redraw()
			elif _press(e, [KEY_O], [JOY_BUTTON_Y]):
				se_panel_outline = not se_panel_outline; queue_redraw()
			elif _press(e, [KEY_PAGEUP], [JOY_BUTTON_RIGHT_STICK]):
				se_panel_radius = minf(se_panel_radius + 0.05, 0.5); queue_redraw()
			elif _press(e, [KEY_PAGEDOWN], []):
				se_panel_radius = maxf(se_panel_radius - 0.05, 0.0); queue_redraw()
			elif _press(e, [KEY_BACKSPACE], [JOY_BUTTON_LEFT_STICK]):
				se_panel_anchor = Vector2i(-1, -1)
				if not _cur_screen()["panels"].is_empty():
					_cur_screen()["panels"].pop_back(); queue_redraw()
		TOOL_TEXTE:
			if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
				se_text_sel = (se_text_sel + 1) % ScreenArt.TITLE_TEXTS.size(); queue_redraw()
			elif _press(e, [KEY_X], [JOY_BUTTON_X]):
				_resize_text(-0.006)
			elif _press(e, [KEY_C], [JOY_BUTTON_Y]):
				_resize_text(0.006)
		TOOL_STYLE:
			_style_input(e)


func _style_input(e: InputEvent) -> void:
	var max_props := _se_max_props()
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		edit_prop_sel = (edit_prop_sel + 1) % max_props; queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		edit_prop_sel = (edit_prop_sel - 1 + max_props) % max_props; queue_redraw()
	elif _press(e, [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]):
		_screenedit_change(-1)
	elif _press(e, [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]):
		_screenedit_change(1)
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		if edit_screen_key == "title" and edit_prop_sel == 5:
			text_edit_mode = true; text_edit_cursor = String(_cur_screen()["subtitle"]).length()


func _se_max_props() -> int:
	# accent, fond, dégradé, grille(taille), grille(visible) [, sous-titre si titre]
	return 6 if edit_screen_key == "title" else 5


func _screenedit_change(dir: int) -> void:
	var d := _cur_screen()
	match edit_prop_sel:
		0:
			var cur := Color(String(d["accent"]))
			var idx := ACCENT_PALETTE.find(cur)
			if idx < 0: idx = 0
			var nc: Color = ACCENT_PALETTE[(idx + dir + ACCENT_PALETTE.size()) % ACCENT_PALETTE.size()]
			d["accent"] = nc.to_html(false)
		1:
			d["bg"] = (int(d["bg"]) + dir + BG_THEMES.size()) % BG_THEMES.size()
		2:
			d["bg_grad"] = not bool(d["bg_grad"])
		3:
			d["grid"] = clampi(int(d["grid"]) + dir, 0, ScreenArt.GRID_SIZES.size() - 1)
			var dims := ScreenArt.grid_dims(d)
			se_cursor.x = clampi(se_cursor.x, 0, int(dims.x) - 1)
			se_cursor.y = clampi(se_cursor.y, 0, int(dims.y) - 1)
		4:
			d["grid_show"] = not bool(d["grid_show"])
	queue_redraw()


func _paint_deco_cell() -> void:
	var d := _cur_screen()
	d["deco"]["%d,%d" % [se_cursor.x, se_cursor.y]] = se_color
	queue_redraw()


func _erase_deco_cell() -> void:
	var d := _cur_screen()
	d["deco"].erase("%d,%d" % [se_cursor.x, se_cursor.y])
	queue_redraw()


# centre de la case courante en coords normalisées 0..1
func _cursor_norm() -> Vector2:
	var dims := _se_dims()
	return Vector2((se_cursor.x + 0.5) / dims.x, (se_cursor.y + 0.5) / dims.y)


func _place_stamp() -> void:
	var d := _cur_screen()
	var n := _cursor_norm()
	d["stamps"].append({"shape": se_shape, "nx": n.x, "ny": n.y,
		"col": se_color, "size": se_stamp_size, "alpha": se_stamp_alpha,
		"outline": se_stamp_outline})
	queue_redraw()


func _panel_click() -> void:
	# 1er appui : ancre un coin ; 2e appui : crée le panneau
	if se_panel_anchor == Vector2i(-1, -1):
		se_panel_anchor = se_cursor
		queue_redraw(); return
	var dims := _se_dims()
	var ax := mini(se_panel_anchor.x, se_cursor.x); var ay := mini(se_panel_anchor.y, se_cursor.y)
	var bx := maxi(se_panel_anchor.x, se_cursor.x) + 1; var by := maxi(se_panel_anchor.y, se_cursor.y) + 1
	var d := _cur_screen()
	d["panels"].append({
		"nx": float(ax) / dims.x, "ny": float(ay) / dims.y,
		"nw": float(bx - ax) / dims.x, "nh": float(by - ay) / dims.y,
		"col": se_color, "radius": se_panel_radius, "alpha": se_panel_alpha,
		"outline": se_panel_outline})
	se_panel_anchor = Vector2i(-1, -1)
	queue_redraw()


func _resize_text(delta: float) -> void:
	var d := _cur_screen()
	var key: String = ScreenArt.TITLE_TEXTS[se_text_sel]
	var p := ScreenArt.text_props(d, key)
	if not d["texts"].has(key): d["texts"][key] = {}
	d["texts"][key]["scale"] = clampf(p.scale + delta, 0.02, 0.3)
	d["texts"][key]["nx"] = p.nx
	d["texts"][key]["ny"] = p.ny
	queue_redraw()


func _move_text(dx: float, dy: float) -> void:
	var d := _cur_screen()
	var key: String = ScreenArt.TITLE_TEXTS[se_text_sel]
	var p := ScreenArt.text_props(d, key)
	if not d["texts"].has(key): d["texts"][key] = {}
	d["texts"][key]["nx"] = clampf(p.nx + dx, 0.0, 1.0)
	d["texts"][key]["ny"] = clampf(p.ny + dy, 0.0, 1.0)
	d["texts"][key]["scale"] = p.scale
	queue_redraw()


func _text_edit_input(e: InputEvent) -> void:
	var d := _cur_screen()
	var s := String(d["subtitle"])
	if _press(e, [KEY_ESCAPE, KEY_ENTER], [JOY_BUTTON_B, JOY_BUTTON_START]):
		text_edit_mode = false; queue_redraw(); return
	if _press(e, [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]):
		text_edit_cursor = max(0, text_edit_cursor - 1); queue_redraw(); return
	if _press(e, [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]):
		if text_edit_cursor < s.length():
			text_edit_cursor += 1
		elif s.length() < 30:
			d["subtitle"] = s + TEXT_CHARS[0]; text_edit_cursor += 1
		queue_redraw(); return
	if _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		_text_cycle(1); return
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		_text_cycle(-1); return
	if _press(e, [KEY_BACKSPACE], [JOY_BUTTON_X]):
		if text_edit_cursor > 0:
			d["subtitle"] = s.substr(0, text_edit_cursor - 1) + s.substr(text_edit_cursor)
			text_edit_cursor -= 1; queue_redraw()
		return
	if e is InputEventKey and e.pressed and not e.echo and e.unicode >= 32 and e.unicode < 127:
		if s.length() < 30:
			var ch := char(e.unicode).to_upper()
			d["subtitle"] = s.substr(0, text_edit_cursor) + ch + s.substr(text_edit_cursor)
			text_edit_cursor += 1; queue_redraw()


func _text_cycle(dir: int) -> void:
	var d := _cur_screen()
	var s := String(d["subtitle"])
	if text_edit_cursor >= s.length():
		if s.length() < 30:
			s += TEXT_CHARS[0]; text_edit_cursor = s.length() - 1
		else: return
	var idx := TEXT_CHARS.find(s[text_edit_cursor].to_upper())
	if idx < 0: idx = 0
	idx = (idx + dir + TEXT_CHARS.length()) % TEXT_CHARS.length()
	d["subtitle"] = s.substr(0, text_edit_cursor) + TEXT_CHARS[idx] + s.substr(text_edit_cursor + 1)
	queue_redraw()


func _release_insp_if_elsewhere() -> void:
	if insp_cell != Vector2i(-999, -999) and cursor != insp_cell and not _insp_hover():
		insp_cell = Vector2i(-999, -999)
		queue_redraw()


func _begin_stroke(place: bool) -> void:
	_release_insp_if_elsewhere()
	_push_undo()
	if place:
		if tmpl.can_grab(cursor):
			# bloc déjà posé sous le pointeur → on le ramasse pour le déplacer
			grabbing = true
			grab_tile = grid[cursor]
			grab_from = cursor
			grab_cfg = cell_cfg.get(cursor, {})
			grid.erase(cursor); cell_cfg.erase(cursor)
			place_held = false
		else:
			place_held = true; tmpl.place_tile(cursor, _active_tile(), true)
	else:
		erase_held = true; tmpl.erase_tile(cursor); erase_last = cursor
	queue_redraw(); _redraw_world()


func _drop_grab() -> void:
	if not grabbing: return
	grid[cursor] = grab_tile   # dépose à la cellule visée (écrase si occupée)
	if not grab_cfg.is_empty(): cell_cfg[cursor] = grab_cfg
	grab_cfg = {}
	grabbing = false
	queue_redraw(); _redraw_world()


func _redraw_world() -> void:
	# redessine le monde (template) — à n'appeler QUE quand le monde change
	# (case éditée, pan, dézoom, thème, undo, chargement). Sinon le monde reste figé.
	if tmpl: tmpl.queue_redraw()


func _active_tile() -> int:
	var c: Dictionary = _cats()[cat]
	var t: Array = c["tiles"]
	return int(t[cat_pal[cat]])


func _cycle(dir: int) -> void:
	cat = (cat + dir + _cats().size()) % _cats().size()
	queue_redraw()


func _toggle_cursor_mode() -> void:
	cursor_mode = "précis" if cursor_mode == "rapide" else "rapide"; queue_redraw()


# ---------------- undo / redo
func _push_undo() -> void:
	undo_stack.append(grid.duplicate())
	if undo_stack.size() > 60: undo_stack.pop_front()
	redo_stack.clear()


func _undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(grid.duplicate())
	grid = undo_stack.pop_back(); queue_redraw(); _redraw_world()


func _redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(grid.duplicate())
	grid = redo_stack.pop_back(); queue_redraw(); _redraw_world()


# ---------------- menu éditeur
# menu data-driven : chaque entrée porte son libellé ET son action.
# Insérer/retirer une entrée ne décale plus rien (fini le match indexé fragile).
func _menu_def_build() -> Array:
	var hp := int(level_props.get("player_hp", tmpl.default_hp()))
	var tl := int(level_props.get("time_limit", 0))
	var wc := int(level_props.get("win_coins", 0))
	return [
		{"label": "Sauvegarder", "act": _save_current},
		{"label": "Copier zone", "act": _start_selection},
		{"label": "Coller ici", "act": _paste_clip},
		{"label": "Vider niveau", "act": func() -> void:
			_push_undo(); grid.clear(); cell_cfg.clear(); _set_toast("Niveau vidé")},
		{"label": "Customiser le fond…", "act": bg_ed.open, "modal": true},
		{"label": "📤  Partager : exporter (.spark)", "act": _export_creation},
		{"label": "Autorun: %s" % _onoff(level_props.get("autorun", false)),
			"act": func() -> void: _toggle_prop("autorun", "Autorun")},
		{"label": "Physique Sonic: %s" % _onoff(level_props.get("sonic", false)),
			"act": func() -> void: _toggle_prop("sonic", "Physique Sonic")},
		{"label": "2 joueurs (co-op): %s" % _onoff(level_props.get("coop", false)),
			"act": func() -> void: _toggle_prop("coop", "Co-op local (manette 2 / ZQSD)")},
		{"label": "Eau · Nage: %s" % _onoff(level_props.get("water_swim", false)),
			"act": func() -> void: _toggle_prop("water_swim", "Eau · Nage")},
		{"label": "Eau · Noyade: %s" % _onoff(level_props.get("water_drown", false)),
			"act": func() -> void: _toggle_prop("water_drown", "Eau · Noyade")},
		{"label": "Victoire · Pièces: %s" % (str(wc) if wc > 0 else "OFF"),
			"act": func() -> void: _cycle_prop("win_coins", [0, 5, 10, 20], "Victoire · Pièces")},
		{"label": "Victoire · Tuer tous: %s" % _onoff(level_props.get("win_killall", false)),
			"act": func() -> void: _toggle_prop("win_killall", "Victoire · Tuer tous")},
		{"label": "Victoire · Temps: %s" % ((str(tl) + "s") if tl > 0 else "OFF"),
			"act": func() -> void: _cycle_prop("time_limit", [0, 30, 60, 90], "Victoire · Temps")},
		{"label": "PV joueur (cœurs): %s" % (str(hp) if hp > 0 else "OFF"), "act": func() -> void:
			level_props["player_hp"] = _cycle_preset(hp, [0, 3, 5])
			var v: int = int(level_props["player_hp"])
			_set_toast("PV joueur : %s" % (str(v) + " cœurs" if v > 0 else "désactivé"))},
		{"label": "Caméra salles (top-down): %s" % ("ON" if String(level_props.get("cam", "rooms")) == "rooms" else "OFF"),
			"act": func() -> void:
				var was := String(level_props.get("cam", "rooms")) == "rooms"
				level_props["cam"] = "free" if was else "rooms"
				cam_init = false
				_set_toast("Caméra : %s" % ("libre" if was else "salles (verrou)"))},
		{"label": "Éditer les salles… (%d)" % rooms.size(), "modal": true, "act": room_ed.open},
		{"label": "Zone: %s / %d  (suivante)" % [level_name(cur_level), level_ids().size()], "act": _cycle_level},
		{"label": "Renommer la zone…", "modal": true, "act": func() -> void: lvl_rename = true},
		{"label": "Nouvelle zone", "act": _add_level},
		{"label": "Supprimer cette zone", "act": _delete_level},
		{"label": "Musique: %s" % _onoff(audio.music_on), "act": _toggle_music},
		{"label": "FPS (debug): %s" % _onoff(show_fps), "act": func() -> void:
			show_fps = not show_fps
			_set_toast("FPS %s" % _onoff(show_fps))},
		{"label": "Générer avec IA...", "act": _open_ai_panel, "modal": true},
		{"label": "Projets (quitter)", "act": func() -> void:
			_save_current(); states.change_state("ListState")},
		{"label": "Fermer"},
	]


func _onoff(b: bool) -> String:
	return "ON" if b else "OFF"


func _toggle_prop(key: String, label: String) -> void:
	level_props[key] = not level_props.get(key, false)
	_set_toast("%s %s" % [label, _onoff(level_props[key])])


func _cycle_prop(key: String, presets: Array, label: String) -> void:
	level_props[key] = _cycle_preset(int(level_props.get(key, 0)), presets)
	var v: int = int(level_props[key])
	_set_toast("%s : %s" % [label, (str(v) if v > 0 else "désactivé")])


func _open_menu() -> void:
	menu_open = true; menu_idx = 0
	menu_def = _menu_def_build()
	menu_items = menu_def.map(func(it): return str(it["label"]))
	queue_redraw()


func _cycle_preset(cur: int, presets: Array) -> int:
	var i := presets.find(cur)
	return int(presets[(i + 1) % presets.size()])


# ---------------- config par instance (objet sous le curseur)
# les champs sont définis par le template (connaissance des tuiles = au genre)
func _cfg_fields_for(t: int) -> Array:
	return tmpl.config_fields(t)


func _open_config() -> void:
	var t: int = int(grid.get(cursor, -1))
	cfg_fields = _cfg_fields_for(t)
	if cfg_fields.is_empty():
		_set_toast("Rien à configurer ici"); return
	cfg_cell = cursor; cfg_idx = 0; cfg_open = true; queue_redraw()


func _cfg_get(fld: Dictionary, cell: Vector2i = Vector2i(-999, -999)):
	if cell == Vector2i(-999, -999): cell = cfg_cell
	var d: Dictionary = cell_cfg.get(cell, {})
	return d.get(fld["key"], fld["def"])


func _cfg_adjust(dir: int) -> void:
	var fld: Dictionary = cfg_fields[cfg_idx]
	var opts: Array = fld["opts"]
	var i := opts.find(_cfg_get(fld))
	if i < 0: i = 0
	var nv = opts[(i + dir + opts.size()) % opts.size()]
	var d: Dictionary = cell_cfg.get(cfg_cell, {})
	d[fld["key"]] = nv
	cell_cfg[cfg_cell] = d
	queue_redraw()


func _config_input(e: InputEvent) -> void:
	if _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B, JOY_BUTTON_BACK, JOY_BUTTON_A]):
		cfg_open = false; queue_redraw(); return
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		cfg_idx = (cfg_idx + 1) % cfg_fields.size(); queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		cfg_idx = (cfg_idx - 1 + cfg_fields.size()) % cfg_fields.size(); queue_redraw()
	elif _press(e, [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]):
		_cfg_adjust(1)
	elif _press(e, [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]):
		_cfg_adjust(-1)


# ---------------- édition du fond (vue parallax seule + placement de formes)
func _menu_input(e: InputEvent) -> void:
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		menu_idx = (menu_idx + 1) % menu_items.size(); queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		menu_idx = (menu_idx - 1 + menu_items.size()) % menu_items.size(); queue_redraw()
	elif _press(e, [KEY_ESCAPE], [JOY_BUTTON_BACK, JOY_BUTTON_B]):
		menu_open = false; queue_redraw()
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		_menu_select()


func _menu_select() -> void:
	var it: Dictionary = menu_def[menu_idx] if menu_idx < menu_def.size() else {}
	menu_open = false
	if it.has("act"):
		(it["act"] as Callable).call()
	if it.get("modal", false):
		queue_redraw(); return   # l'action a ouvert un autre panneau
	queue_redraw(); _redraw_world()   # vidage/thème/sonic peuvent changer le monde


func _toggle_music() -> void:
	_set_toast("Musique %s" % ("ON" if audio.toggle_music() else "OFF"))


func _set_toast(s: String) -> void:
	toast = s; toast_t = 2.0; queue_redraw()


# ---------------- panneau IA
func _open_ai_panel() -> void:
	ai_open = true
	ai_state = "idle"
	ai_result = ""
	queue_redraw()


func _ai_context_label() -> String:
	var tpl := cur_template.capitalize()
	var props: Array = []
	if level_props.get("sonic", false): props.append("Sonic")
	if level_props.get("autorun", false): props.append("Autorun")
	var tile_count := grid.size()
	return "%s  •  %d×%d cases  •  %d tuiles%s" % [
		tpl, cols, rows, tile_count,
		("  •  " + "  ".join(props)) if props.size() > 0 else ""
	]


func _ai_panel_input(e: InputEvent) -> void:
	if ai_state == "thinking": return
	if _press(e, [KEY_ESCAPE], [JOY_BUTTON_B, JOY_BUTTON_BACK]):
		ai_open = false; queue_redraw(); return
	if ai_state in ["done", "error"]:
		if _press(e, [KEY_ENTER], [JOY_BUTTON_A]):
			ai_state = "idle"; ai_result = ""; queue_redraw()
		return
	# navigation curseur prompt
	if _press(e, [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]):
		ai_cursor = max(0, ai_cursor - 1); queue_redraw(); return
	if _press(e, [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]):
		if ai_cursor < ai_prompt.length(): ai_cursor += 1
		elif ai_prompt.length() < 80:
			ai_prompt += TEXT_CHARS[0]; ai_cursor += 1
		queue_redraw(); return
	if _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		_ai_char_cycle(1); return
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		_ai_char_cycle(-1); return
	if _press(e, [KEY_BACKSPACE], [JOY_BUTTON_X]):
		if ai_cursor > 0:
			ai_prompt = ai_prompt.substr(0, ai_cursor - 1) + ai_prompt.substr(ai_cursor)
			ai_cursor -= 1; queue_redraw()
		return
	if _press(e, [KEY_ENTER], [JOY_BUTTON_A]):
		if ai_prompt.strip_edges() != "":
			ai_state = "thinking"; ai_result = ""; queue_redraw()
			# TODO: call backend API here
			_ai_stub_response()
		return
	# saisie clavier directe
	if e is InputEventKey and e.pressed and not e.echo and e.unicode >= 32 and e.unicode < 127:
		if ai_prompt.length() < 80:
			ai_prompt = ai_prompt.substr(0, ai_cursor) + char(e.unicode) + ai_prompt.substr(ai_cursor)
			ai_cursor += 1; queue_redraw()


func _ai_char_cycle(dir: int) -> void:
	if ai_cursor >= ai_prompt.length():
		if ai_prompt.length() < 80:
			ai_prompt += TEXT_CHARS[0]; ai_cursor = ai_prompt.length() - 1
		else: return
	var idx := TEXT_CHARS.find(ai_prompt[ai_cursor].to_upper())
	if idx < 0: idx = 0
	idx = (idx + dir + TEXT_CHARS.length()) % TEXT_CHARS.length()
	ai_prompt = ai_prompt.substr(0, ai_cursor) + TEXT_CHARS[idx] + ai_prompt.substr(ai_cursor + 1)
	queue_redraw()


func _ai_stub_response() -> void:
	# frontend only — remplacer par vrai call HTTP quand backend prêt
	await get_tree().create_timer(1.2).timeout
	ai_state = "error"
	ai_result = "Backend non configuré — branchement API requis"
	queue_redraw()


func _draw_ai_panel(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var pw := minf(720.0, vp.x - 40.0)
	var ph := 210.0
	var o := Vector2(vp.x * 0.5 - pw * 0.5, vp.y * 0.5 - ph * 0.5)
	# fond sombre
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(o, Vector2(pw, ph)), Color("0d1117"))
	draw_rect(Rect2(o, Vector2(pw, ph)), Color("f39c12"), false, 2.0)
	# titre + modèle
	_text(f, o + Vector2(16, 28), "IA FORGE", Color("f39c12"), 18)
	_text(f, o + Vector2(pw - 120, 28), "Gemini Flash", Color(1, 1, 1, 0.4), 13)
	# contexte
	draw_rect(Rect2(o + Vector2(0, 38), Vector2(pw, 1)), Color(1, 1, 1, 0.1))
	_text(f, o + Vector2(16, 58), _ai_context_label(), Color(1, 1, 1, 0.5), 12)
	# champ prompt
	draw_rect(Rect2(o + Vector2(0, 68), Vector2(pw, 1)), Color(1, 1, 1, 0.1))
	var field := Rect2(o + Vector2(12, 78), Vector2(pw - 24, 36))
	draw_rect(field, Color("1a2233"))
	draw_rect(field, Color("f39c12", 0.5) if ai_state == "idle" else Color("444444"), false, 1.5)
	var prompt_display := ai_prompt if ai_prompt != "" else "Décris le niveau à générer..."
	var prompt_col := Color.WHITE if ai_prompt != "" else Color(1, 1, 1, 0.3)
	_text(f, field.position + Vector2(10, 24), prompt_display, prompt_col, 15)
	# curseur clignotant
	if ai_state == "idle" and int(anim_t * 2.0) % 2 == 0 and ai_prompt != "":
		var cx := field.position.x + 10.0 + f.get_string_size(ai_prompt.substr(0, ai_cursor), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_line(Vector2(cx, field.position.y + 8), Vector2(cx, field.position.y + 28), Color("f39c12"), 2.0)
	# état
	var sy := o.y + 126.0
	match ai_state:
		"thinking":
			var dots := ".".repeat(1 + int(anim_t * 3.0) % 3)
			_text(f, Vector2(o.x + 16, sy), "Génération en cours" + dots, Color("f39c12"), 14)
		"done":
			_text(f, Vector2(o.x + 16, sy), "✓ " + ai_result, Color("2ecc71"), 14)
			_text(f, Vector2(o.x + 16, sy + 22), "A: Recommencer  B: Fermer", Color(1, 1, 1, 0.5), 12)
		"error":
			_text(f, Vector2(o.x + 16, sy), "⚠ " + ai_result, Color("e74c3c"), 13)
			_text(f, Vector2(o.x + 16, sy + 22), "A: Recommencer  B: Fermer", Color(1, 1, 1, 0.5), 12)
		"idle":
			var x2 := o.x + 16.0
			x2 = _badge(x2, sy, "A", "Générer")
			x2 = _badge(x2, sy, "B", "Annuler")
			x2 = _badge(x2, sy, "↑↓", "Lettre")
			x2 = _badge(x2, sy, "X", "Effacer")
			var chars_left := 80 - ai_prompt.length()
			_text(f, Vector2(o.x + pw - 50, sy + 16), "%d" % chars_left, Color(1, 1, 1, 0.3), 12)


# ---------------- projets
# persistance déléguée à ProjectStore (pur I/O)
func _scan_projects(dim: String) -> void:
	proj_list = ProjectStore.list(dim)


func _new_project(template_id: String) -> void:
	cur_template = template_id
	_load_template(cur_template)
	# nom par défaut = nom du template ("Vue de dessus 1", "Metroidvania 2", ...)
	var base := "Projet"
	for dim_list in TEMPLATES.values():
		for t in dim_list:
			if str(t["id"]) == template_id: base = str(t["name"])
	var i := 1
	while ProjectStore.exists("%s %d" % [base, i]): i += 1
	cur_project = "%s %d" % [base, i]
	cur_author = String(creator.get("name", ""))
	cur_author_color = int(creator.get("color", 0))
	cur_remix_of = ""; cur_remix_by = ""
	cols = LEVEL_COLS_DEF
	bg_theme = 0
	undo_stack.clear(); redo_stack.clear()
	# reset AVANT le seed : le seed peut poser salles/props/thème sans être écrasé
	screens = {}; level_props = {}; cell_cfg.clear(); bg_deco.clear(); rooms.clear(); cur_room = -1
	levels = {}; cur_level = "1"; warp_cd = 0.0
	game_unlocked = 1; game_mode = false; game_stage = ""
	tmpl.seed_demo()
	# défaut par genre : top-down a les cœurs activés (3), platformer non
	if tmpl.default_hp() > 0: level_props["player_hp"] = tmpl.default_hp()
	aim = Vector2(-1, -1); cam_init = false; grabbing = false
	gfx.apply()
	_save_current()
	mode = "edit"; dash_sel = 0
	states.change_state("GameDashState")


func _parse_level(ld: Dictionary) -> Dictionary:
	var L := {"name": str(ld.get("name", "")), "cols": int(ld.get("cols", LEVEL_COLS_DEF)),
		"bg": int(ld.get("bg", 0)) % BG_THEMES.size(),
		"tiles": {}, "cfg": {}, "bg_deco": ld.get("bg_deco", []), "rooms": []}
	for k in ld.get("tiles", {}):
		var parts: PackedStringArray = String(k).split(",")
		L["tiles"][Vector2i(int(parts[0]), int(parts[1]))] = int(ld["tiles"][k])
	for k in ld.get("cfg", {}):
		var cp: PackedStringArray = String(k).split(",")
		L["cfg"][Vector2i(int(cp[0]), int(cp[1]))] = ld["cfg"][k]
	for ra in ld.get("rooms", []):
		L["rooms"].append(Rect2i(int(ra[0]), int(ra[1]), int(ra[2]), int(ra[3])))
	return L


func _open_project(p: Dictionary) -> void:
	var data = ProjectStore.load_file(String(p.get("path", "")))
	if typeof(data) != TYPE_DICTIONARY:
		_set_toast("Ouverture impossible"); return
	_apply_project_data(data, String(p.get("dim", "2D")), String(p.get("template", "platformer")), String(p.get("name", "")))


# charge un projet depuis un dict en mémoire (réutilisé : ouverture fichier ET WORKSHOP)
# go_dash=false : ne PAS basculer vers le dash (le WORKSHOP enchaîne direct sur _game_start)
func _apply_project_data(data: Dictionary, dim: String, template: String, pname: String, go_dash := true) -> void:
	cur_dim = dim
	cur_template = template
	_load_template(cur_template)
	cur_project = pname
	cur_author = String(data.get("author", ""))
	cur_author_color = int(data.get("author_color", 0))
	cur_remix_of = String(data.get("remix_of", ""))
	cur_remix_by = String(data.get("remix_by", ""))
	var pr = data.get("props", {})
	level_props = pr if typeof(pr) == TYPE_DICTIONARY else {}
	game_unlocked = maxi(1, int(data.get("progress", {}).get("unlocked", 1)))
	game_mode = false; game_stage = ""
	screens = {}
	var sc = data.get("screens", {})
	if typeof(sc) == TYPE_DICTIONARY:
		for k in sc:
			var sd: Dictionary = sc[k]
			screens[k] = {
				"accent": sd.get("accent", "3498db"),
				"bg": int(sd.get("bg", 0)),
				"bg_grad": bool(sd.get("bg_grad", false)),
				"grid": int(sd.get("grid", 1)),
				"grid_show": bool(sd.get("grid_show", true)),
				"subtitle": sd.get("subtitle", ""),
				"deco": sd.get("deco", {}),
				"stamps": sd.get("stamps", []),
				"panels": sd.get("panels", []),
				"texts": sd.get("texts", {}),
			}
	# migration : ancien style projet (subtitle/accent au niveau racine) -> écran titre
	if not screens.has("title") and (data.has("subtitle") or data.has("accent")):
		screens["title"] = {
			"accent": data.get("accent", "3498db"),
			"bg": int(data.get("bg", 0)),
			"subtitle": data.get("subtitle", ""),
			"deco": {}, "stamps": [], "texts": {},
		}
	# niveaux : nouveau format {levels} ou migration de l'ancien (grille racine)
	levels = {}
	if data.has("levels"):
		for id in data["levels"]:
			levels[str(id)] = _parse_level(data["levels"][id])
		cur_level = str(data.get("cur_level", "1"))
		if not levels.has(cur_level): cur_level = str(levels.keys()[0])
	else:
		levels["1"] = _parse_level(data)   # ancien projet = 1 niveau
		cur_level = "1"
	_level_unpack(levels[cur_level])
	levels.erase(cur_level)
	undo_stack.clear(); redo_stack.clear()
	cursor = Vector2i(4, rows - 3)
	aim = Vector2(-1, -1); cam_init = false; grabbing = false
	gfx.apply()
	mode = "edit"; dash_sel = 0
	if go_dash:
		states.change_state("GameDashState")


func _serialize_level(L: Dictionary) -> Dictionary:
	var out := {"name": str(L.get("name", "")), "cols": int(L.get("cols", LEVEL_COLS_DEF)), "bg": int(L.get("bg", 0)),
		"tiles": {}, "cfg": {}, "bg_deco": L.get("bg_deco", []),
		"rooms": (L.get("rooms", []) as Array).map(func(r): return [r.position.x, r.position.y, r.size.x, r.size.y])}
	for k in L.get("tiles", {}):
		out["tiles"]["%d,%d" % [k.x, k.y]] = L["tiles"][k]
	for k in L.get("cfg", {}):
		out["cfg"]["%d,%d" % [k.x, k.y]] = L["cfg"][k]
	return out


# construit le dict de sauvegarde complet (réutilisé par save ET export .spark)
func _build_save_dict() -> Dictionary:
	if cur_project == "":
		cur_project = "Plateformer 1"
	var all_levels := levels.duplicate()
	all_levels[cur_level] = _level_pack()
	var lv := {}
	for id in all_levels:
		lv[id] = _serialize_level(all_levels[id])
	var d := {"name": cur_project, "dim": cur_dim, "template": cur_template,
		"props": level_props, "screens": screens,
		"levels": lv, "cur_level": cur_level,
		"progress": {"unlocked": game_unlocked},
		# identité : celui qui sauvegarde signe (voyagera dans le .spark → feed/titre)
		"author": String(creator.get("name", "")),
		"author_color": int(creator.get("color", 0))}
	if cur_remix_of != "":   # crédit remix conservé à travers les saves
		d["remix_of"] = cur_remix_of
		d["remix_by"] = cur_remix_by
	return d


func _save_current() -> void:
	if ProjectStore.save(_build_save_dict()):
		_set_toast("Sauvegardé : %s" % cur_project)
	else:
		_set_toast("Erreur sauvegarde")


# validation "façon Mario Maker" : on ne partage que ce qui est jouable
# (au moins un départ ET une arrivée, toutes zones confondues)
func _validate_for_share() -> String:
	var all := levels.duplicate()
	all[cur_level] = _level_pack()
	var has_spawn := false
	var has_goal := false
	for id in all:
		var tiles: Dictionary = (all[id] as Dictionary).get("tiles", {})
		for k in tiles:
			if tiles[k] == tmpl.SPAWN: has_spawn = true
			elif tiles[k] == tmpl.GOAL: has_goal = true
	if not has_spawn: return "il manque un point de départ (Spawn)"
	if not has_goal: return "il manque une arrivée (Goal)"
	return ""


func _export_creation() -> void:
	var reason := _validate_for_share()
	if reason != "":
		_set_toast("Partage refusé : %s" % reason); return
	_save_current()
	var fp := ProjectStore.export_spark(_build_save_dict())
	if fp == "":
		_set_toast("Export échoué")
	else:
		_set_toast("Exporté → %s" % fp.get_file())


# ---------------- sélection / copier-coller
func _start_selection() -> void:
	sel_mode = true; sel_anchor = Vector2i(-1, -1)
	_set_toast("A: 1er coin puis 2e coin · B: annuler")


func _sel_click() -> void:
	if sel_anchor == Vector2i(-1, -1):
		sel_anchor = cursor
		_set_toast("Coin 1 posé · A: coin 2")
	else:
		_copy_region(sel_anchor, cursor)
		sel_mode = false; sel_anchor = Vector2i(-1, -1)


func _sel_cancel() -> void:
	sel_mode = false; sel_anchor = Vector2i(-1, -1); _set_toast("Sélection annulée"); queue_redraw()


func _copy_region(a: Vector2i, b: Vector2i) -> void:
	var x0 := mini(a.x, b.x); var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y); var y1 := maxi(a.y, b.y)
	clipboard.clear()
	clip_size = Vector2i(x1 - x0 + 1, y1 - y0 + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			if grid.has(c): clipboard[c - Vector2i(x0, y0)] = grid[c]
	_set_toast("Copié %d×%d · Menu > Coller ici" % [clip_size.x, clip_size.y])


func _paste_clip() -> void:
	if clipboard.is_empty():
		_set_toast("Presse-papier vide"); return
	_push_undo()
	for off in clipboard:
		var c: Vector2i = cursor + off
		if c.x >= 0 and c.x < cols and c.y >= 0 and c.y < rows:
			grid[c] = clipboard[off]
	_set_toast("Collé"); _redraw_world()


func _dir_held() -> Vector2i:
	var v := Vector2i.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP): v.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN): v.y += 1
	var ax := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ay := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(ax) > DEADZONE: v.x += int(signf(ax))
	if absf(ay) > DEADZONE: v.y += int(signf(ay))
	return Vector2i(clampi(v.x, -1, 1), clampi(v.y, -1, 1))


func _stick() -> Vector2:
	var s := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	return s if s.length() > DEADZONE else Vector2.ZERO


# ============================================================= PROCESS (éditeur)
func _process(delta: float) -> void:
	anim_t += delta
	_update_fx(delta)
	# transition de style graphique (wipe) : déléguée au module
	if gfx.process(delta):
		queue_redraw()
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0: queue_redraw()
	if warp_cd > 0.0: warp_cd -= delta
	if show_fps: queue_redraw()   # overlay FPS : rafraîchit le chrome (monde intact)
	if screen == "screenedit":
		_screenedit_process(delta)
		queue_redraw()
		return
	if screen == "gamedash":
		queue_redraw()
		return
	if screen == "game":
		queue_redraw()   # écrans animés (titre clignotant)
		return
	if screen == "workshop":
		queue_redraw()
		return
	if screen == "list" or screen == "dim" or screen == "template":
		ui_sel_f = lerpf(ui_sel_f, float(sel), minf(1.0, delta * 14.0))   # sélecteur glissant
		queue_redraw()
		return
	if ai_open:
		queue_redraw()
		return
	# mode jeu : victoire de zone (après une courte fête) et game over différé
	if game_mode and mode == "play":
		if tmpl.won and game_win_t <= 0.0:
			game_win_t = 1.4
		if game_win_t > 0.0:
			game_win_t -= delta
			if game_win_t <= 0.0:
				_game_zone_won()
				return
		if game_over_t > 0.0:
			game_over_t -= delta
			if game_over_t <= 0.0:
				_stop_play(); game_mode = false
				screen = "game"; game_stage = "over"
				_play("death"); queue_redraw()
				return
	if screen != "edit" or mode == "play":
		return
	_auto_resize_cols()
	if menu_open or ai_open:
		return
	var peek := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5 or Input.is_key_pressed(KEY_SHIFT)
	if peek != dezoom:
		dezoom = peek; queue_redraw(); _redraw_world()   # zoom change → recalcul vue/monde
	var l2 := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5 or Input.is_key_pressed(KEY_Q)
	if l2 and not radial_open:
		radial_open = true; radial_pick = cat_pal[cat]
	elif not l2 and radial_open:
		radial_open = false; cat_pal[cat] = radial_pick; queue_redraw()
	if radial_open:
		queue_redraw()
		return
	# --- édition du fond : pointeur au stick uniquement (croix réservée au panneau) ---
	if bg_edit:
		var ab := _edit_area()
		if aim.x < 0.0: aim = ab.position + ab.size * 0.5
		var sb := _stick()
		if sb != Vector2.ZERO: aim += sb * AIM_SPEED * delta
		aim.x = clampf(aim.x, ab.position.x, ab.position.x + ab.size.x)
		aim.y = clampf(aim.y, ab.position.y, ab.position.y + ab.size.y)
		if _edge_pan(ab, delta, sb): _redraw_world()
		bg_ed.process_triggers()   # L2/R2 : reculer/avancer le décor visé
		queue_redraw()
		return
	# --- pointeur libre : stick (vélocité) + croix directionnelle (pas d'une cellule) ---
	var area := _edit_area()
	if aim.x < 0.0:
		aim = area.position + area.size * 0.5
	var st := _stick()
	if st != Vector2.ZERO:
		aim += st * AIM_SPEED * delta
	var d := _dpad_held()
	if d == Vector2i.ZERO:
		cursor_cd = 0.0; hold_time = 0.0; last_dir = Vector2i.ZERO
	else:
		hold_time += delta
		cursor_cd -= delta
		if d != last_dir:
			_nudge_aim(d); cursor_cd = CURSOR_DELAY; last_dir = d; hold_time = 0.0
		elif cursor_cd <= 0.0:
			_nudge_aim(d)
			cursor_cd = RATE_SLOW if cursor_mode == "précis" else lerpf(RATE_SLOW, RATE_FAST, clampf(hold_time / 0.6, 0.0, 1.0))
	aim.x = clampf(aim.x, area.position.x, area.position.x + area.size.x)
	aim.y = clampf(aim.y, area.position.y, area.position.y + area.size.y)
	var push := Vector2(st.x + float(d.x), st.y + float(d.y))
	var panned := _edge_pan(area, delta, push)
	var moved := st != Vector2.ZERO or d != Vector2i.ZERO or panned
	if moved:
		_sync_cursor_from_aim()
	if panned:
		_redraw_world()   # le pan déplace monde+parallax → redraw monde
	if sel_mode:
		if moved: queue_redraw()
		return
	var grid_changed := false
	if place_held and not grabbing and grid.get(cursor) != _active_tile():
		tmpl.place_tile(cursor, _active_tile(), false); grid_changed = true
	elif erase_held and grid.has(cursor) and cursor != erase_last:
		# une seule couche par case et par stroke (l'effacement est PROGRESSIF :
		# objet → étage de bloc → sol → vide ; tenir B ne doit pas tout raser)
		tmpl.erase_tile(cursor); erase_last = cursor; grid_changed = true
	if grid_changed:
		_redraw_world()
	if moved or grid_changed or not particles.is_empty():
		queue_redraw()


func _edit_area() -> Rect2:
	# inclut la TOPBAR : le pointeur peut atteindre la palette du haut
	var vp := get_viewport_rect().size
	return Rect2(0, 0, vp.x, vp.y - BOTTOM)


func _dpad_held() -> Vector2i:
	var v := Vector2i.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP): v.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN): v.y += 1
	return v


func _nudge_aim(d: Vector2i) -> void:
	# déplace le pointeur d'une cellule dans la direction d
	aim += Vector2(d) * CELL * view_scale


# clic pointeur sur la barre du haut (palette) : catégorie / cycle de tuile
func _topbar_click() -> bool:
	if aim.y >= TOPBAR + 14.0 or mode != "edit" or bg_edit: return false
	var i := int((aim.x - 90.0) / 52.0)
	if aim.x >= 90.0 and i >= 0 and i < _cats().size():
		if i == cat:
			# catégorie déjà active → tuile suivante dans la catégorie
			var n: int = (_cats()[i]["tiles"] as Array).size()
			cat_pal[i] = (cat_pal[i] + 1) % n
		else:
			cat = i
		_play("coin"); queue_redraw()
	return true   # tout clic dans la topbar est consommé (pas de pose dessous)


func _insp_hover() -> bool:
	return insp_panel.size.x > 0.0 and insp_panel.has_point(aim)


# clic/A sur une ligne de l'inspecteur : change la valeur (dir = +1 / -1)
func _insp_click(dir: int) -> bool:
	if not _insp_hover(): return false
	for i in insp_rows.size():
		if (insp_rows[i] as Rect2).has_point(aim):
			var t: int = int(grid.get(insp_cell, -1))
			cfg_fields = _cfg_fields_for(t)
			if i < cfg_fields.size():
				cfg_cell = insp_cell; cfg_idx = i
				_cfg_adjust(dir)
				_play("coin")
			return true
	return true   # clic dans le panneau (hors ligne) : consommé quand même


func _sync_cursor_from_aim() -> void:
	if _insp_hover(): return   # pointeur sur l'inspecteur : on n'édite pas dessous
	var c: Vector2i = tmpl.screen_to_cell(aim)
	cursor.x = clampi(c.x, 0, cols - 1)
	cursor.y = clampi(c.y, 0, rows - 1)


func _edge_pan(area: Rect2, delta: float, push: Vector2) -> bool:
	# vitesse proportionnelle à l'enfoncement dans la marge : au bord = vitesse max.
	# Ne pane QUE si on pousse activement vers ce bord (sinon le pointeur collé au
	# bord scrollerait tout seul indéfiniment).
	var pan := Vector2.ZERO
	var lo_x := area.position.x + EDGE_MARGIN
	var hi_x := area.position.x + area.size.x - EDGE_MARGIN
	var lo_y := area.position.y + EDGE_MARGIN
	var hi_y := area.position.y + area.size.y - EDGE_MARGIN
	if aim.x < lo_x and push.x < -0.1: pan.x = -(lo_x - aim.x) / EDGE_MARGIN
	elif aim.x > hi_x and push.x > 0.1: pan.x = (aim.x - hi_x) / EDGE_MARGIN
	if aim.y < lo_y and push.y < -0.1: pan.y = -(lo_y - aim.y) / EDGE_MARGIN
	elif aim.y > hi_y and push.y > 0.1: pan.y = (aim.y - hi_y) / EDGE_MARGIN
	if pan == Vector2.ZERO: return false
	pan.x = clampf(pan.x, -1.0, 1.0); pan.y = clampf(pan.y, -1.0, 1.0)
	cam_init = true
	cam_focus += pan * PAN_SPEED * delta / maxf(view_scale, 0.01)
	var lvl := Vector2(cols * CELL, rows * CELL)
	cam_focus.x = clampf(cam_focus.x, 0.0, lvl.x)
	cam_focus.y = clampf(cam_focus.y, 0.0, lvl.y)
	return true


func _screenedit_process(delta: float) -> void:
	if text_edit_mode or se_tool == TOOL_STYLE:
		return
	# gâchettes L2/R2 : taille tampon / opacité panneau (manette)
	if se_tool == TOOL_TAMPON:
		if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			se_stamp_size = minf(se_stamp_size + delta * 0.4, 1.0); queue_redraw()
		elif Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5:
			se_stamp_size = maxf(se_stamp_size - delta * 0.4, 0.02); queue_redraw()
	elif se_tool == TOOL_PANNEAU:
		if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			se_panel_alpha = minf(se_panel_alpha + delta * 1.5, 1.0); queue_redraw()
		elif Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5:
			se_panel_alpha = maxf(se_panel_alpha - delta * 1.5, 0.1); queue_redraw()
	var dims := _se_dims()
	var d := _dir_held()
	if d == Vector2i.ZERO:
		cursor_cd = 0.0; hold_time = 0.0; last_dir = Vector2i.ZERO
	else:
		hold_time += delta
		cursor_cd -= delta
		var step := false
		if d != last_dir:
			step = true; cursor_cd = CURSOR_DELAY; last_dir = d; hold_time = 0.0
		elif cursor_cd <= 0.0:
			step = true
			cursor_cd = lerpf(RATE_SLOW, RATE_FAST, clampf(hold_time / 0.6, 0.0, 1.0))
		if step:
			if se_tool == TOOL_TEXTE:
				_move_text(d.x * 0.01, d.y * 0.01)
			else:
				se_cursor.x = clampi(se_cursor.x + d.x, 0, int(dims.x) - 1)
				se_cursor.y = clampi(se_cursor.y + d.y, 0, int(dims.y) - 1)
	if se_place_held: _paint_deco_cell()
	elif se_erase_held: _erase_deco_cell()


func _auto_resize_cols() -> void:
	var max_x := -1
	var max_y := -1
	for k in grid:
		if k.x > max_x: max_x = k.x
		if k.y > max_y: max_y = k.y
	var new_cols := clampi(max_x + 5, 16, 200)
	# hauteur du niveau = contenu (mini = hauteur écran), pour que la caméra suive en Y
	var base_rows := maxi(6, int((get_viewport_rect().size.y - TOPBAR - BOTTOM) / CELL))
	var new_rows := clampi(max_y + 5, base_rows, 200)
	if new_cols != cols or new_rows != rows:
		cols = new_cols; rows = new_rows
		cursor.x = mini(cursor.x, cols - 1); cursor.y = mini(cursor.y, rows - 1)
		queue_redraw(); _redraw_world()


# ============================================================= FX
func _emit(pos: Vector2, count: int, col: Color, spd: float, life: float, grav := true, size := 4.0) -> void:
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * (spd * (0.4 + randf() * 0.6))
		particles.append({"pos": pos, "vel": v, "life": life, "max": life, "col": col, "size": size * (0.6 + randf() * 0.6), "grav": grav})


func _shake(mag: float, t: float) -> void:
	shake_mag = max(shake_mag, mag); shake_t = max(shake_t, t)


func _update_fx(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		if shake_t <= 0.0: shake_mag = 0.0
	squash = squash.lerp(Vector2.ONE, clampf(delta * 12.0, 0.0, 1.0))
	if particles.is_empty():
		return
	var keep := []
	for p in particles:
		p.life -= delta
		if p.life <= 0.0: continue
		if p.grav: p.vel.y += 1100.0 * delta
		p.pos += p.vel * delta
		keep.append(p)
	particles = keep
	queue_redraw()


# ============================================================= PLAY (délégué au template)
# =============================================== MULTI-NIVEAUX (zones reliées)
func level_name(id: String) -> String:
	var nm := cur_level_name if id == cur_level else str((levels.get(id, {}) as Dictionary).get("name", ""))
	return nm if nm != "" else "Zone %s" % id


func _backup_level_for_play(id: String) -> void:
	if play_backup.has(id): return
	if id == cur_level:
		play_backup[id] = _level_pack()
	elif levels.has(id):
		play_backup[id] = (levels[id] as Dictionary).duplicate(true)


func _restore_play_world() -> void:
	for id in play_backup:
		if id == cur_level:
			_level_unpack((play_backup[id] as Dictionary).duplicate(true))
		else:
			levels[id] = (play_backup[id] as Dictionary).duplicate(true)
	play_backup.clear()

func level_ids() -> Array:
	var ids := levels.keys()
	if not ids.has(cur_level): ids.append(cur_level)
	ids.sort()
	return ids


func _level_pack() -> Dictionary:
	return {"name": cur_level_name, "cols": cols, "bg": bg_theme, "tiles": grid.duplicate(),
		"cfg": cell_cfg.duplicate(true), "bg_deco": bg_deco.duplicate(true),
		"rooms": rooms.duplicate()}


func _level_unpack(L: Dictionary) -> void:
	cur_level_name = str(L.get("name", ""))
	cols = int(L.get("cols", LEVEL_COLS_DEF))
	bg_theme = int(L.get("bg", 0)) % BG_THEMES.size()
	grid = L.get("tiles", {})
	cell_cfg = L.get("cfg", {})
	bg_deco = L.get("bg_deco", [])
	rooms = L.get("rooms", [])
	cur_room = -1
	undo_stack.clear(); redo_stack.clear()
	_auto_resize_cols()
	cam_init = false


func _switch_level(id: String) -> void:
	if id == cur_level or not levels.has(id): return
	if mode == "play": _backup_level_for_play(id)
	levels[cur_level] = _level_pack()
	cur_level = id
	_level_unpack(levels[id])
	queue_redraw(); _redraw_world()


func _add_level() -> void:
	levels[cur_level] = _level_pack()
	var n := 1
	while levels.has(str(n)) or str(n) == cur_level: n += 1
	cur_level = str(n)
	cols = LEVEL_COLS_DEF; bg_theme = 0
	grid = {}; cell_cfg = {}; bg_deco = []; rooms = []
	cur_room = -1
	undo_stack.clear(); redo_stack.clear()
	tmpl.seed_demo()
	_auto_resize_cols()
	cur_level_name = "Zone %s" % cur_level
	_set_toast("Zone créée : %s" % cur_level_name)
	queue_redraw(); _redraw_world()


func _delete_level() -> void:
	if levels.is_empty():
		_set_toast("Impossible : dernier niveau"); return
	var ids := levels.keys(); ids.sort()
	var nxt: String = ids[0]
	cur_level = nxt
	_level_unpack(levels[nxt])
	levels.erase(nxt)
	_set_toast("Niveau supprimé → %s" % cur_level)
	queue_redraw(); _redraw_world()


func _cycle_level() -> void:
	var ids := level_ids()
	if ids.size() < 2:
		_set_toast("Un seul niveau (Nouveau niveau pour en ajouter)"); return
	var i := ids.find(cur_level)
	_switch_level(str(ids[(i + 1) % ids.size()]))
	_set_toast(level_name(cur_level))


# warp en PLAY : touche une tuile Sortie → bascule de niveau + spawn à la porte cible
func _warp_play(c: Vector2i) -> void:
	if warp_cd > 0.0 or mode != "play": return
	var cfg: Dictionary = cell_cfg.get(c, {})
	var dest := str(cfg.get("dest", ""))
	var door := int(cfg.get("door", 1))
	if dest == "" or dest == cur_level or not (levels.has(dest) or dest == cur_level):
		_set_toast("Sortie non configurée (Configurer objet…)"); warp_cd = 1.0; return
	_switch_level(dest)
	# porte d'arrivée : warp du niveau cible dont l'id correspond
	var arrival := Vector2i(-1, -1)
	for k in grid:
		if grid[k] == tmpl.WARP and int(cell_cfg.get(k, {}).get("id", 1)) == door:
			arrival = k; break
	tmpl._build_entities()
	if arrival == Vector2i(-1, -1):
		arrival = tmpl._find(tmpl.SPAWN)
		if arrival == Vector2i(-1, -1): arrival = Vector2i(2, 2)
	tmpl._place_player(arrival)
	tmpl.respawn_cell = arrival
	warp_cd = 1.0
	cam_init = false; cur_room = -1
	_set_toast("→ %s" % level_name(cur_level))
	_play("warp")
	queue_redraw(); _redraw_world()


func _start_play(from_cursor: bool) -> void:
	_restore_play_world()                 # mutations d'un test précédent → état auteur
	_backup_level_for_play(cur_level)     # snapshot du niveau de départ
	visited_rooms.clear(); map_open = false
	tmpl.start_play(from_cursor)
	mode = "play"
	cam_init = false; cur_room = -1   # snap caméra (salle ou suivi) au démarrage du test
	queue_redraw(); _redraw_world()


func _stop_play() -> void:
	mode = "edit"
	tmpl.stop_play()
	_restore_play_world()                 # l'éditeur retrouve l'état auteur
	queue_redraw(); _redraw_world()


# ============================================================= VUE (utilisée par le template)
func _w2s(wp: Vector2) -> Vector2:
	return view_origin + wp * view_scale


func _s2w(sp: Vector2) -> Vector2:
	return (sp - view_origin) / view_scale


const ROOM_VIEW_H := 11   # hauteur visible en cases (zoom constant, façon Celeste ~11 tuiles)

# caméra style Celeste : ZOOM CONSTANT, suit le joueur, clampée aux bords de la salle
func _compute_room_view(area: Rect2) -> void:
	var pc: Vector2 = tmpl.ppos + tmpl.PSIZE * 0.5
	var pcell := Vector2i(int(pc.x / CELL), int(pc.y / CELL))
	for i in rooms.size():
		if (rooms[i] as Rect2i).has_point(pcell):
			cur_room = i
			visited_rooms["%s:%d" % [cur_level, i]] = true
			break
	var sc: float = area.size.y / (ROOM_VIEW_H * CELL)   # zoom fixe (identique partout)
	var target := area.position + area.size * 0.5 - pc * sc   # centré sur le joueur
	if cur_room >= 0 and cur_room < rooms.size():
		var r: Rect2i = rooms[cur_room]
		target.x = _room_clamp(target.x, area.position.x, area.size.x, r.position.x * CELL, r.size.x * CELL, sc)
		target.y = _room_clamp(target.y, area.position.y, area.size.y, r.position.y * CELL, r.size.y * CELL, sc)
	else:
		# hors salle (ou aucune salle) : le niveau entier sert de salle → jamais de vide hors-monde
		target.x = _room_clamp(target.x, area.position.x, area.size.x, 0.0, cols * CELL, sc)
		target.y = _room_clamp(target.y, area.position.y, area.size.y, 0.0, rows * CELL, sc)
	if not cam_init:
		view_scale = sc; view_origin = target; cam_init = true
	else:
		view_scale = lerpf(view_scale, sc, 0.18)
		view_origin = view_origin.lerp(target, 0.18)


# clampe l'origine pour que la vue reste DANS la salle (sinon centre si salle + petite)
func _room_clamp(origin: float, area_min: float, area_size: float, room_min: float, room_size: float, sc: float) -> float:
	var rsz := room_size * sc
	if rsz <= area_size:
		return area_min + (area_size - rsz) * 0.5 - room_min * sc   # salle + petite → centrée
	var lo := area_min + area_size - (room_min + room_size) * sc    # bord droit/bas
	var hi := area_min - room_min * sc                              # bord gauche/haut
	return clampf(origin, lo, hi)


func _compute_view() -> void:
	var vp := get_viewport_rect().size
	var area := Rect2(0, TOPBAR, vp.x, vp.y - TOPBAR - BOTTOM)
	var lvl := Vector2(cols * CELL, rows * CELL)
	if mode == "play" and tmpl.wants_room_camera():
		_compute_room_view(area)
		if shake_t > 0.0:
			view_origin += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_mag
		return
	if mode == "play":
		view_scale = 1.0
		view_origin = area.position + area.size * 0.5 - (tmpl.ppos + tmpl.PSIZE * 0.5) * view_scale
	elif dezoom:
		view_scale = min(area.size.x / lvl.x, area.size.y / lvl.y) * 0.96
		view_origin = area.position
	else:
		view_scale = 1.0
		if not cam_init:
			cam_focus = (Vector2(cursor) + Vector2(0.5, 0.5)) * CELL
			cam_init = true
		view_origin = area.position + area.size * 0.5 - cam_focus * view_scale
	var sw := lvl.x * view_scale; var sh := lvl.y * view_scale
	if sw <= area.size.x: view_origin.x = area.position.x + (area.size.x - sw) * 0.5
	else: view_origin.x = clampf(view_origin.x, area.position.x + area.size.x - sw, area.position.x)
	if sh <= area.size.y: view_origin.y = area.position.y + (area.size.y - sh) * 0.5
	else: view_origin.y = clampf(view_origin.y, area.position.y + area.size.y - sh, area.position.y)
	if shake_t > 0.0:
		view_origin += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_mag


# ============================================================= DRAW (chrome uniquement ; le monde = template)
func _draw() -> void:
	var vp := get_viewport_rect().size
	gfx.resize(vp)
	if screen == "dim":        _draw_dim(vp); return
	if screen == "list":       _draw_list(vp); return
	if screen == "template":   _draw_template(vp); return
	if screen == "gamedash":   _draw_gamedash(vp); return
	if screen == "screenedit": _draw_screenedit(vp); return
	if screen == "game":       _draw_game(vp); return
	if screen == "workshop":   _draw_workshop(vp); return
	# jeu en mode salles : masque tout ce qui dépasse la salle courante (letterbox)
	if mode == "play" and tmpl.wants_room_camera() and cur_room >= 0 and cur_room < rooms.size():
		_draw_room_mask(vp)
	# édition/jeu : le monde est rendu par le template (derrière), ici le chrome par-dessus
	if mode == "edit" and not radial_open and not bg_edit and get("hide_editor_chrome") != true and tmpl.wants_2d_world():
		_draw_edit_cursor()
	_draw_topbar(vp)
	_draw_hints(vp)
	if mode == "edit" and not bg_edit:
		gfx.draw_strip()
	if mode == "edit" and not menu_open and not radial_open and not bg_edit and aim.x >= 0.0:
		_draw_reticle()
	if room_edit: room_ed.draw(vp)
	if mode == "edit" and not menu_open and not radial_open and not bg_edit and not room_edit:
		_draw_inspector(vp)
	if bg_edit: bg_ed.draw(vp)
	if radial_open: _draw_radial(vp)
	if menu_open: _draw_menu(vp)
	if ai_open: _draw_ai_panel(vp)
	if toast_t > 0.0: _draw_toast(vp)
	if mode == "play" and tmpl.won:
		if game_mode:
			# fête courte avant l'écran "zone terminée"
			_ctext(ThemeDB.fallback_font, vp.x * 0.5, vp.y * 0.4, "ZONE TERMINÉE !", Color("2ecc71"), 44)
		else:
			_draw_banner(vp)
	if show_fps:
		var fps := Engine.get_frames_per_second()
		var fcol := Color("2ecc71") if fps >= 55 else (Color("f39c12") if fps >= 30 else Color("e74c3c"))
		var txt := "%d FPS" % fps
		draw_rect(Rect2(Vector2(vp.x - 86, TOPBAR + 6), Vector2(76, 22)), Color(0, 0, 0, 0.55))
		_text(ThemeDB.fallback_font, Vector2(vp.x - 78, TOPBAR + 22), txt, fcol, 14)
	if mode == "play" and map_open: _draw_minimap(vp)
	if lvl_rename: _draw_rename(vp)
	gfx.draw_transition(vp)   # wipe de transition de style (au-dessus de tout)


func _draw_edit_cursor() -> void:
	# curseur d'édition dessiné en overlay (au-dessus du monde) → bouger le pointeur
	# ne redessine que ForgeApp, jamais le monde (template).
	if sel_mode and sel_anchor != Vector2i(-1, -1):
		var x0 := mini(sel_anchor.x, cursor.x); var y0 := mini(sel_anchor.y, cursor.y)
		var x1 := maxi(sel_anchor.x, cursor.x); var y1 := maxi(sel_anchor.y, cursor.y)
		var rr := Rect2(_w2s(Vector2(x0 * CELL, y0 * CELL)), Vector2((x1 - x0 + 1) * CELL, (y1 - y0 + 1) * CELL) * view_scale)
		draw_rect(rr, Color(0.2, 0.8, 1, 0.18)); draw_rect(rr, Color("3498db"), false, 2.0)
	var cp := _w2s(Vector2(cursor.x * CELL, cursor.y * CELL))
	if not sel_mode:
		var ghost_tile: int = grab_tile if grabbing else _active_tile()
		tmpl.draw_tile(self, cp, ghost_tile, view_scale, 0.7 if grabbing else 0.45, grabbing)
	var cc := Color("3498db") if sel_mode else (Color("f39c12") if grabbing else (Color.WHITE if cursor_mode == "rapide" else Color("f39c12")))
	draw_rect(Rect2(cp, Vector2(CELL, CELL) * view_scale), cc, false, 3.0)


# INSPECTEUR (panneau droit) : s'affiche dès que l'objet sous le curseur est
# configurable, reste ÉPINGLÉ tant que le pointeur est dessus. Chaque ligne est
# cliquable au curseur : A/clic = valeur suivante, clic droit = précédente.
# (C / L3 = mode focus dpad, toujours dispo.)
func _draw_inspector(vp: Vector2) -> void:
	# épinglage : nouvel objet configurable sous le curseur → on le suit ;
	# sinon on garde l'objet épinglé tant que le pointeur survole le panneau
	if not cfg_open:
		var cur_t: int = int(grid.get(cursor, -1))
		if not _cfg_fields_for(cur_t).is_empty():
			insp_cell = cursor   # nouvel objet survolé → re-épingle
		elif insp_cell != Vector2i(-999, -999):
			# épingle STICKY : reste tant que l'objet existe. Elle se libère quand
			# on édite AILLEURS (pose/efface sur une autre case, voir _begin_stroke)
			# ou si l'objet a disparu.
			var still: int = int(grid.get(insp_cell, -1))
			if still < 0 or _cfg_fields_for(still).is_empty():
				insp_cell = Vector2i(-999, -999)
	var cell := cfg_cell if cfg_open else insp_cell
	var t: int = int(grid.get(cell, -1))
	var fields := cfg_fields if cfg_open else _cfg_fields_for(t)
	if fields.is_empty() or t < 0:
		insp_panel = Rect2(); insp_rows = []
		return
	var f := ThemeDB.fallback_font
	var pw := 232.0
	var ph := 74.0 + fields.size() * 32.0
	var o := Vector2(vp.x - pw - 10.0, TOPBAR + 12.0)
	insp_panel = Rect2(o, Vector2(pw, ph))
	var hovered := _insp_hover()
	var acc := UI_ACCENT if (cfg_open or hovered) else Color(1, 1, 1, 0.35)
	draw_rect(insp_panel, Color(13.0 / 255, 17.0 / 255, 23.0 / 255, 0.96 if hovered else 0.9))
	draw_rect(insp_panel, acc, false, 2.0 if (cfg_open or hovered) else 1.0)
	# lien visuel : cadre sur l'objet inspecté dans le monde
	var wp := _w2s(Vector2(cell.x * CELL, cell.y * CELL))
	draw_rect(Rect2(wp, Vector2(CELL, CELL) * view_scale), acc, false, 2.0)
	# en-tête : aperçu de la tuile + nom
	tmpl.draw_tile(self, o + Vector2(10, 8), t, 0.55)
	_text(f, o + Vector2(44, 20), tmpl.tile_name(t), Color.WHITE, 14)
	_text(f, o + Vector2(44, 36), "case %d,%d" % [cell.x, cell.y], Color(1, 1, 1, 0.4), 10)
	insp_rows = []
	for i in fields.size():
		var fld: Dictionary = fields[i]
		var y := o.y + 60.0 + i * 32.0
		var row := Rect2(Vector2(o.x + 5, y - 14), Vector2(pw - 10, 28))
		insp_rows.append(row)
		var sel := (cfg_open and i == cfg_idx) or (hovered and row.has_point(aim))
		if sel:
			draw_rect(row, Color(1, 1, 1, 0.10))
		_text(f, Vector2(o.x + 12, y + 5), str(fld["label"]), Color(1, 1, 1, 0.75), 12)
		var val := str(_cfg_get(fld, cell))
		# pastille pour les couleurs (visuel direct)
		if str(fld["key"]) == "color" and tmpl.KEY_COLORS.has(val):
			draw_circle(Vector2(o.x + pw - 76, y), 6.0, tmpl.KEY_COLORS[val])
		var vcol := UI_ACCENT if sel else Color(1, 1, 1, 0.9)
		_text(f, Vector2(o.x + pw - 62, y + 5), "◄ %s ►" % val, vcol, 12)
	var hint := "pointe une ligne · A/clic + · clic droit −"
	if cfg_open: hint = "◄► régler  ▲▼ champ  B OK"
	_text(f, Vector2(o.x + 12, o.y + ph - 10), hint, Color(1, 1, 1, 0.4), 10)


func _draw_reticle() -> void:
	var c := Color("f39c12") if grabbing else Color.WHITE
	draw_arc(aim, 9.0, 0.0, TAU, 18, Color(c.r, c.g, c.b, 0.85), 1.8)
	draw_line(aim - Vector2(13, 0), aim - Vector2(4, 0), c, 1.5)
	draw_line(aim + Vector2(4, 0), aim + Vector2(13, 0), c, 1.5)
	draw_line(aim - Vector2(0, 13), aim - Vector2(0, 4), c, 1.5)
	draw_line(aim + Vector2(0, 4), aim + Vector2(0, 13), c, 1.5)
	draw_circle(aim, 1.6, c)


func _draw_topbar(vp: Vector2) -> void:
	if bg_edit:
		bg_ed.draw_topbar(vp); return
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, TOPBAR)), Color("11161f"))
	var f := ThemeDB.fallback_font
	if mode == "edit":
		_text(f, Vector2(12, 32), "FORGE", Color("f39c12"), 20)
		var x := 90.0
		for i in _cats().size():
			var c_data: Dictionary = _cats()[i]
			var tile_id: int = int((c_data["tiles"] as Array)[cat_pal[i]])
			var is_active := (i == cat)
			var box := Rect2(Vector2(x, 4), Vector2(44, 44))
			draw_rect(box, Color("1a2233") if not is_active else Color("223349"))
			tmpl.draw_tile(self, Vector2(x + 5, 4), tile_id, 34.0 / CELL)
			if is_active:
				draw_rect(box, Color("f39c12"), false, 3.0)
			else:
				draw_rect(box, Color(1, 1, 1, 0.15), false, 1.0)
			_text(f, Vector2(x + 2, 52), str(c_data["name"]).substr(0, 6), (Color("f39c12") if is_active else Color("778899")), 9)
			x += 52
		_text(f, Vector2(x + 8, 22), tmpl.tile_name(_active_tile()), Color("f39c12"), 14)
		_text(f, Vector2(x + 8, 42), "Curseur: %s" % cursor_mode, Color(1, 1, 1, 0.6), 12)
	else:
		var hud_title := "FORGE — TEST"
		if game_mode:
			hud_title = cur_project.to_upper()
			_text(f, Vector2(16, 34), hud_title, Color("f39c12"), 22)
			_text(f, Vector2(16, 52), "%s   ♥ ×%d" % [level_name(cur_level), game_lives], Color(1, 1, 1, 0.75), 13)
		else:
			_text(f, Vector2(16, 34), hud_title, Color("2ecc71"), 22)
		var need_coins: int = int(level_props.get("win_coins", 0))
		var coin_str := "Pièces: %d/%d" % [tmpl.coins_got, tmpl.coins_total]
		if need_coins > 0:
			coin_str = "Pièces: %d/%d (req. %d)" % [tmpl.coins_got, tmpl.coins_total, need_coins]
		var coin_col := Color("f1c40f")
		if need_coins > 0 and tmpl.coins_got < need_coins: coin_col = Color("e67e22")
		# jamais superposé à un titre long : posé après la fin du titre
		var cx0 := maxf(240.0, 16.0 + f.get_string_size(hud_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 28.0)
		_text(f, Vector2(cx0, 34), coin_str, coin_col, 18)
		# clés tenues (par couleur)
		var kx := 540.0
		for kcol in tmpl.keys:
			if int(tmpl.keys[kcol]) > 0:
				var kc: Color = tmpl.KEY_COLORS.get(kcol, Color("f1c40f"))
				draw_circle(Vector2(kx, 30), 6.0, kc)
				draw_rect(Rect2(Vector2(kx - 2, 30), Vector2(4, 12)), kc)
				if int(tmpl.keys[kcol]) > 1:
					_text(f, Vector2(kx + 6, 36), "x%d" % int(tmpl.keys[kcol]), kc, 12)
				kx += 30.0
		# PV joueur : cœurs (pleins/vides)
		var hud_txt: String = tmpl.play_hud_text()
		if hud_txt != "":
			_text(f, Vector2(240, 76), hud_txt, Color("9be7ff"), 13)
		if tmpl.max_hearts > 0:
			for i in tmpl.max_hearts:
				var hc := Color("e74c3c") if i < tmpl.hearts else Color(1, 1, 1, 0.18)
				var hx := 240.0 + i * 26.0
				draw_circle(Vector2(hx, 52), 7.0, hc)
				draw_circle(Vector2(hx + 9, 52), 7.0, hc)
				draw_colored_polygon(PackedVector2Array([
					Vector2(hx - 6, 54), Vector2(hx + 15, 54), Vector2(hx + 4.5, 66)]), hc)
		# objectif "tuer tous" : compteur d'ennemis restants
		if level_props.get("win_killall", false):
			var left: int = tmpl._enemies_left()
			_text(f, Vector2(600, 34), "Ennemis: %d" % left, Color("2ecc71") if left == 0 else Color("e74c3c"), 18)
		# chrono
		if level_props.get("time_limit", 0) > 0 and mode == "play":
			var tl: float = tmpl.time_left
			var tcol := Color("ffffff") if tl > 10.0 else Color("e74c3c")
			_text(f, Vector2(790, 34), "⏱ %d" % ceili(tl), tcol, 20)
		# jauge d'air (noyade) : bulles qui se vident sous l'eau
		if level_props.get("water_drown", false):
			var frac: float = clampf(tmpl.air_t / tmpl.AIR_MAX, 0.0, 1.0)
			var n := 8
			for i in n:
				var on := float(i) / float(n) < frac
				var bc := Color("aee3f0") if on else Color(1, 1, 1, 0.15)
				draw_circle(Vector2(470 + i * 18, 26), 6.0, bc)
			if frac < 0.34:
				_text(f, Vector2(470, 48), "⚠ AIR", Color("e74c3c"), 12)
		else:
			# texte debug fourni par le genre (ex: sonic) — vide = rien
			var dbg := tmpl.debug_text()
			if dbg != "" and show_fps:
				_text(f, Vector2(470, 34), dbg, Color("00e5ff"), 14)


func _draw_hints(vp: Vector2) -> void:
	if bg_edit:
		bg_ed.draw_hints(vp); return
	draw_rect(Rect2(Vector2(0, vp.y - BOTTOM), Vector2(vp.x, BOTTOM)), Color("11161f"))
	var x := 12.0
	var y := vp.y - BOTTOM + 6.0
	if mode == "edit":
		if sel_mode:
			x = _badge(x, y, "A", "Poser coin")
			x = _badge(x, y, "B", "Annuler")
		else:
			x = _badge(x, y, "A", "Placer/Déplacer" if not grabbing else "Déposer")
			x = _badge(x, y, "B", "Effacer")
			x = _badge(x, y, "L1/R1", "Categorie")
			x = _badge(x, y, "L2", "Tuile")
			x = _badge(x, y, "X", "Annuler")
			x = _badge(x, y, "Y", "Refaire")
			x = _badge(x, y, "R2", "Vue")
			x = _badge(x, y, "ST", "Tester")
			x = _badge(x, y, "Sel", "Menu")
	else:
		# badges de test fournis par le genre (le shell ne connaît pas les genres)
		for b in tmpl.play_badges():
			x = _badge(x, y, str(b[0]), str(b[1]))


func _badge(x: float, y: float, glyph: String, label: String) -> float:
	var f := ThemeDB.fallback_font
	var gw := 26.0
	draw_rect(Rect2(Vector2(x, y), Vector2(gw, 22)), Color("2c3e50"), true)
	draw_rect(Rect2(Vector2(x, y), Vector2(gw, 22)), Color("f39c12"), false, 1.5)
	_text(f, Vector2(x + 4, y + 16), glyph, Color.WHITE, 12)
	_text(f, Vector2(x + gw + 5, y + 16), label, Color(1, 1, 1, 0.7), 12)
	return x + gw + 5 + label.length() * 6.2 + 14


func _draw_radial(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var tiles: Array = _cats()[cat]["tiles"]
	var n: int = tiles.size()
	var slot := 52.0
	var total: float = float(n) * slot
	var ox: float = vp.x * 0.5 - total * 0.5
	var oy: float = vp.y * 0.5 - 80.0
	var pw: float = total + 20.0; var ph := 100.0
	draw_rect(Rect2(Vector2(ox - 10, oy - 10), Vector2(pw, ph)), Color(0, 0, 0, 0.82))
	draw_rect(Rect2(Vector2(ox - 10, oy - 10), Vector2(pw, ph)), Color("f39c12"), false, 2.0)
	_text(f, Vector2(ox - 8, oy + 6), str(_cats()[cat]["name"]), Color("f39c12", 0.7), 11)
	for i in n:
		var tile_id: int = int(tiles[i])
		var is_sel: bool = (i == radial_pick)
		var bx: float = ox + float(i) * slot
		var box := Rect2(Vector2(bx, oy + 14), Vector2(44, 44))
		draw_rect(box, Color("223349"))
		tmpl.draw_tile(self, Vector2(bx, oy + 14), tile_id, 44.0 / CELL)
		if is_sel:
			draw_rect(box, Color.WHITE, false, 4.0)
	if radial_pick < n:
		var sel_name: String = tmpl.tile_name(tiles[radial_pick])
		_ctext(f, vp.x * 0.5, oy + 72, sel_name, Color.WHITE, 14)
	_text(f, Vector2(ox - 8, oy + 88), "← →  choisir  |  Relache L2  confirmer", Color(1,1,1,0.5), 10)


func _draw_menu(vp: Vector2) -> void:
	# menu défilant : ne déborde jamais de l'écran, fenêtre centrée sur la sélection
	var f := ThemeDB.fallback_font
	var w := 340.0
	var row := 34.0
	var head := 50.0
	var vis: int = mini(menu_items.size(), int((vp.y - 110.0 - head) / row))
	var h := vis * row + head + 12.0
	var o := vp * 0.5 - Vector2(w * 0.5, h * 0.5)
	var first: int = clampi(menu_idx - vis / 2, 0, maxi(0, menu_items.size() - vis))
	draw_rect(Rect2(o, Vector2(w, h)), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(o, Vector2(w, h)), Color("f39c12"), false, 2.0)
	_text(f, o + Vector2(16, 30), "MENU", Color("f39c12"), 20)
	if first > 0:
		_text(f, Vector2(o.x + w - 30, 30 + o.y), "▲", Color(1, 1, 1, 0.6), 14)
	if first + vis < menu_items.size():
		_text(f, Vector2(o.x + w - 30, o.y + h - 12), "▼", Color(1, 1, 1, 0.6), 14)
	for k in vis:
		var i := first + k
		var y := o.y + 56 + k * row
		if i == menu_idx:
			draw_rect(Rect2(Vector2(o.x + 8, y - 18), Vector2(w - 16, 28)), Color(1, 1, 1, 0.12))
		_text(f, Vector2(o.x + 20, y), menu_items[i], Color.WHITE if i == menu_idx else Color(1, 1, 1, 0.65), 16)


func _draw_toast(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 46.0
	# petit slide-in : arrive du haut sur les ~0.15 premières secondes
	var slide := clampf((2.0 - toast_t) / 0.15, 0.0, 1.0)   # toast_t part de 2.0 (_set_toast)
	var o := Vector2(vp.x * 0.5 - w * 0.5, TOPBAR + 14 - (1.0 - slide) * 26.0)
	var r := Rect2(o, Vector2(w, 32))
	draw_style_box(ForgeUI.sb(Color("0d1322", 0.92), 16, Color(ForgeUI.ACCENT.r, ForgeUI.ACCENT.g, ForgeUI.ACCENT.b, 0.7), 1, 6), r)
	draw_style_box(ForgeUI.sb(ForgeUI.ACCENT, 2), Rect2(o + Vector2(12, 9), Vector2(4, 14)))
	_text(f, o + Vector2(26, 22), toast, Color.WHITE, 15)


func _draw_banner(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var col := Color("2ecc71")
	var box := Rect2(vp * 0.5 - Vector2(210, 95), Vector2(420, 190))
	draw_rect(box, Color(0, 0, 0, 0.78)); draw_rect(box, col, false, 3.0)
	_ctext(f, vp.x * 0.5, vp.y * 0.5 - 38, "GAGNÉ !", col, 40)
	# stats du run : temps + pièces (façon écran de fin)
	var mins := int(tmpl.play_time) / 60
	var secs := fmod(tmpl.play_time, 60.0)
	var stats := "Temps  %d:%05.2f" % [mins, secs]
	if tmpl.coins_total > 0:
		stats += "      Pièces  %d/%d" % [tmpl.coins_got, tmpl.coins_total]
	_ctext(f, vp.x * 0.5, vp.y * 0.5 + 8, stats, Color("f1c40f"), 18)
	_ctext(f, vp.x * 0.5, vp.y * 0.5 + 62, "Y: Rejouer   Start/B: Éditeur", Color.WHITE, 16)


func _text(f: Font, pos: Vector2, s: String, col: Color, size: int) -> void:
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _ctext(f: Font, cx: float, y: float, s: String, col: Color, size: int) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(cx - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _shell_bg(vp: Vector2, with_title := true) -> void:
	ForgeUI.bg(self, vp)
	if with_title:
		var f := ThemeDB.fallback_font
		ForgeUI.glow(self, Vector2(vp.x * 0.5, 78.0), 170.0, ForgeUI.ACCENT)
		_ctext(f, vp.x * 0.5, 90, "FORGE", ForgeUI.ACCENT, 56)
		_ctext(f, vp.x * 0.5, 114, "crée · partage · joue", ForgeUI.TXT_FAINT, 13)


func _draw_dim(vp: Vector2) -> void:
	_shell_bg(vp)
	var f := ThemeDB.fallback_font
	_ctext(f, vp.x * 0.5, 168, "Choisis un type de création", ForgeUI.TXT_DIM, 18)
	var opts := ["2D", "3D"]
	var bw := 230.0; var bh := 170.0; var gap := 44.0
	var x0 := vp.x * 0.5 - bw - gap * 0.5
	for i in 2:
		var bx := x0 + i * (bw + gap)
		var box := Rect2(Vector2(bx, vp.y * 0.52 - bh * 0.5), Vector2(bw, bh))
		if i == sel: box = box.grow(6.0)   # la carte choisie respire
		ForgeUI.card(self, box, i == sel, anim_t)
		var cy := box.position.y + box.size.y * 0.5
		_ctext(f, box.position.x + box.size.x * 0.5, cy + 16, opts[i], Color.WHITE if i == sel else ForgeUI.TXT_DIM, 58)
		if i == 1 and (TEMPLATES.get("3D", []) as Array).is_empty():
			_ctext(f, box.position.x + box.size.x * 0.5, cy + 52, "bientôt", ForgeUI.TXT_FAINT, 14)
	ForgeUI.footer(self, vp, [["◄ ►", "choisir"], ["A", "valider"]])


func _draw_list(vp: Vector2) -> void:
	_shell_bg(vp)
	var f := ThemeDB.fallback_font
	_ctext(f, vp.x * 0.5, 158, "Projets — %s" % cur_dim, ForgeUI.TXT_DIM, 17)
	var np := proj_list.size()
	var n := np + 3   # projets + Nouveau + Importer + WORKSHOP
	var y0 := 192.0
	var row_h := 46.0
	# sélecteur glissant (ui_sel_f lissé dans _process)
	var sel_r := Rect2(Vector2(vp.x * 0.5 - 244, y0 + ui_sel_f * row_h - 20), Vector2(488, 40))
	ForgeUI.card(self, sel_r, true, anim_t)
	for i in n:
		var y := y0 + i * row_h
		var label: String
		var col: Color
		if i < np:
			label = "📄  " + String(proj_list[i]["name"]); col = Color.WHITE if i == sel else ForgeUI.TXT_DIM
		elif i == np:
			label = "＋  Nouveau projet"; col = ForgeUI.GREEN if i == sel else ForgeUI.GREEN.darkened(0.25)
		elif i == np + 1:
			label = "📥  Importer une création…"; col = ForgeUI.CYAN if i == sel else ForgeUI.CYAN.darkened(0.3)
		else:
			label = "🌐  WORKSHOP — jouer des créations"; col = ForgeUI.PURPLE if i == sel else ForgeUI.PURPLE.darkened(0.3)
		_text(f, Vector2(vp.x * 0.5 - 224, y + 6), label, col, 18)
	if proj_list.is_empty():
		_ctext(f, vp.x * 0.5, y0 - 26, "Aucun projet — crée le premier", ForgeUI.TXT_FAINT, 14)
	# chip profil créateur (haut droite) : avatar + nom — "le créateur est VU"
	var av := CreatorProfile.avatar_color(creator)
	var cname := String(creator.get("name", CreatorProfile.DEFAULT_NAME))
	var cw := f.get_string_size(cname, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var chip_r := Rect2(Vector2(vp.x - cw - 74.0, 28), Vector2(cw + 50.0, 34))
	draw_style_box(ForgeUI.sb(Color(1, 1, 1, 0.06), 17, Color(1, 1, 1, 0.14), 1), chip_r)
	ForgeUI.avatar(self, chip_r.position + Vector2(19, 17), 11.0, av, CreatorProfile.initial(cname))
	_text(f, chip_r.position + Vector2(38, 22), cname, ForgeUI.TXT_DIM, 14)
	ForgeUI.footer(self, vp, [["▲▼", "choisir"], ["A", "ouvrir"], ["Y", "profil"], ["B", "retour"]])
	if import_open: _draw_import(vp)
	if profile_open: _draw_profile(vp)


func _draw_import(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var r := ForgeUI.modal(self, vp, 560.0, 360.0, ForgeUI.CYAN)
	var o := r.position
	var w := r.size.x
	var h := r.size.y
	_ctext(f, vp.x * 0.5, o.y + 38, "Importer une création (%s)" % cur_dim, ForgeUI.CYAN, 21)
	if import_list.is_empty():
		_ctext(f, vp.x * 0.5, o.y + h * 0.42, "Aucune création à importer.", ForgeUI.TXT, 16)
		_ctext(f, vp.x * 0.5, o.y + h * 0.42 + 28, "Dépose des fichiers .spark dans :", ForgeUI.TXT_DIM, 13)
		_ctext(f, vp.x * 0.5, o.y + h * 0.42 + 48, ProjectStore.SHARED_DIR, ForgeUI.TXT_DIM, 12)
	else:
		var vis: int = mini(import_list.size(), 7)
		var first: int = clampi(import_sel - vis / 2, 0, maxi(0, import_list.size() - vis))
		for k in vis:
			var idx := first + k
			var ent: Dictionary = import_list[idx]
			var y := o.y + 72 + k * 36
			if idx == import_sel:
				draw_style_box(ForgeUI.sb(Color(1, 1, 1, 0.10), 8), Rect2(Vector2(o.x + 16, y - 19), Vector2(w - 32, 30)))
			var lbl := "📦  %s   (%s)" % [String(ent["name"]), String(ent["template"])]
			_text(f, Vector2(o.x + 30, y), lbl, Color.WHITE if idx == import_sel else ForgeUI.TXT_DIM, 15)
	_ctext(f, vp.x * 0.5, o.y + h - 18, "▲▼ choisir    A importer    B retour", ForgeUI.TXT_FAINT, 13)


# modal PROFIL : nom (clavier) + couleur d'avatar (◄►) — signé sur chaque création
func _draw_profile(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var r := ForgeUI.modal(self, vp, 460.0, 310.0, ForgeUI.ACCENT)
	var o := r.position
	var h := r.size.y
	_ctext(f, vp.x * 0.5, o.y + 38, "Profil créateur", ForgeUI.ACCENT, 21)
	_ctext(f, vp.x * 0.5, o.y + 62, "Ton nom + ton avatar signent tes créations", ForgeUI.TXT_DIM, 13)
	# gros avatar de prévisualisation (halo + pastilles de couleurs dispo)
	var av := CreatorProfile.avatar_color(creator)
	var cname := String(creator.get("name", ""))
	ForgeUI.glow(self, Vector2(vp.x * 0.5, o.y + 122), 70.0, av)
	ForgeUI.avatar(self, Vector2(vp.x * 0.5, o.y + 122), 34.0, av, CreatorProfile.initial(cname))
	var npal := CreatorProfile.AVATAR_COLORS.size()
	var px0 := vp.x * 0.5 - (npal - 1) * 11.0
	for i in npal:
		var pc: Color = CreatorProfile.AVATAR_COLORS[i]
		draw_circle(Vector2(px0 + i * 22.0, o.y + 174), 6.0 if i == int(creator.get("color", 0)) else 4.0, pc)
	# champ nom (curseur clignotant)
	var shown := cname + ("_" if int(anim_t * 2.0) % 2 == 0 else " ")
	draw_style_box(ForgeUI.sb(Color(1, 1, 1, 0.08), 10, Color(1, 1, 1, 0.15), 1), Rect2(Vector2(o.x + 90, o.y + 196), Vector2(r.size.x - 180, 36)))
	_ctext(f, vp.x * 0.5, o.y + 220, shown, Color.WHITE, 18)
	_ctext(f, vp.x * 0.5, o.y + h - 20, "clavier : nom    ◄ ► couleur    A valider", ForgeUI.TXT_FAINT, 13)


func _draw_workshop(vp: Vector2) -> void:
	_shell_bg(vp, false)
	var f := ThemeDB.fallback_font
	ForgeUI.header(self, vp, "🌐  WORKSHOP", "Joue les créations de la communauté", ForgeUI.PURPLE)
	# barre d'état : tri · filtre · recherche (chips ; mode saisie = champ surligné)
	var sort_lbl := String({"recent": "récent", "joués": "plus joués", "nom": "A→Z"}.get(workshop_sort, workshop_sort))
	var filt_lbl := workshop_filter if workshop_filter != "" else "tous"
	if workshop_search:
		var q := workshop_query + ("_" if int(anim_t * 2.0) % 2 == 0 else " ")
		var qw := f.get_string_size("Recherche : " + q, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0
		draw_style_box(ForgeUI.sb(Color(ForgeUI.ACCENT.r, ForgeUI.ACCENT.g, ForgeUI.ACCENT.b, 0.14), 13, ForgeUI.ACCENT, 1),
			Rect2(Vector2(vp.x * 0.5 - qw * 0.5, 114), Vector2(qw, 26)))
		_ctext(f, vp.x * 0.5, 132, "Recherche : %s" % q, ForgeUI.ACCENT, 14)
	else:
		var c1 := "tri  %s" % sort_lbl
		var c2 := "filtre  %s" % filt_lbl
		var w1 := f.get_string_size(c1, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0
		var w2 := f.get_string_size(c2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0
		var w3 := 0.0
		var c3 := ""
		if workshop_query != "":
			c3 = "« %s »" % workshop_query
			w3 = f.get_string_size(c3, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0 + 10.0
		var x := vp.x * 0.5 - (w1 + 10.0 + w2 + w3) * 0.5
		x += ForgeUI.chip(self, Vector2(x, 114), c1, ForgeUI.PURPLE) + 10.0
		x += ForgeUI.chip(self, Vector2(x, 114), c2, ForgeUI.CYAN) + 10.0
		if c3 != "":
			ForgeUI.chip(self, Vector2(x, 114), c3, ForgeUI.ACCENT)
	if workshop_items.is_empty():
		if workshop_all.is_empty():
			_ctext(f, vp.x * 0.5, vp.y * 0.45, "Aucune création disponible.", Color(1, 1, 1, 0.7), 18)
			_ctext(f, vp.x * 0.5, vp.y * 0.45 + 28, "(WORKSHOP v0 : dépose des .spark + index.json dans)", Color(1, 1, 1, 0.4), 13)
			_ctext(f, vp.x * 0.5, vp.y * 0.45 + 48, ProjectStore.WORKSHOP_DIR, Color(1, 1, 1, 0.4), 12)
		else:
			_ctext(f, vp.x * 0.5, vp.y * 0.45, "Rien ne correspond au filtre / à la recherche.", Color(1, 1, 1, 0.7), 16)
			_ctext(f, vp.x * 0.5, vp.y * 0.45 + 26, "B : réinitialiser", Color(1, 1, 1, 0.4), 13)
		_ctext(f, vp.x * 0.5, vp.y - 30, "B retour", Color(1, 1, 1, 0.5), 14)
		return
	# feed : cartes empilées, fenêtre défilante centrée sur la sélection
	var card_h := 78.0
	var gap := 12.0
	var top := 142.0
	var vis: int = mini(workshop_items.size(), int((vp.y - top - 60.0) / (card_h + gap)))
	var first: int = clampi(workshop_sel - vis / 2, 0, maxi(0, workshop_items.size() - vis))
	for k in vis:
		var idx := first + k
		var it: Dictionary = workshop_items[idx]
		var y := top + k * (card_h + gap)
		var r := Rect2(vp.x * 0.5 - 300, y, 600, card_h)
		var on := idx == workshop_sel
		if on: r = r.grow(3.0)   # la carte sélectionnée respire
		ForgeUI.card(self, r, on, anim_t, ForgeUI.PURPLE)
		# miniature de la création (mini-rendu de la 1re zone)
		var thumb := Rect2(r.position + Vector2(12, 11), Vector2(108, r.size.y - 22))
		_draw_thumb(thumb, it.get("thumb", {}))
		draw_rect(thumb, Color(1, 1, 1, 0.18), false, 1.0)
		# pastille dim en coin de la miniature
		_text(f, thumb.position + Vector2(4, 16), String(it["dim"]), ForgeUI.PURPLE, 12)
		var tx := thumb.position.x + thumb.size.x + 16
		var nm := String(it["name"])
		if String(it.get("remix_of", "")) != "": nm = "↻ " + nm   # badge remix
		_text(f, Vector2(tx, r.position.y + 32), nm, Color.WHITE if on else Color(1, 1, 1, 0.8), 20)
		# avatar (cercle + initiale) + auteur + genre
		var acol: Color = CreatorProfile.AVATAR_COLORS[clampi(int(it.get("author_color", 0)), 0, CreatorProfile.AVATAR_COLORS.size() - 1)]
		ForgeUI.avatar(self, Vector2(tx + 9, r.position.y + 53), 9.0, acol, CreatorProfile.initial(String(it["author"])))
		_text(f, Vector2(tx + 26, r.position.y + 58), "%s   ·   %s" % [String(it["author"]), String(it["template"])], ForgeUI.TXT_DIM, 13)
		# nb de parties locales (▶ N) en haut à droite de la carte
		var np := WorkshopStats.plays_of(workshop_plays, String(it["path"]).get_file())
		if np > 0:
			var ptxt := "▶ %d" % np
			var pw := f.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0
			ForgeUI.chip(self, Vector2(r.position.x + r.size.x - pw - 12.0, r.position.y + 10), ptxt, ForgeUI.TXT_DIM)
		if on:
			_text(f, Vector2(r.position.x + r.size.x - 84, r.position.y + r.size.y * 0.72), "▶ A", ForgeUI.PURPLE, 22)
	ForgeUI.footer(self, vp, [["A", "jouer"], ["X", "remixer"], ["Y", "tri"], ["L R", "filtre"], ["S", "chercher"], ["B", "retour"]])
	_ctext(f, vp.x - 30, vp.y - 22, "%d" % workshop_items.size(), ForgeUI.TXT_FAINT, 12)


func _draw_template(vp: Vector2) -> void:
	_shell_bg(vp)
	var f := ThemeDB.fallback_font
	_ctext(f, vp.x * 0.5, 158, "Nouveau projet — templates %s" % cur_dim, ForgeUI.TXT_DIM, 17)
	var list: Array = TEMPLATES.get(cur_dim, [])
	if list.is_empty():
		_ctext(f, vp.x * 0.5, vp.y * 0.5, "Aucun template %s pour l'instant (bientôt)" % cur_dim, ForgeUI.TXT_DIM, 20)
	else:
		var y0 := 208.0
		var row_h := 56.0
		for i in list.size():
			var box := Rect2(Vector2(vp.x * 0.5 - 210, y0 + i * row_h), Vector2(420, 46))
			if i == sel: box = box.grow(3.0)
			ForgeUI.card(self, box, i == sel, anim_t, ForgeUI.GREEN)
			_ctext(f, vp.x * 0.5, box.position.y + box.size.y * 0.5 + 8, String(list[i]["name"]),
				Color.WHITE if i == sel else ForgeUI.TXT_DIM, 21)
	ForgeUI.footer(self, vp, [["▲▼", "choisir"], ["A", "créer"], ["B", "retour"]])


# ============================================================= MODE JEU (écrans)
func _draw_game(vp: Vector2) -> void:
	var full := Rect2(Vector2.ZERO, vp)
	var st := _screen_style("title")
	var f := ThemeDB.fallback_font
	match game_stage:
		"title":
			var data: Dictionary = screens.get("title", ScreenArt.empty_screen())
			var ctx := {"accent": st.accent, "bg": BG_THEMES[st.bg][0],
				"title_text": cur_project, "subtitle": st.subtitle, "anim_t": anim_t}
			ScreenArt.draw_title(self, full, data, ctx)
			# crédit créateur ("le créateur est VU") + lignée du remix
			if cur_author != "":
				var acol: Color = CreatorProfile.AVATAR_COLORS[clampi(cur_author_color, 0, CreatorProfile.AVATAR_COLORS.size() - 1)]
				draw_circle(Vector2(vp.x * 0.5 - f.get_string_size("par " + cur_author, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5 - 14, vp.y - 62), 8.0, acol)
				_ctext(f, vp.x * 0.5, vp.y - 57, "par " + cur_author, Color(1, 1, 1, 0.55), 14)
			if cur_remix_of != "":
				_ctext(f, vp.x * 0.5, vp.y - 38, "↻ remix de « %s » (par %s)" % [cur_remix_of, cur_remix_by], Color(1, 1, 1, 0.35), 12)
			_ctext(f, vp.x * 0.5, vp.y - 18, "A jouer    B quitter", Color(1, 1, 1, 0.4), 13)
		"select":
			draw_rect(full, BG_THEMES[st.bg][0])
			_ctext(f, vp.x * 0.5, 70, cur_project.to_upper(), st.accent, 30)
			_ctext(f, vp.x * 0.5, 104, "Choisis une zone", Color(1, 1, 1, 0.6), 15)
			var ids := level_ids()
			for i in ids.size():
				var y := 150.0 + i * 52.0
				var locked := i >= game_unlocked
				var r := Rect2(vp.x * 0.5 - 220, y, 440, 42)
				if i == game_sel and not locked:
					draw_rect(r, Color(1, 1, 1, 0.10))
					draw_rect(r, st.accent, false, 2.0)
				var nm := level_name(str(ids[i]))
				if locked:
					_ctext(f, vp.x * 0.5, y + 28, "🔒  %s" % nm, Color(1, 1, 1, 0.25), 17)
				else:
					_ctext(f, vp.x * 0.5, y + 28, "%d. %s" % [i + 1, nm], Color.WHITE if i == game_sel else Color(1, 1, 1, 0.6), 17)
			_ctext(f, vp.x * 0.5, vp.y - 18, "▲▼ choisir    A jouer    B retour", Color(1, 1, 1, 0.4), 13)
		"complete":
			draw_rect(full, BG_THEMES[st.bg][0])
			_ctext(f, vp.x * 0.5, vp.y * 0.32, "ZONE TERMINÉE !", Color("2ecc71"), 46)
			_ctext(f, vp.x * 0.5, vp.y * 0.32 + 44, level_name(cur_level), Color(1, 1, 1, 0.7), 18)
			var mins := int(game_zone_time) / 60
			_ctext(f, vp.x * 0.5, vp.y * 0.52,
				"Temps  %d:%05.2f      Pièces  %d/%d" % [mins, fmod(game_zone_time, 60.0), game_zone_coins, game_zone_ctotal],
				Color("f1c40f"), 19)
			var last := game_zone_i + 1 >= level_ids().size()
			_ctext(f, vp.x * 0.5, vp.y * 0.72, "A  %s" % ("Voir la fin" if last else "Zone suivante →"), Color.WHITE, 17)
		"over":
			draw_rect(full, Color("12060a"))
			_ctext(f, vp.x * 0.5, vp.y * 0.4, "GAME OVER", Color("e74c3c"), 52)
			_ctext(f, vp.x * 0.5, vp.y * 0.6, "A Réessayer      B Zones", Color(1, 1, 1, 0.7), 17)
		"end":
			draw_rect(full, BG_THEMES[st.bg][0])
			_ctext(f, vp.x * 0.5, vp.y * 0.30, "JEU TERMINÉ !", st.accent, 52)
			_ctext(f, vp.x * 0.5, vp.y * 0.30 + 46, cur_project.to_upper(), Color.WHITE, 22)
			var tm := int(game_total_time) / 60
			_ctext(f, vp.x * 0.5, vp.y * 0.52,
				"Temps total  %d:%05.2f      Pièces  %d" % [tm, fmod(game_total_time, 60.0), game_total_coins],
				Color("f1c40f"), 19)
			if fmod(anim_t, 1.0) < 0.65:
				_ctext(f, vp.x * 0.5, vp.y * 0.74, "Merci d'avoir joué  —  A retour", Color(1, 1, 1, 0.7), 16)


# ============================================================= GAMEDASH
func _draw_gamedash(vp: Vector2) -> void:
	_shell_bg(vp, false)   # pas de gros titre FORGE : les cartes occupent tout l'écran
	var f := ThemeDB.fallback_font
	_ctext(f, vp.x * 0.5, 34, cur_project.to_upper(), Color.WHITE, 22)
	var entries := _dash_entries()
	var pad := 18.0; var gap_x := 12.0; var gap_y := 10.0
	var card_w := (vp.x - 2.0 * pad - gap_x) * 0.5
	var label_h := 26.0
	var rows_n: int = maxi(1, int(ceil(entries.size() / 2.0)))
	var card_h := (vp.y - 56.0 - 30.0 - float(rows_n - 1) * gap_y) / float(rows_n)
	var prev_h := card_h - label_h
	for i in entries.size():
		var ent: Dictionary = entries[i]
		var ci := i % 2; var ri := i / 2
		var x := pad + ci * (card_w + gap_x)
		var y := 56.0 + ri * (card_h + gap_y)
		var sel_i := i == dash_sel
		var pr := Rect2(x, y, card_w, prev_h)
		match str(ent["key"]):
			"playgame":
				var stt := _screen_style("title")
				draw_rect(pr, BG_THEMES[stt.bg][0].darkened(0.2))
				var cc := pr.position + pr.size * 0.5
				draw_colored_polygon(PackedVector2Array([
					cc + Vector2(-14, -20), cc + Vector2(22, 0), cc + Vector2(-14, 20)]), stt.accent)
				_ctext(f, cc.x, pr.position.y + pr.size.y * 0.82,
					"Progression : %d/%d zones" % [mini(game_unlocked, level_ids().size()), level_ids().size()],
					Color(1, 1, 1, 0.55), 12)
			"level":
				_draw_level_preview(pr, str(ent["id"]))
			"newlevel":
				draw_rect(pr, Color("0d1117"))
				_ctext(f, pr.position.x + pr.size.x * 0.5, pr.position.y + pr.size.y * 0.6, "+", Color(1, 1, 1, 0.5), 38)
			_:
				_draw_screen_preview(pr, str(ent["key"]))
		draw_rect(Rect2(x, y + prev_h, card_w, label_h), Color(0, 0, 0, 0.55))
		var lcol := UI_ACCENT if sel_i else Color(1, 1, 1, 0.65)
		var lbl: String = str(ent["label"]) + ("  ●" if str(ent.get("id", "")) == cur_level and str(ent["key"]) == "level" else "")
		_ctext(f, x + card_w * 0.5, y + prev_h + label_h * 0.72, lbl, lcol, 13)
		draw_rect(Rect2(x, y, card_w, card_h), UI_ACCENT if sel_i else Color(1, 1, 1, 0.18), false, 3.0 if sel_i else 1.0)
	_ctext(f, vp.x * 0.5, vp.y - 12, "◀▶▲▼ naviguer    A ouvrir    B liste projets", ForgeUI.TXT_FAINT, 12)


# mini-aperçu d'un niveau (carte du dash) : chaque tuile = un pixel coloré
# minimap (test) : salles VISITÉES de la zone courante + position du joueur
func _draw_minimap(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var panel := Rect2(vp * 0.5 - Vector2(vp.x * 0.32, vp.y * 0.32), Vector2(vp.x * 0.64, vp.y * 0.64))
	draw_rect(panel, Color(8.0 / 255, 12.0 / 255, 18.0 / 255, 0.93))
	draw_rect(panel, UI_ACCENT, false, 2.0)
	_ctext(f, panel.position.x + panel.size.x * 0.5, panel.position.y + 26, level_name(cur_level).to_upper(), Color.WHITE, 18)
	var inner := Rect2(panel.position + Vector2(20, 40), panel.size - Vector2(40, 78))
	# bornes en cases : union des salles, sinon le niveau entier
	var bx0 := 999999; var by0 := 999999; var bx1 := 0; var by1 := 0
	for r in rooms:
		bx0 = mini(bx0, r.position.x); by0 = mini(by0, r.position.y)
		bx1 = maxi(bx1, r.position.x + r.size.x); by1 = maxi(by1, r.position.y + r.size.y)
	if rooms.is_empty():
		bx0 = 0; by0 = 0; bx1 = cols; by1 = rows
	var sc: float = minf(inner.size.x / float(bx1 - bx0), inner.size.y / float(by1 - by0))
	var ox: float = inner.position.x + (inner.size.x - float(bx1 - bx0) * sc) * 0.5
	var oy: float = inner.position.y + (inner.size.y - float(by1 - by0) * sc) * 0.5
	if rooms.is_empty():
		draw_rect(Rect2(ox, oy, float(bx1 - bx0) * sc, float(by1 - by0) * sc), Color(0.25, 0.55, 0.9, 0.18))
	for i in rooms.size():
		var r: Rect2i = rooms[i]
		var rr := Rect2(ox + float(r.position.x - bx0) * sc, oy + float(r.position.y - by0) * sc,
			float(r.size.x) * sc, float(r.size.y) * sc)
		var seen: bool = visited_rooms.has("%s:%d" % [cur_level, i])
		if not seen:
			continue   # brouillard : salle jamais visitée = cachée
		draw_rect(rr, Color(0.25, 0.55, 0.9, 0.30) if i != cur_room else Color(0.4, 0.75, 1.0, 0.45))
		draw_rect(rr, Color(0.55, 0.8, 1.0, 0.9), false, 1.5)
	# joueur
	var pcell: Vector2 = (tmpl.ppos + tmpl.PSIZE * 0.5) / float(tmpl.CELL)
	var pdot := Vector2(ox + (pcell.x - bx0) * sc, oy + (pcell.y - by0) * sc)
	draw_circle(pdot, 4.0, Color("ffde59"))
	draw_circle(pdot, 4.0, Color("2c3e50"), false, 1.0)
	_ctext(f, panel.position.x + panel.size.x * 0.5, panel.end.y - 14, "Select / M : fermer", Color(1, 1, 1, 0.45), 12)


# overlay de saisie du nom de zone (clavier)
func _draw_rename(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var box := Rect2(vp * 0.5 - Vector2(220, 50), Vector2(440, 100))
	draw_rect(box, Color(13.0 / 255, 17.0 / 255, 23.0 / 255, 0.96))
	draw_rect(box, UI_ACCENT, false, 2.0)
	_ctext(f, vp.x * 0.5, box.position.y + 30, "NOM DE LA ZONE", Color(1, 1, 1, 0.7), 13)
	var nm := cur_level_name if cur_level_name != "" else " "
	_ctext(f, vp.x * 0.5, box.position.y + 62, nm + "_", Color.WHITE, 20)
	_ctext(f, vp.x * 0.5, box.end.y - 12, "Tape au clavier · Entrée pour valider", Color(1, 1, 1, 0.4), 11)


func _draw_level_preview(r: Rect2, id: String) -> void:
	draw_rect(r, Color("0d1117"))
	var L: Dictionary = _level_pack() if id == cur_level else levels.get(id, {})
	var tiles: Dictionary = L.get("tiles", {})
	if tiles.is_empty():
		_ctext(ThemeDB.fallback_font, r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.55, "(vide)", Color(1, 1, 1, 0.3), 12)
		return
	var mx := 16; var my := 10
	for k in tiles:
		mx = maxi(mx, k.x + 1); my = maxi(my, k.y + 1)
	var sc: float = minf((r.size.x - 8.0) / float(mx), (r.size.y - 8.0) / float(my))
	var ox: float = r.position.x + (r.size.x - mx * sc) * 0.5
	var oy: float = r.position.y + (r.size.y - my * sc) * 0.5
	for k in tiles:
		var col: Color = tmpl.COLORS.get(tiles[k], Color.GRAY)
		draw_rect(Rect2(ox + k.x * sc, oy + k.y * sc, maxf(sc, 1.5), maxf(sc, 1.5)), col)


# ============================================================= SCREENEDIT
const _SCREEN_LABELS := {
	"title": "Écran titre", "select": "Sélection niveaux",
	"pause": "Pause", "complete": "Niveau terminé", "gameover": "Game Over"
}

func _draw_screenedit(vp: Vector2) -> void:
	_shell_bg(vp)
	var f := ThemeDB.fallback_font
	var sname: String = _SCREEN_LABELS.get(edit_screen_key, edit_screen_key)
	var acc: Color = _screen_style(edit_screen_key).accent

	# --- canvas WYSIWYG (rendu réel de l'écran via ScreenArt) ---
	var top := 44.0; var bot := 78.0
	var cw := vp.x - 32.0
	var ch := vp.y - top - bot
	var canvas := Rect2(16, top, cw, ch)
	_draw_screen_preview(canvas, edit_screen_key)
	draw_rect(canvas, acc, false, 2.0)

	# --- overlays selon l'outil ---
	var dims := _se_dims()
	match se_tool:
		TOOL_PINCEAU, TOOL_GOMME:
			_draw_se_grid(canvas, dims)
			_draw_se_cursor(canvas, dims)
		TOOL_TAMPON:
			_draw_se_grid(canvas, dims)
			var center := ScreenArt.cell_p(canvas, se_cursor.x, se_cursor.y, dims) + ScreenArt.cell_px(canvas, dims) * 0.5
			var size := se_stamp_size * canvas.size.y
			var ghost: Color = ScreenArt.DECO[se_color]; ghost.a = se_stamp_alpha * 0.7
			if se_stamp_outline:
				ScreenArt.draw_shape_outline(self, se_shape, center, size, ghost, 3.0)
			else:
				ScreenArt.draw_shape(self, se_shape, center, size, ghost)
			draw_circle(center, 4, Color.WHITE)
		TOOL_PANNEAU:
			_draw_se_grid(canvas, dims)
			_draw_se_cursor(canvas, dims)
			if se_panel_anchor != Vector2i(-1, -1):
				var a := ScreenArt.cell_p(canvas, mini(se_panel_anchor.x, se_cursor.x), mini(se_panel_anchor.y, se_cursor.y), dims)
				var b := ScreenArt.cell_p(canvas, maxi(se_panel_anchor.x, se_cursor.x) + 1, maxi(se_panel_anchor.y, se_cursor.y) + 1, dims)
				var gr := Rect2(a, b - a)
				var gc: Color = ScreenArt.DECO[se_color]; gc.a = se_panel_alpha * 0.6
				ScreenArt.draw_round_rect(self, gr, gc, se_panel_radius * minf(gr.size.x, gr.size.y) * 0.5)
		TOOL_TEXTE:
			if edit_screen_key == "title":
				var key: String = ScreenArt.TITLE_TEXTS[se_text_sel]
				var p := ScreenArt.text_props(_cur_screen(), key)
				var c := ScreenArt.np(canvas, p.nx, p.ny)
				var bw := 140.0
				draw_rect(Rect2(c.x - bw * 0.5, c.y - 24, bw, 48), Color("f39c12"), false, 2.0)
				draw_line(Vector2(c.x - 12, c.y), Vector2(c.x + 12, c.y), Color("f39c12"), 1.5)
				draw_line(Vector2(c.x, c.y - 12), Vector2(c.x, c.y + 12), Color("f39c12"), 1.5)
		TOOL_STYLE:
			_draw_se_style_panel(vp)

	# --- barre supérieure : nom écran + sélecteur d'outils ---
	draw_rect(Rect2(0, 0, vp.x, top), Color("11161f"))
	_text(f, Vector2(14, 30), sname.to_upper(), Color.WHITE, 18)
	var tx := 230.0
	for i in TOOL_NAMES.size():
		var on := i == se_tool
		var box := Rect2(tx, 8, 100, 28)
		if on: draw_rect(box, acc)
		else: draw_rect(box, Color("223349"))
		_ctext(f, tx + 50, 27, TOOL_NAMES[i], Color("11161f") if on else Color(1, 1, 1, 0.7), 14)
		tx += 108

	# --- barre inférieure : options outil + hint ---
	draw_rect(Rect2(0, vp.y - bot, vp.x, bot), Color("11161f"))
	_draw_se_toolbar(vp, bot)


func _draw_se_grid(canvas: Rect2, dims: Vector2) -> void:
	if not bool(_cur_screen()["grid_show"]):
		return
	var gc := Color(1, 1, 1, 0.07)
	for x in range(int(dims.x) + 1):
		draw_line(ScreenArt.cell_p(canvas, x, 0, dims), ScreenArt.cell_p(canvas, x, int(dims.y), dims), gc)
	for y in range(int(dims.y) + 1):
		draw_line(ScreenArt.cell_p(canvas, 0, y, dims), ScreenArt.cell_p(canvas, int(dims.x), y, dims), gc)


func _draw_se_cursor(canvas: Rect2, dims: Vector2) -> void:
	var cs := ScreenArt.cell_px(canvas, dims)
	var p := ScreenArt.cell_p(canvas, se_cursor.x, se_cursor.y, dims)
	if se_tool == TOOL_PINCEAU:
		var preview: Color = ScreenArt.DECO[se_color]; preview.a = 0.45
		draw_rect(Rect2(p, cs), preview)
	var col := Color.WHITE if se_tool == TOOL_PINCEAU else Color("e74c3c")
	draw_rect(Rect2(p, cs), col, false, 2.5)


func _draw_se_toolbar(vp: Vector2, bot: float) -> void:
	var f := ThemeDB.fallback_font
	var y := vp.y - bot + 10.0
	var hint := ""
	match se_tool:
		TOOL_PINCEAU:
			_text(f, Vector2(14, y + 16), "Couleur :", Color(1, 1, 1, 0.6), 14)
			for i in ScreenArt.DECO.size():
				var sw := Rect2(100 + i * 30, y, 24, 24)
				draw_rect(sw, ScreenArt.DECO[i])
				if i == se_color: draw_rect(sw, Color.WHITE, false, 2.5)
			hint = "A poser (maintenir) • X/Y couleur • LB/RB outil • B sauver"
		TOOL_GOMME:
			hint = "A effacer (maintenir) • LB/RB outil • B sauver"
		TOOL_TAMPON:
			_text(f, Vector2(14, y + 16), "%s  %d%%  %s" % [ScreenArt.SHAPE_NAMES[se_shape], int(se_stamp_size * 100), "contour" if se_stamp_outline else "plein"], Color(1, 1, 1, 0.7), 14)
			for i in ScreenArt.DECO.size():
				var sw := Rect2(330 + i * 26, y, 20, 20)
				draw_rect(sw, ScreenArt.DECO[i])
				if i == se_color: draw_rect(sw, Color.WHITE, false, 2.0)
			hint = "A poser • X forme • Y couleur • O contour • PgUp/Dn (L2/R2) taille • L3 annuler"
		TOOL_PANNEAU:
			_text(f, Vector2(14, y + 16), "Arrondi %d%%  Opacité %d%%  %s" % [int(se_panel_radius * 100), int(se_panel_alpha * 100), "contour" if se_panel_outline else "plein"], Color(1, 1, 1, 0.7), 14)
			for i in ScreenArt.DECO.size():
				var sw := Rect2(380 + i * 26, y, 20, 20)
				draw_rect(sw, ScreenArt.DECO[i])
				if i == se_color: draw_rect(sw, Color.WHITE, false, 2.0)
			var anchored := se_panel_anchor != Vector2i(-1, -1)
			hint = ("A 2e coin" if anchored else "A 1er coin") + " • X couleur • O contour • PgUp/Dn arrondi • L2/R2 opacité • L3 annuler"
		TOOL_TEXTE:
			var key: String = ScreenArt.TITLE_TEXTS[se_text_sel]
			_text(f, Vector2(14, y + 16), "Élément : %s" % key.to_upper(), Color("f39c12"), 15)
			hint = "▲▼◀▶ déplacer • A élément suivant • X/Y taille • B sauver"
		TOOL_STYLE:
			hint = "▲▼ propriété • ◀▶ changer • A éditer sous-titre • B sauver"
	_ctext(f, vp.x * 0.5, vp.y - 14, hint, Color(1, 1, 1, 0.5), 13)


func _draw_se_style_panel(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var d := _cur_screen()
	var st := _screen_style(edit_screen_key)
	var acc: Color = st.accent
	var pw := 380.0
	var px := vp.x - pw - 24.0
	var ph := 360.0
	var py := 64.0
	draw_rect(Rect2(px, py, pw, ph), Color(0.04, 0.05, 0.09, 0.93))
	draw_rect(Rect2(px, py, pw, ph), acc, false, 2.0)
	var rx := px + 16.0; var ry := py + 28.0
	_text(f, Vector2(rx, ry), "STYLE DE CET ÉCRAN", acc, 15); ry += 32

	# 0 — accent
	var sel0 := edit_prop_sel == 0
	_text(f, Vector2(rx, ry), ("▶ " if sel0 else "  ") + "Couleur accent", Color.WHITE if sel0 else Color(1,1,1,0.5), 15)
	ry += 24
	for i in ACCENT_PALETTE.size():
		var ac: Color = ACCENT_PALETTE[i]
		draw_rect(Rect2(rx + 4 + i * 30, ry, 24, 18), ac)
		if ac == acc: draw_rect(Rect2(rx + 4 + i * 30, ry, 24, 18), Color.WHITE, false, 2.5)
	ry += 34

	# 1 — fond
	var sel1 := edit_prop_sel == 1
	_text(f, Vector2(rx, ry), ("▶ " if sel1 else "  ") + "Fond", Color.WHITE if sel1 else Color(1,1,1,0.5), 15)
	ry += 24
	for i in BG_THEMES.size():
		draw_rect(Rect2(rx + 4 + i * 40, ry, 34, 18), BG_THEMES[i][0])
		if i == int(st.bg): draw_rect(Rect2(rx + 4 + i * 40, ry, 34, 18), Color.WHITE, false, 2.0)
	ry += 34

	# 2 — dégradé
	var sel2 := edit_prop_sel == 2
	_text(f, Vector2(rx, ry), ("▶ " if sel2 else "  ") + "Dégradé : %s" % ("OUI" if bool(d["bg_grad"]) else "non"), Color.WHITE if sel2 else Color(1,1,1,0.5), 15)
	ry += 32

	# 3 — taille grille
	var sel3 := edit_prop_sel == 3
	_text(f, Vector2(rx, ry), ("▶ " if sel3 else "  ") + "Grille : %s" % ScreenArt.GRID_NAMES[int(d["grid"])], Color.WHITE if sel3 else Color(1,1,1,0.5), 15)
	ry += 32

	# 4 — grille visible
	var sel4 := edit_prop_sel == 4
	_text(f, Vector2(rx, ry), ("▶ " if sel4 else "  ") + "Afficher grille : %s" % ("oui" if bool(d["grid_show"]) else "NON"), Color.WHITE if sel4 else Color(1,1,1,0.5), 15)
	ry += 32

	# 5 — sous-titre (titre uniquement)
	if edit_screen_key == "title":
		var sub := String(st.subtitle)
		var sel5 := edit_prop_sel == 5
		_text(f, Vector2(rx, ry), ("▶ " if sel5 else "  ") + "Sous-titre", Color.WHITE if sel5 else Color(1,1,1,0.5), 15)
		ry += 24
		if text_edit_mode:
			var blink := int(anim_t * 2) % 2 == 0
			var stxt := sub.substr(0, text_edit_cursor) + ("|" if blink else "") + sub.substr(text_edit_cursor)
			_text(f, Vector2(rx + 8, ry), stxt if stxt != "" else "_", Color("f39c12"), 15)
			_text(f, Vector2(rx + 8, ry + 20), "▲▼ lettre • ◀▶ curseur • X suppr • B ok", Color(1,1,1,0.4), 11)
		else:
			_text(f, Vector2(rx + 8, ry), sub if sub != "" else "(vide — A éditer)", Color("f39c12"), 14)


func _draw_screen_preview(r: Rect2, key: String) -> void:
	var st := _screen_style(key)
	var data: Dictionary = screens.get(key, ScreenArt.empty_screen())
	if key == "title":
		var ctx := {"accent": st.accent, "bg": BG_THEMES[st.bg][0],
			"title_text": cur_project, "subtitle": st.subtitle, "anim_t": anim_t}
		ScreenArt.draw_title(self, r, data, ctx)
		return
	# autres écrans : preview simplifiée (éditeur dédié à venir)
	var f := ThemeDB.fallback_font
	var sc := r.size.y / 600.0
	var bg: Color = BG_THEMES[st.bg][0]
	draw_rect(r, bg)
	var cx := r.position.x + r.size.x * 0.5
	match key:
		"editor":
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.14), Color("11161f"))
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.86, r.size.x, r.size.y * 0.14), Color("11161f"))
			_ctext(f, cx, r.position.y + r.size.y * 0.55, "✏  NIVEAUX", Color("f39c12"), int(14 * sc))
		"select":
			_ctext(f, cx, r.position.y + r.size.y * 0.18, cur_project, st.accent, int(18 * sc))
			for i in 3:
				var y := r.position.y + r.size.y * (0.32 + i * 0.15)
				draw_rect(Rect2(r.position.x + r.size.x * 0.12, y - 8 * sc, r.size.x * 0.76, 16 * sc), Color(1,1,1, 0.22 if i == 0 else 0.08))
		"pause":
			draw_rect(r, Color(0, 0, 0, 0.35))
			_ctext(f, cx, r.position.y + r.size.y * 0.5, "PAUSE", Color.WHITE, int(36 * sc))
		"complete":
			_ctext(f, cx, r.position.y + r.size.y * 0.3, "NIVEAU TERMINÉ !", Color("2ecc71"), int(22 * sc))
			_ctext(f, cx, r.position.y + r.size.y * 0.55, "★★★", st.accent, int(34 * sc))
		"gameover":
			_ctext(f, cx, r.position.y + r.size.y * 0.5, "GAME OVER", Color("e74c3c"), int(36 * sc))
