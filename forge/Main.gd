extends Node2D
# SPARK FORGE — Lite 2D (plateformer), manette-first.
# Juice (sons générés, particules, screen shake, squash/stretch), ennemis vivants
# (patrouille + écrasables), sauvegarde/chargement, nouvelles tuiles, menu éditeur.

const CELL := 48
const TOPBAR := 52
const BOTTOM := 34
const LEVEL_COLS_DEF := 40
const PSIZE := Vector2(36, 36)
const SAVE_PATH := "user://forge_level.json"

# physique
const GRAVITY := 1900.0
const SPEED := 330.0
const JUMP_V := -660.0
const ACCEL_GROUND := 2600.0
const ACCEL_AIR := 1500.0
const FRICTION := 3000.0
const JUMP_CUT := 0.45
const COYOTE := 0.10
const JUMP_BUFFER := 0.12
const MAX_FALL := 1300.0
const DEADZONE := 0.35
const STOMP_BOUNCE := -460.0
const SPRING_V := -1050.0
const ESIZE := 36
const ESPEED := 85.0
const SLOPE_SNAP_UP := 22.0      # tolérance pénétration sous la rampe (montée)
const SLOPE_SNAP_DOWN := 16.0    # tolérance au-dessus (coller en descente)

# curseur
const CURSOR_DELAY := 0.25
const RATE_SLOW := 0.12
const RATE_FAST := 0.035

enum { EMPTY, GROUND, SPAWN, COIN, ENEMY, GOAL, SPRING, SPIKE, BREAKABLE, MOVPLAT, CHECKPOINT, KEY, DOOR,
	SLOPE_R, SLOPE_L, GSL_R_LO, GSL_R_HI, GSL_L_HI, GSL_L_LO }
const PALETTE := [GROUND, SPAWN, COIN, ENEMY, GOAL, SPRING, SPIKE, BREAKABLE, MOVPLAT, CHECKPOINT, KEY, DOOR,
	SLOPE_R, SLOPE_L, GSL_R_LO, GSL_R_HI, GSL_L_HI, GSL_L_LO]
const SLOPES := [SLOPE_R, SLOPE_L, GSL_R_LO, GSL_R_HI, GSL_L_HI, GSL_L_LO]
const NAMES := {
	GROUND: "Sol", SPAWN: "Spawn", COIN: "Pièce", ENEMY: "Ennemi", GOAL: "Arrivée",
	SPRING: "Ressort", SPIKE: "Piques", BREAKABLE: "Cassable", MOVPLAT: "Plateforme",
	CHECKPOINT: "Checkpoint", KEY: "Clé", DOOR: "Porte",
	SLOPE_R: "Pente45 ↗", SLOPE_L: "Pente45 ↖", GSL_R_LO: "Pente↗ bas", GSL_R_HI: "Pente↗ haut",
	GSL_L_HI: "Pente↖ haut", GSL_L_LO: "Pente↖ bas"
}
const COLORS := {
	GROUND: Color("6b4a2b"), SPAWN: Color("2ecc71"), COIN: Color("f1c40f"),
	ENEMY: Color("e74c3c"), GOAL: Color("3498db"), SPRING: Color("e67e22"),
	SPIKE: Color("95a5a6"), BREAKABLE: Color("a0522d"), MOVPLAT: Color("16a085"),
	CHECKPOINT: Color("9b59b6"), KEY: Color("f1c40f"), DOOR: Color("7f5539"),
	SLOPE_R: Color("6b4a2b"), SLOPE_L: Color("6b4a2b"), GSL_R_LO: Color("6b4a2b"),
	GSL_R_HI: Color("6b4a2b"), GSL_L_HI: Color("6b4a2b"), GSL_L_LO: Color("6b4a2b")
}
const BG_THEMES := [
	[Color("1b2838"), Color("223349")], [Color("2c1b38"), Color("3a2349")],
	[Color("1b3826"), Color("224935")], [Color("382b1b"), Color("493a23")]
]

# état éditeur
var grid := {}
var cols := LEVEL_COLS_DEF
var rows := 14
var cursor := Vector2i(4, 8)
var pal := 0
var mode := "edit"
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

# menu radial
var radial_open := false
var radial_pick := 0

# menu éditeur
var menu_open := false
var menu_idx := 0
var menu_items := []
var toast := ""
var toast_t := 0.0

# sélection / copier-coller
var sel_mode := false
var sel_anchor := Vector2i(-1, -1)
var clipboard := {}      # offset Vector2i -> type
var clip_size := Vector2i.ZERO

