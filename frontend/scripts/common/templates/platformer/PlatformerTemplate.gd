extends TemplateBase
class_name PlatformerTemplate
# Genre PLATEFORMER : physique (normale + Sonic), pentes/courbes/loopings, eau,
# echelles/glace/tapis, hazards (barre de feu, blocs tombants, friables),
# ennemis au sol et rendu specifiques. Les services partages (tuiles, PV/dash,
# cles/portes/dalles, boss FSM, projectiles, parallax, draw_tile) = TemplateBase.
# Le personnage est pilote par une machine XSM (Locomotion + Air), voir states/.

# --- constantes du genre ---
const CONV_SPEED := 95.0
const CLIMB_SPEED := 200.0
const ICE_FRICTION := 0.04   # 0 = patine a fond, 1 = stop net
const SPEED := 330.0
const JUMP_V := -660.0
const ACCEL_GROUND := 2600.0
const ACCEL_AIR := 1500.0
const FRICTION := 3000.0
const JUMP_CUT := 0.45
const COYOTE := 0.10
const JUMP_BUFFER := 0.12
const STOMP_BOUNCE := -460.0
const SPRING_V := -1050.0
const EFISH_SPEED := 65.0   # poisson : vitesse de nage
const FISH_HOP_V := -560.0  # poisson hors de l'eau : impulsion de sursaut
const FISH_HOP_VX := 70.0   # poisson hors de l'eau : derive horizontale
const HOP_INTERVAL := 1.3   # sauteur : delai entre bonds
const HOP_V := -700.0
const HOP_VX := 135.0
const BOUNCE_SPEED := 165.0 # rebondisseur : vitesse diagonale
const FIREBAR_SPEED := 2.0  # barre de feu : vitesse de rotation (rad/s)
const CRUMBLE_DELAY := 0.45 # friable : delai avant rupture sous le joueur
const FALL_DELAY := 0.35    # bloc tombant : delai avant chute
const SLOPE_SNAP_UP := 22.0
const SLOPE_SNAP_DOWN := 16.0
const STEP_UP := 24.0   # marche franchie sans saut

# eau : nage (gravite reduite, descente lente, brasse, trainee horizontale)
const WATER_GRAV := 0.30
const WATER_SINK := 150.0
const WATER_RISE := -280.0
const WATER_SWIM := -310.0
const WATER_DRAG := 0.86

# mode Sonic (physique a momentum, activee par level_props.sonic)
const SONIC_ACC := 1500.0
const SONIC_DEC := 4200.0
const SONIC_FRIC := 1100.0
const SONIC_TOP := 760.0
const SONIC_SLOPE := 800.0
const SONIC_JUMP := 660.0
const SONIC_AIR_ACC := 1500.0
const STICK_TOL := 26.0
const LAND_TOL := 30.0
const LOOP_R := 3.0 * CELL     # rayon looping (144px)
const LOOP_WALL := CELL * 0.3  # epaisseur mur looping
const LOOP_OPEN := 0.20944     # demi-angle ouverture bas (12 deg) : base du mur a ~3px
                               # du sol avec une pente de 12 deg = rampe d'entree naturelle

# --- etat du genre ---
var input_x := 0
var coyote_t := 0.0
var jbuf := 0.0
var hazards := []       # barres de feu + blocs en chute {type, ...}
var crumble_t := {}     # compte a rebours de rupture par case friable
var fb_t := {}          # compte a rebours de declenchement par bloc tombant
var plats := []         # plateformes mobiles
var on_ladder := false
var climbing := false
var on_ice := false
var was_in_water := false
var prev_vx := 0.0
# mode Sonic
var gsp := 0.0           # vitesse le long du sol (tangente)
var gangle := 0.0        # angle du sol (radians)
var sonic_grounded := false
var land_debug := ""
var active_loops: Array = []
var rail_lp = null       # loop dont le joueur suit le RAIL (null = aucun)
var rail_th := 0.0       # angle position sur le rail (atan2 depuis le centre)
var rail_topped := false # le SOMMET a été franchi pendant ce parcours → loop validé
var rail_r := 0.0        # rayon courant des pieds (converge vers la surface interne)
var rail_fb0 := 0.0      # angle (depuis le bas) où le sol rencontre le cercle (entrée)
var rail_exit_y := 0.0   # hauteur du sol enregistrée à l'entrée (sortie continue)


# =================================================== contrat du genre
const CATEGORIES := [
	{"name": "Terrain",  "tiles": [1, 13, 14, 15, 16, 17, 18, 26, 27, 28, 29, 8, 21, 19, 30]},
	{"name": "Danger",   "tiles": [7, 35, 36, 44, 45, 46]},
	{"name": "Ennemis",  "tiles": [4, 37, 38, 39, 40, 41, 42, 43, 47]},
	{"name": "Items",    "tiles": [3, 11, 6]},
	{"name": "Mecanique","tiles": [9, 20, 22, 23, 24, 25, 12, 64]},
	{"name": "Reperes",  "tiles": [2, 10, 5, 51]},
	{"name": "Decor",    "tiles": [31, 32, 33, 34]},
]
func categories() -> Array: return CATEGORIES
func movplat_tile() -> int: return MOVPLAT


func debug_text() -> String:
	return land_debug if _sonic() else ""


func seed_demo() -> void:
	# petit niveau-vitrine : sauts → pentes → plateforme mobile → ressort/pics → arrivée
	var grid: Dictionary = app.grid
	var cols: int = app.cols
	var rows: int = app.rows
	grid.clear()
	for x in range(0, cols):
		grid[Vector2i(x, rows - 1)] = GROUND
	grid[Vector2i(2, rows - 2)] = SPAWN
	# 1) sauts simples + pièces
	for x in range(7, 10):
		grid[Vector2i(x, rows - 4)] = GROUND
	grid[Vector2i(8, rows - 5)] = COIN
	grid[Vector2i(9, rows - 5)] = COIN
	grid[Vector2i(12, rows - 2)] = ENEMY
	# 2) colline en pentes (montée, plateau, descente)
	grid[Vector2i(15, rows - 2)] = SLOPE_R
	grid[Vector2i(16, rows - 2)] = GROUND
	grid[Vector2i(16, rows - 3)] = SLOPE_R
	grid[Vector2i(17, rows - 2)] = GROUND
	grid[Vector2i(17, rows - 3)] = GROUND
	grid[Vector2i(17, rows - 4)] = COIN
	grid[Vector2i(18, rows - 2)] = GROUND
	grid[Vector2i(18, rows - 3)] = SLOPE_L
	grid[Vector2i(19, rows - 2)] = SLOPE_L
	# 3) checkpoint puis plateforme mobile au-dessus d'une fosse de pics
	grid[Vector2i(21, rows - 2)] = CHECKPOINT
	for x in range(23, 27):
		grid.erase(Vector2i(x, rows - 1))
		grid[Vector2i(x, rows - 1)] = SPIKE
	grid[Vector2i(23, rows - 5)] = MOVPLAT
	for x in range(27, cols):
		grid[Vector2i(x, rows - 1)] = GROUND
	# 4) mur cassable qui cache une pièce + ressort vers une corniche bonus
	for y in range(rows - 4, rows - 1):
		grid[Vector2i(29, y)] = BREAKABLE
	grid[Vector2i(30, rows - 2)] = COIN
	grid[Vector2i(33, rows - 2)] = SPRING
	for x in range(34, 37):
		grid[Vector2i(x, rows - 7)] = GROUND
	grid[Vector2i(35, rows - 8)] = COIN
	grid[Vector2i(35, rows - 2)] = ENEMY
	grid[Vector2i(cols - 2, rows - 2)] = GOAL
	app.cursor = Vector2i(4, rows - 3)


