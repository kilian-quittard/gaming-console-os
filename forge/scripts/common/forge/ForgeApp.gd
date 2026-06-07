extends Node2D
# SPARK FORGE — coquille générique : shell (écrans XSM), éditeur de niveau, chrome (UI),
# caméra/vue, fx, audio, sauvegarde de projets. Le GENRE (tuiles + simulation + rendu du
# monde + personnage XSM) vit dans un template à part (scripts/common/templates/...).

const CELL := 48
const SFX_DB := -16.0   # atténuation globale des effets sonores
const TOPBAR := 52
const BOTTOM := 34
const LEVEL_COLS_DEF := 40
const PROJ_DIR := "user://forge_projects/"
const TEMPLATES := {
	"2D": [{"id": "platformer", "name": "Plateformer"}, {"id": "topdown", "name": "Vue de dessus"}],
	"3D": []
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
var bg_shape := 0              # forme sélectionnée (index BG_SHAPES)
var bg_depth := 1              # profondeur (index BG_DEPTHS)
var bg_scale_i := 1            # taille (index BG_SCALES)
var bg_tool := 0               # 0 = formes (stamps), 1 = polygone libre (dessin)
var bg_pts := []               # points du polygone en cours [[x,y]] (coords monde)
var bg_col := 0                # couleur sélectionnée (polygone)
var bg_trig_l := false         # debounce gâchette L2 (reculer)
var bg_trig_r := false         # debounce gâchette R2 (avancer)
const BG_SHAPES := ["nuage", "montagne", "colline", "soleil", "lune", "etoile", "arbre", "sapin"]
const BG_SHAPE_NAMES := ["Nuage", "Montagne", "Colline", "Soleil", "Lune", "Étoile", "Arbre", "Sapin"]
const BG_DEPTHS := [0.08, 0.28, 0.55, 0.85]
const BG_DEPTH_NAMES := ["loin", "moyen", "proche", "devant"]
const BG_SCALES := [0.6, 1.0, 1.6, 2.4]
const BG_COLORS := ["3a8f4f", "2e7d32", "1b5e20", "c68642", "8b4513", "7f8c8d", "5a6978", "2e1152", "e8a04b", "ecf0f1"]
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
var menu_items := []
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
var music_on := false

# shell
var screen := "dim"
var cur_dim := "2D"
var cur_template := "platformer"
var cur_project := ""
var proj_list := []
var sel := 0

# game config (couleurs, sous-titre — partagé avec GameShell)
var anim_t := 0.0

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
var sfx := {}
var music_player: AudioStreamPlayer

# template de jeu actif (le genre) + machine d'écrans (XSM)
var tmpl: PlatformerTemplate = null
@onready var states: State = $States


func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	_compute_grid()
	_build_audio()
	DirAccess.make_dir_recursive_absolute(PROJ_DIR)
	# instancie le template du genre courant (rendu du monde + simulation)
	_load_template(cur_template)
	queue_redraw()
	if OS.get_cmdline_args().has("--selftest"):
		call_deferred("_self_test")


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
	tmpl.setup(self)
	# adapte cat_pal au nombre de catégories du genre
	cat_pal = []
	for _i in tmpl.categories().size(): cat_pal.append(0)
	cat = clampi(cat, 0, maxi(0, cat_pal.size() - 1))


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
			print("f%3d x=%4.0f y=%4.0f sgr=%s gsp=%5.0f ang=%+.2f" % [f, tmpl.ppos.x, tmpl.ppos.y, str(tmpl.sonic_grounded), tmpl.gsp, tmpl.gangle])
	level_props = {}
	get_tree().quit()


func _compute_grid() -> void:
	var vp := get_viewport_rect().size
	rows = max(6, int((vp.y - TOPBAR - BOTTOM) / CELL))


# ============================================================= AUDIO
func _build_audio() -> void:
	sfx["jump"] = _mk_player(_tone([520.0, 760.0], 0.10, 0.35, "square"))
	sfx["coin"] = _mk_player(_tone([900.0, 1300.0], 0.09, 0.30, "square"))
	sfx["death"] = _mk_player(_tone([400.0, 120.0], 0.35, 0.40, "square"))
	sfx["win"] = _mk_player(_tone([660.0, 880.0, 1180.0], 0.40, 0.35, "square"))
	sfx["spring"] = _mk_player(_tone([300.0, 1000.0], 0.16, 0.40, "square"))
	sfx["break"] = _mk_player(_tone([220.0, 90.0], 0.12, 0.35, "noise"))
	sfx["stomp"] = _mk_player(_tone([700.0, 300.0], 0.10, 0.35, "square"))
	sfx["key"] = _mk_player(_tone([800.0, 1200.0, 1000.0], 0.16, 0.30, "square"))
	music_player = AudioStreamPlayer.new()
	music_player.stream = _music_loop()
	music_player.volume_db = -14.0
	add_child(music_player)


func _mk_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = SFX_DB
	add_child(p)
	return p


func _play(name: String) -> void:
	if sfx.has(name): sfx[name].play()


func _tone(freqs: Array, dur: float, vol := 0.4, kind := "square") -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var prog := float(i) / n
		var f: float = freqs[clampi(int(prog * freqs.size()), 0, freqs.size() - 1)]
		ph += f / rate
		var s: float
		if kind == "square": s = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		elif kind == "noise": s = randf() * 2.0 - 1.0
		else: s = sin(ph * TAU)
		var env := 1.0 - prog
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _music_loop() -> AudioStreamWAV:
	var rate := 22050
	var notes := [392.0, 523.0, 392.0, 659.0]
	var nlen := 0.4
	var n := int(rate * nlen * notes.size())
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var ni := int(t / nlen) % notes.size()
		ph += notes[ni] / rate
		var s := sin(ph * TAU) * 0.5 + sin(ph * TAU * 0.5) * 0.3
		data.encode_s16(i * 2, int(clampf(s * 0.5, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


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
	if screen == "dim":        _dim_input(e); return
	if screen == "list":       _list_input(e); return
	if screen == "template":   _tmpl_input(e); return
	if screen == "gamedash":   _gamedash_input(e); return
	if screen == "screenedit": _screenedit_input(e); return
	if ai_open:    _ai_panel_input(e); return
	if cfg_open:   _config_input(e); return
	if bg_edit:    _bgedit_input(e); return
	if menu_open:
		_menu_input(e); return
	if mode == "edit":
		_edit_input(e)
	else:
		_play_input(e)


func _dim_input(e: InputEvent) -> void:
	if _press(e, [KEY_LEFT, KEY_UP], [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP]):
		sel = 0; queue_redraw()
	elif _press(e, [KEY_RIGHT, KEY_DOWN], [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]):
		sel = 1; queue_redraw()
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		cur_dim = "2D" if sel == 0 else "3D"
		states.change_state("ListState")


func _list_input(e: InputEvent) -> void:
	var n := proj_list.size() + 1
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		sel = (sel + 1) % n; queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		sel = (sel - 1 + n) % n; queue_redraw()
	elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		states.change_state("DimState")
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		if sel < proj_list.size():
			_open_project(proj_list[sel])
		else:
			states.change_state("TemplateState")


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
		aim = mb.position; _sync_cursor_from_aim()
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
	elif _press(e, [KEY_C], [JOY_BUTTON_LEFT_STICK]): _toggle_cursor_mode()
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
		_stop_play()
	elif _press(e, [KEY_R], [JOY_BUTTON_Y]):
		tmpl.start_play(tmpl.last_from_cursor)


func _gamedash_input(e: InputEvent) -> void:
	var n := DASH_ITEMS.size()
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
		var key: String = DASH_KEYS[dash_sel]
		if key == "editor":
			states.change_state("EditorState")
		else:
			edit_screen_key = key; edit_prop_sel = 0; text_edit_mode = false
			states.change_state("ScreenEditState")


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


func _begin_stroke(place: bool) -> void:
	_push_undo()
	if place:
		if grid.has(cursor):
			# bloc déjà posé sous le pointeur → on le ramasse pour le déplacer
			grabbing = true
			grab_tile = grid[cursor]
			grab_from = cursor
			grab_cfg = cell_cfg.get(cursor, {})
			grid.erase(cursor); cell_cfg.erase(cursor)
			place_held = false
		else:
			place_held = true; grid[cursor] = _active_tile()
	else:
		erase_held = true; grid.erase(cursor); cell_cfg.erase(cursor)
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
func _open_menu() -> void:
	menu_open = true; menu_idx = 0
	menu_items = ["Sauvegarder", "Copier zone", "Coller ici", "Configurer objet…", "Vider niveau",
		"Customiser le fond…", "Autorun: %s" % ("ON" if level_props.get("autorun", false) else "OFF"),
		"Physique Sonic: %s" % ("ON" if level_props.get("sonic", false) else "OFF"),
		"Eau · Nage: %s" % ("ON" if level_props.get("water_swim", false) else "OFF"),
		"Eau · Noyade: %s" % ("ON" if level_props.get("water_drown", false) else "OFF"),
		"Victoire · Pièces: %s" % (str(int(level_props.get("win_coins", 0))) if int(level_props.get("win_coins", 0)) > 0 else "OFF"),
		"Victoire · Tuer tous: %s" % ("ON" if level_props.get("win_killall", false) else "OFF"),
		"Victoire · Temps: %s" % ((str(int(level_props.get("time_limit", 0))) + "s") if int(level_props.get("time_limit", 0)) > 0 else "OFF"),
		"Musique: %s" % ("ON" if music_on else "OFF"),
		"FPS (debug): %s" % ("ON" if show_fps else "OFF"),
		"Générer avec IA...",
		"Projets (quitter)", "Fermer"]
	queue_redraw()


func _cycle_preset(cur: int, presets: Array) -> int:
	var i := presets.find(cur)
	return int(presets[(i + 1) % presets.size()])


# ---------------- config par instance (objet sous le curseur)
func _cfg_fields_for(t: int) -> Array:
	if tmpl.has_method("movplat_tile") and t == tmpl.movplat_tile():
		return [
			{"key": "width", "label": "Largeur", "opts": [1, 2, 3, 4, 5],           "def": 1},
			{"key": "axis",  "label": "Axe",     "opts": ["H", "V"],                 "def": "H"},
			{"key": "dir",   "label": "Sens",    "opts": ["+", "-"],                 "def": "+"},
			{"key": "span",  "label": "Portée",  "opts": [1, 2, 3, 4, 5, 6],         "def": 3},
			{"key": "speed", "label": "Vitesse", "opts": ["lent", "normal", "rapide"], "def": "normal"},
		]
	return []


func _open_config() -> void:
	var t: int = int(grid.get(cursor, -1))
	cfg_fields = _cfg_fields_for(t)
	if cfg_fields.is_empty():
		_set_toast("Rien à configurer ici"); return
	cfg_cell = cursor; cfg_idx = 0; cfg_open = true; queue_redraw()


func _cfg_get(fld: Dictionary):
	var d: Dictionary = cell_cfg.get(cfg_cell, {})
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
const BG_NAMES := ["Ciel", "Espace", "Neige", "Désert"]

func _open_bgedit() -> void:
	bg_edit = true; queue_redraw(); _redraw_world()


func _bgedit_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		aim = (e as InputEventMouseMotion).position; queue_redraw(); return
	if _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_BACK, JOY_BUTTON_B]):
		bg_edit = false; bg_pts.clear(); queue_redraw(); _redraw_world(); return
	# bascule d'outil
	if _press(e, [KEY_TAB], [JOY_BUTTON_LEFT_STICK]):
		bg_tool = 1 - bg_tool; bg_pts.clear(); queue_redraw(); return
	# valider le polygone en cours
	if bg_tool == 1 and _press(e, [KEY_ENTER], [JOY_BUTTON_START]):
		_bg_commit_poly(); return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		var rects := _bg_icon_rects()
		for i in rects.size():
			if (rects[i] as Rect2).has_point(e.position):
				if bg_tool == 0: bg_shape = i
				else: bg_col = i % BG_COLORS.size()
				queue_redraw(); return
		_bg_place(); return
	if _press(e, [KEY_SPACE], [JOY_BUTTON_A]):
		_bg_place(); return
	if _press(e, [KEY_DELETE, KEY_X], [JOY_BUTTON_X]) or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT and e.pressed):
		if bg_tool == 1 and not bg_pts.is_empty(): bg_pts.pop_back(); queue_redraw()
		else: _bg_erase()
		return
	if _press(e, [KEY_BRACKETLEFT, KEY_A], [JOY_BUTTON_LEFT_SHOULDER]):
		if bg_tool == 0: bg_shape = (bg_shape - 1 + BG_SHAPES.size()) % BG_SHAPES.size()
		else: bg_col = (bg_col - 1 + BG_COLORS.size()) % BG_COLORS.size()
		queue_redraw()
	elif _press(e, [KEY_BRACKETRIGHT, KEY_E], [JOY_BUTTON_RIGHT_SHOULDER]):
		if bg_tool == 0: bg_shape = (bg_shape + 1) % BG_SHAPES.size()
		else: bg_col = (bg_col + 1) % BG_COLORS.size()
		queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		if bg_tool == 0: bg_scale_i = mini(bg_scale_i + 1, BG_SCALES.size() - 1)
		else: bg_col = (bg_col + 1) % BG_COLORS.size()
		queue_redraw()
	elif _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		if bg_tool == 0: bg_scale_i = maxi(bg_scale_i - 1, 0)
		else: bg_col = (bg_col - 1 + BG_COLORS.size()) % BG_COLORS.size()
		queue_redraw()
	elif _press(e, [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]):
		bg_depth = maxi(bg_depth - 1, 0); queue_redraw()
	elif _press(e, [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]):
		bg_depth = mini(bg_depth + 1, BG_DEPTHS.size() - 1); queue_redraw()
	elif _press(e, [KEY_PAGEUP], []):
		_bg_reorder(1)
	elif _press(e, [KEY_PAGEDOWN], []):
		_bg_reorder(-1)
	elif _press(e, [KEY_Y], [JOY_BUTTON_Y]):
		bg_theme = (bg_theme + 1) % BG_THEMES.size(); queue_redraw(); _redraw_world()


func _bg_place() -> void:
	var d: float = BG_DEPTHS[bg_depth]
	var wx: float = (aim.x - view_origin.x * d) / view_scale
	var wy: float = (aim.y - view_origin.y * d) / view_scale
	if bg_tool == 1:
		bg_pts.append([wx, wy]); queue_redraw(); return
	bg_deco.append({"shape": BG_SHAPES[bg_shape], "x": wx, "y": wy,
		"scale": BG_SCALES[bg_scale_i], "factor": d, "col": tmpl.bg_shape_color(BG_SHAPES[bg_shape], bg_theme).to_html(false)})
	queue_redraw(); _redraw_world()


func _bg_commit_poly() -> void:
	if bg_pts.size() < 3:
		_set_toast("Polygone : place au moins 3 points"); return
	bg_deco.append({"shape": "poly", "factor": BG_DEPTHS[bg_depth],
		"col": BG_COLORS[bg_col], "pts": bg_pts.duplicate(true)})
	bg_pts.clear()
	queue_redraw(); _redraw_world()


func _bg_pick() -> int:
	# décor le plus proche du pointeur (ancre = position stamp ou centroïde du polygone)
	var best := -1; var bestd := 80.0
	for i in bg_deco.size():
		var dd: Dictionary = bg_deco[i]
		var f: float = float(dd["factor"])
		var sp: Vector2
		if str(dd.get("shape", "")) == "poly":
			var c := Vector2.ZERO
			var pts: Array = dd["pts"]
			for p in pts: c += Vector2(float(p[0]), float(p[1]))
			c /= float(max(1, pts.size()))
			sp = Vector2(c.x * view_scale + view_origin.x * f, c.y * view_scale + view_origin.y * f)
		else:
			sp = Vector2(float(dd["x"]) * view_scale + view_origin.x * f, float(dd["y"]) * view_scale + view_origin.y * f)
		var dist := sp.distance_to(aim)
		if dist < bestd: bestd = dist; best = i
	return best


func _bg_reorder(dir: int) -> void:
	# change la PROFONDEUR du décor visé (= son plan vs collines + parallax).
	# dir > 0 : rapprocher (devant) ; dir < 0 : éloigner (derrière)
	var i := _bg_pick()
	if i < 0:
		_set_toast("Vise un décor pour changer son plan"); return
	var dd: Dictionary = bg_deco[i]
	var cur: float = float(dd["factor"])
	var ci := 0; var cd := 1e9
	for j in BG_DEPTHS.size():
		var diff: float = absf(float(BG_DEPTHS[j]) - cur)
		if diff < cd: cd = diff; ci = j
	ci = clampi(ci + dir, 0, BG_DEPTHS.size() - 1)
	dd["factor"] = BG_DEPTHS[ci]
	# garde un ordre de tableau cohérent : devant = fin, derrière = début
	bg_deco.remove_at(i)
	if dir > 0: bg_deco.append(dd)
	else: bg_deco.insert(0, dd)
	_set_toast("Plan : %s" % BG_DEPTH_NAMES[ci])
	queue_redraw(); _redraw_world()


func _bg_erase() -> void:
	# gère stamps ET polygones (via _bg_pick, qui ne lit pas dd["x"] sur un poly)
	var i := _bg_pick()
	if i >= 0:
		bg_deco.remove_at(i); queue_redraw(); _redraw_world()


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
	match menu_idx:
		0: _save_current()
		1: _start_selection()
		2: _paste_clip()
		3: menu_open = false; queue_redraw(); _open_config(); return
		4: _push_undo(); grid.clear(); cell_cfg.clear(); _set_toast("Niveau vidé")
		5: menu_open = false; queue_redraw(); _open_bgedit(); return
		6:
			level_props["autorun"] = not level_props.get("autorun", false)
			_set_toast("Autorun %s" % ("ON" if level_props["autorun"] else "OFF"))
		7:
			level_props["sonic"] = not level_props.get("sonic", false)
			_set_toast("Physique Sonic %s" % ("ON" if level_props["sonic"] else "OFF"))
		8:
			level_props["water_swim"] = not level_props.get("water_swim", false)
			_set_toast("Eau · Nage %s" % ("ON" if level_props["water_swim"] else "OFF"))
		9:
			level_props["water_drown"] = not level_props.get("water_drown", false)
			_set_toast("Eau · Noyade %s" % ("ON" if level_props["water_drown"] else "OFF"))
		10:
			level_props["win_coins"] = _cycle_preset(int(level_props.get("win_coins", 0)), [0, 5, 10, 20])
			var wc: int = int(level_props["win_coins"])
			_set_toast("Victoire · Pièces : %s" % (str(wc) if wc > 0 else "désactivé"))
		11:
			level_props["win_killall"] = not level_props.get("win_killall", false)
			_set_toast("Victoire · Tuer tous %s" % ("ON" if level_props["win_killall"] else "OFF"))
		12:
			level_props["time_limit"] = _cycle_preset(int(level_props.get("time_limit", 0)), [0, 30, 60, 90])
			var tl: int = int(level_props["time_limit"])
			_set_toast("Victoire · Temps : %s" % ((str(tl) + "s") if tl > 0 else "désactivé"))
		13: _toggle_music()
		14:
			show_fps = not show_fps
			_set_toast("FPS %s" % ("ON" if show_fps else "OFF"))
		15: _open_ai_panel()
		16: _save_current(); states.change_state("ListState")
		17: pass
	menu_open = false
	queue_redraw(); _redraw_world()   # vidage/thème/sonic peuvent changer le monde


func _toggle_music() -> void:
	music_on = not music_on
	if music_on: music_player.play()
	else: music_player.stop()
	_set_toast("Musique %s" % ("ON" if music_on else "OFF"))


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
func _proj_path(name: String) -> String:
	return PROJ_DIR + name.replace(" ", "_") + ".json"


func _scan_projects(dim: String) -> void:
	proj_list.clear()
	var d := DirAccess.open(PROJ_DIR)
	if d == null: return
	for fn in d.get_files():
		if not fn.ends_with(".json"): continue
		var fa := FileAccess.open(PROJ_DIR + fn, FileAccess.READ)
		if fa == null: continue
		var data = JSON.parse_string(fa.get_as_text())
		fa.close()
		if typeof(data) == TYPE_DICTIONARY and String(data.get("dim", "2D")) == dim:
			proj_list.append({"name": String(data.get("name", fn)), "dim": dim,
				"template": String(data.get("template", "platformer")), "path": PROJ_DIR + fn})


func _new_project(template_id: String) -> void:
	cur_template = template_id
	_load_template(cur_template)
	var base := "Plateformer"
	var i := 1
	while FileAccess.file_exists(_proj_path("%s %d" % [base, i])): i += 1
	cur_project = "%s %d" % [base, i]
	cols = LEVEL_COLS_DEF
	bg_theme = 0
	undo_stack.clear(); redo_stack.clear()
	tmpl.seed_demo()
	screens = {}; level_props = {}; cell_cfg.clear(); bg_deco.clear()
	aim = Vector2(-1, -1); cam_init = false; grabbing = false
	_save_current()
	mode = "edit"; dash_sel = 0
	states.change_state("GameDashState")


func _open_project(p: Dictionary) -> void:
	cur_dim = String(p.get("dim", "2D"))
	cur_template = String(p.get("template", "platformer"))
	_load_template(cur_template)
	cur_project = String(p.get("name", ""))
	var fa := FileAccess.open(String(p.get("path", "")), FileAccess.READ)
	if fa == null:
		_set_toast("Ouverture impossible"); return
	var data = JSON.parse_string(fa.get_as_text())
	fa.close()
	cols = int(data.get("cols", LEVEL_COLS_DEF))
	bg_theme = int(data.get("bg", 0)) % BG_THEMES.size()  # fond du NIVEAU (gameplay)
	var pr = data.get("props", {})
	level_props = pr if typeof(pr) == TYPE_DICTIONARY else {}
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
	grid.clear()
	for k in data.get("tiles", {}):
		var parts: PackedStringArray = String(k).split(",")
		grid[Vector2i(int(parts[0]), int(parts[1]))] = int(data["tiles"][k])
	cell_cfg.clear()
	for k in data.get("cfg", {}):
		var cp: PackedStringArray = String(k).split(",")
		cell_cfg[Vector2i(int(cp[0]), int(cp[1]))] = data["cfg"][k]
	bg_deco = data.get("bg_deco", [])
	undo_stack.clear(); redo_stack.clear()
	cursor = Vector2i(4, rows - 3)
	aim = Vector2(-1, -1); cam_init = false; grabbing = false
	mode = "edit"; dash_sel = 0
	states.change_state("GameDashState")


func _save_current() -> void:
	if cur_project == "":
		cur_project = "Plateformer 1"
	var d := {"name": cur_project, "dim": cur_dim, "template": cur_template,
		"cols": cols, "bg": bg_theme,
		"props": level_props,
		"screens": screens,
		"tiles": {}, "cfg": {}, "bg_deco": bg_deco}
	for k in grid:
		d["tiles"]["%d,%d" % [k.x, k.y]] = grid[k]
	for k in cell_cfg:
		d["cfg"]["%d,%d" % [k.x, k.y]] = cell_cfg[k]
	var f := FileAccess.open(_proj_path(cur_project), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d)); f.close()
		_set_toast("Sauvegardé : %s" % cur_project)
	else:
		_set_toast("Erreur sauvegarde")


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
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0: queue_redraw()
	if show_fps: queue_redraw()   # overlay FPS : rafraîchit le chrome (monde intact)
	if screen == "screenedit":
		_screenedit_process(delta)
		queue_redraw()
		return
	if screen == "gamedash":
		queue_redraw()
		return
	if ai_open:
		queue_redraw()
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
		# gâchettes : reculer (L2) / avancer (R2) le décor visé — sur front montant
		var tr := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.6
		var tl := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.6
		if tr and not bg_trig_r: _bg_reorder(1)
		if tl and not bg_trig_l: _bg_reorder(-1)
		bg_trig_r = tr; bg_trig_l = tl
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
		grid[cursor] = _active_tile(); grid_changed = true
	elif erase_held and grid.has(cursor):
		grid.erase(cursor); cell_cfg.erase(cursor); grid_changed = true
	if grid_changed:
		_redraw_world()
	if moved or grid_changed or not particles.is_empty():
		queue_redraw()