# vue
var view_origin := Vector2.ZERO
var view_scale := 1.0
var dezoom := false

# fx
var particles := []      # {pos,vel,life,max,col,size,grav}
var shake_t := 0.0
var shake_mag := 0.0
var squash := Vector2.ONE
var music_on := false

# état jeu
var ppos := Vector2.ZERO
var pvel := Vector2.ZERO
var on_floor := false
var was_floor := false
var coyote_t := 0.0
var jbuf := 0.0
var coins_got := 0
var coins_total := 0
var dead := false
var won := false
var death_t := 0.0
var has_key := false
var spawn_cell := Vector2i(4, 8)
var respawn_cell := Vector2i(4, 8)
var last_from_cursor := false
var enemies := []        # {pos:Vector2, dir:int, alive:bool}
var plats := []          # {pos:Vector2, dir:int, min:float, max:float}

# audio
var sfx := {}
var music_player: AudioStreamPlayer


func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	_compute_grid()
	_build_audio()
	_seed_demo()
	queue_redraw()


func _compute_grid() -> void:
	var vp := get_viewport_rect().size
	rows = max(6, int((vp.y - TOPBAR - BOTTOM) / CELL))


func _seed_demo() -> void:
	grid.clear()
	for x in range(0, cols):
		grid[Vector2i(x, rows - 1)] = GROUND
	for x in range(8, 12):
		grid[Vector2i(x, rows - 4)] = GROUND
	for x in range(16, 19):
		grid[Vector2i(x, rows - 6)] = GROUND
	grid[Vector2i(2, rows - 2)] = SPAWN
	grid[Vector2i(9, rows - 5)] = COIN
	grid[Vector2i(10, rows - 5)] = COIN
	grid[Vector2i(17, rows - 7)] = COIN
	grid[Vector2i(13, rows - 2)] = ENEMY
	grid[Vector2i(22, rows - 2)] = SPRING
	grid[Vector2i(26, rows - 2)] = SPIKE
	grid[Vector2i(cols - 2, rows - 2)] = GOAL
	cursor = Vector2i(4, rows - 3)


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
	var notes := [392.0, 523.0, 392.0, 659.0]   # petite boucle douce
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
	if menu_open:
		_menu_input(e); return
	if mode == "edit":
		_edit_input(e)
	else:
		_play_input(e)


func _edit_input(e: InputEvent) -> void:
	# ouvrir menu
	if _press(e, [KEY_ESCAPE], [JOY_BUTTON_BACK]):
		_open_menu(); return
	if sel_mode:
		if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]): _sel_click()
		elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]): _sel_cancel()
		return
	# place / erase continus
	if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], true):
		if not radial_open: _begin_stroke(true)
		return
	if _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], false):
		place_held = false; return
	if _is_btn(e, [KEY_DELETE, KEY_D], [JOY_BUTTON_B], true):
		_begin_stroke(false); return
	if _is_btn(e, [KEY_DELETE, KEY_D], [JOY_BUTTON_B], false):
		erase_held = false; return
	# discrets
	if _press(e, [KEY_Z], [JOY_BUTTON_X]): _undo()
	elif _press(e, [KEY_Y], [JOY_BUTTON_Y]): _redo()
	elif _press(e, [KEY_BRACKETLEFT, KEY_A], [JOY_BUTTON_LEFT_SHOULDER]): _cycle(-1)
	elif _press(e, [KEY_BRACKETRIGHT, KEY_E], [JOY_BUTTON_RIGHT_SHOULDER]): _cycle(1)
	elif _press(e, [KEY_TAB], [JOY_BUTTON_START]): _start_play(false)
	elif _press(e, [KEY_T], [JOY_BUTTON_RIGHT_STICK]): _start_play(true)
	elif _press(e, [KEY_C], [JOY_BUTTON_LEFT_STICK]): _toggle_cursor_mode()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_9:
		pal = clampi(e.keycode - KEY_1, 0, PALETTE.size() - 1); queue_redraw()


func _play_input(e: InputEvent) -> void:
	if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		if not dead and not won: jbuf = JUMP_BUFFER
	elif _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], false):
		if pvel.y < 0: pvel.y *= JUMP_CUT
	elif _press(e, [KEY_TAB], [JOY_BUTTON_START, JOY_BUTTON_B]):
		_stop_play()
	elif _press(e, [KEY_R], [JOY_BUTTON_Y]):
		_start_play(last_from_cursor)