# =================================================== play
func start_play(from_cursor: bool) -> void:
	super(from_cursor)
	on_floor = false; was_floor = false; coyote_t = 0.0; jbuf = 0.0
	input_x = 0
	on_ladder = false; climbing = false; on_ice = false; prev_vx = 0.0
	was_in_water = false
	gsp = 0.0; gangle = 0.0; sonic_grounded = false
	if player_sm:
		player_sm.change_state("Grounded")
		player_sm.change_state("Idle")


# entites specifiques au genre (appele par TemplateBase._build_entities)
func _build_extra() -> void:
	plats.clear(); active_loops.clear()
	hazards.clear(); crumble_t.clear(); fb_t.clear()
	rail_lp = null
	for k in app.grid:
		if app.grid[k] == FIREBAR:
			hazards.append({"type": "firebar", "center": Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL), "ang": 0.0})
		elif app.grid[k] == MOVPLAT:
			var cfg: Dictionary = app.cell_cfg.get(k, {})
			var axis: String = str(cfg.get("axis", "H"))
			var span: int = int(cfg.get("span", 3))
			var spd: float = {"lent": 50.0, "normal": 90.0, "rapide": 150.0}.get(cfg.get("speed", "normal"), 90.0)
			var sdir: int = -1 if str(cfg.get("dir", "+")) == "-" else 1
			var w: int = int(cfg.get("width", 1))
			var pos := Vector2(k.x * CELL, k.y * CELL)
			if axis == "V":
				plats.append({"pos": pos, "dir": sdir, "axis": "V", "spd": spd, "w": w,
					"min": float((k.y - span) * CELL), "max": float((k.y + span) * CELL)})
			else:
				plats.append({"pos": pos, "dir": sdir, "axis": "H", "spd": spd, "w": w,
					"min": float((k.x - span) * CELL), "max": float((k.x + span) * CELL)})
		elif app.grid[k] == LOOP_CENTER:
			active_loops.append({"center": Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL), "radius": LOOP_R})


# effet du ressort (hook TemplateBase._interactions)
func _touch_spring(c: Vector2i) -> void:
	if _sonic():
		sonic_grounded = false
		pvel = Vector2(cos(gangle) * gsp, SPRING_V); jbuf = 0.0
		app.squash = Vector2(0.7, 1.35)
		app._emit(_cell_center(c), 8, COLORS[SPRING], 220.0, 0.35, false, 3.0)
		app._shake(3.0, 0.1); app._play("spring")
	elif pvel.y >= 0:
		pvel.y = SPRING_V; jbuf = 0.0
		app.squash = Vector2(0.7, 1.35)
		app._emit(_cell_center(c), 8, COLORS[SPRING], 220.0, 0.35, false, 3.0)
		app._shake(3.0, 0.1); app._play("spring")

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


func _sonic() -> bool:
	var ap = app.get("level_props")
	return ap != null and ap.get("sonic", false)


func _physics_process(delta: float) -> void:
	if app == null or app.screen != "edit" or app.mode != "play" or won:
		return
	if dead:
		death_t -= delta
		if death_t <= 0.0:
			dead = false
			_build_entities()           # reset ennemis/plateformes/grilles
			_place_player(respawn_cell)
			pvel = Vector2.ZERO
			gsp = 0.0; sonic_grounded = false; on_floor = false
			was_in_water = false; air_t = AIR_MAX
			time_left = _time_limit()
			pinv = 0.0; dashing = 0.0; dash_cd = 0.0
			hearts = max_hearts
		return

	_update_plates()
	if _sonic():
		_move_plats(delta)
		_tick_player_timers(delta)
		if dashing <= 0.0 and dash_cd <= 0.0 and _dash_input():
			_start_dash(Vector2(signf(gsp) if gsp != 0.0 else 1.0, 0.0))
		if dashing > 0.0:
			gsp = dash_dir.x * DASH_SPEED
		_sonic_physics(delta)
		_carry_on_plat(delta)
		_update_enemies(delta)
		if ppos.y > app.rows * CELL + 200: _kill()
		_interactions(delta)
		_p2_step(delta)
		queue_redraw(); app.queue_redraw()
		return

	input_x = _dir_x()
	if input_x != 0: face_x = input_x   # direction regardée (yeux du perso)
	coyote_t -= delta
	jbuf -= delta
	switch_cd -= delta

	# glace : on retient la vitesse horizontale (patinage). on_floor = état frame précédente.
	on_ice = on_floor and _ground_tile() == ICE
	prev_vx = pvel.x

	# --- échelle : prise par haut/bas, repos sinclus ---
	on_ladder = _ladder_overlap()
	var climb_y := _dir_y()
	if not on_ladder:
		climbing = false
	elif climb_y != 0:
		climbing = true
	if climbing and jbuf > 0.0:   # sauter depuis l'échelle
		climbing = false
		do_jump()

	# --- XSM : les états règlent pvel.x et le saut
	if player_sm:
		player_sm._physics_process(delta)

	if on_ice:   # mélange avec la vitesse précédente -> glisse
		pvel.x = lerpf(prev_vx, pvel.x, 0.12 if input_x != 0 else ICE_FRICTION)

	var in_water := _in_water()
	if climbing:
		pvel.y = float(climb_y) * CLIMB_SPEED
	elif in_water:
		pvel.y = clampf(pvel.y + GRAVITY * WATER_GRAV * delta, WATER_RISE, WATER_SINK)
		pvel.x *= WATER_DRAG
	else:
		pvel.y = min(pvel.y + GRAVITY * delta, MAX_FALL)
	# brasse vers le haut (répétable) — seulement si la nage est activée
	if in_water and _water_swim() and jbuf > 0.0:
		pvel.y = WATER_SWIM; jbuf = 0.0
		app._emit(ppos + Vector2(PSIZE.x * 0.5, 0.0), 5, Color("aee3f0"), 120.0, 0.3, false, 3.0)
		app._play("jump")
	# éclaboussure à l'entrée/sortie de l'eau
	if in_water != was_in_water:
		app._emit(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y * 0.5), 10, Color("aee3f0"), 170.0, 0.35, true, 3.0)
		app._shake(2.0, 0.08)
	was_in_water = in_water
	_update_air(delta, in_water)

	# dash horizontal (esquive) : override la vitesse pendant le dash
	_tick_player_timers(delta)
	if dashing <= 0.0 and dash_cd <= 0.0 and _dash_input():
		var dx := signf(float(input_x)) if input_x != 0 else signf(pvel.x)
		_start_dash(Vector2(dx if dx != 0.0 else 1.0, 0.0))
	if dashing > 0.0:
		pvel.x = dash_dir.x * DASH_SPEED
		pvel.y = 0.0

	_move_plats(delta)
	var rects := _solid_rects()
	var oneways := _oneway_rects()
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
			# step-up : franchir une petite marche (jonction pente↔bloc). _support_y garde le point haut → pas d'oscillation.
			var pen: float = (ppos.y + PSIZE.y) - r.position.y
			if (on_floor or was_floor) and pen > 0 and pen <= STEP_UP and not _solid_tile(Vector2i(int((r.position.x + CELL * 0.5) / CELL), int(r.position.y / CELL) - 1)):
				ppos.y = r.position.y - PSIZE.y
				on_floor = true
				continue
			if pvel.x > 0: ppos.x = r.position.x - PSIZE.x
			elif pvel.x < 0: ppos.x = r.position.x + r.size.x
			pvel.x = 0
			if _autorun(): autorun_dir = -autorun_dir   # demi-tour sur mur

	# Y : gravité + collision sol/plafond
	var prev_bottom := ppos.y + PSIZE.y
	ppos.y += pvel.y * delta
	for r in rects:
		var pr := Rect2(ppos, PSIZE)
		if pr.intersects(r):
			if pvel.y > 0: ppos.y = r.position.y - PSIZE.y; on_floor = true
			elif pvel.y < 0: ppos.y = r.position.y + r.size.y; head_hit = true
			pvel.y = 0
	# plateformes 1-sens : atterrissage seulement par le dessus, en descente
	if pvel.y > 0 and not climbing:
		for r in oneways:
			if prev_bottom <= r.position.y + 6 and (ppos.y + PSIZE.y) >= r.position.y:
				var pr := Rect2(ppos, PSIZE)
				if pr.intersects(r):
					ppos.y = r.position.y - PSIZE.y; on_floor = true; pvel.y = 0

	_slope_snap()   # coller en descente

	if head_hit: _hit_head()
	if on_floor: coyote_t = COYOTE
	if on_floor and not was_floor:
		app.squash = Vector2(1.28, 0.72)
		app._emit(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y), 6, Color("c8b89a"), 120.0, 0.30, true, 3.0)
		Input.start_joy_vibration(0, 0.0, 0.30, 0.05)

	_carry_on_plat(delta)
	_conveyor_push(delta)
	_update_enemies(delta)
	if ppos.y > app.rows * CELL + 200: _kill()
	_interactions(delta)
	_p2_step(delta)
	queue_redraw()
	app.queue_redraw()


