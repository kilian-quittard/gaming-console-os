extends Node2D
class_name PlatformerTemplate
# Template PLATEFORMER : données de tuiles + simulation de jeu + rendu du monde.

signal player_died     # émis au début de la mort (avant le timer de respawn)
signal level_won       # émis quand le joueur touche l'arrivée
signal coin_collected  # émis à chaque pièce ramassée
# Le personnage est piloté par une machine XSM (StateRegions : Locomotion + Air),
# voir scenes/.../PlatformerPlay.tscn et les états dans states/.
# Le noeud est dessiné DERRIÈRE ForgeApp (show_behind_parent) : il rend le monde,
# ForgeApp rend le chrome par-dessus.

const CELL := 48

# --- tuiles (sémantique du genre) ---
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

# --- physique ---
const PSIZE := Vector2(36, 36)
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
const SLOPE_SNAP_UP := 22.0
const SLOPE_SNAP_DOWN := 16.0

var app: Node = null                    # ForgeApp (grille, vue, fx, audio)
@onready var player_sm := $PlayerSM      # XSM (StateRegions)

# état jeu
var ppos := Vector2.ZERO
var pvel := Vector2.ZERO
var input_x := 0
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
var enemies := []
var plats := []
var testing := false
var test_dir := 0


func _ready() -> void:
	show_behind_parent = true
	# XSM piloté manuellement par ce noeud (ordre maîtrisé)
	if player_sm:
		player_sm.set_physics_process(false)


func setup(forge_app: Node) -> void:
	app = forge_app


# =================================================== données / seed
func palette() -> Array: return PALETTE
func tile_name(t: int) -> String: return NAMES.get(t, "")
func tile_color(t: int) -> Color: return COLORS.get(t, Color.GRAY)


func seed_demo() -> void:
	var grid: Dictionary = app.grid
	var cols: int = app.cols
	var rows: int = app.rows
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
	app.cursor = Vector2i(4, rows - 3)


# =================================================== play
func start_play(from_cursor: bool) -> void:
	last_from_cursor = from_cursor
	if from_cursor:
		spawn_cell = app.cursor
	else:
		spawn_cell = _find(SPAWN)
		if spawn_cell == Vector2i(-1, -1): spawn_cell = app.cursor
	respawn_cell = spawn_cell
	coins_total = _count(COIN)
	coins_got = 0
	dead = false; won = false; death_t = 0.0; has_key = false
	on_floor = false; was_floor = false; coyote_t = 0.0; jbuf = 0.0
	pvel = Vector2.ZERO; input_x = 0
	enemies.clear(); plats.clear()
	for k in app.grid:
		if app.grid[k] == ENEMY:
			enemies.append({"pos": Vector2(k.x * CELL + 6, k.y * CELL + (CELL - ESIZE)), "dir": -1, "alive": true, "vy": 0.0})
		elif app.grid[k] == MOVPLAT:
			plats.append({"pos": Vector2(k.x * CELL, k.y * CELL), "dir": 1, "min": float((k.x - 3) * CELL), "max": float((k.x + 3) * CELL)})
	_place_player(spawn_cell)
	if player_sm:
		player_sm.change_state("Grounded")
		player_sm.change_state("Idle")


func stop_play() -> void:
	Input.stop_joy_vibration(0)


func _place_player(c: Vector2i) -> void:
	ppos = Vector2(c.x * CELL + (CELL - PSIZE.x) * 0.5, c.y * CELL + (CELL - PSIZE.y))
	pvel = Vector2.ZERO


# entrées transmises par ForgeApp
func jump_pressed() -> void:
	if not dead and not won: jbuf = JUMP_BUFFER


func jump_released() -> void:
	if pvel.y < 0: pvel.y *= JUMP_CUT


# saut déclenché par l'état Grounded (XSM)
func do_jump() -> void:
	pvel.y = JUMP_V; jbuf = 0.0; coyote_t = 0.0; on_floor = false
	app.squash = Vector2(0.78, 1.25)
	Input.start_joy_vibration(0, 0.10, 0.25, 0.07); app._play("jump")