func _begin_stroke(place: bool) -> void:
	_push_undo()
	if place:
		place_held = true; grid[cursor] = PALETTE[pal]
	else:
		erase_held = true; grid.erase(cursor)
	queue_redraw()


func _cycle(dir: int) -> void:
	pal = (pal + dir + PALETTE.size()) % PALETTE.size(); queue_redraw()


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
	menu_items = ["Sauvegarder", "Charger", "Copier zone", "Coller ici", "Vider niveau",
		"Largeur +", "Largeur -", "Fond suivant", "Musique: %s" % ("ON" if music_on else "OFF"), "Fermer"]
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
		0: _save_level()
		1: _load_level()
		2: _start_selection()
		3: _paste_clip()
		4: _push_undo(); grid.clear(); _set_toast("Niveau vidé")
		5: cols = min(cols + 5, 80); _set_toast("Largeur: %d" % cols)
		6: cols = max(cols - 5, 16); cursor.x = min(cursor.x, cols - 1); _set_toast("Largeur: %d" % cols)
		7: bg_theme = (bg_theme + 1) % BG_THEMES.size(); _set_toast("Fond #%d" % (bg_theme + 1))
		8: _toggle_music()
		9: pass
	if menu_idx != 2 and menu_idx != 3:
		menu_open = false
	else:
		menu_open = false   # sélection/coller : on ferme et on agit dans l'éditeur
	queue_redraw()


func _toggle_music() -> void:
	music_on = not music_on
	if music_on: music_player.play()
	else: music_player.stop()
	_set_toast("Musique %s" % ("ON" if music_on else "OFF"))


func _set_toast(s: String) -> void:
	toast = s; toast_t = 2.0; queue_redraw()


# ---------------- sauvegarde
func _save_level() -> void:
	var d := {"cols": cols, "rows": rows, "bg": bg_theme, "tiles": {}}
	for k in grid:
		d["tiles"]["%d,%d" % [k.x, k.y]] = grid[k]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d)); f.close()
		_set_toast("Sauvegardé ✓")
	else:
		_set_toast("Erreur sauvegarde")


func _load_level() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_set_toast("Aucune sauvegarde"); return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		_set_toast("Sauvegarde invalide"); return
	_push_undo()
	cols = int(d.get("cols", LEVEL_COLS_DEF))
	bg_theme = int(d.get("bg", 0)) % BG_THEMES.size()
	grid.clear()
	for k in d.get("tiles", {}):
		var parts: PackedStringArray = String(k).split(",")
		grid[Vector2i(int(parts[0]), int(parts[1]))] = int(d["tiles"][k])
	_set_toast("Chargé ✓")


# ---------------- sélection / copier-coller (A7)
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


# ============================================================= PROCESS
func _process(delta: float) -> void:
	_update_fx(delta)
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0: queue_redraw()
	if mode == "play":
		queue_redraw()
		return
	if menu_open:
		return
	# dézoom
	var peek := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5 or Input.is_key_pressed(KEY_SHIFT)
	if peek != dezoom:
		dezoom = peek; queue_redraw()
	# radial
	var l2 := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5
	if l2 and not radial_open:
		radial_open = true; radial_pick = pal
	elif not l2 and radial_open:
		radial_open = false; pal = radial_pick; queue_redraw()
	if radial_open:
		var s := _stick()
		if s.length() > 0.5:
			var ang := atan2(s.y, s.x)
			var n := PALETTE.size()
			radial_pick = ((int(round((ang + PI / 2.0) / (TAU / n)))) % n + n) % n
		queue_redraw()
		return
	# curseur
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
	if place_held and grid.get(cursor, EMPTY) != PALETTE[pal]:
		grid[cursor] = PALETTE[pal]; queue_redraw()
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


# ============================================================= PLAY
func _start_play(from_cursor: bool) -> void:
	last_from_cursor = from_cursor
	if from_cursor:
		spawn_cell = cursor
	else:
		spawn_cell = _find(SPAWN)
		if spawn_cell == Vector2i(-1, -1): spawn_cell = cursor
	respawn_cell = spawn_cell
	coins_total = _count(COIN)
	coins_got = 0
	dead = false; won = false; death_t = 0.0; has_key = false
	on_floor = false; was_floor = false; coyote_t = 0.0; jbuf = 0.0
	# entités
	enemies.clear(); plats.clear()
	for k in grid:
		if grid[k] == ENEMY:
			enemies.append({"pos": Vector2(k.x * CELL + 6, k.y * CELL + (CELL - ESIZE)), "dir": -1, "alive": true, "vy": 0.0})
		elif grid[k] == MOVPLAT:
			plats.append({"pos": Vector2(k.x * CELL, k.y * CELL), "dir": 1, "min": float((k.x - 3) * CELL), "max": float((k.x + 3) * CELL)})
	_place_player(spawn_cell)
	mode = "play"
	queue_redraw()