func _ladder_overlap() -> bool:
	for c in _cells(Rect2(ppos + Vector2(PSIZE.x * 0.5 - 4, 2), Vector2(8, PSIZE.y - 4))):
		if app.grid.get(c, EMPTY) == LADDER: return true
	return false


func _ground_tile() -> int:
	var fx := ppos.x + PSIZE.x * 0.5
	var fy := ppos.y + PSIZE.y + 2.0
	return app.grid.get(Vector2i(int(fx / CELL), int(fy / CELL)), EMPTY)


func _conveyor_push(delta: float) -> void:
	if not on_floor: return
	match _ground_tile():
		CONV_R: ppos.x = clampf(ppos.x + CONV_SPEED * delta, 0, app.cols * CELL - PSIZE.x)
		CONV_L: ppos.x = clampf(ppos.x - CONV_SPEED * delta, 0, app.cols * CELL - PSIZE.x)


func _move_plats(delta: float) -> void:
	for p in plats:
		var spd: float = p.get("spd", 90.0)
		if p.get("axis", "H") == "V":
			p.pos.y += p.dir * spd * delta
			if p.pos.y <= p.min: p.pos.y = p.min; p.dir = 1
			elif p.pos.y >= p.max: p.pos.y = p.max; p.dir = -1
		else:
			p.pos.x += p.dir * spd * delta
			if p.pos.x <= p.min: p.pos.x = p.min; p.dir = 1
			elif p.pos.x >= p.max: p.pos.x = p.max; p.dir = -1


func _carry_on_plat(delta: float) -> void:
	var feet := Rect2(ppos + Vector2(2, PSIZE.y - 2), Vector2(PSIZE.x - 4, 6))
	for p in plats:
		if feet.intersects(Rect2(p.pos, Vector2(int(p.get("w", 1)) * CELL, 14))):
			var spd: float = p.get("spd", 90.0)
			if p.get("axis", "H") == "V":
				ppos.y += p.dir * spd * delta   # porté verticalement
			else:
				ppos.x += p.dir * spd * delta


func _solid_rects() -> Array:
	var out := []
	for c in _cells(Rect2(ppos - Vector2(CELL, CELL), PSIZE + Vector2(CELL, CELL) * 2)):
		# friable rompue / bloc tombant déclenché → plus solides
		if crumbled.has(c) or fb_trig.has(c):
			continue
		if _cell_solid(c) and not _under_slope(c):
			out.append(_cell_rect(c))
	for p in plats:
		out.append(Rect2(p.pos, Vector2(int(p.get("w", 1)) * CELL, 14)))
	return out


# rects de plateformes 1-sens (collision uniquement par le dessus, en descente)
func _oneway_rects() -> Array:
	var out := []
	for c in _cells(Rect2(ppos - Vector2(CELL, CELL), PSIZE + Vector2(CELL, CELL) * 2)):
		if app.grid.get(c, EMPTY) == ONEWAY:
			out.append(_cell_rect(c))
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
		var t: String = en.type
		match t:
			"flyer":   _enemy_flyer(en, delta)
			"fish":    _enemy_fish(en, delta)
			"chaser":  _enemy_chaser(en, delta)
			"hopper":  _enemy_hopper(en, delta)
			"bouncer": _enemy_bouncer(en, delta)
			"shooter": _enemy_shooter(en, delta)
			"boss":    _enemy_boss(en, delta)
			_:         _enemy_ground(en, delta)   # walker + spiker
		var esz: float = BOSS_SIZE if t == "boss" else float(ESIZE)
		var er := Rect2(en.pos, Vector2(esz, esz))
		if not pr.intersects(er): continue
		if t == "boss":
			# stomp = un coup ; contact latéral = mort (sauf pdt l'invulnérabilité)
			if pvel.y > 0 and (ppos.y + PSIZE.y) - en.pos.y < esz * 0.5:
				pvel.y = STOMP_BOUNCE
				if en.inv <= 0.0:
					en.hp -= 1; en.inv = BOSS_INV
					app._emit(en.pos + Vector2(esz, esz) * 0.5, 14, COLORS[BOSS].lightened(0.3), 220.0, 0.4, true, 4.0)
					app._shake(5.0, 0.15); app._play("stomp")
					if en.hp <= 0:
						en.alive = false
						app._emit(en.pos + Vector2(esz, esz) * 0.5, 40, COLORS[BOSS], 320.0, 0.9, true, 6.0)
						app._shake(10.0, 0.4); app._play("win")
					elif not en.enraged and en.hp <= BOSS_ENRAGE_HP:
						en.state = "enrage"; en.st = 0.0; en.tele = false; en.queue = []
					else:
						en.state = "hurt"; en.st = 0.0; en.tele = false; en.queue = []
			elif en.inv <= 0.0:
				_die()
			continue
		# stompable : tout sauf piquant, poisson, rebondisseur
		var stompable: bool = t != "spiker" and t != "fish" and t != "bouncer"
		if stompable and pvel.y > 0 and (ppos.y + PSIZE.y) - en.pos.y < 22:
			en.alive = false; pvel.y = STOMP_BOUNCE
			app._emit(er.position + Vector2(ESIZE, ESIZE) * 0.5, 10, COLORS[ENEMY], 200.0, 0.4, true, 4.0)
			app._shake(4.0, 0.12); app._play("stomp")
		else:
			_die()   # piquant + poisson + rebondisseur : mortel au moindre contact
	_update_projectiles(delta)
	_update_hazards(delta)


# marcheur/piquant : gravité, patrouille, demi-tour mur ou bord
func _enemy_ground(en: Dictionary, delta: float) -> void:
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


