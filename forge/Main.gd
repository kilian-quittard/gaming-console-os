extends Node2D
# SPARK FORGE — Lite 2D prototype.
# Éditeur de plateformer à la Mario Maker, manette-first (clavier en fallback).
# Édite : pose des tuiles. Test : joue ton niveau (gravité, saut, pièces, ennemis, arrivée).

const CELL := 48
const TOPBAR := 56          # barre d'info en haut (px)
const PSIZE := Vector2(36, 36)   # taille du joueur
const GRAVITY := 1800.0
const SPEED := 320.0
const JUMP_V := -640.0
const CURSOR_DELAY := 0.28  # délai avant répétition
const CURSOR_RATE := 0.07   # vitesse de répétition

enum { EMPTY, GROUND, SPAWN, COIN, ENEMY, GOAL }
const PALETTE := [GROUND, SPAWN, COIN, ENEMY, GOAL]
const NAMES := {
	GROUND: "Sol", SPAWN: "Spawn", COIN: "Pièce", ENEMY: "Ennemi", GOAL: "Arrivée"
}
const COLORS := {
	GROUND: Color("6b4a2b"), SPAWN: Color("2ecc71"), COIN: Color("f1c40f"),
	ENEMY: Color("e74c3c"), GOAL: Color("3498db")
}

var grid := {}                # Vector2i -> type
var cols := 26
var rows := 14
var cursor := Vector2i(4, 8)
var pal := 0                  # index dans PALETTE
var mode := "edit"            # "edit" | "play"
var cursor_cd := 0.0
var last_dir := Vector2i.ZERO

# état du mode jeu
var ppos := Vector2.ZERO
var pvel := Vector2.ZERO
var on_floor := false
var coins_got := 0
var coins_total := 0
var dead := false
var won := false
var spawn_cell := Vector2i(4, 8)


func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	_compute_grid()
	_seed_demo()
	queue_redraw()


func _compute_grid() -> void:
	var vp := get_viewport_rect().size
	cols = int((vp.x) / CELL)
	rows = int((vp.y - TOPBAR) / CELL)


func _seed_demo() -> void:
	# petit niveau de départ pour montrer le principe
	grid.clear()
	for x in range(0, cols):
		grid[Vector2i(x, rows - 1)] = GROUND      # sol bas
	for x in range(8, 12):
		grid[Vector2i(x, rows - 4)] = GROUND      # plateforme
	grid[Vector2i(2, rows - 2)] = SPAWN
	grid[Vector2i(9, rows - 5)] = COIN
	grid[Vector2i(10, rows - 5)] = COIN
	grid[Vector2i(15, rows - 2)] = ENEMY
	grid[Vector2i(cols - 2, rows - 2)] = GOAL
	cursor = Vector2i(4, rows - 3)


# ---------------------------------------------------------------- input
func _unhandled_input(e: InputEvent) -> void:
	if mode == "edit":
		if _pressed(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
			grid[cursor] = PALETTE[pal]; queue_redraw()
		elif _pressed(e, [KEY_DELETE, KEY_X], [JOY_BUTTON_B]):
			grid.erase(cursor); queue_redraw()
		elif _pressed(e, [KEY_A], [JOY_BUTTON_LEFT_SHOULDER]):
			pal = (pal - 1 + PALETTE.size()) % PALETTE.size(); queue_redraw()
		elif _pressed(e, [KEY_E], [JOY_BUTTON_RIGHT_SHOULDER]):
			pal = (pal + 1) % PALETTE.size(); queue_redraw()
		elif _pressed(e, [KEY_BACKSPACE], [JOY_BUTTON_BACK]):
			_seed_demo(); queue_redraw()
		elif _pressed(e, [KEY_TAB], [JOY_BUTTON_START]):
			_start_play()
	else: # play
		if _pressed(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
			if on_floor and not dead and not won:
				pvel.y = JUMP_V
		elif _pressed(e, [KEY_TAB], [JOY_BUTTON_START, JOY_BUTTON_B]):
			mode = "edit"; queue_redraw()
		elif _pressed(e, [KEY_R], [JOY_BUTTON_Y]):
			_start_play()  # rejouer


func _pressed(e: InputEvent, keys: Array, btns: Array) -> bool:
	if e is InputEventKey and e.pressed and not e.echo:
		return keys.has(e.keycode)
	if e is InputEventJoypadButton and e.pressed:
		return btns.has(e.button_index)
	return false


func _dir_held() -> Vector2i:
	var v := Vector2i.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP): v.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN): v.y += 1
	var ax := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ay := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if ax < -0.5: v.x -= 1
	elif ax > 0.5: v.x += 1
	if ay < -0.5: v.y -= 1
	elif ay > 0.5: v.y += 1
	return Vector2i(clampi(v.x, -1, 1), clampi(v.y, -1, 1))