func _physics_process(delta: float) -> void:
	if app == null or app.screen != "edit" or app.mode != "play" or won:
		return
	if dead:
		death_t -= delta
		if death_t <= 0.0:
			dead = false
			_place_player(respawn_cell)
		return

	input_x = _dir_x()
	coyote_t -= delta
	jbuf -= delta

	# --- XSM : les états (Idle/Run, Grounded/Jumping/Falling) règlent pvel.x et le saut
	if player_sm:
		player_sm._physics_process(delta)

	pvel.y = min(pvel.y + GRAVITY * delta, MAX_FALL)

	_move_plats(delta)
	var rects := _solid_rects()
	was_floor = on_floor
	on_floor = false
	var head_hit := false

	# X : déplace → cale rampe (montée) → collision murs
	ppos.x += pvel.x * delta
	ppos.x = clampf(ppos.x, 0, app.cols * CELL - PSIZE.x)
	_slope_snap()
	for r in rects:
		var pr := Rect2(ppos, PSIZE)
		if pr.intersects(r):
			if pvel.x > 0: ppos.x = r.position.x - PSIZE.x
			elif pvel.x < 0: ppos.x = r.position.x + r.size.x
			pvel.x = 0

	# Y : gravité + collision sol/plafond
	ppos.y += pvel.y * delta
	for r in rects:
		var pr := Rect2(ppos, PSIZE)
		if pr.intersects(r):
			if pvel.y > 0: ppos.y = r.position.y - PSIZE.y; on_floor = true
			elif pvel.y < 0: ppos.y = r.position.y + r.size.y; head_hit = true
			pvel.y = 0

	_slope_snap()   # coller en descente

	if head_hit: _hit_head()
	if on_floor: coyote_t = COYOTE
	if on_floor and not was_floor:
		app.squash = Vector2(1.28, 0.72)
		app._emit(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y), 6, Color("c8b89a"), 120.0, 0.30, true, 3.0)
		Input.start_joy_vibration(0, 0.0, 0.30, 0.05)

	_carry_on_plat(delta)
	_update_enemies(delta)
	if ppos.y > app.rows * CELL + 200: _die()
	_interactions()
	queue_redraw()
	app.queue_redraw()


# =================================================== simulation helpers
func _dir_x() -> int:
	if testing: return test_dir
	var v := 0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): v -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): v += 1
	var ax := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	if absf(ax) > DEADZONE: v += int(signf(ax))
	return clampi(v, -1, 1)


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
		var t: int = app.grid.get(c, EMPTY)
		if (t == GROUND or t == BREAKABLE or t == DOOR) and not _under_slope(c):
			out.append(_cell_rect(c))
	for p in plats:
		out.append(Rect2(p.pos, Vector2(CELL, 14)))
	return out


func _hit_head() -> void:
	var head := Vector2i(int((ppos.x + PSIZE.x * 0.5) / CELL), int((ppos.y - 2) / CELL))
	if app.grid.get(head, EMPTY) == BREAKABLE:
		app.grid.erase(head)
		app._emit(_cell_center(head), 12, COLORS[BREAKABLE], 220.0, 0.45, true, 4.0)
		app._shake(6.0, 0.18); app._play("break")


func _update_enemies(delta: float) -> void:
	var pr := Rect2(ppos, PSIZE)
	for en in enemies:
		if not en.alive: continue
		en.vy = min(en.vy + GRAVITY * delta, MAX_FALL)
		en.pos.y += en.vy * delta
		var grounded := false
		for cx in [int(en.pos.x / CELL), int((en.pos.x + ESIZE - 1) / CELL)]:
			var fc := Vector2i(cx, int((en.pos.y + ESIZE) / CELL))
			if _solid_tile(fc):
				en.pos.y = fc.y * CELL - ESIZE; en.vy = 0.0; grounded = true
		var nx: float = en.pos.x + en.dir * ESPEED * delta
		var front_col := int((nx + (ESIZE if en.dir > 0 else 0)) / CELL)
		var foot_row := int((en.pos.y + ESIZE - 1) / CELL)
		var wall := _solid_tile(Vector2i(front_col, foot_row))
		var edge := grounded and not _solid_tile(Vector2i(front_col, foot_row + 1))
		if wall or edge: en.dir = -en.dir
		else: en.pos.x = nx
		en.pos.x = clampf(en.pos.x, 0, app.cols * CELL - ESIZE)
		var er := Rect2(en.pos, Vector2(ESIZE, ESIZE))
		if pr.intersects(er):
			if pvel.y > 0 and (ppos.y + PSIZE.y) - en.pos.y < 22:
				en.alive = false; pvel.y = STOMP_BOUNCE
				app._emit(er.position + Vector2(ESIZE, ESIZE) * 0.5, 10, COLORS[ENEMY], 200.0, 0.4, true, 4.0)
				app._shake(4.0, 0.12); app._play("stomp")
			else:
				_die()