func _place_player(c: Vector2i) -> void:
	ppos = Vector2(c.x * CELL + (CELL - PSIZE.x) * 0.5, c.y * CELL + (CELL - PSIZE.y))
	pvel = Vector2.ZERO


func _stop_play() -> void:
	mode = "edit"; Input.stop_joy_vibration(0)
	if music_on: pass
	queue_redraw()


func _physics_process(delta: float) -> void:
	if mode != "play" or won:
		return
	if dead:
		death_t -= delta
		if death_t <= 0.0:
			dead = false
			_place_player(respawn_cell)
		return

	var dir := _dir_held()
	var target := dir.x * SPEED
	if dir.x != 0:
		pvel.x = move_toward(pvel.x, target, (ACCEL_GROUND if on_floor else ACCEL_AIR) * delta)
	else:
		pvel.x = move_toward(pvel.x, 0.0, (FRICTION if on_floor else ACCEL_AIR) * delta)

	coyote_t -= delta
	jbuf -= delta
	if jbuf > 0.0 and (on_floor or coyote_t > 0.0):
		pvel.y = JUMP_V; jbuf = 0.0; coyote_t = 0.0; on_floor = false
		squash = Vector2(0.78, 1.25)
		Input.start_joy_vibration(0, 0.10, 0.25, 0.07); _play("jump")

	pvel.y = min(pvel.y + GRAVITY * delta, MAX_FALL)

	_move_plats(delta)
	var rects := _solid_rects()
	was_floor = on_floor
	on_floor = false
	var head_hit := false

	# X : déplace, cale sur la rampe (montée), PUIS collision murs pleins
	# (l'ordre fait que le remplissage sous la pente ne bloque pas)
	ppos.x += pvel.x * delta
	ppos.x = clampf(ppos.x, 0, cols * CELL - PSIZE.x)
	_slope_snap()
	for r in rects:
		var pr := Rect2(ppos, PSIZE)
		if pr.intersects(r):
			if pvel.x > 0: ppos.x = r.position.x - PSIZE.x
			elif pvel.x < 0: ppos.x = r.position.x + r.size.x
			pvel.x = 0

	# Y : gravité + collision sol/plafond pleins
	ppos.y += pvel.y * delta
	for r in rects:
		var pr := Rect2(ppos, PSIZE)
		if pr.intersects(r):
			if pvel.y > 0: ppos.y = r.position.y - PSIZE.y; on_floor = true
			elif pvel.y < 0: ppos.y = r.position.y + r.size.y; head_hit = true
			pvel.y = 0

	# pente : coller en descente (évite le rollback / saut de marche)
	_slope_snap()

	if head_hit: _hit_head()
	if on_floor: coyote_t = COYOTE
	if on_floor and not was_floor:
		squash = Vector2(1.28, 0.72)
		_emit(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y), 6, Color("c8b89a"), 120.0, 0.30, true, 3.0)
		Input.start_joy_vibration(0, 0.0, 0.30, 0.05)

	_carry_on_plat(delta)
	_update_enemies(delta)
	if ppos.y > rows * CELL + 200: _die()
	_interactions()
	queue_redraw()


func _move_plats(delta: float) -> void:
	for p in plats:
		p.pos.x += p.dir * 90.0 * delta
		if p.pos.x <= p.min: p.pos.x = p.min; p.dir = 1
		elif p.pos.x >= p.max: p.pos.x = p.max; p.dir = -1


func _carry_on_plat(delta: float) -> void:
	var feet := Rect2(ppos + Vector2(2, PSIZE.y - 2), Vector2(PSIZE.x - 4, 6))
	for p in plats:
		if feet.intersects(Rect2(p.pos, Vector2(CELL, 14))):
			ppos.x += p.dir * 90.0 * delta


func _solid_rects() -> Array:
	var out := []
	for c in _cells(Rect2(ppos - Vector2(CELL, CELL), PSIZE + Vector2(CELL, CELL) * 2)):
		var t: int = grid.get(c, EMPTY)
		if t == GROUND or t == BREAKABLE or t == DOOR:
			out.append(_cell_rect(c))
	for p in plats:
		out.append(Rect2(p.pos, Vector2(CELL, 14)))
	return out


