extends Node2D
# SPARK FORGE — Lite 2D (plateformer), manette-first.
# A. Éditeur pad : peinture/effacement continus, menu radial, curseur accéléré, undo/redo, dézoom.
# B. Game feel : coyote time, jump buffer, saut variable, accél/friction, deadzone.
# C. Confort : glyphes manette, vibration, test depuis curseur, modes curseur précis/rapide.

const CELL := 48
const TOPBAR := 52
const BOTTOM := 34
const LEVEL_COLS := 40
const PSIZE := Vector2(36, 36)

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

# curseur
const CURSOR_DELAY := 0.25
const RATE_SLOW := 0.12
const RATE_FAST := 0.035

enum { EMPTY, GROUND, SPAWN, COIN, ENEMY, GOAL }
const PALETTE := [GROUND, SPAWN, COIN, ENEMY, GOAL]
const NAMES := { GROUND: "Sol", SPAWN: "Spawn", COIN: "Pièce", ENEMY: "Ennemi", GOAL: "Arrivée" }
const COLORS := {
	GROUND: Color("6b4a2b"), SPAWN: Color("2ecc71"), COIN: Color("f1c40f"),
	ENEMY: Color("e74c3c"), GOAL: Color("3498db")
}

# état éditeur
var grid := {}
var cols := LEVEL_COLS
var rows := 14
var cursor := Vector2i(4, 8)
var pal := 0
var mode := "edit"
var cursor_cd := 0.0
var hold_time := 0.0
var last_dir := Vector2i.ZERO
var cursor_mode := "rapide"      # "rapide" (accél) | "précis"
var place_held := false
var erase_held := false

# undo / redo
var undo_stack := []
var redo_stack := []

# menu radial
var radial_open := false
var radial_pick := 0

# vue / caméra / zoom
var view_origin := Vector2.ZERO
var view_scale := 1.0
var dezoom := false

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
var spawn_cell := Vector2i(4, 8)
var last_from_cursor := false


func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	_compute_grid()
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
	grid[Vector2i(14, rows - 2)] = ENEMY
	grid[Vector2i(cols - 2, rows - 2)] = GOAL
	cursor = Vector2i(4, rows - 3)


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
	if mode == "edit":
		# A3 : ne pas agir tant que le menu radial est ouvert (sélection au stick)
		# place / erase continus (held)
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
		elif _press(e, [KEY_BACKSPACE], [JOY_BUTTON_BACK]):
			_push_undo(); _seed_demo(); queue_redraw()
		elif e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_5:
			pal = clampi(e.keycode - KEY_1, 0, PALETTE.size() - 1); queue_redraw()
	else:
		if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
			if not dead and not won: jbuf = JUMP_BUFFER
		elif _is_btn(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A], false):
			if pvel.y < 0: pvel.y *= JUMP_CUT     # B2 saut variable
		elif _press(e, [KEY_TAB], [JOY_BUTTON_START, JOY_BUTTON_B]):
			mode = "edit"; Input.stop_joy_vibration(0); queue_redraw()
		elif _press(e, [KEY_R], [JOY_BUTTON_Y]):
			_start_play(last_from_cursor)


func _begin_stroke(place: bool) -> void:
	_push_undo()
	if place:
		place_held = true
		grid[cursor] = PALETTE[pal]
	else:
		erase_held = true
		grid.erase(cursor)
	queue_redraw()


func _cycle(dir: int) -> void:
	pal = (pal + dir + PALETTE.size()) % PALETTE.size()
	queue_redraw()


func _toggle_cursor_mode() -> void:
	cursor_mode = "précis" if cursor_mode == "rapide" else "rapide"
	queue_redraw()


# A5 : undo / redo
func _push_undo() -> void:
	undo_stack.append(grid.duplicate())
	if undo_stack.size() > 60: undo_stack.pop_front()
	redo_stack.clear()


func _undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(grid.duplicate())
	grid = undo_stack.pop_back()
	queue_redraw()


func _redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(grid.duplicate())
	grid = redo_stack.pop_back()
	queue_redraw()


func _dir_held() -> Vector2i:
	var v := Vector2i.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP): v.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN): v.y += 1
	var ax := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ay := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(ax) > DEADZONE: v.x += signi(int(signf(ax)))
	if absf(ay) > DEADZONE: v.y += signi(int(signf(ay)))
	return Vector2i(clampi(v.x, -1, 1), clampi(v.y, -1, 1))


func _stick() -> Vector2:
	var s := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	return s if s.length() > DEADZONE else Vector2.ZERO


