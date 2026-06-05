extends Node2D
# SPARK FORGE — coquille générique : shell (écrans XSM), éditeur de niveau, chrome (UI),
# caméra/vue, fx, audio, sauvegarde de projets. Le GENRE (tuiles + simulation + rendu du
# monde + personnage XSM) vit dans un template à part (scripts/common/templates/...).

const CELL := 48
const TOPBAR := 52
const BOTTOM := 34
const LEVEL_COLS_DEF := 40
const PROJ_DIR := "user://forge_projects/"
const TEMPLATES := {
	"2D": [{"id": "platformer", "name": "Plateformer"}],
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

# état éditeur
var grid := {}
var cols := LEVEL_COLS_DEF
var rows := 14
var cursor := Vector2i(4, 8)
var pal := 0
var mode := "edit"             # "edit" | "play"
var cursor_cd := 0.0
var hold_time := 0.0
var last_dir := Vector2i.ZERO
var cursor_mode := "rapide"
var place_held := false
var erase_held := false
var bg_theme := 0

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
	# instancie le template plateformer (rendu du monde + simulation + perso XSM)
	tmpl = PLATFORMER_PLAY.instantiate()
	add_child(tmpl)
	tmpl.setup(self)
	queue_redraw()
	if OS.get_cmdline_args().has("--selftest"):
		call_deferred("_self_test")


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
	if screen == "dim":
		_dim_input(e); return
	if screen == "list":
		_list_input(e); return
	if screen == "template":
		_tmpl_input(e); return
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
	if sel_mode:
		if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]): _sel_click()
		elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]): _sel_cancel()
		return
	if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], true):
		if not radial_open: _begin_stroke(true)
		return
	if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], false):
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
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_9:
		pal = clampi(e.keycode - KEY_1, 0, tmpl.palette().size() - 1); queue_redraw()


func _play_input(e: InputEvent) -> void:
	if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		tmpl.jump_pressed()
	elif _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], false):
		tmpl.jump_released()
	elif _press(e, [KEY_TAB], [JOY_BUTTON_START, JOY_BUTTON_B]):
		_stop_play()
	elif _press(e, [KEY_R], [JOY_BUTTON_Y]):
		tmpl.start_play(tmpl.last_from_cursor)


func _begin_stroke(place: bool) -> void:
	_push_undo()
	if place:
		place_held = true; grid[cursor] = tmpl.palette()[pal]
	else:
		erase_held = true; grid.erase(cursor)
	queue_redraw()


func _cycle(dir: int) -> void:
	var n := tmpl.palette().size()
	pal = (pal + dir + n) % n; queue_redraw()


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
	grid = undo_stack.pop_back(); queue_redraw()


func _redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(grid.duplicate())
	grid = redo_stack.pop_back(); queue_redraw()


# ---------------- menu éditeur
func _open_menu() -> void:
	menu_open = true; menu_idx = 0
	menu_items = ["Sauvegarder", "Copier zone", "Coller ici", "Vider niveau",
		"Largeur +", "Largeur -", "Fond suivant", "Musique: %s" % ("ON" if music_on else "OFF"),
		"Projets (quitter)", "Fermer"]
	queue_redraw()


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
		3: _push_undo(); grid.clear(); _set_toast("Niveau vidé")
		4: cols = min(cols + 5, 80); _set_toast("Largeur: %d" % cols)
		5: cols = max(cols - 5, 16); cursor.x = min(cursor.x, cols - 1); _set_toast("Largeur: %d" % cols)
		6: bg_theme = (bg_theme + 1) % BG_THEMES.size(); _set_toast("Fond #%d" % (bg_theme + 1))
		7: _toggle_music()
		8: _save_current(); states.change_state("ListState")
		9: pass
	menu_open = false
	queue_redraw()


func _toggle_music() -> void:
	music_on = not music_on
	if music_on: music_player.play()
	else: music_player.stop()
	_set_toast("Musique %s" % ("ON" if music_on else "OFF"))