# poisson : nage dans l'eau ; hors de l'eau, sautille au sol comme un magicarpe
func _enemy_fish(en: Dictionary, delta: float) -> void:
	en.phase += delta
	var here := Vector2i(int((en.pos.x + ESIZE * 0.5) / CELL), int((en.pos.y + ESIZE * 0.5) / CELL))
	if app.grid.get(here, EMPTY) == WATER:
		# nage : va-et-vient tant que la case suivante reste de l'eau
		var nx: float = en.pos.x + en.dir * EFISH_SPEED * delta
		var ncc := Vector2i(int((nx + ESIZE * 0.5) / CELL), int((en.pos.y + ESIZE * 0.5) / CELL))
		if app.grid.get(ncc, EMPTY) != WATER:
			en.dir = -en.dir
		else:
			en.pos.x = nx
		en.pos.y = en.base_y + sin(en.phase * 2.0) * 6.0
		en.vy = 0.0
		en.base_y = en.pos.y
	else:
		# hors de l'eau : gravité + sursauts périodiques (flop)
		en.vy = min(en.vy + GRAVITY * delta, MAX_FALL)
		en.pos.y += en.vy * delta
		var grounded := false
		for cx in [int(en.pos.x / CELL), int((en.pos.x + ESIZE - 1) / CELL)]:
			var fc := Vector2i(cx, int((en.pos.y + ESIZE) / CELL))
			if _solid_tile(fc):
				en.pos.y = fc.y * CELL - ESIZE; en.vy = 0.0; grounded = true
		if grounded:
			en.hop_t -= delta
			if en.hop_t <= 0.0:
				en.vy = FISH_HOP_V
				en.dir = -en.dir
				en.hop_t = randf_range(0.5, 1.1)
				app._emit(en.pos + Vector2(ESIZE * 0.5, ESIZE), 4, COLORS[FISH], 110.0, 0.25, true, 3.0)
		else:
			# dérive horizontale pendant le saut, demi-tour sur mur
			var nx2: float = en.pos.x + en.dir * FISH_HOP_VX * delta
			var col2 := int((nx2 + (ESIZE if en.dir > 0 else 0)) / CELL)
			var row2 := int((en.pos.y + ESIZE * 0.5) / CELL)
			if _solid_tile(Vector2i(col2, row2)):
				en.dir = -en.dir
			else:
				en.pos.x = nx2
		en.pos.x = clampf(en.pos.x, 0, app.cols * CELL - ESIZE)
		en.base_y = en.pos.y


# sauteur : grenouille, bonds périodiques vers le joueur (gravité au sol)
func _enemy_hopper(en: Dictionary, delta: float) -> void:
	en.vy = min(en.vy + GRAVITY * delta, MAX_FALL)
	en.pos.y += en.vy * delta
	var grounded := false
	for cx in [int(en.pos.x / CELL), int((en.pos.x + ESIZE - 1) / CELL)]:
		var fc := Vector2i(cx, int((en.pos.y + ESIZE) / CELL))
		if _solid_tile(fc):
			en.pos.y = fc.y * CELL - ESIZE; en.vy = 0.0; grounded = true
	if grounded:
		en.hop_t -= delta
		if en.hop_t <= 0.0:
			en.vy = HOP_V
			en.dir = 1 if (ppos.x > en.pos.x) else -1   # bond vers le joueur
			en.hop_t = HOP_INTERVAL
	else:
		var nx: float = en.pos.x + en.dir * HOP_VX * delta
		var col := int((nx + (ESIZE if en.dir > 0 else 0)) / CELL)
		var row := int((en.pos.y + ESIZE * 0.5) / CELL)
		if _solid_tile(Vector2i(col, row)):
			en.dir = -en.dir
		else:
			en.pos.x = nx
	en.pos.x = clampf(en.pos.x, 0, app.cols * CELL - ESIZE)


# rebondisseur : balle diagonale qui ricoche sur murs/sol/plafond, mortelle
func _enemy_bouncer(en: Dictionary, delta: float) -> void:
	var hw := ESIZE * 0.5
	en.pos.x += en.vel.x * delta
	var mid_row := int((en.pos.y + hw) / CELL)
	if en.vel.x > 0 and _solid_tile(Vector2i(int((en.pos.x + ESIZE) / CELL), mid_row)):
		en.vel.x = -absf(en.vel.x); en.pos.x = floor((en.pos.x + ESIZE) / CELL) * CELL - ESIZE
	elif en.vel.x < 0 and _solid_tile(Vector2i(int(en.pos.x / CELL), mid_row)):
		en.vel.x = absf(en.vel.x); en.pos.x = ceil(en.pos.x / CELL) * CELL
	en.pos.y += en.vel.y * delta
	var mid_col := int((en.pos.x + hw) / CELL)
	if en.vel.y > 0 and _solid_tile(Vector2i(mid_col, int((en.pos.y + ESIZE) / CELL))):
		en.vel.y = -absf(en.vel.y); en.pos.y = floor((en.pos.y + ESIZE) / CELL) * CELL - ESIZE
	elif en.vel.y < 0 and _solid_tile(Vector2i(mid_col, int(en.pos.y / CELL))):
		en.vel.y = absf(en.vel.y); en.pos.y = ceil(en.pos.y / CELL) * CELL


# tourelle : fixe au sol, tire un projectile vers le joueur à intervalle
func _enemy_shooter(en: Dictionary, delta: float) -> void:
	en.vy = min(en.vy + GRAVITY * delta, MAX_FALL)
	en.pos.y += en.vy * delta
	for cx in [int(en.pos.x / CELL), int((en.pos.x + ESIZE - 1) / CELL)]:
		var fc := Vector2i(cx, int((en.pos.y + ESIZE) / CELL))
		if _solid_tile(fc):
			en.pos.y = fc.y * CELL - ESIZE; en.vy = 0.0
	en.dir = 1 if (ppos.x > en.pos.x) else -1
	en.shoot_t -= delta
	if en.shoot_t <= 0.0:
		en.shoot_t = SHOOT_INTERVAL
		var origin: Vector2 = en.pos + Vector2(ESIZE * 0.5, ESIZE * 0.4)
		projectiles.append({"pos": origin, "vel": Vector2(en.dir * PROJ_SPEED, 0.0), "alive": true})
		app._emit(origin, 4, COLORS[SHOOTER].lightened(0.4), 120.0, 0.2, false, 2.5)
		app._play("spring")


func _update_hazards(delta: float) -> void:
	var pr := Rect2(ppos, PSIZE)
	# barres de feu (rotation + contact) et blocs en chute
	for h in hazards:
		if h.type == "firebar":
			h.ang += FIREBAR_SPEED * delta
			for i in range(1, FIREBAR_LEN + 1):
				var fp: Vector2 = h.center + Vector2(cos(h.ang), sin(h.ang)) * (float(i) * CELL * 0.5)
				if pr.intersects(Rect2(fp - Vector2(12, 12), Vector2(24, 24))):
					_die(); break
		elif h.type == "fallblock":
			h.vy = min(h.vy + GRAVITY * delta, MAX_FALL)
			h.pos.y += h.vy * delta
			if pr.intersects(Rect2(h.pos, Vector2(CELL, CELL))):
				_die()
			var below := Vector2i(int((h.pos.x + CELL * 0.5) / CELL), int((h.pos.y + CELL) / CELL))
			if _solid_tile(below) or h.pos.y > app.rows * CELL:
				h["done"] = true
				app._emit(h.pos + Vector2(CELL, CELL) * 0.5, 10, COLORS[FALLBLOCK], 160.0, 0.4, true, 4.0)
				app._shake(4.0, 0.12); app._play("break")
	if hazards.any(func(h): return h.get("done", false)):
		hazards = hazards.filter(func(h): return not h.get("done", false))
	# déclenchement bloc tombant : joueur sous une case FALLBLOCK (même colonne, ≤5 cases)
	var head_col := int((ppos.x + PSIZE.x * 0.5) / CELL)
	for dy in range(1, 6):
		var c := Vector2i(head_col, int(ppos.y / CELL) - dy)
		if app.grid.get(c, EMPTY) == FALLBLOCK and not fb_trig.has(c):
			fb_t[c] = fb_t.get(c, FALL_DELAY) - delta
			if fb_t[c] <= 0.0:
				fb_trig[c] = true
				hazards.append({"type": "fallblock", "pos": Vector2(c.x * CELL, c.y * CELL), "vy": 0.0})
			break
	# plateforme friable : rupture sous les pieds
	if on_floor:
		var fy := int((ppos.y + PSIZE.y + 1.0) / CELL)
		for fx in [int(ppos.x / CELL), int((ppos.x + PSIZE.x - 1) / CELL)]:
			var fc := Vector2i(fx, fy)
			if app.grid.get(fc, EMPTY) == CRUMBLE and not crumbled.has(fc):
				crumble_t[fc] = crumble_t.get(fc, CRUMBLE_DELAY) - delta
				if crumble_t[fc] <= 0.0:
					crumbled[fc] = true
					app._emit(_cell_center(fc), 10, COLORS[CRUMBLE], 150.0, 0.4, true, 4.0)
					app._play("break")


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
	var R := float(CELL)
	match t:
		SLOPE_R: return bot - lx
		SLOPE_L: return top + lx
		GSL_R_LO: return bot - lx * 0.5
		GSL_R_HI: return bot - CELL * 0.5 - lx * 0.5
		GSL_L_HI: return top + lx * 0.5
		GSL_L_LO: return top + CELL * 0.5 + lx * 0.5
		# rampes courbes (quart de cercle, rayon = CELL) — montant ↗ / descendant ↘, bombé / creux
		CURVE_RU_CV: return top + sqrt(maxf(0.0, R * R - lx * lx))            # bas→haut, convexe
		CURVE_RU_CC: return bot - sqrt(maxf(0.0, R * R - (R - lx) * (R - lx))) # bas→haut, concave
		CURVE_RD_CV: return top + sqrt(maxf(0.0, R * R - (R - lx) * (R - lx))) # haut→bas, convexe
		CURVE_RD_CC: return bot - sqrt(maxf(0.0, R * R - lx * lx))            # haut→bas, concave
	return INF