# ---------------------------------------------------------------- edit loop
func _process(delta: float) -> void:
	if mode != "edit":
		return
	var d := _dir_held()
	if d == Vector2i.ZERO:
		cursor_cd = 0.0
		last_dir = Vector2i.ZERO
		return
	cursor_cd -= delta
	if d != last_dir:
		_move_cursor(d)
		cursor_cd = CURSOR_DELAY
		last_dir = d
	elif cursor_cd <= 0.0:
		_move_cursor(d)
		cursor_cd = CURSOR_RATE


func _move_cursor(d: Vector2i) -> void:
	cursor.x = clampi(cursor.x + d.x, 0, cols - 1)
	cursor.y = clampi(cursor.y + d.y, 0, rows - 1)
	queue_redraw()


# ---------------------------------------------------------------- play loop
func _start_play() -> void:
	spawn_cell = _find(SPAWN)
	if spawn_cell == Vector2i(-1, -1):
		spawn_cell = Vector2i(2, rows - 2)
	coins_total = _count(COIN)
	coins_got = 0
	dead = false
	won = false
	ppos = Vector2(spawn_cell.x * CELL + (CELL - PSIZE.x) * 0.5,
				   spawn_cell.y * CELL + (CELL - PSIZE.y))
	pvel = Vector2.ZERO
	on_floor = false
	mode = "play"
	queue_redraw()


func _physics_process(delta: float) -> void:
	if mode != "play" or dead or won:
		return
	var dir := _dir_held()
	pvel.x = dir.x * SPEED
	pvel.y += GRAVITY * delta
	pvel.y = clampf(pvel.y, JUMP_V, 1200.0)

	# X
	ppos.x += pvel.x * delta
	for c in _solids_overlapping():
		var r := _cell_rect(c)
		if pvel.x > 0: ppos.x = r.position.x - PSIZE.x
		elif pvel.x < 0: ppos.x = r.position.x + CELL
		pvel.x = 0
	ppos.x = clampf(ppos.x, 0, cols * CELL - PSIZE.x)

	# Y
	on_floor = false
	ppos.y += pvel.y * delta
	for c in _solids_overlapping():
		var r := _cell_rect(c)
		if pvel.y > 0:
			ppos.y = r.position.y - PSIZE.y
			on_floor = true
		elif pvel.y < 0:
			ppos.y = r.position.y + CELL
		pvel.y = 0

	# chute hors écran = mort
	if ppos.y > rows * CELL + 200:
		dead = true

	_check_interactions()
	queue_redraw()


func _check_interactions() -> void:
	var pr := Rect2(ppos, PSIZE)
	for c in _cells_overlapping(pr):
		match grid.get(c, EMPTY):
			COIN:
				grid.erase(c); coins_got += 1
			ENEMY:
				dead = true
			GOAL:
				won = true


# ---------------------------------------------------------------- helpers
func _world_off() -> Vector2:
	return Vector2(0, TOPBAR)


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c.x * CELL, c.y * CELL), Vector2(CELL, CELL))


func _cells_overlapping(r: Rect2) -> Array:
	var out := []
	var x0 := int(floor(r.position.x / CELL))
	var x1 := int(floor((r.position.x + r.size.x - 1) / CELL))
	var y0 := int(floor(r.position.y / CELL))
	var y1 := int(floor((r.position.y + r.size.y - 1) / CELL))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out.append(Vector2i(x, y))
	return out


func _solids_overlapping() -> Array:
	var out := []
	for c in _cells_overlapping(Rect2(ppos, PSIZE)):
		if grid.get(c, EMPTY) == GROUND:
			out.append(c)
	return out


func _find(t: int) -> Vector2i:
	for k in grid:
		if grid[k] == t:
			return k
	return Vector2i(-1, -1)


func _count(t: int) -> int:
	var n := 0
	for k in grid:
		if grid[k] == t: n += 1
	return n