# ============================================================= EDIT LOOP
func _process(delta: float) -> void:
	if mode != "edit":
		return
	# A6 : dézoom (maintien R2 / Shift)
	var peek := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5 or Input.is_key_pressed(KEY_SHIFT)
	if peek != dezoom:
		dezoom = peek; queue_redraw()
	# A3 : menu radial (maintien L2)
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
			radial_pick = int(round((ang + PI / 2.0) / (TAU / n))) % n
			radial_pick = (radial_pick + n) % n
		queue_redraw()
		return   # stick = sélection, pas déplacement curseur

	# A4 : déplacement curseur (accéléré en mode rapide)
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
			if cursor_mode == "précis":
				cursor_cd = RATE_SLOW
			else:
				cursor_cd = lerpf(RATE_SLOW, RATE_FAST, clampf(hold_time / 0.6, 0.0, 1.0))

	# A1/A2 : peinture / effacement continus
	if place_held:
		if grid.get(cursor, EMPTY) != PALETTE[pal]:
			grid[cursor] = PALETTE[pal]; queue_redraw()
	elif erase_held:
		if grid.has(cursor):
			grid.erase(cursor); queue_redraw()


func _move_cursor(d: Vector2i) -> void:
	cursor.x = clampi(cursor.x + d.x, 0, cols - 1)
	cursor.y = clampi(cursor.y + d.y, 0, rows - 1)
	queue_redraw()


# ============================================================= PLAY LOOP
func _start_play(from_cursor: bool) -> void:
	last_from_cursor = from_cursor
	if from_cursor:
		spawn_cell = cursor
	else:
		spawn_cell = _find(SPAWN)
		if spawn_cell == Vector2i(-1, -1): spawn_cell = cursor
	coins_total = _count(COIN)
	coins_got = 0
	dead = false
	won = false
	on_floor = false
	was_floor = false
	coyote_t = 0.0
	jbuf = 0.0
	ppos = Vector2(spawn_cell.x * CELL + (CELL - PSIZE.x) * 0.5, spawn_cell.y * CELL + (CELL - PSIZE.y))
	pvel = Vector2.ZERO
	mode = "play"
	queue_redraw()


func _physics_process(delta: float) -> void:
	if mode != "play" or dead or won:
		return
	var dir := _dir_held()

	# B3 : accél / friction + contrôle en l'air
	var target := dir.x * SPEED
	if dir.x != 0:
		pvel.x = move_toward(pvel.x, target, (ACCEL_GROUND if on_floor else ACCEL_AIR) * delta)
	else:
		pvel.x = move_toward(pvel.x, 0.0, (FRICTION if on_floor else ACCEL_AIR) * delta)

	# B1 : coyote + jump buffer
	coyote_t -= delta
	jbuf -= delta
	if jbuf > 0.0 and (on_floor or coyote_t > 0.0):
		pvel.y = JUMP_V
		jbuf = 0.0
		coyote_t = 0.0
		on_floor = false
		Input.start_joy_vibration(0, 0.10, 0.25, 0.07)   # C2

	pvel.y = min(pvel.y + GRAVITY * delta, MAX_FALL)

	# X
	ppos.x += pvel.x * delta
	for c in _solids():
		var r := _cell_rect(c)
		if pvel.x > 0: ppos.x = r.position.x - PSIZE.x
		elif pvel.x < 0: ppos.x = r.position.x + CELL
		pvel.x = 0
	ppos.x = clampf(ppos.x, 0, cols * CELL - PSIZE.x)

	# Y
	was_floor = on_floor
	on_floor = false
	ppos.y += pvel.y * delta
	for c in _solids():
		var r := _cell_rect(c)
		if pvel.y > 0:
			ppos.y = r.position.y - PSIZE.y; on_floor = true
		elif pvel.y < 0:
			ppos.y = r.position.y + CELL
		pvel.y = 0

	if on_floor: coyote_t = COYOTE
	if on_floor and not was_floor:
		Input.start_joy_vibration(0, 0.0, 0.35, 0.05)    # C2 atterrissage

	if ppos.y > rows * CELL + 200: _die()
	_interactions()
	queue_redraw()


func _die() -> void:
	dead = true
	Input.start_joy_vibration(0, 0.6, 0.7, 0.30)


func _interactions() -> void:
	for c in _cells(Rect2(ppos, PSIZE)):
		match grid.get(c, EMPTY):
			COIN:
				grid.erase(c); coins_got += 1
				Input.start_joy_vibration(0, 0.25, 0.0, 0.04)
			ENEMY:
				_die()
			GOAL:
				won = true
				Input.start_joy_vibration(0, 0.3, 0.5, 0.30)


# ============================================================= HELPERS
func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c.x * CELL, c.y * CELL), Vector2(CELL, CELL))


func _cells(r: Rect2) -> Array:
	var out := []
	var x0 := int(floor(r.position.x / CELL)); var x1 := int(floor((r.position.x + r.size.x - 1) / CELL))
	var y0 := int(floor(r.position.y / CELL)); var y1 := int(floor((r.position.y + r.size.y - 1) / CELL))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out.append(Vector2i(x, y))
	return out