func _edit_area() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(0, TOPBAR, vp.x, vp.y - TOPBAR - BOTTOM)


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


func _sync_cursor_from_aim() -> void:
	var w := _s2w(aim)
	cursor.x = clampi(int(floor(w.x / CELL)), 0, cols - 1)
	cursor.y = clampi(int(floor(w.y / CELL)), 0, rows - 1)


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
	for k in grid:
		if k.x > max_x:
			max_x = k.x
	var new_cols := clampi(max_x + 5, 16, 200)
	if new_cols != cols:
		cols = new_cols
		cursor.x = mini(cursor.x, cols - 1)
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
func _start_play(from_cursor: bool) -> void:
	tmpl.start_play(from_cursor)
	mode = "play"
	queue_redraw(); _redraw_world()


func _stop_play() -> void:
	mode = "edit"
	tmpl.stop_play()
	queue_redraw(); _redraw_world()


# ============================================================= VUE (utilisée par le template)
func _w2s(wp: Vector2) -> Vector2:
	return view_origin + wp * view_scale


func _s2w(sp: Vector2) -> Vector2:
	return (sp - view_origin) / view_scale


func _compute_view() -> void:
	var vp := get_viewport_rect().size
	var area := Rect2(0, TOPBAR, vp.x, vp.y - TOPBAR - BOTTOM)
	var lvl := Vector2(cols * CELL, rows * CELL)
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
	if screen == "dim":        _draw_dim(vp); return
	if screen == "list":       _draw_list(vp); return
	if screen == "template":   _draw_template(vp); return
	if screen == "gamedash":   _draw_gamedash(vp); return
	if screen == "screenedit": _draw_screenedit(vp); return
	# édition/jeu : le monde est rendu par le template (derrière), ici le chrome par-dessus
	if mode == "edit" and not radial_open and not bg_edit and get("hide_editor_chrome") != true:
		_draw_edit_cursor()
	_draw_topbar(vp)
	_draw_hints(vp)
	if mode == "edit" and not menu_open and not radial_open and not bg_edit and aim.x >= 0.0:
		_draw_reticle()
	if bg_edit: _draw_bgedit(vp)
	if radial_open: _draw_radial(vp)
	if menu_open: _draw_menu(vp)
	if cfg_open: _draw_config(vp)
	if ai_open: _draw_ai_panel(vp)
	if toast_t > 0.0: _draw_toast(vp)
	if mode == "play" and tmpl.won: _draw_banner(vp)
	if show_fps:
		var fps := Engine.get_frames_per_second()
		var fcol := Color("2ecc71") if fps >= 55 else (Color("f39c12") if fps >= 30 else Color("e74c3c"))
		var txt := "%d FPS" % fps
		draw_rect(Rect2(Vector2(vp.x - 86, TOPBAR + 6), Vector2(76, 22)), Color(0, 0, 0, 0.55))
		_text(ThemeDB.fallback_font, Vector2(vp.x - 78, TOPBAR + 22), txt, fcol, 14)


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