# colle le joueur sur le support le plus HAUT sous l'empreinte des pieds
# (pentes ET blocs pleins, échantillonné gauche/centre/droite). Gère la jonction pente↔sol sans à-coups.
func _slope_snap() -> void:
	if pvel.y < 0: return
	var sy := _support_y()
	if sy == INF: return
	var feet := ppos.y + PSIZE.y
	if feet >= sy - SLOPE_SNAP_DOWN and feet <= sy + SLOPE_SNAP_UP:
		ppos.y = sy - PSIZE.y
		pvel.y = 0.0
		on_floor = true


func _support_y() -> float:
	var feet := ppos.y + PSIZE.y
	var foot_row := int(feet / CELL)
	var best := INF
	for fx: float in [ppos.x + 4.0, ppos.x + PSIZE.x * 0.5, ppos.x + PSIZE.x - 4.0]:
		var col := int(fx / CELL)
		var lx: float = fx - col * CELL
		for dy in [-1, 0, 1]:
			var c := Vector2i(col, foot_row + dy)
			var t: int = app.grid.get(c, EMPTY)
			var sy := INF
			if _is_slope(t):
				sy = _slope_surface(t, c, lx)
			elif _is_full_solid(t):
				sy = float(c.y * CELL)
			if sy == INF: continue
			if sy >= (foot_row - 1) * CELL - 2 and sy <= (foot_row + 1) * CELL + 2:
				if sy < best: best = sy
	return best


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


# =================================================== mode SONIC (capteurs + quadrants)
# un point du monde est-il dans du solide ? (blocs pleins + dessous des pentes/courbes)
func _solid_at(p: Vector2, check_loops: bool = true) -> bool:
	var c := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
	var t: int = app.grid.get(c, EMPTY)
	if crumbled.has(c) or fb_trig.has(c): t = EMPTY   # friable rompue / bloc tombé → non solide
	if t != EMPTY:
		if _is_full_solid(t): return true
		if t == GATE and not open_gate_cells.has(c): return true   # grille fermée (couleur)
		if _is_slope(t):
			var lx: float = clampf(p.x - c.x * CELL, 0.0, CELL)
			if p.y >= _slope_surface(t, c, lx): return true
	for pl in plats:   # plateformes mobiles : solides aussi en mode Sonic
		if Rect2(pl.pos, Vector2(int(pl.get("w", 1)) * CELL, 14)).has_point(p):
			return true
	# NOTE loops : les anneaux ne sont PAS solides — le joueur les parcourt via
	# le RAIL paramétrique (_rail_update). check_loops conservé pour l'API.
	return false


# capteur : depuis origin, balaie le long de dir de -ext à +ext ; renvoie la distance
# (signée) du 1er solide rencontré en venant de l'extérieur, ou INF.
func _cast(origin: Vector2, dir: Vector2, ext: float) -> float:
	var step := 3.0
	var n := int(ext / step)
	for i in range(-n, n + 1):
		if _solid_at(origin + dir * (i * step)):
			return i * step
	return INF


# surface (Y) la plus proche de ref_y dans la colonne de x (pentes/courbes/blocs pleins)
func _surf_y(x: float, ref_y: float) -> float:
	var col := int(x / CELL)
	var lx: float = clampf(x - col * CELL, 0.0, CELL)
	var row0 := int(ref_y / CELL)
	var best := INF; var bestd := INF
	for row in range(row0 - 2, row0 + 3):
		var c := Vector2i(col, row)
		if crumbled.has(c) or fb_trig.has(c): continue
		var t: int = app.grid.get(c, EMPTY)
		var sy := INF
		if _is_slope(t):
			sy = _slope_surface(t, c, lx)
		elif _is_full_solid(t) and not _under_slope(c):   # ignore le sol sous une pente
			sy = float(row * CELL)
		if sy == INF: continue
		var d: float = absf(sy - ref_y)
		if d < bestd: bestd = d; best = sy
	return best


func _ground_angle(x: float, foot_y: float) -> float:
	var d := 7.0
	var y1 := _surf_y(x - d, foot_y)
	var y2 := _surf_y(x + d, foot_y)
	if y1 == INF or y2 == INF: return gangle
	return atan2(y2 - y1, 2.0 * d)


# ====================== LOOP = RAIL paramétrique (méthode fiable) ======================
# Le joueur sur un loop n'est PAS géré par capteurs : sa position = un angle θ
# sur le cercle, avancé de gsp/r par frame. Déterministe : zéro snap, zéro dérive.
# Entrée : au sol, en franchissant le bord de l'ouverture (toutes vitesses).
# Pente : sin(gangle) freine en montée → trop lent = redescend et ressort. Naturel.
# Sortie : θ revient dans l'ouverture → reposé au sol, cooldown anti-recapture.
func _rail_try_enter(pc: Vector2) -> void:
	for lp in active_loops:
		var cl: int = int(lp.get("cleared", 0))   # 0=armé, +1=validé vers la droite, -1=vers la gauche
		if cl != 0 and (cl > 0) == (gsp > 0.0): continue   # déverrouillé DANS CE SENS → traverse
		var lc: Vector2 = lp.center
		var r_in: float = lp.radius - LOOP_WALL - PSIZE.y * 0.5
		var d: float = (pc - lc).length()
		# capture au CONTACT du mur, tolérante à l'alignement grille/sol
		# (le cercle est forcément enterré OU flottant d'une demi-case)
		if d < r_in - 4.0 or d > lp.radius + 28.0: continue
		var th: float = atan2(pc.y - lc.y, pc.x - lc.x)
		if sin(th) < 0.25: continue                   # moitié basse uniquement
		var fb: float = absf(wrapf(th - PI * 0.5, -PI, PI))
		if fb <= 0.02 or fb > 1.2: continue
		# direction : il faut avancer VERS le mur…
		var toward: bool = (gsp > 0.0 and th < PI * 0.5) or (gsp < 0.0 and th > PI * 0.5)
		if not toward: continue
		# …ET dans le SENS imposé par le côté d'entrée (entré à gauche → vers la droite)
		var side: int = int(lp.get("side", 0))
		if side != 0 and (side > 0) != (gsp > 0.0): continue
		rail_lp = lp
		rail_th = th
		rail_topped = false
		lp["cleared"] = 0
		rail_r = clampf(d, r_in, lp.radius + 30.0)   # part d'où on est : zéro snap
		rail_fb0 = fb
		rail_exit_y = ppos.y                  # hauteur du sol pour la sortie
		return