func _set_toast(s: String) -> void:
	toast = s; toast_t = 2.0; queue_redraw()


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
	var base := "Plateformer"
	var i := 1
	while FileAccess.file_exists(_proj_path("%s %d" % [base, i])): i += 1
	cur_project = "%s %d" % [base, i]
	cols = LEVEL_COLS_DEF
	bg_theme = 0
	undo_stack.clear(); redo_stack.clear()
	tmpl.seed_demo()
	_save_current()
	mode = "edit"
	states.change_state("EditorState")


func _open_project(p: Dictionary) -> void:
	cur_dim = String(p.get("dim", "2D"))
	cur_template = String(p.get("template", "platformer"))
	cur_project = String(p.get("name", ""))
	var fa := FileAccess.open(String(p.get("path", "")), FileAccess.READ)
	if fa == null:
		_set_toast("Ouverture impossible"); return
	var data = JSON.parse_string(fa.get_as_text())
	fa.close()
	cols = int(data.get("cols", LEVEL_COLS_DEF))
	bg_theme = int(data.get("bg", 0)) % BG_THEMES.size()
	grid.clear()
	for k in data.get("tiles", {}):
		var parts: PackedStringArray = String(k).split(",")
		grid[Vector2i(int(parts[0]), int(parts[1]))] = int(data["tiles"][k])
	undo_stack.clear(); redo_stack.clear()
	cursor = Vector2i(4, rows - 3)
	mode = "edit"
	states.change_state("EditorState")


func _save_current() -> void:
	if cur_project == "":
		cur_project = "Plateformer 1"
	var d := {"name": cur_project, "dim": cur_dim, "template": cur_template,
		"cols": cols, "bg": bg_theme, "tiles": {}}
	for k in grid:
		d["tiles"]["%d,%d" % [k.x, k.y]] = grid[k]
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
	_set_toast("Collé")


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
	_update_fx(delta)
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0: queue_redraw()
	if screen != "edit" or mode == "play":
		return
	if menu_open:
		return
	var peek := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5 or Input.is_key_pressed(KEY_SHIFT)
	if peek != dezoom:
		dezoom = peek; queue_redraw()
	var l2 := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5
	if l2 and not radial_open:
		radial_open = true; radial_pick = pal
	elif not l2 and radial_open:
		radial_open = false; pal = radial_pick; queue_redraw()
	if radial_open:
		var s := _stick()
		if s.length() > 0.5:
			var ang := atan2(s.y, s.x)
			var n := tmpl.palette().size()
			radial_pick = ((int(round((ang + PI / 2.0) / (TAU / n)))) % n + n) % n
		queue_redraw()
		return
	var d := _dir_held()
	if d == Vector2i.ZERO:
		cursor_cd = 0.0; hold_time = 0.0; last_dir = Vector2i.ZERO
	else:
		hold_time += delta
		cursor_cd -= delta
		if d != last_dir:
			_move_cursor(d); cursor_cd = CURSOR_DELAY; last_dir = d; hold_time = 0.0
		elif cursor_cd <= 0.0:
			_move_cursor(d)
			cursor_cd = RATE_SLOW if cursor_mode == "précis" else lerpf(RATE_SLOW, RATE_FAST, clampf(hold_time / 0.6, 0.0, 1.0))
	if sel_mode:
		queue_redraw()
		return
	if place_held and grid.get(cursor) != tmpl.palette()[pal]:
		grid[cursor] = tmpl.palette()[pal]; queue_redraw()
	elif erase_held and grid.has(cursor):
		grid.erase(cursor); queue_redraw()


func _move_cursor(d: Vector2i) -> void:
	cursor.x = clampi(cursor.x + d.x, 0, cols - 1)
	cursor.y = clampi(cursor.y + d.y, 0, rows - 1)
	queue_redraw()


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
	queue_redraw()