func _draw_config(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var pw := 360.0
	var ph := 60.0 + cfg_fields.size() * 34.0
	var o := Vector2(vp.x * 0.5 - pw * 0.5, vp.y * 0.5 - ph * 0.5)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(o, Vector2(pw, ph)), Color("0d1117"))
	draw_rect(Rect2(o, Vector2(pw, ph)), Color("f39c12"), false, 2.0)
	_text(f, o + Vector2(16, 28), "Config : %s" % tmpl.tile_name(int(grid.get(cfg_cell, 0))), Color("f39c12"), 16)
	for i in cfg_fields.size():
		var fld: Dictionary = cfg_fields[i]
		var y := o.y + 52.0 + i * 34.0
		var sel := (i == cfg_idx)
		if sel:
			draw_rect(Rect2(Vector2(o.x + 6, y - 18), Vector2(pw - 12, 28)), Color(1, 1, 1, 0.08))
		_text(f, Vector2(o.x + 18, y + 3), str(fld["label"]), Color(1, 1, 1, 0.8), 14)
		var val := str(_cfg_get(fld))
		var vcol := Color("f39c12") if sel else Color(1, 1, 1, 0.9)
		_text(f, Vector2(o.x + pw - 150, y + 3), "◄ %s ►" % val, vcol, 14)
	_text(f, o + Vector2(16, ph - 10), "◄ ► régler   ▲▼ champ   B fermer", Color(1, 1, 1, 0.4), 11)