func _solids() -> Array:
	var out := []
	for c in _cells(Rect2(ppos, PSIZE)):
		if grid.get(c, EMPTY) == GROUND: out.append(c)
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


# vue : monde -> écran (zoom + caméra)
func _w2s(wp: Vector2) -> Vector2:
	return view_origin + wp * view_scale


func _compute_view() -> void:
	var vp := get_viewport_rect().size
	var area := Rect2(0, TOPBAR, vp.x, vp.y - TOPBAR - BOTTOM)
	var lvl := Vector2(cols * CELL, rows * CELL)
	if mode == "play":
		view_scale = 1.0
		var target := ppos + PSIZE * 0.5
		view_origin = area.position + area.size * 0.5 - target * view_scale
	elif dezoom:
		view_scale = min(area.size.x / lvl.x, area.size.y / lvl.y) * 0.96
		view_origin = area.position
	else:
		view_scale = 1.0
		var tc := (Vector2(cursor) + Vector2(0.5, 0.5)) * CELL
		view_origin = area.position + area.size * 0.5 - tc * view_scale
	# clamp caméra aux bords du niveau
	var sw := lvl.x * view_scale; var sh := lvl.y * view_scale
	if sw <= area.size.x:
		view_origin.x = area.position.x + (area.size.x - sw) * 0.5
	else:
		view_origin.x = clampf(view_origin.x, area.position.x + area.size.x - sw, area.position.x)
	if sh <= area.size.y:
		view_origin.y = area.position.y + (area.size.y - sh) * 0.5
	else:
		view_origin.y = clampf(view_origin.y, area.position.y + area.size.y - sh, area.position.y)


# ============================================================= DRAW
func _draw() -> void:
	var vp := get_viewport_rect().size
	_compute_view()
	draw_rect(Rect2(Vector2.ZERO, vp), Color("1b2838"))
	# fond niveau
	var lvl := Vector2(cols * CELL, rows * CELL)
	draw_rect(Rect2(_w2s(Vector2.ZERO), lvl * view_scale), Color("223349"))

	if mode == "edit" and not dezoom:
		var gcol := Color(1, 1, 1, 0.06)
		for x in range(cols + 1):
			draw_line(_w2s(Vector2(x * CELL, 0)), _w2s(Vector2(x * CELL, rows * CELL)), gcol)
		for y in range(rows + 1):
			draw_line(_w2s(Vector2(0, y * CELL)), _w2s(Vector2(cols * CELL, y * CELL)), gcol)

	for k in grid:
		_draw_tile(_w2s(Vector2(k.x * CELL, k.y * CELL)), grid[k], view_scale)

	if mode == "edit":
		var cp := _w2s(Vector2(cursor.x * CELL, cursor.y * CELL))
		_draw_tile(cp, PALETTE[pal], view_scale, 0.45)
		var cc := Color.WHITE if cursor_mode == "rapide" else Color("f39c12")
		draw_rect(Rect2(cp, Vector2(CELL, CELL) * view_scale), cc, false, 3.0)

	if mode == "play":
		var pr := Rect2(_w2s(ppos), PSIZE * view_scale)
		draw_rect(pr, Color("ffffff"))
		draw_rect(pr, Color("2c3e50"), false, 2.0)

	_draw_topbar(vp)
	_draw_hints(vp)
	if radial_open: _draw_radial(vp)
	if mode == "play" and (dead or won): _draw_banner(vp)


func _draw_tile(p: Vector2, t: int, scale := 1.0, alpha := 1.0) -> void:
	var col: Color = COLORS.get(t, Color.GRAY)
	col.a = alpha
	var cs := CELL * scale
	var pad := 3.0 * scale
	match t:
		COIN:
			draw_circle(p + Vector2(cs, cs) * 0.5, cs * 0.3, col)
		ENEMY:
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(cs * 0.5, pad), p + Vector2(cs - pad, cs - pad), p + Vector2(pad, cs - pad)]), col)
		GOAL:
			draw_rect(Rect2(p + Vector2(cs * 0.4, pad), Vector2(4 * scale, cs - pad * 2)), col)
			draw_rect(Rect2(p + Vector2(cs * 0.4 + 4 * scale, pad), Vector2(cs * 0.4, cs * 0.3)), col)
		SPAWN:
			draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col, false, 3.0)
		GROUND:
			# cellule pleine (terrain uni, pas de trous entre blocs) + liseré haut subtil
			draw_rect(Rect2(p, Vector2(cs, cs)), col)
			var top := col.lightened(0.12)
			top.a = col.a
			draw_rect(Rect2(p, Vector2(cs, max(2.0, cs * 0.10))), top)
		_:
			draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col)