func _solid_tile(c: Vector2i) -> bool:
	var t: int = app.grid.get(c, EMPTY)
	return t == GROUND or t == BREAKABLE or t == DOOR


func _is_slope(t: int) -> bool:
	return SLOPES.has(t)


func _under_slope(c: Vector2i) -> bool:
	var y := c.y - 1
	while y >= 0:
		var t: int = app.grid.get(Vector2i(c.x, y), EMPTY)
		if t == EMPTY: return false
		if _is_slope(t): return true
		y -= 1
	return false


func _slope_surface(t: int, c: Vector2i, lx: float) -> float:
	var top := float(c.y * CELL)
	var bot := float((c.y + 1) * CELL)
	match t:
		SLOPE_R: return bot - lx
		SLOPE_L: return top + lx
		GSL_R_LO: return bot - lx * 0.5
		GSL_R_HI: return bot - CELL * 0.5 - lx * 0.5
		GSL_L_HI: return top + lx * 0.5
		GSL_L_LO: return top + CELL * 0.5 + lx * 0.5
	return INF


func _slope_snap() -> void:
	if pvel.y < 0: return
	var sy := _slope_ground(ppos.x + PSIZE.x * 0.5)
	if sy == INF: return
	var feet := ppos.y + PSIZE.y
	if feet >= sy - SLOPE_SNAP_DOWN and feet <= sy + SLOPE_SNAP_UP:
		ppos.y = sy - PSIZE.y
		pvel.y = 0.0
		on_floor = true


func _slope_ground(footx: float) -> float:
	var col := int(footx / CELL)
	var lx := footx - col * CELL
	var foot_row := int((ppos.y + PSIZE.y) / CELL)
	var best := INF
	for dy in [-1, 0, 1]:
		var c := Vector2i(col, foot_row + dy)
		var t: int = app.grid.get(c, EMPTY)
		if _is_slope(t):
			var sy := _slope_surface(t, c, lx)
			if sy >= c.y * CELL - 2 and sy <= (c.y + 1) * CELL + 2:
				if best == INF or sy < best: best = sy
	return best


func _die() -> void:
	if dead: return
	dead = true; death_t = 0.7
	app._emit(ppos + PSIZE * 0.5, 16, Color("ecf0f1"), 260.0, 0.5, true, 4.0)
	app._shake(9.0, 0.30)
	Input.start_joy_vibration(0, 0.6, 0.7, 0.30); app._play("death")
	player_died.emit()


func _interactions() -> void:
	for c in _cells(Rect2(ppos, PSIZE)):
		match app.grid.get(c, EMPTY):
			COIN:
				app.grid.erase(c); coins_got += 1
				app._emit(_cell_center(c), 8, COLORS[COIN], 160.0, 0.35, false, 3.0)
				Input.start_joy_vibration(0, 0.25, 0.0, 0.04); app._play("coin")
				coin_collected.emit()
			KEY:
				app.grid.erase(c); has_key = true
				app._emit(_cell_center(c), 10, COLORS[KEY], 180.0, 0.4, false, 3.0)
				app._play("key")
			SPIKE:
				_die()
			SPRING:
				if pvel.y >= 0:
					pvel.y = SPRING_V; jbuf = 0.0
					app.squash = Vector2(0.7, 1.35)
					app._emit(_cell_center(c), 8, COLORS[SPRING], 220.0, 0.35, false, 3.0)
					app._shake(3.0, 0.1); app._play("spring")
			GOAL:
				if not won:
					won = true
					app._emit(_cell_center(c), 24, COLORS[GOAL], 240.0, 0.7, false, 4.0)
					app._play("win")
					level_won.emit()
	if has_key:
		for c in _cells(Rect2(ppos - Vector2(5, 5), PSIZE + Vector2(10, 10))):
			if app.grid.get(c, EMPTY) == DOOR:
				app.grid.erase(c); has_key = false
				app._emit(_cell_center(c), 14, COLORS[DOOR], 200.0, 0.45, true, 4.0)
				app._play("key"); app._shake(3.0, 0.1)
				break


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
	for k in app.grid:
		if app.grid[k] == t: return k
	return Vector2i(-1, -1)