func _hit_head() -> void:
	# casser un bloc cassable touché par le dessus de la tête
	var head := Vector2i(int((ppos.x + PSIZE.x * 0.5) / CELL), int((ppos.y - 2) / CELL))
	if grid.get(head, EMPTY) == BREAKABLE:
		grid.erase(head)
		_emit(_cell_center(head), 12, COLORS[BREAKABLE], 220.0, 0.45, true, 4.0)
		_shake(6.0, 0.18); _play("break")


func _update_enemies(delta: float) -> void:
	var pr := Rect2(ppos, PSIZE)
	for en in enemies:
		if not en.alive: continue
		# gravité + pose sur le sol
		en.vy = min(en.vy + GRAVITY * delta, MAX_FALL)
		en.pos.y += en.vy * delta
		var grounded := false
		for cx in [int(en.pos.x / CELL), int((en.pos.x + ESIZE - 1) / CELL)]:
			var fc := Vector2i(cx, int((en.pos.y + ESIZE) / CELL))
			if _solid_tile(fc):
				en.pos.y = fc.y * CELL - ESIZE; en.vy = 0.0; grounded = true
		# patrouille : demi-tour au mur ou au bord du vide (seulement si au sol)
		var nx: float = en.pos.x + en.dir * ESPEED * delta
		var front_col := int((nx + (ESIZE if en.dir > 0 else 0)) / CELL)
		var foot_row := int((en.pos.y + ESIZE - 1) / CELL)
		var wall := _solid_tile(Vector2i(front_col, foot_row))
		var edge := grounded and not _solid_tile(Vector2i(front_col, foot_row + 1))
		if wall or edge:
			en.dir = -en.dir
		else:
			en.pos.x = nx
		en.pos.x = clampf(en.pos.x, 0, cols * CELL - ESIZE)
		# collision joueur
		var er := Rect2(en.pos, Vector2(ESIZE, ESIZE))
		if pr.intersects(er):
			if pvel.y > 0 and (ppos.y + PSIZE.y) - en.pos.y < 22:
				en.alive = false
				pvel.y = STOMP_BOUNCE
				_emit(er.position + Vector2(ESIZE, ESIZE) * 0.5, 10, COLORS[ENEMY], 200.0, 0.4, true, 4.0)
				_shake(4.0, 0.12); _play("stomp")
			else:
				_die()


func _solid_tile(c: Vector2i) -> bool:
	var t: int = grid.get(c, EMPTY)
	return t == GROUND or t == BREAKABLE or t == DOOR


func _is_slope(t: int) -> bool:
	return SLOPES.has(t)


# hauteur de la surface (y écran) d'une tuile pente, à la position x locale [0..CELL]
func _slope_surface(t: int, c: Vector2i, lx: float) -> float:
	var top := float(c.y * CELL)
	var bot := float((c.y + 1) * CELL)
	match t:
		SLOPE_R: return bot - lx                      # 45° monte vers la droite
		SLOPE_L: return top + lx                       # 45° monte vers la gauche
		GSL_R_LO: return bot - lx * 0.5                # 26.5° ↗ moitié basse
		GSL_R_HI: return bot - CELL * 0.5 - lx * 0.5   # 26.5° ↗ moitié haute
		GSL_L_HI: return top + lx * 0.5                # 26.5° ↖ moitié haute (gauche)
		GSL_L_LO: return top + CELL * 0.5 + lx * 0.5   # 26.5° ↖ moitié basse (droite)
	return INF


# cale le joueur sur la surface d'une pente (montée ou descente)
func _slope_snap() -> void:
	if pvel.y < 0: return    # en montée de saut : ne pas coller
	var sy := _slope_ground(ppos.x + PSIZE.x * 0.5)
	if sy == INF: return
	var feet := ppos.y + PSIZE.y
	if feet >= sy - SLOPE_SNAP_DOWN and feet <= sy + SLOPE_SNAP_UP:
		ppos.y = sy - PSIZE.y
		pvel.y = 0.0
		on_floor = true