func _rail_update(delta: float, ix: int) -> void:
	var lp = rail_lp
	var lc: Vector2 = lp.center
	var r_in: float = lp.radius - LOOP_WALL - PSIZE.y * 0.5   # pieds sur la surface interne
	var r_fl: float = lp.radius - PSIZE.y * 0.5               # pieds au niveau du plancher
	# tangente actuelle (sert à l'accélération et aux détachements)
	gangle = wrapf(atan2(-cos(rail_th), sin(rail_th)), -PI, PI)
	# accélération / friction / pente : MÊMES règles que le sol
	if ix != 0:
		if gsp == 0.0 or signf(float(ix)) == signf(gsp):
			gsp += ix * SONIC_ACC * delta
		else:
			gsp += ix * SONIC_DEC * delta
	else:
		gsp = move_toward(gsp, 0.0, SONIC_FRIC * delta)
	gsp += sin(gangle) * SONIC_SLOPE * delta
	gsp = clampf(gsp, -SONIC_TOP, SONIC_TOP)
	# saut : quitte le rail (normale = vers le centre)
	if jbuf > 0.0:
		jbuf = 0.0
		var up := -Vector2(cos(rail_th), sin(rail_th))
		pvel = Vector2(cos(gangle), sin(gangle)) * gsp + up * SONIC_JUMP
		rail_lp = null
		if rail_topped: lp["cleared"] = 1 if gsp >= 0.0 else -1
		sonic_grounded = false; on_floor = false
		gangle = 0.0
		app.squash = Vector2(0.78, 1.25)
		Input.start_joy_vibration(0, 0.10, 0.25, 0.07); app._play("jump")
		return
	# trop lent : sur les MURS on reste collé au rail (la pente fait reglisser
	# vers le bas) ; on ne décroche qu'au PLAFOND (>135°) → chute À L'INTÉRIEUR
	# du loop, jamais de l'autre côté
	var deg: float = absf(rad_to_deg(gangle))
	if absf(gsp) < 120.0 and deg > 135.0:
		pvel = Vector2(cos(gangle), sin(gangle)) * gsp
		rail_lp = null
		if rail_topped: lp["cleared"] = 1 if gsp >= 0.0 else -1
		sonic_grounded = false; on_floor = false
		gsp = 0.0
		return
	# avance le long du cercle (θ décroît quand on va à droite)
	rail_th = wrapf(rail_th - (gsp / rail_r) * delta, -PI, PI)
	# franchir le SOMMET (milieu haut) = loop validé → il deviendra traversable
	if absf(wrapf(rail_th + PI * 0.5, -PI, PI)) < 0.25:
		rail_topped = true
	var fb: float = absf(wrapf(rail_th - PI * 0.5, -PI, PI))
	# sortie : revenu à l'angle où le sol rencontre le cercle (des 2 côtés).
	# Loop validé (sommet franchi) → traversable jusqu'à quitter sa zone ;
	# glissade ratée → le loop reste actif.
	if fb <= rail_fb0:
		ppos.x = lc.x + cos(rail_th) * (lp.radius if rail_fb0 > LOOP_OPEN else rail_r) - PSIZE.x * 0.5
		ppos.y = rail_exit_y          # exactement la hauteur de sol de l'entrée
		rail_lp = null
		if rail_topped: lp["cleared"] = 1 if gsp >= 0.0 else -1
		lp["side"] = -1 if gsp >= 0.0 else 1   # sorti vers la droite = désormais "entré par la droite"
		gangle = 0.0
		on_floor = true
		return
	# rayon des pieds : converge en douceur vers la surface interne (zéro snap)
	rail_r = move_toward(rail_r, r_in, 260.0 * delta)
	var new_pc: Vector2 = lc + Vector2(cos(rail_th), sin(rail_th)) * rail_r
	ppos = new_pc - PSIZE * 0.5
	on_floor = true
	land_debug = "RAIL θ=%.0f° gsp=%.0f" % [rad_to_deg(rail_th), gsp]


func _sonic_physics(delta: float) -> void:
	input_x = _dir_x()
	jbuf -= delta
	switch_cd -= delta
	var ix := autorun_dir if _autorun() else input_x
	var pc := ppos + PSIZE * 0.5
	land_debug = "gsp=%.0f ang=%.0f°" % [gsp, rad_to_deg(gangle)]

	# zones de loop : le CÔTÉ d'entrée dans la zone fixe le sens unique de prise ;
	# sommet franchi → sortie déverrouillée (cleared, directionnel) ; quitter la
	# zone réarme tout
	for lp in active_loops:
		var dl: float = (pc - lp.center).length()
		if dl > lp.radius + 60.0:
			lp["cleared"] = 0
			lp["side"] = 0
		elif int(lp.get("side", 0)) == 0 and pc.y > lp.center.y:
			lp["side"] = 1 if pc.x < lp.center.x else -1   # +1 = entré par la GAUCHE → prise vers la droite


	var in_water := _in_water()
	if in_water != was_in_water:
		app._emit(pc, 10, Color("aee3f0"), 170.0, 0.35, true, 3.0)
		app._shake(2.0, 0.08)
	was_in_water = in_water
	_update_air(delta, in_water)

	if sonic_grounded:
		# === RAIL de loop : entrée puis suivi paramétrique (cercle exact) ===
		if rail_lp == null:
			_rail_try_enter(pc)
		if rail_lp != null:
			_rail_update(delta, ix)
			return
		# accélération / friction le long de la surface
		if ix != 0:
			if gsp == 0.0 or signf(float(ix)) == signf(gsp):
				gsp += ix * SONIC_ACC * delta
			else:
				gsp += ix * SONIC_DEC * delta
		else:
			gsp = move_toward(gsp, 0.0, SONIC_FRIC * delta)
		gsp += sin(gangle) * SONIC_SLOPE * delta   # gravité projetée sur la pente
		if in_water: gsp *= WATER_DRAG   # eau : freine la course
		gsp = clampf(gsp, -SONIC_TOP, SONIC_TOP)

		if jbuf > 0.0:
			jbuf = 0.0
			sonic_grounded = false
			var up := Vector2(sin(gangle), -cos(gangle))   # normale surface (vers le haut)
			pvel = Vector2(cos(gangle), sin(gangle)) * gsp + up * SONIC_JUMP
			gangle = 0.0
			app.squash = Vector2(0.78, 1.25)
			Input.start_joy_vibration(0, 0.10, 0.25, 0.07); app._play("jump")
		else:
			# avance le long de la tangente, puis re-capte le sol (capteurs)
			pc += Vector2(cos(gangle), sin(gangle)) * gsp * delta
			if _ground_sense(pc):
				on_floor = true
				# chute seulement vers le plafond si trop lent (sur les murs on glisse, pas de détach)
				var deg: float = absf(rad_to_deg(gangle))
				if absf(gsp) < 120.0 and deg > 100.0 and deg < 260.0:
					pvel = Vector2(cos(gangle), sin(gangle)) * gsp   # sync avant de quitter le sol
					sonic_grounded = false
					gsp = 0.0
			else:
				sonic_grounded = false
				on_floor = false
				ppos = pc - PSIZE * 0.5
				pvel = Vector2(cos(gangle), sin(gangle)) * gsp
	else:
		pvel.x += ix * SONIC_AIR_ACC * delta
		pvel.x = clampf(pvel.x, -SONIC_TOP, SONIC_TOP)
		if in_water:
			pvel.x *= WATER_DRAG
			pvel.y = clampf(pvel.y + GRAVITY * WATER_GRAV * delta, WATER_RISE, WATER_SINK)
			if _water_swim() and jbuf > 0.0:   # brasse vers le haut (répétable)
				pvel.y = WATER_SWIM; jbuf = 0.0
				app._emit(pc - Vector2(0.0, PSIZE.y * 0.5), 5, Color("aee3f0"), 120.0, 0.3, false, 3.0)
				app._play("jump")
		else:
			pvel.y = min(pvel.y + GRAVITY * delta, MAX_FALL)
		gangle = move_toward(gangle, 0.0, deg_to_rad(360.0) * delta)   # se remet droit en l'air
		pc += pvel * delta
		pc.x = clampf(pc.x, PSIZE.x * 0.5, app.cols * CELL - PSIZE.x * 0.5)
		# collision X murs (loop exclus : le mur ext. ne bloque pas l'approche au sol)
		var hw := PSIZE.x * 0.5
		for frac: float in [0.0, 0.35, -0.35]:
			if _solid_at(pc + Vector2(hw, frac * PSIZE.y), false):
				pc.x = floor((pc.x + hw) / CELL) * CELL - hw
				pvel.x = minf(0.0, pvel.x)
				break
			if _solid_at(pc + Vector2(-hw, frac * PSIZE.y), false):
				pc.x = ceil((pc.x - hw) / CELL) * CELL + hw
				pvel.x = maxf(0.0, pvel.x)
				break
		# collision Y plafond (loop exclus pour la même raison)
		if pvel.y < 0.0:
			var hh := PSIZE.y * 0.5
			for fdx: float in [0.0, hw - 2.0, -(hw - 2.0)]:
				if _solid_at(pc + Vector2(fdx, -hh), false):
					pc.y = floor((pc.y - hh) / CELL + 1.0) * CELL + hh
					pvel.y = 0.0
					break
		ppos = pc - PSIZE * 0.5
		on_floor = false
		if pvel.y >= 0.0:
			_try_land(delta)