func _count(t: int) -> int:
	var n := 0
	for k in app.grid:
		if app.grid[k] == t: n += 1
	return n


# =================================================== rendu du MONDE (derrière le chrome)
func _draw() -> void:
	if app == null: return
	if app.screen != "edit": return
	var vp := get_viewport_rect().size
	app._compute_view()
	var th: Array = app.BG_THEMES[app.bg_theme]
	draw_rect(Rect2(Vector2.ZERO, vp), th[0])
	var lvl := Vector2(app.cols * CELL, app.rows * CELL)
	draw_rect(Rect2(app._w2s(Vector2.ZERO), lvl * app.view_scale), th[1])

	var _hide_chrome: bool = app.get("hide_editor_chrome") == true
	if app.mode == "edit" and not app.dezoom and not _hide_chrome:
		var gcol := Color(1, 1, 1, 0.06)
		for x in range(app.cols + 1):
			draw_line(app._w2s(Vector2(x * CELL, 0)), app._w2s(Vector2(x * CELL, app.rows * CELL)), gcol)
		for y in range(app.rows + 1):
			draw_line(app._w2s(Vector2(0, y * CELL)), app._w2s(Vector2(app.cols * CELL, y * CELL)), gcol)

	for k in app.grid:
		if app.mode == "play" and (app.grid[k] == ENEMY or app.grid[k] == MOVPLAT):
			continue
		draw_tile(self, app._w2s(Vector2(k.x * CELL, k.y * CELL)), app.grid[k], app.view_scale)

	for p in app.particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		var c: Color = p.col; c.a = a
		draw_circle(app._w2s(p.pos), p.size * app.view_scale, c)

	if app.mode == "edit" and not _hide_chrome:
		if app.sel_mode and app.sel_anchor != Vector2i(-1, -1):
			var x0 := mini(app.sel_anchor.x, app.cursor.x); var y0 := mini(app.sel_anchor.y, app.cursor.y)
			var x1 := maxi(app.sel_anchor.x, app.cursor.x); var y1 := maxi(app.sel_anchor.y, app.cursor.y)
			var rr := Rect2(app._w2s(Vector2(x0 * CELL, y0 * CELL)), Vector2((x1 - x0 + 1) * CELL, (y1 - y0 + 1) * CELL) * app.view_scale)
			draw_rect(rr, Color(0.2, 0.8, 1, 0.18)); draw_rect(rr, Color("3498db"), false, 2.0)
		var cp: Vector2 = app._w2s(Vector2(app.cursor.x * CELL, app.cursor.y * CELL))
		if not app.sel_mode:
			draw_tile(self, cp, palette()[app.pal], app.view_scale, 0.45)
		var cc := Color("3498db") if app.sel_mode else (Color.WHITE if app.cursor_mode == "rapide" else Color("f39c12"))
		draw_rect(Rect2(cp, Vector2(CELL, CELL) * app.view_scale), cc, false, 3.0)

	if app.mode == "play":
		for p in plats:
			draw_tile(self, app._w2s(p.pos), MOVPLAT, app.view_scale)
		for en in enemies:
			if en.alive:
				draw_tile(self, app._w2s(en.pos - Vector2(6, 6)), ENEMY, app.view_scale)
		var ps: Vector2 = PSIZE * app.squash
		var anchor: Vector2 = app._w2s(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y))
		var pr := Rect2(anchor - Vector2(ps.x * 0.5, ps.y) * app.view_scale, ps * app.view_scale)
		draw_rect(pr, Color("ffffff")); draw_rect(pr, Color("2c3e50"), false, 2.0)
		if has_key:
			draw_circle(pr.position + Vector2(pr.size.x * 0.5, -8), 5, COLORS[KEY])