# y de sol sous le joueur s'il est sur une pente, sinon INF
func _slope_ground(footx: float) -> float:
	var col := int(footx / CELL)
	var lx := footx - col * CELL
	var foot_row := int((ppos.y + PSIZE.y) / CELL)
	var best := INF
	for dy in [-1, 0, 1]:
		var c := Vector2i(col, foot_row + dy)
		var t: int = grid.get(c, EMPTY)
		if _is_slope(t):
			var sy := _slope_surface(t, c, lx)
			if sy >= c.y * CELL - 2 and sy <= (c.y + 1) * CELL + 2:
				if best == INF or sy < best: best = sy
	return best


func _die() -> void:
	if dead: return
	dead = true; death_t = 0.7
	_emit(ppos + PSIZE * 0.5, 16, Color("ecf0f1"), 260.0, 0.5, true, 4.0)
	_shake(9.0, 0.30)
	Input.start_joy_vibration(0, 0.6, 0.7, 0.30); _play("death")


func _interactions() -> void:
	for c in _cells(Rect2(ppos, PSIZE)):
		match grid.get(c, EMPTY):
			COIN:
				grid.erase(c); coins_got += 1
				_emit(_cell_center(c), 8, COLORS[COIN], 160.0, 0.35, false, 3.0)
				Input.start_joy_vibration(0, 0.25, 0.0, 0.04); _play("coin")
			KEY:
				grid.erase(c); has_key = true
				_emit(_cell_center(c), 10, COLORS[KEY], 180.0, 0.4, false, 3.0)
				_play("key")
			SPIKE:
				_die()
			SPRING:
				if pvel.y >= 0:
					pvel.y = SPRING_V; jbuf = 0.0
					squash = Vector2(0.7, 1.35)
					_emit(_cell_center(c), 8, COLORS[SPRING], 220.0, 0.35, false, 3.0)
					_shake(3.0, 0.1); _play("spring")
			GOAL:
				if not won:
					won = true
					_emit(_cell_center(c), 24, COLORS[GOAL], 240.0, 0.7, false, 4.0)
					_play("win")
	# porte : s'ouvre au contact si on a une clé (consomme la clé)
	if has_key:
		for c in _cells(Rect2(ppos - Vector2(5, 5), PSIZE + Vector2(10, 10))):
			if grid.get(c, EMPTY) == DOOR:
				grid.erase(c); has_key = false
				_emit(_cell_center(c), 14, COLORS[DOOR], 200.0, 0.45, true, 4.0)
				_play("key"); _shake(3.0, 0.1)
				break


# ============================================================= HELPERS
func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c.x * CELL, c.y * CELL), Vector2(CELL, CELL))


func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)


func _cells(r: Rect2) -> Array:
	var out := []
	var x0 := int(floor(r.position.x / CELL)); var x1 := int(floor((r.position.x + r.size.x - 1) / CELL))
	var y0 := int(floor(r.position.y / CELL)); var y1 := int(floor((r.position.y + r.size.y - 1) / CELL))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out.append(Vector2i(x, y))
	return out


func _find(t: int) -> Vector2i:
	for k in grid:
		if grid[k] == t: return k
	return Vector2i(-1, -1)


func _count(t: int) -> int:
	var n := 0
	for k in grid:
		if grid[k] == t: n += 1
	return n


func _w2s(wp: Vector2) -> Vector2:
	return view_origin + wp * view_scale


func _compute_view() -> void:
	var vp := get_viewport_rect().size
	var area := Rect2(0, TOPBAR, vp.x, vp.y - TOPBAR - BOTTOM)
	var lvl := Vector2(cols * CELL, rows * CELL)
	if mode == "play":
		view_scale = 1.0
		view_origin = area.position + area.size * 0.5 - (ppos + PSIZE * 0.5) * view_scale
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