func _point_in_loop(p: Vector2) -> bool:
	for lp in active_loops:
		var lc: Vector2 = lp.center
		var lr: float = lp.radius
		var d: float = (p - lc).length()
		if d >= lr - LOOP_WALL and d <= lr:
			var theta: float = atan2(p.y - lc.y, p.x - lc.x)
			if absf(wrapf(theta - PI * 0.5, -PI, PI)) > LOOP_OPEN:
				return true
	return false


# capte le sol AUX CAPTEURS uniquement (méthode Sonic Physics Guide) : le loop
# n'est PAS un objet spécial — c'est une surface solide continue que les sondes
# suivent comme n'importe quelle pente. Pas d'état "attaché", pas de snap :
# trop lent dans le mur = la pente (sin(gangle)) te fait reglisser naturellement.
func _ground_sense(pc: Vector2) -> bool:
	var dn := Vector2(-sin(gangle), cos(gangle))
	var fw := Vector2(cos(gangle), sin(gangle))
	var reach := PSIZE.y * 0.5 + 22.0
	var dc := _cast(pc, dn, reach)
	# ONEWAY invisible à _solid_at — check séparé quand sol plat uniquement
	if dc == INF and absf(gangle) < deg_to_rad(5.0):
		var ow_dc := _cast_down_oneway(pc, reach)
		if ow_dc != INF and ow_dc > 0.0:
			pc += dn * (ow_dc - PSIZE.y * 0.5)
			ppos = pc - PSIZE * 0.5
			return true
	if dc == INF:
		return false

	pc += dn * clampf(dc - PSIZE.y * 0.5, -20.0, 20.0)

	var off := 10.0
	var oa := pc + fw * (-off)
	var ob := pc + fw * (off)
	var da := _cast(oa, dn, reach + 12.0)
	var db := _cast(ob, dn, reach + 12.0)
	if da != INF and db != INF and absf(da - db) < CELL:
		var ha := oa + dn * da
		var hb := ob + dn * db
		var raw := atan2(hb.y - ha.y, hb.x - ha.x)
		var diff := angle_difference(gangle, raw)
		# lissage 18°/frame en temps normal ; jonction brutale (vallée en V) =
		# rotation accélérée mais PLAFONNÉE (45°/frame) : assez vite pour ne pas
		# labourer la pente opposée, sans téléporter la position (recale ≤20px/frame)
		var max_step: float = deg_to_rad(18.0)
		if absf(diff) >= deg_to_rad(30.0):
			max_step = deg_to_rad(45.0)
		var step: float = clampf(diff, -max_step, max_step)
		gangle = wrapf(gangle + step, -PI, PI)
	ppos = pc - PSIZE * 0.5
	return true


# atterrissage depuis l'air : capteurs monde-bas sous les pieds
func _try_land(delta: float) -> void:
	var pc := ppos + PSIZE * 0.5
	var reach := PSIZE.y * 0.5 + maxf(10.0, absf(pvel.y) * delta + 4.0)
	var dc := _cast_down(pc, reach)
	# ONEWAY : non détecté par _solid_at, scan séparé
	var ow_dc := _cast_down_oneway(pc, reach)
	if ow_dc != INF and ow_dc < dc:
		if ow_dc == 0.0: return
		pc.y += ow_dc - PSIZE.y * 0.5
		ppos = pc - PSIZE * 0.5
		sonic_grounded = true; on_floor = true; gangle = 0.0
		gsp = pvel.x
		app.squash = Vector2(1.28, 0.72)
		return
	if dc == INF: return
	if dc == 0.0: return  # centre déjà dans un solide → pas d'atterrissage
	# vérification analytique : pente au point d'impact (dérivée de _slope_surface)
	var hit_p := pc + Vector2(0.0, dc)
	var hc := Vector2i(int(floor(hit_p.x / CELL)), int(floor(hit_p.y / CELL)))
	var ht: int = app.grid.get(hc, EMPTY)
	var slope_val := 0.0
	if ht in [CURVE_RU_CV, CURVE_RU_CC, CURVE_RD_CV, CURVE_RD_CC]:
		var lx_h := clampf(hit_p.x - hc.x * CELL, 0.001, CELL - 0.001)
		var R := float(CELL)
		match ht:
			CURVE_RU_CV, CURVE_RD_CC:
				slope_val = lx_h / sqrt(maxf(0.001, R * R - lx_h * lx_h))
			CURVE_RU_CC, CURVE_RD_CV:
				var v := R - lx_h
				slope_val = v / sqrt(maxf(0.001, R * R - v * v))
		land_debug = "dc=%.0f ht=%d lx=%.1f sl=%.2f" % [dc, ht, hit_p.x - hc.x * CELL, slope_val]
		if slope_val > tan(deg_to_rad(70.0)):
			land_debug += " →SKIP"
			return
	else:
		land_debug = "dc=%.0f ht=%d(flat)" % [dc, ht]
	# angle : sondes bidirectionnelles (gère surface plus haute que pc)
	var dn := Vector2(0.0, 1.0)
	var off := 10.0
	var da := _cast(pc + Vector2(-off, 0.0), dn, reach + 12.0)
	var db := _cast(pc + Vector2(off, 0.0), dn, reach + 12.0)
	gangle = 0.0
	if da != INF and db != INF and absf(da - db) < CELL:
		var ha := pc + Vector2(-off, da)
		var hb := pc + Vector2(off, db)
		gangle = atan2(hb.y - ha.y, hb.x - ha.x)
	if absf(gangle) > deg_to_rad(70.0):
		return
	# position : snap capteur central après calcul angle
	pc.y += dc - PSIZE.y * 0.5
	ppos = pc - PSIZE * 0.5
	sonic_grounded = true
	on_floor = true
	gsp = pvel.dot(Vector2(cos(gangle), sin(gangle)))
	app.squash = Vector2(1.28, 0.72)