func _draw_bgedit(vp: Vector2) -> void:
	# le chrome (barres) est dessiné par _draw_bg_topbar/_hints
	if bg_tool == 0:
		# aperçu fantôme de la forme au pointeur
		if aim.x >= 0.0:
			var gs: float = BG_SCALES[bg_scale_i] * view_scale
			var gcol: Color = tmpl.bg_shape_color(BG_SHAPES[bg_shape], bg_theme); gcol.a = 0.55
			tmpl.draw_bg_shape(self, BG_SHAPES[bg_shape], aim, gs, gcol)
			draw_arc(aim, 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.8), 1.5)
	else:
		# forme fermée libre en cours : points dans l'ordre, fermeture auto (dernier→premier)
		var d: float = BG_DEPTHS[bg_depth]
		var col := Color(BG_COLORS[bg_col])
		var screen_pts := PackedVector2Array()
		for p in bg_pts:
			screen_pts.append(Vector2(float(p[0]) * view_scale + view_origin.x * d, float(p[1]) * view_scale + view_origin.y * d))
		var preview := PackedVector2Array(screen_pts)
		if aim.x >= 0.0: preview.append(aim)
		if preview.size() >= 3:
			var fill := col; fill.a = 0.4
			tmpl.fill_poly_closed(self, preview, fill)
		# contour fermé (relie aussi le dernier au premier)
		var m := preview.size()
		for i in m:
			draw_line(preview[i], preview[(i + 1) % m], col, 2.0)
		for i in screen_pts.size():
			draw_circle(screen_pts[i], 4.0, Color("f39c12"))
		if aim.x >= 0.0:
			draw_arc(aim, 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.8), 1.5)
		_text(ThemeDB.fallback_font, Vector2(aim.x + 10, aim.y - 8), "%d pts — Entrée pour fermer" % screen_pts.size(), Color(1, 1, 1, 0.7), 12)