# ============================================================= DRAW
func _draw() -> void:
	var vp := get_viewport_rect().size
	_compute_view()
	var th: Array = BG_THEMES[bg_theme]
	draw_rect(Rect2(Vector2.ZERO, vp), th[0])
	var lvl := Vector2(cols * CELL, rows * CELL)
	draw_rect(Rect2(_w2s(Vector2.ZERO), lvl * view_scale), th[1])

	if mode == "edit" and not dezoom:
		var gcol := Color(1, 1, 1, 0.06)
		for x in range(cols + 1):
			draw_line(_w2s(Vector2(x * CELL, 0)), _w2s(Vector2(x * CELL, rows * CELL)), gcol)
		for y in range(rows + 1):
			draw_line(_w2s(Vector2(0, y * CELL)), _w2s(Vector2(cols * CELL, y * CELL)), gcol)

	for k in grid:
		# en jeu, ennemis et plateformes sont des entités (pas la tuile statique)
		if mode == "play" and (grid[k] == ENEMY or grid[k] == MOVPLAT):
			continue
		_draw_tile(_w2s(Vector2(k.x * CELL, k.y * CELL)), grid[k], view_scale)

	# particules
	for p in particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		var c: Color = p.col; c.a = a
		draw_circle(_w2s(p.pos), p.size * view_scale, c)

	if mode == "edit":
		# sélection en cours
		if sel_mode and sel_anchor != Vector2i(-1, -1):
			var x0 := mini(sel_anchor.x, cursor.x); var y0 := mini(sel_anchor.y, cursor.y)
			var x1 := maxi(sel_anchor.x, cursor.x); var y1 := maxi(sel_anchor.y, cursor.y)
			var rr := Rect2(_w2s(Vector2(x0 * CELL, y0 * CELL)), Vector2((x1 - x0 + 1) * CELL, (y1 - y0 + 1) * CELL) * view_scale)
			draw_rect(rr, Color(0.2, 0.8, 1, 0.18)); draw_rect(rr, Color("3498db"), false, 2.0)
		var cp := _w2s(Vector2(cursor.x * CELL, cursor.y * CELL))
		if not sel_mode:
			_draw_tile(cp, PALETTE[pal], view_scale, 0.45)
		var cc := Color("3498db") if sel_mode else (Color.WHITE if cursor_mode == "rapide" else Color("f39c12"))
		draw_rect(Rect2(cp, Vector2(CELL, CELL) * view_scale), cc, false, 3.0)

	# entités jeu
	if mode == "play":
		for p in plats:
			_draw_tile(_w2s(p.pos), MOVPLAT, view_scale)
		for en in enemies:
			if en.alive:
				_draw_tile(_w2s(en.pos - Vector2(6, 6)), ENEMY, view_scale)
		var ps := PSIZE * squash
		var anchor := _w2s(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y))
		var pr := Rect2(anchor - Vector2(ps.x * 0.5, ps.y) * view_scale, ps * view_scale)
		draw_rect(pr, Color("ffffff")); draw_rect(pr, Color("2c3e50"), false, 2.0)
		if has_key:
			draw_circle(pr.position + Vector2(pr.size.x * 0.5, -8), 5, COLORS[KEY])

	_draw_topbar(vp)
	_draw_hints(vp)
	if radial_open: _draw_radial(vp)
	if menu_open: _draw_menu(vp)
	if toast_t > 0.0: _draw_toast(vp)
	if mode == "play" and (dead or won): _draw_banner(vp)


func _draw_tile(p: Vector2, t: int, scale := 1.0, alpha := 1.0) -> void:
	var col: Color = COLORS.get(t, Color.GRAY); col.a = alpha
	var cs := CELL * scale
	var pad := 3.0 * scale
	match t:
		COIN:
			draw_circle(p + Vector2(cs, cs) * 0.5, cs * 0.3, col)
		KEY:
			draw_circle(p + Vector2(cs * 0.4, cs * 0.4), cs * 0.18, col)
			draw_rect(Rect2(p + Vector2(cs * 0.4, cs * 0.4), Vector2(cs * 0.32, cs * 0.1)), col)
		ENEMY:
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(cs * 0.5, pad), p + Vector2(cs - pad, cs - pad), p + Vector2(pad, cs - pad)]), col)
		SPIKE:
			for i in 3:
				var bx := p.x + pad + i * (cs - pad * 2) / 3.0
				var bw := (cs - pad * 2) / 3.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(bx, p.y + cs - pad), Vector2(bx + bw * 0.5, p.y + pad), Vector2(bx + bw, p.y + cs - pad)]), col)
		SPRING:
			draw_rect(Rect2(p + Vector2(pad, cs * 0.55), Vector2(cs - pad * 2, cs * 0.45 - pad)), col)
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(cs * 0.5, pad), p + Vector2(cs * 0.75, cs * 0.5), p + Vector2(cs * 0.25, cs * 0.5)]), col.lightened(0.2))
		GOAL:
			draw_rect(Rect2(p + Vector2(cs * 0.4, pad), Vector2(4 * scale, cs - pad * 2)), col)
			draw_rect(Rect2(p + Vector2(cs * 0.4 + 4 * scale, pad), Vector2(cs * 0.4, cs * 0.3)), col)
		CHECKPOINT:
			draw_rect(Rect2(p + Vector2(cs * 0.4, pad), Vector2(4 * scale, cs - pad * 2)), col)
			draw_rect(Rect2(p + Vector2(cs * 0.4 + 4 * scale, pad), Vector2(cs * 0.35, cs * 0.28)), col)
		SPAWN:
			draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col, false, 3.0)
		DOOR:
			draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad)), col)
			draw_circle(p + Vector2(cs * 0.72, cs * 0.5), cs * 0.06, Color("f1c40f"))
		MOVPLAT:
			draw_rect(Rect2(p + Vector2(0, cs * 0.2), Vector2(cs, cs * 0.35)), col)
		GROUND:
			draw_rect(Rect2(p, Vector2(cs, cs)), col)
			var top: Color = col.lightened(0.12); top.a = col.a
			draw_rect(Rect2(p, Vector2(cs, max(2.0, cs * 0.10))), top)
		BREAKABLE:
			draw_rect(Rect2(p, Vector2(cs, cs)), col)
			draw_line(p + Vector2(0, cs * 0.5), p + Vector2(cs, cs * 0.5), col.darkened(0.3), 1.5)
			draw_line(p + Vector2(cs * 0.5, 0), p + Vector2(cs * 0.5, cs), col.darkened(0.3), 1.5)
		SLOPE_R:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, cs), p + Vector2(cs, cs), p + Vector2(cs, 0)]), col)
		SLOPE_L:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, 0), p + Vector2(0, cs), p + Vector2(cs, cs)]), col)
		GSL_R_LO:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, cs), p + Vector2(cs, cs), p + Vector2(cs, cs * 0.5)]), col)
		GSL_R_HI:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, cs), p + Vector2(cs, cs), p + Vector2(cs, 0), p + Vector2(0, cs * 0.5)]), col)
		GSL_L_HI:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, 0), p + Vector2(0, cs), p + Vector2(cs, cs), p + Vector2(cs, cs * 0.5)]), col)
		GSL_L_LO:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, cs * 0.5), p + Vector2(0, cs), p + Vector2(cs, cs)]), col)
		_:
			draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col)