# capteur vers le bas (monde) uniquement : distance au 1er solide sous origin, ou INF
func _cast_down(origin: Vector2, ext: float) -> float:
	var step := 3.0
	var n := int(ext / step)
	for i in range(0, n + 1):
		if _solid_at(origin + Vector2(0, i * step)):
			return i * step
	return INF


func _cast_down_oneway(origin: Vector2, ext: float) -> float:
	var step := 3.0
	var n := int(ext / step)
	for i in range(0, n + 1):
		var p := origin + Vector2(0.0, float(i) * step)
		var c := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
		if app.grid.get(c, EMPTY) == ONEWAY:
			return float(i) * step
	return INF


func _in_water() -> bool:
	var c := Vector2i(int((ppos.x + PSIZE.x * 0.5) / CELL), int((ppos.y + PSIZE.y * 0.5) / CELL))
	return app.grid.get(c, EMPTY) == WATER


func _water_swim() -> bool:
	var ap = app.get("level_props")
	return ap != null and ap.get("water_swim", false)


func _water_drown() -> bool:
	var ap = app.get("level_props")
	return ap != null and ap.get("water_drown", false)


func _update_air(delta: float, in_water: bool) -> void:
	# noyade : décompte d'air sous l'eau ; remonter (tête hors de l'eau) recharge.
	if in_water and _water_drown():
		air_t -= delta
		if air_t <= 0.0:
			air_t = AIR_MAX
			_kill()
	else:
		air_t = AIR_MAX


# =================================================== hooks de rendu (TemplateBase._draw)
# rendu jeu specifique : loopings + plateformes mobiles + hazards
func _draw_world_extra() -> void:
	for lp in active_loops:
		_draw_loop_ring(app._w2s(lp.center), lp.radius * app.view_scale)
	# debug (toggle FPS) : zones du loop — capture (bas), sommet, réarmement, point rail
	if app.get("show_fps") == true and _sonic():
		var vs: float = app.view_scale
		for lp in active_loops:
			var c: Vector2 = app._w2s(lp.center)
			var r_in: float = lp.radius - LOOP_WALL - PSIZE.y * 0.5
			var armed: bool = int(lp.get("cleared", 0)) == 0
			var col := Color(0.2, 1.0, 0.3, 0.7) if armed else Color(0.65, 0.65, 0.65, 0.5)
			# bande de capture (moitié basse) : intérieur + extérieur
			draw_arc(c, (r_in - 4.0) * vs, 0.25, PI - 0.25, 24, col, 2.0)
			draw_arc(c, (lp.radius + 28.0) * vs, 0.25, PI - 0.25, 24, col, 2.0)
			# zone sommet (validation)
			draw_arc(c, lp.radius * vs, -PI * 0.5 - 0.25, -PI * 0.5 + 0.25, 8, Color(1.0, 0.85, 0.2, 0.9), 4.0)
			# rayon de réarmement (sortie consommée au-delà)
			draw_arc(c, (lp.radius + 60.0) * vs, 0.0, TAU, 48, Color(0.3, 0.7, 1.0, 0.3), 1.5)
		# position exacte sur le rail
		if rail_lp != null:
			var rp: Vector2 = rail_lp.center + Vector2(cos(rail_th), sin(rail_th)) * rail_r
			draw_circle(app._w2s(rp), 5.0, Color(1.0, 0.25, 0.25))
	for p in plats:
		for wi in int(p.get("w", 1)):
			draw_tile(self, app._w2s(p.pos + Vector2(wi * CELL, 0)), MOVPLAT, app.view_scale)
	for h in hazards:
		if h.type == "firebar":
			var pivot: Vector2 = app._w2s(h.center)
			draw_circle(pivot, 6.0 * app.view_scale, Color("c0392b"))
			for i in range(1, FIREBAR_LEN + 1):
				var fp: Vector2 = h.center + Vector2(cos(h.ang), sin(h.ang)) * (float(i) * CELL * 0.5)
				var fs: Vector2 = app._w2s(fp)
				draw_circle(fs, (13.0 - float(i)) * app.view_scale, Color("e8521f"))
				draw_circle(fs, (7.0 - float(i) * 0.6) * app.view_scale, Color("ffce54"))
		elif h.type == "fallblock":
			draw_tile(self, app._w2s(h.pos), FALLBLOCK, app.view_scale)


# apercu des loopings en edition (depuis la grille)
func _draw_edit_extra(cx0: int, cx1: int, cy0: int, cy1: int) -> void:
	for k in app.grid:
		if app.grid[k] != LOOP_CENTER:
			continue
		if k.x < cx0 - 4 or k.x > cx1 + 4 or k.y < cy0 - 4 or k.y > cy1 + 4:
			continue
		_draw_loop_ring(app._w2s(Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL)), LOOP_R * app.view_scale)


# joueur : carre droit (base) ou tourne selon l'angle du sol en mode Sonic
func _draw_player() -> void:
	if not _sonic():
		super()
		return
	var ps: Vector2 = PSIZE * app.squash
	var ctr: Vector2 = app._w2s(ppos + PSIZE * 0.5)
	var hx: float = ps.x * 0.5 * app.view_scale
	var hy: float = ps.y * 0.5 * app.view_scale
	var co := cos(gangle); var si := sin(gangle)
	var corners := PackedVector2Array()
	for o in [Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]:
		corners.append(ctr + Vector2(o.x * co - o.y * si, o.x * si + o.y * co))
	draw_colored_polygon(corners, Color("ffffff"))
	var outline := corners; outline.append(corners[0])
	draw_polyline(outline, Color("2c3e50"), 2.0)


func _draw_loop_ring(center_s: Vector2, r_s: float) -> void:
	var wt_s: float = LOOP_WALL * float(app.view_scale)
	var col := COLORS[GROUND]
	var n := 72
	for i in n:
		var a0: float = i * TAU / n
		var a1: float = (i + 1.0) * TAU / n
		var amid: float = (a0 + a1) * 0.5
		if absf(wrapf(amid - PI * 0.5, -PI, PI)) <= LOOP_OPEN:
			continue
		var p0: Vector2 = center_s + Vector2(cos(a0), sin(a0)) * (r_s - wt_s)
		var p1: Vector2 = center_s + Vector2(cos(a1), sin(a1)) * (r_s - wt_s)
		var p2: Vector2 = center_s + Vector2(cos(a1), sin(a1)) * r_s
		var p3: Vector2 = center_s + Vector2(cos(a0), sin(a0)) * r_s
		draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), col)
	var ht := col.lightened(0.12)
	for i in n:
		var a0: float = i * TAU / n
		var a1: float = (i + 1.0) * TAU / n
		var amid: float = (a0 + a1) * 0.5
		if absf(wrapf(amid - PI * 0.5, -PI, PI)) <= LOOP_OPEN: continue
		draw_line(center_s + Vector2(cos(a0), sin(a0)) * (r_s - wt_s * 0.15),
			center_s + Vector2(cos(a1), sin(a1)) * (r_s - wt_s * 0.15), ht, wt_s * 0.18)