func _draw_topbar(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, TOPBAR)), Color("11161f"))
	var f := ThemeDB.fallback_font
	if mode == "edit":
		_text(f, Vector2(16, 34), "FORGE — ÉDITION", Color("f39c12"), 22)
		var x := 300.0
		for i in PALETTE.size():
			var box := Rect2(Vector2(x, 9), Vector2(34, 34))
			draw_rect(box, Color("223349"))
			_draw_tile(Vector2(x, 9), PALETTE[i], 34.0 / CELL)
			if i == pal: draw_rect(box, Color.WHITE, false, 3.0)
			x += 60
		_text(f, Vector2(x + 12, 22), "Curseur: %s" % cursor_mode.to_upper(),
			Color("f39c12") if cursor_mode == "précis" else Color(1, 1, 1, 0.7), 14)
		if dezoom: _text(f, Vector2(x + 12, 42), "VUE D'ENSEMBLE", Color("3498db"), 14)
	else:
		_text(f, Vector2(16, 34), "FORGE — TEST", Color("2ecc71"), 22)
		_text(f, Vector2(240, 34), "Pièces: %d / %d" % [coins_got, coins_total], Color("f1c40f"), 20)


# C1 : glyphes manette contextuels
func _draw_hints(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2(0, vp.y - BOTTOM), Vector2(vp.x, BOTTOM)), Color("11161f"))
	var x := 12.0
	var y := vp.y - BOTTOM + 6.0
	if mode == "edit":
		x = _badge(x, y, "A", "Placer (maintenir)")
		x = _badge(x, y, "B", "Effacer (maintenir)")
		x = _badge(x, y, "L2", "Palette")
		x = _badge(x, y, "X", "Annuler")
		x = _badge(x, y, "Y", "Refaire")
		x = _badge(x, y, "R2", "Vue")
		x = _badge(x, y, "L3", "Curseur")
		x = _badge(x, y, "R3", "Test ici")
		x = _badge(x, y, "ST", "Tester")
	else:
		x = _badge(x, y, "←→", "Bouger")
		x = _badge(x, y, "A", "Sauter (var.)")
		x = _badge(x, y, "Y", "Rejouer")
		x = _badge(x, y, "ST", "Éditeur")


func _badge(x: float, y: float, glyph: String, label: String) -> float:
	var f := ThemeDB.fallback_font
	var gw := 26.0
	draw_rect(Rect2(Vector2(x, y), Vector2(gw, 22)), Color("2c3e50"), true)
	draw_rect(Rect2(Vector2(x, y), Vector2(gw, 22)), Color("f39c12"), false, 1.5)
	_text(f, Vector2(x + 4, y + 16), glyph, Color.WHITE, 12)
	_text(f, Vector2(x + gw + 5, y + 16), label, Color(1, 1, 1, 0.7), 12)
	return x + gw + 6 + label.length() * 6.5 + 16


# A3 : menu radial
func _draw_radial(vp: Vector2) -> void:
	var c := vp * 0.5
	var rad := 120.0
	draw_circle(c, rad + 40, Color(0, 0, 0, 0.55))
	var f := ThemeDB.fallback_font
	var n := PALETTE.size()
	for i in n:
		var ang := -PI / 2.0 + i * TAU / n
		var p := c + Vector2(cos(ang), sin(ang)) * rad
		var sel: bool = i == radial_pick
		var box := Rect2(p - Vector2(24, 24), Vector2(48, 48))
		draw_rect(box, Color("223349"))
		_draw_tile(p - Vector2(24, 24), PALETTE[i], 48.0 / CELL)
		if sel: draw_rect(box, Color.WHITE, false, 4.0)
		_text(f, p + Vector2(-NAMES[PALETTE[i]].length() * 3.5, 44), NAMES[PALETTE[i]],
			Color.WHITE if sel else Color(1, 1, 1, 0.6), 13)
	_text(f, c + Vector2(-70, 4), "Stick → choisir", Color(1, 1, 1, 0.8), 14)


func _draw_banner(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var msg := "GAGNÉ !" if won else "PERDU"
	var col := Color("2ecc71") if won else Color("e74c3c")
	var box := Rect2(vp * 0.5 - Vector2(200, 70), Vector2(400, 140))
	draw_rect(box, Color(0, 0, 0, 0.7))
	draw_rect(box, col, false, 3.0)
	_text(f, vp * 0.5 - Vector2(80, 10), msg, col, 40)
	_text(f, vp * 0.5 + Vector2(-130, 40), "Y: Rejouer   Start/B: Éditeur", Color.WHITE, 16)


func _text(f: Font, pos: Vector2, s: String, col: Color, size: int) -> void:
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