func draw_tile(ci: CanvasItem, p: Vector2, t: int, scale := 1.0, alpha := 1.0) -> void:
	var col: Color = COLORS.get(t, Color.GRAY); col.a = alpha
	var cs := CELL * scale
	var pad := 3.0 * scale
	match t:
		COIN:
			ci.draw_circle(p + Vector2(cs, cs) * 0.5, cs * 0.3, col)
		KEY:
			ci.draw_circle(p + Vector2(cs * 0.4, cs * 0.4), cs * 0.18, col)
			ci.draw_rect(Rect2(p + Vector2(cs * 0.4, cs * 0.4), Vector2(cs * 0.32, cs * 0.1)), col)
		ENEMY:
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(cs * 0.5, pad), p + Vector2(cs - pad, cs - pad), p + Vector2(pad, cs - pad)]), col)
		SPIKE:
			for i in 3:
				var bx := p.x + pad + i * (cs - pad * 2) / 3.0
				var bw := (cs - pad * 2) / 3.0
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(bx, p.y + cs - pad), Vector2(bx + bw * 0.5, p.y + pad), Vector2(bx + bw, p.y + cs - pad)]), col)
		SPRING:
			ci.draw_rect(Rect2(p + Vector2(pad, cs * 0.55), Vector2(cs - pad * 2, cs * 0.45 - pad)), col)
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(cs * 0.5, pad), p + Vector2(cs * 0.75, cs * 0.5), p + Vector2(cs * 0.25, cs * 0.5)]), col.lightened(0.2))
		GOAL:
			ci.draw_rect(Rect2(p + Vector2(cs * 0.4, pad), Vector2(4 * scale, cs - pad * 2)), col)
			ci.draw_rect(Rect2(p + Vector2(cs * 0.4 + 4 * scale, pad), Vector2(cs * 0.4, cs * 0.3)), col)
		CHECKPOINT:
			ci.draw_rect(Rect2(p + Vector2(cs * 0.4, pad), Vector2(4 * scale, cs - pad * 2)), col)
			ci.draw_rect(Rect2(p + Vector2(cs * 0.4 + 4 * scale, pad), Vector2(cs * 0.35, cs * 0.28)), col)
		SPAWN:
			ci.draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col, false, 3.0)
		DOOR:
			ci.draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad)), col)
			ci.draw_circle(p + Vector2(cs * 0.72, cs * 0.5), cs * 0.06, Color("f1c40f"))
		MOVPLAT:
			ci.draw_rect(Rect2(p + Vector2(0, cs * 0.2), Vector2(cs, cs * 0.35)), col)
		GROUND:
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col)
			var top: Color = col.lightened(0.12); top.a = col.a
			ci.draw_rect(Rect2(p, Vector2(cs, max(2.0, cs * 0.10))), top)
		BREAKABLE:
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col)
			ci.draw_line(p + Vector2(0, cs * 0.5), p + Vector2(cs, cs * 0.5), col.darkened(0.3), 1.5)
			ci.draw_line(p + Vector2(cs * 0.5, 0), p + Vector2(cs * 0.5, cs), col.darkened(0.3), 1.5)
		SLOPE_R:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, cs), p + Vector2(cs, cs), p + Vector2(cs, 0)]), col)
		SLOPE_L:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, 0), p + Vector2(0, cs), p + Vector2(cs, cs)]), col)
		GSL_R_LO:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, cs), p + Vector2(cs, cs), p + Vector2(cs, cs * 0.5)]), col)
		GSL_R_HI:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, cs), p + Vector2(cs, cs), p + Vector2(cs, 0), p + Vector2(0, cs * 0.5)]), col)
		GSL_L_HI:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, 0), p + Vector2(0, cs), p + Vector2(cs, cs), p + Vector2(cs, cs * 0.5)]), col)
		GSL_L_LO:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, cs * 0.5), p + Vector2(0, cs), p + Vector2(cs, cs)]), col)
		_:
			ci.draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col)