# ---------------------------------------------------------------- draw
func _draw() -> void:
	var vp := get_viewport_rect().size
	# fond
	draw_rect(Rect2(Vector2.ZERO, vp), Color("1b2838"))
	var off := _world_off()
	# zone de jeu
	draw_rect(Rect2(off, Vector2(cols * CELL, rows * CELL)), Color("223349"))

	# grille (édition)
	if mode == "edit":
		var gcol := Color(1, 1, 1, 0.06)
		for x in range(cols + 1):
			draw_line(off + Vector2(x * CELL, 0), off + Vector2(x * CELL, rows * CELL), gcol)
		for y in range(rows + 1):
			draw_line(off + Vector2(0, y * CELL), off + Vector2(cols * CELL, y * CELL), gcol)

	# tuiles
	for k in grid:
		_draw_tile(off + Vector2(k.x * CELL, k.y * CELL), grid[k])

	# curseur (édition)
	if mode == "edit":
		var cp := off + Vector2(cursor.x * CELL, cursor.y * CELL)
		_draw_tile(cp, PALETTE[pal], 0.45)  # aperçu translucide
		draw_rect(Rect2(cp, Vector2(CELL, CELL)), Color.WHITE, false, 3.0)

	# joueur (jeu)
	if mode == "play":
		draw_rect(Rect2(off + ppos, PSIZE), Color("ffffff"))
		draw_rect(Rect2(off + ppos, PSIZE), Color("2c3e50"), false, 2.0)

	_draw_topbar(vp)
	if mode == "play" and (dead or won):
		_draw_banner(vp)


func _draw_tile(p: Vector2, t: int, alpha := 1.0) -> void:
	var col: Color = COLORS.get(t, Color.GRAY)
	col.a = alpha
	var pad := 3.0
	match t:
		COIN:
			draw_circle(p + Vector2(CELL, CELL) * 0.5, CELL * 0.3, col)
		ENEMY:
			var pts := PackedVector2Array([
				p + Vector2(CELL * 0.5, pad), p + Vector2(CELL - pad, CELL - pad),
				p + Vector2(pad, CELL - pad)])
			draw_colored_polygon(pts, col)
		GOAL:
			draw_rect(Rect2(p + Vector2(CELL * 0.4, pad), Vector2(4, CELL - pad * 2)), col)
			draw_rect(Rect2(p + Vector2(CELL * 0.4 + 4, pad), Vector2(CELL * 0.4, CELL * 0.3)), col)
		SPAWN:
			draw_rect(Rect2(p + Vector2(pad, pad), Vector2(CELL - pad * 2, CELL - pad * 2)), col, false, 3.0)
		_:
			draw_rect(Rect2(p + Vector2(pad, pad), Vector2(CELL - pad * 2, CELL - pad * 2)), col)


func _draw_topbar(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, TOPBAR)), Color("11161f"))
	var f := ThemeDB.fallback_font
	if mode == "edit":
		_text(f, Vector2(16, 36), "FORGE — ÉDITION", Color("f39c12"), 22)
		# palette
		var x := 320.0
		for i in PALETTE.size():
			var sel: bool = i == pal
			var box := Rect2(Vector2(x, 12), Vector2(34, 34))
			draw_rect(box, Color("223349"))
			_draw_tile(Vector2(x, 12), PALETTE[i])
			if sel:
				draw_rect(box, Color.WHITE, false, 3.0)
			_text(f, Vector2(x - 2, 54), NAMES[PALETTE[i]], Color(1, 1, 1, 0.7 if not sel else 1.0), 12)
			x += 110
		_text(f, Vector2(vp.x - 470, 24), "A: Placer   X/B: Effacer   L/R: Tuile", Color(1, 1, 1, 0.75), 14)
		_text(f, Vector2(vp.x - 470, 46), "Start: Tester   Select: Reset", Color(1, 1, 1, 0.75), 14)
	else:
		_text(f, Vector2(16, 36), "FORGE — TEST", Color("2ecc71"), 22)
		_text(f, Vector2(260, 36), "Pièces: %d / %d" % [coins_got, coins_total], Color("f1c40f"), 20)
		_text(f, Vector2(vp.x - 360, 24), "Stick/D-pad: bouger   A: Sauter", Color(1, 1, 1, 0.75), 14)
		_text(f, Vector2(vp.x - 360, 46), "Start/B: Éditeur   Y: Rejouer", Color(1, 1, 1, 0.75), 14)


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