func _draw_topbar(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, TOPBAR)), Color("11161f"))
	var f := ThemeDB.fallback_font
	if mode == "edit":
		_text(f, Vector2(12, 32), "FORGE", Color("f39c12"), 20)
		var x := 96.0
		for i in PALETTE.size():
			var box := Rect2(Vector2(x, 9), Vector2(34, 34))
			draw_rect(box, Color("223349"))
			_draw_tile(Vector2(x, 9), PALETTE[i], 34.0 / CELL)
			if i == pal: draw_rect(box, Color.WHITE, false, 3.0)
			x += 44
		_text(f, Vector2(x + 8, 22), NAMES[PALETTE[pal]], Color("f39c12"), 14)
		_text(f, Vector2(x + 8, 42), "Curseur: %s" % cursor_mode, Color(1, 1, 1, 0.6), 12)
	else:
		_text(f, Vector2(16, 34), "FORGE — TEST", Color("2ecc71"), 22)
		_text(f, Vector2(240, 34), "Pièces: %d/%d" % [coins_got, coins_total], Color("f1c40f"), 20)
		if has_key: _text(f, Vector2(430, 34), "🔑", Color("f1c40f"), 20)


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
	var n := PALETTE.size()
	for i in n:
		var ang := -PI / 2.0 + i * TAU / n
		var p := c + Vector2(cos(ang), sin(ang)) * rad
		var sel: bool = i == radial_pick
		var box := Rect2(p - Vector2(22, 22), Vector2(44, 44))
		draw_rect(box, Color("223349"))
		_draw_tile(p - Vector2(22, 22), PALETTE[i], 44.0 / CELL)
		if sel:
			draw_rect(box, Color.WHITE, false, 4.0)
			_text(f, c + Vector2(-NAMES[PALETTE[i]].length() * 4.0, 5), NAMES[PALETTE[i]], Color.WHITE, 16)


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
	var msg := "GAGNÉ !" if won else ""
	if not won: return
	var col := Color("2ecc71")
	var box := Rect2(vp * 0.5 - Vector2(200, 70), Vector2(400, 140))
	draw_rect(box, Color(0, 0, 0, 0.7)); draw_rect(box, col, false, 3.0)
	_text(f, vp * 0.5 - Vector2(80, 10), msg, col, 40)
	_text(f, vp * 0.5 + Vector2(-130, 40), "Y: Rejouer   Start/B: Éditeur", Color.WHITE, 16)


func _text(f: Font, pos: Vector2, s: String, col: Color, size: int) -> void:
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