func _sorted_by_x(pts: PackedVector2Array) -> Array:
	var arr := []
	for p in pts: arr.append(p)
	arr.sort_custom(func(a, b): return a.x < b.x)
	return arr


func _bg_icon_rects() -> Array:
	# rectangles cliquables (formes en mode stamp, couleurs en mode polygone)
	var out := []
	var n: int = BG_SHAPES.size() if bg_tool == 0 else BG_COLORS.size()
	var x := 150.0
	for i in n:
		out.append(Rect2(Vector2(x, 4), Vector2(44, 44)))
		x += 48.0
	return out


func _draw_bg_topbar(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, TOPBAR)), Color("11161f"))
	_text(f, Vector2(12, 22), "FOND", Color("f39c12"), 16)
	_text(f, Vector2(12, 42), "Formes" if bg_tool == 0 else "Polygone", Color(1, 1, 1, 0.7), 12)
	var rects := _bg_icon_rects()
	for i in rects.size():
		var box: Rect2 = rects[i]
		if bg_tool == 0:
			var act := (i == bg_shape)
			draw_rect(box, Color("223349") if act else Color("1a2233"))
			tmpl.draw_bg_shape(self, BG_SHAPES[i], box.position + box.size * 0.5, 0.42, tmpl.bg_shape_color(BG_SHAPES[i], bg_theme))
			draw_rect(box, Color("f39c12") if act else Color(1, 1, 1, 0.15), false, 3.0 if act else 1.0)
		else:
			var acc := (i == bg_col)
			draw_rect(box, Color(BG_COLORS[i]))
			draw_rect(box, Color("f39c12") if acc else Color(1, 1, 1, 0.2), false, 3.0 if acc else 1.0)
	var rx: float = rects[rects.size() - 1].end.x + 14.0
	_text(f, Vector2(rx, 20), "Prof: %s   Taille: %.1f" % [BG_DEPTH_NAMES[bg_depth], BG_SCALES[bg_scale_i]], Color(1, 1, 1, 0.85), 12)
	_text(f, Vector2(rx, 40), "Thème: %s   (TAB outil)" % [BG_NAMES[bg_theme] if bg_theme < BG_NAMES.size() else str(bg_theme)], Color(1, 1, 1, 0.6), 12)