func _stop_play() -> void:
	mode = "edit"
	tmpl.stop_play()
	queue_redraw()


# ============================================================= VUE (utilisée par le template)
func _w2s(wp: Vector2) -> Vector2:
	return view_origin + wp * view_scale


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
		view_origin = area.position + area.size * 0.5 - (Vector2(cursor) + Vector2(0.5, 0.5)) * CELL * view_scale
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
	if screen == "dim": _draw_dim(vp); return
	if screen == "list": _draw_list(vp); return
	if screen == "template": _draw_template(vp); return
	# édition/jeu : le monde est rendu par le template (derrière), ici le chrome par-dessus
	_draw_topbar(vp)
	_draw_hints(vp)
	if radial_open: _draw_radial(vp)
	if menu_open: _draw_menu(vp)
	if toast_t > 0.0: _draw_toast(vp)
	if mode == "play" and tmpl.won: _draw_banner(vp)


func _draw_topbar(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, TOPBAR)), Color("11161f"))
	var f := ThemeDB.fallback_font
	var palette: Array = tmpl.palette()
	if mode == "edit":
		_text(f, Vector2(12, 32), "FORGE", Color("f39c12"), 20)
		var x := 96.0
		for i in palette.size():
			var box := Rect2(Vector2(x, 9), Vector2(34, 34))
			draw_rect(box, Color("223349"))
			tmpl.draw_tile(self, Vector2(x, 9), palette[i], 34.0 / CELL)
			if i == pal: draw_rect(box, Color.WHITE, false, 3.0)
			x += 44
		_text(f, Vector2(x + 8, 22), tmpl.tile_name(palette[pal]), Color("f39c12"), 14)
		_text(f, Vector2(x + 8, 42), "Curseur: %s" % cursor_mode, Color(1, 1, 1, 0.6), 12)
	else:
		_text(f, Vector2(16, 34), "FORGE — TEST", Color("2ecc71"), 22)
		_text(f, Vector2(240, 34), "Pièces: %d/%d" % [tmpl.coins_got, tmpl.coins_total], Color("f1c40f"), 20)
		if tmpl.has_key: _text(f, Vector2(430, 34), "🔑", Color("f1c40f"), 20)


func _draw_hints(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2(0, vp.y - BOTTOM), Vector2(vp.x, BOTTOM)), Color("11161f"))
	var x := 12.0
	var y := vp.y - BOTTOM + 6.0
	if mode == "edit":
		if sel_mode:
			x = _badge(x, y, "A", "Poser coin")
			x = _badge(x, y, "B", "Annuler")
		else:
			x = _badge(x, y, "A", "Placer")
			x = _badge(x, y, "B", "Effacer")
			x = _badge(x, y, "L2", "Palette")
			x = _badge(x, y, "X", "Annuler")
			x = _badge(x, y, "Y", "Refaire")
			x = _badge(x, y, "R2", "Vue")
			x = _badge(x, y, "R3", "Test ici")
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
	var c := vp * 0.5
	var rad := 140.0
	draw_circle(c, rad + 44, Color(0, 0, 0, 0.55))
	var f := ThemeDB.fallback_font
	var palette: Array = tmpl.palette()
	var n := palette.size()
	for i in n:
		var ang := -PI / 2.0 + i * TAU / n
		var p := c + Vector2(cos(ang), sin(ang)) * rad
		var is_sel: bool = i == radial_pick
		var box := Rect2(p - Vector2(22, 22), Vector2(44, 44))
		draw_rect(box, Color("223349"))
		tmpl.draw_tile(self, p - Vector2(22, 22), palette[i], 44.0 / CELL)
		if is_sel:
			draw_rect(box, Color.WHITE, false, 4.0)
			_text(f, c + Vector2(-tmpl.tile_name(palette[i]).length() * 4.0, 5), tmpl.tile_name(palette[i]), Color.WHITE, 16)


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