func _draw_bg_hints(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2(0, vp.y - BOTTOM), Vector2(vp.x, BOTTOM)), Color("131a14"))
	var x := 12.0
	var y := vp.y - BOTTOM + 6.0
	x = _badge(x, y, "TAB", "Outil")
	if bg_tool == 0:
		x = _badge(x, y, "A", "Poser")
		x = _badge(x, y, "X", "Effacer")
		x = _badge(x, y, "A/E", "Forme")
		x = _badge(x, y, "↑↓", "Taille")
	else:
		x = _badge(x, y, "A", "Point")
		x = _badge(x, y, "Enter", "Valider")
		x = _badge(x, y, "X", "Retirer pt")
		x = _badge(x, y, "A/E", "Couleur")
	x = _badge(x, y, "←→", "Profondeur")
	x = _badge(x, y, "L2/R2", "Arr./Av. plan")
	x = _badge(x, y, "Y", "Thème")
	x = _badge(x, y, "B", "Sortir")


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
		_draw_bg_topbar(vp); return
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
		_text(f, Vector2(16, 34), "FORGE — TEST", Color("2ecc71"), 22)
		var need_coins: int = int(level_props.get("win_coins", 0))
		var coin_str := "Pièces: %d/%d" % [tmpl.coins_got, tmpl.coins_total]
		if need_coins > 0:
			coin_str = "Pièces: %d/%d (req. %d)" % [tmpl.coins_got, tmpl.coins_total, need_coins]
		var coin_col := Color("f1c40f")
		if need_coins > 0 and tmpl.coins_got < need_coins: coin_col = Color("e67e22")
		_text(f, Vector2(240, 34), coin_str, coin_col, 18)
		if tmpl.has_key: _text(f, Vector2(560, 34), "🔑", Color("f1c40f"), 20)
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
		elif level_props.get("sonic", false):
			var dbg := "SONIC  sol=%s  ang=%+.0f°  gsp=%4.0f  vy=%4.0f" % [
				("OUI" if tmpl.sonic_grounded else "non"),
				rad_to_deg(tmpl.gangle), tmpl.gsp, tmpl.pvel.y]
			_text(f, Vector2(470, 34), dbg, Color("00e5ff"), 16)
			if tmpl.land_debug != "":
				_text(f, Vector2(470, 54), tmpl.land_debug, Color("ff9800"), 14)


func _draw_hints(vp: Vector2) -> void:
	if bg_edit:
		_draw_bg_hints(vp); return
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
		x = _badge(x, y, "←→", "Bouger")
		x = _badge(x, y, "A", "Sauter")
		x = _badge(x, y, "Y", "Rejouer")
		x = _badge(x, y, "ST", "Éditeur")


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
	var f := ThemeDB.fallback_font
	var w := 320.0
	var h := menu_items.size() * 34.0 + 50.0
	var o := vp * 0.5 - Vector2(w * 0.5, h * 0.5)
	draw_rect(Rect2(o, Vector2(w, h)), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(o, Vector2(w, h)), Color("f39c12"), false, 2.0)
	_text(f, o + Vector2(16, 30), "MENU", Color("f39c12"), 20)
	for i in menu_items.size():
		var y := o.y + 56 + i * 34
		if i == menu_idx:
			draw_rect(Rect2(Vector2(o.x + 8, y - 18), Vector2(w - 16, 28)), Color(1, 1, 1, 0.12))
		_text(f, Vector2(o.x + 20, y), menu_items[i], Color.WHITE if i == menu_idx else Color(1, 1, 1, 0.65), 16)


func _draw_toast(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var w := toast.length() * 9.0 + 30.0
	var o := Vector2(vp.x * 0.5 - w * 0.5, TOPBAR + 14)
	draw_rect(Rect2(o, Vector2(w, 30)), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(o, Vector2(w, 30)), Color("f39c12"), false, 1.5)
	_text(f, o + Vector2(15, 21), toast, Color.WHITE, 15)


func _draw_banner(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var col := Color("2ecc71")
	var box := Rect2(vp * 0.5 - Vector2(200, 70), Vector2(400, 140))
	draw_rect(box, Color(0, 0, 0, 0.7)); draw_rect(box, col, false, 3.0)
	_text(f, vp * 0.5 - Vector2(80, 10), "GAGNÉ !", col, 40)
	_text(f, vp * 0.5 + Vector2(-130, 40), "Y: Rejouer   Start/B: Éditeur", Color.WHITE, 16)


func _text(f: Font, pos: Vector2, s: String, col: Color, size: int) -> void:
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _ctext(f: Font, cx: float, y: float, s: String, col: Color, size: int) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(cx - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _shell_bg(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color("1b2838"))
	var f := ThemeDB.fallback_font
	_ctext(f, vp.x * 0.5, 90, "FORGE", Color("f39c12"), 56)


func _draw_dim(vp: Vector2) -> void:
	_shell_bg(vp)
	var f := ThemeDB.fallback_font
	_ctext(f, vp.x * 0.5, 150, "Choisis un type de création", Color(1, 1, 1, 0.7), 20)
	var opts := ["2D", "3D"]
	var bw := 220.0; var bh := 160.0; var gap := 40.0
	var x0 := vp.x * 0.5 - bw - gap * 0.5
	for i in 2:
		var bx := x0 + i * (bw + gap)
		var box := Rect2(Vector2(bx, vp.y * 0.5 - bh * 0.5), Vector2(bw, bh))
		draw_rect(box, Color("223349"))
		if i == sel: draw_rect(box, Color("f39c12"), false, 4.0)
		_ctext(f, bx + bw * 0.5, vp.y * 0.5 + 18, opts[i], Color.WHITE if i == sel else Color(1, 1, 1, 0.6), 60)
		if i == 1:
			_ctext(f, bx + bw * 0.5, vp.y * 0.5 + 55, "(bientôt)", Color(1, 1, 1, 0.4), 16)
	_ctext(f, vp.x * 0.5, vp.y - 40, "‹ › choisir    A valider", Color(1, 1, 1, 0.6), 16)


func _draw_list(vp: Vector2) -> void:
	_shell_bg(vp)
	var f := ThemeDB.fallback_font
	_ctext(f, vp.x * 0.5, 150, "Projets — %s" % cur_dim, Color(1, 1, 1, 0.8), 22)
	var n := proj_list.size() + 1
	var y0 := 200.0
	for i in n:
		var y := y0 + i * 44
		var label: String = ("＋  Nouveau projet" if i == proj_list.size() else "📄  " + String(proj_list[i]["name"]))
		var box := Rect2(Vector2(vp.x * 0.5 - 230, y - 26), Vector2(460, 36))
		if i == sel: draw_rect(box, Color(1, 1, 1, 0.12)); draw_rect(box, Color("f39c12"), false, 2.0)
		var col: Color = Color.WHITE if i == sel else Color(1, 1, 1, 0.65)
		if i == proj_list.size(): col = Color("2ecc71") if i == sel else Color(0.4, 0.8, 0.5)
		_text(f, Vector2(vp.x * 0.5 - 210, y), label, col, 18)
	if proj_list.is_empty():
		_ctext(f, vp.x * 0.5, y0 - 30, "Aucun projet — crée le premier", Color(1, 1, 1, 0.4), 15)
	_ctext(f, vp.x * 0.5, vp.y - 40, "▲▼ choisir    A ouvrir    B retour", Color(1, 1, 1, 0.6), 16)


func _draw_template(vp: Vector2) -> void:
	_shell_bg(vp)
	var f := ThemeDB.fallback_font
	_ctext(f, vp.x * 0.5, 150, "Nouveau projet — templates %s" % cur_dim, Color(1, 1, 1, 0.8), 22)
	var list: Array = TEMPLATES.get(cur_dim, [])
	if list.is_empty():
		_ctext(f, vp.x * 0.5, vp.y * 0.5, "Aucun template %s pour l'instant (bientôt)" % cur_dim, Color(1, 1, 1, 0.5), 20)
	else:
		var y0 := 220.0
		for i in list.size():
			var y := y0 + i * 50
			var box := Rect2(Vector2(vp.x * 0.5 - 200, y - 30), Vector2(400, 42))
			draw_rect(box, Color("223349"))
			if i == sel: draw_rect(box, Color("f39c12"), false, 3.0)
			_ctext(f, vp.x * 0.5, y, String(list[i]["name"]), Color.WHITE if i == sel else Color(1, 1, 1, 0.65), 22)
	_ctext(f, vp.x * 0.5, vp.y - 40, "▲▼ choisir    A créer    B retour", Color(1, 1, 1, 0.6), 16)


# ============================================================= GAMEDASH
func _draw_gamedash(vp: Vector2) -> void:
	_shell_bg(vp)
	var f := ThemeDB.fallback_font
	_ctext(f, vp.x * 0.5, 34, cur_project.to_upper(), Color.WHITE, 22)
	var pad := 18.0; var gap_x := 12.0; var gap_y := 10.0
	var card_w := (vp.x - 2.0 * pad - gap_x) * 0.5
	var label_h := 26.0
	var card_h := (vp.y - 56.0 - 30.0 - 2.0 * gap_y) / 3.0
	var prev_h := card_h - label_h
	for i in DASH_ITEMS.size():
		var ci := i % 2; var ri := i / 2
		var x := pad + ci * (card_w + gap_x)
		var y := 56.0 + ri * (card_h + gap_y)
		var sel_i := i == dash_sel
		var pr := Rect2(x, y, card_w, prev_h)
		var key_i: String = DASH_KEYS[i]
		_draw_screen_preview(pr, key_i)
		draw_rect(Rect2(x, y + prev_h, card_w, label_h), Color(0, 0, 0, 0.55))
		var lcol := UI_ACCENT if sel_i else Color(1, 1, 1, 0.65)
		_ctext(f, x + card_w * 0.5, y + prev_h + label_h * 0.72, DASH_ITEMS[i], lcol, 13)
		draw_rect(Rect2(x, y, card_w, card_h), UI_ACCENT if sel_i else Color(1, 1, 1, 0.18), false, 3.0 if sel_i else 1.0)
	_ctext(f, vp.x * 0.5, vp.y - 14, "◀▶▲▼ naviguer    A ouvrir    B liste projets", Color(1, 1, 1, 0.45), 13)


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
