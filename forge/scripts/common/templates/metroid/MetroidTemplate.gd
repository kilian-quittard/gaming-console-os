extends PlatformerTemplate
class_name MetroidTemplate
# Genre METROIDVANIA : platformer (physique héritée) + exploration gated.
# Tir (rayon + missiles), capacités ramassables (double-saut, morph ball),
# portes gated (tir / missile), conduits morph, réservoirs d'énergie.
# Le monde = plusieurs niveaux reliés par des warps (infra multi-niveaux).

const SHOT_SPEED := 620.0
const SHOT_CD := 0.22
const MISSILE_SPEED := 480.0

# capacités du run (reset au start ; le créateur les place comme objets)
var has_djump := false
var has_morph := false
var missiles := 0
var max_missiles := 0
var morphed := false
var air_jumps := 0
var face_x := 1
var pshots := []          # tirs du joueur {pos, vel, alive, missile}
var shot_cd := 0.0
var missile_held := false # debounce gâchette/touche missile

const MD_CATS := [
	{"name": "Terrain", "tiles": [GROUND, SLOPE_R, SLOPE_L, ONEWAY, LADDER, BREAKABLE, CRUMBLE]},
	{"name": "Metroid", "tiles": [DOOR_BEAM, DOOR_MISSILE, MORPH_TUBE, ITEM_DJUMP, ITEM_MORPH, ITEM_MISSILE, ENERGY]},
	{"name": "Danger",  "tiles": [SPIKE, LAVA, FIREBAR]},
	{"name": "Ennemis", "tiles": [ENEMY, FLYER, CHASER, SHOOTER, BOSS]},
	{"name": "Items",   "tiles": [COIN, KEY, DOOR]},
	{"name": "Reperes", "tiles": [SPAWN, GOAL, CHECKPOINT, WARP]},
	{"name": "Decor",   "tiles": [PALM, TREE, BUSH, FLOWER]},
]
func categories() -> Array: return MD_CATS
func default_hp() -> int: return 3       # énergie : cœurs activés par défaut
func wants_room_camera() -> bool: return String(app.level_props.get("cam", "rooms")) == "rooms"


func play_badges() -> Array:
	return [["←→", "Bouger"], ["A", "Sauter"], ["X", "Tir"], ["L1", "Missile"], ["↓", "Morph"], ["ST", "Éditeur"]]


func play_hud_text() -> String:
	var caps := []
	if has_djump: caps.append("2×SAUT")
	if has_morph: caps.append("MORPH")
	var txt := "  ".join(caps)
	if max_missiles > 0:
		txt += ("   " if txt != "" else "") + "MISSILES %d/%d" % [missiles, max_missiles]
	return txt


func seed_demo() -> void:
	var grid: Dictionary = app.grid
	var rows: int = app.rows
	grid.clear()
	# salle 1 : sol, item double-saut sur une corniche, porte tir vers la droite
	for x in range(0, 30):
		grid[Vector2i(x, rows - 1)] = GROUND
	grid[Vector2i(2, rows - 2)] = SPAWN
	for x in range(8, 11): grid[Vector2i(x, rows - 4)] = GROUND
	grid[Vector2i(9, rows - 5)] = ITEM_DJUMP
	# mur avec porte tir
	for y in range(rows - 6, rows - 1): grid[Vector2i(14, y)] = GROUND
	grid[Vector2i(14, rows - 2)] = DOOR_BEAM
	# conduit morph sous une avancée
	for x in range(18, 22):
		grid[Vector2i(x, rows - 3)] = GROUND
		grid[Vector2i(x, rows - 2)] = MORPH_TUBE
	grid[Vector2i(16, rows - 2)] = ITEM_MORPH
	grid[Vector2i(23, rows - 2)] = ENEMY
	grid[Vector2i(26, rows - 4)] = ITEM_MISSILE
	for y in range(rows - 6, rows - 1): grid[Vector2i(28, y)] = GROUND
	grid[Vector2i(28, rows - 2)] = DOOR_MISSILE
	grid[Vector2i(29, rows - 2)] = GOAL
	app.cursor = Vector2i(4, rows - 3)


func start_play(from_cursor: bool) -> void:
	super(from_cursor)
	has_djump = false; has_morph = false
	missiles = 0; max_missiles = 0
	morphed = false; air_jumps = 0; face_x = 1
	pshots = []; shot_cd = 0.0; missile_held = false


# conduit morph : traversable uniquement en boule
func _cell_solid(c: Vector2i) -> bool:
	if morphed and app.grid.get(c, EMPTY) == MORPH_TUBE:
		return false
	return super(c)


# double-saut : un saut aérien si la capacité est acquise
func jump_pressed() -> void:
	if not dead and not won and not on_floor and coyote_t <= 0.0 and has_djump and air_jumps > 0 and not morphed:
		air_jumps -= 1
		pvel.y = JUMP_V * 0.92
		app.squash = Vector2(0.78, 1.25)
		app._emit(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y), 8, Color("4cd6b3"), 160.0, 0.3, false, 3.0)
		app._play("jump")
		return
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if app == null or app.screen != "edit" or app.mode != "play" or won or dead:
		return
	if on_floor: air_jumps = 1
	if input_x != 0: face_x = input_x
	# morph ball : ↓ pour se mettre en boule, ↑ ou saut pour se relever
	if has_morph:
		if _dir_y() > 0 and not morphed:
			morphed = true; app._play("key")
		elif morphed and (_dir_y() < 0 or jbuf > 0.0):
			morphed = false
	# tir / missile (pas en morph)
	if shot_cd > 0.0: shot_cd -= delta
	if not morphed:
		_shoot_input()
	_update_pshots(delta)
	_pickup_items()


func _shoot_input() -> void:
	var beam := Input.is_key_pressed(KEY_X) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	var msl := Input.is_key_pressed(KEY_C) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)
	var aim_up := _dir_y() < 0
	if beam and shot_cd <= 0.0:
		shot_cd = SHOT_CD
		_fire(false, aim_up)
	if msl and not missile_held and missiles > 0:
		missiles -= 1
		_fire(true, aim_up)
	missile_held = msl


func _fire(is_missile: bool, aim_up: bool) -> void:
	var origin := ppos + PSIZE * 0.5
	var dir := Vector2(0, -1) if aim_up else Vector2(face_x, 0)
	origin += dir * PSIZE.x * 0.5
	var spd := MISSILE_SPEED if is_missile else SHOT_SPEED
	pshots.append({"pos": origin, "vel": dir * spd, "alive": true, "missile": is_missile})
	app._emit(origin, 3, Color("ff7043") if is_missile else Color("9be7ff"), 100.0, 0.15, false, 2.0)
	app._play("spring" if is_missile else "jump")


func _update_pshots(delta: float) -> void:
	for s in pshots:
		if not s.alive: continue
		s.pos += s.vel * delta
		var cc := Vector2i(int(s.pos.x / CELL), int(s.pos.y / CELL))
		var t: int = app.grid.get(cc, EMPTY)
		# portes gated : le bon projectile les ouvre
		if t == DOOR_BEAM or (t == DOOR_MISSILE and s.missile):
			app.grid.erase(cc)
			app._emit(_cell_center(cc), 14, COLORS[t], 220.0, 0.45, true, 4.0)
			app._shake(4.0, 0.15); app._play("break")
			s.alive = false; continue
		if _solid_tile(cc) or s.pos.x < 0 or s.pos.x > app.cols * CELL or s.pos.y < 0:
			s.alive = false; continue
		# ennemis : dégâts (missile = 3)
		var sr := Rect2(s.pos - Vector2(6, 6), Vector2(12, 12))
		for en in enemies:
			if not en.alive: continue
			var esz: float = BOSS_SIZE if en.type == "boss" else float(ESIZE)
			if sr.intersects(Rect2(en.pos, Vector2(esz, esz))):
				_md_damage(en, 3 if s.missile else 1)
				s.alive = false
				break
	pshots = pshots.filter(func(p): return p.alive)


# dégâts infligés à un ennemi par un tir (boss = FSM hurt/enrage)
func _md_damage(en: Dictionary, dmg: int) -> void:
	if en.type == "boss":
		if en.inv > 0.0: return
		en.hp -= dmg; en.inv = BOSS_INV
		app._emit(en.pos + Vector2(BOSS_SIZE, BOSS_SIZE) * 0.5, 14, COLORS[BOSS].lightened(0.3), 220.0, 0.4, true, 4.0)
		app._shake(5.0, 0.15); app._play("stomp")
		if en.hp <= 0:
			en.alive = false
			app._emit(en.pos + Vector2(BOSS_SIZE, BOSS_SIZE) * 0.5, 40, COLORS[BOSS], 320.0, 0.9, true, 6.0)
			app._shake(10.0, 0.4); app._play("win")
		elif not en.enraged and en.hp <= BOSS_ENRAGE_HP:
			en.state = "enrage"; en.st = 0.0; en.tele = false; en.queue = []
		else:
			en.state = "hurt"; en.st = 0.0; en.tele = false; en.queue = []
		return
	en["hp2"] = int(en.get("hp2", 2 if en.type in ["chaser", "shooter"] else 1)) - dmg
	if en["hp2"] <= 0:
		en.alive = false
		app._emit(en.pos + Vector2(ESIZE, ESIZE) * 0.5, 10, COLORS[ENEMY], 200.0, 0.4, true, 4.0)
		app._play("stomp")
	else:
		app._emit(en.pos + Vector2(ESIZE, ESIZE) * 0.5, 5, Color(1, 1, 1, 0.8), 140.0, 0.25, false, 3.0)


# pas de stomp en Metroid : contact ennemi = dégât (cœurs/i-frames gèrent)
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
			_:         _enemy_ground(en, delta)
		var esz: float = BOSS_SIZE if t == "boss" else float(ESIZE)
		if pr.intersects(Rect2(en.pos, Vector2(esz, esz))):
			if t == "boss" and en.inv > 0.0:
				continue
			_die()
	_update_projectiles(delta)
	_update_hazards(delta)


# ramassage des capacités / réservoirs
func _pickup_items() -> void:
	for c in _cells(Rect2(ppos, PSIZE)):
		match app.grid.get(c, EMPTY):
			ITEM_DJUMP:
				app.grid.erase(c); has_djump = true
				_item_fx(c, "Double-saut !")
			ITEM_MORPH:
				app.grid.erase(c); has_morph = true
				_item_fx(c, "Morph ball !  (↓ pour rouler)")
			ITEM_MISSILE:
				app.grid.erase(c); max_missiles += 5; missiles += 5
				_item_fx(c, "Missiles +5")
			ENERGY:
				app.grid.erase(c); max_hearts += 1; hearts = max_hearts
				_item_fx(c, "Énergie max +1")


func _item_fx(c: Vector2i, msg: String) -> void:
	app._emit(_cell_center(c), 18, Color("ffde59"), 240.0, 0.6, false, 4.0)
	app._shake(3.0, 0.15); app._play("win")
	app._set_toast(msg)


# rendu : boule en morph, indicateur de visée sinon
func _draw_player() -> void:
	if morphed:
		var ctr: Vector2 = app._w2s(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y * 0.7))
		var rad: float = PSIZE.x * 0.34 * app.view_scale
		draw_circle(ctr, rad, Color("ffb74d"))
		draw_circle(ctr, rad, Color("2c3e50"), false, 2.0)
		draw_arc(ctr, rad * 0.55, app.anim_t * 6.0, app.anim_t * 6.0 + PI, 10, Color("2c3e50"), 2.0)
		return
	super()
	# canon : trait dans la direction de tir
	var pc: Vector2 = app._w2s(ppos + PSIZE * 0.5)
	var dir := Vector2(0, -1) if _dir_y() < 0 else Vector2(face_x, 0)
	draw_line(pc + dir * 8.0 * app.view_scale, pc + dir * 20.0 * app.view_scale, Color("9be7ff"), 3.0 * app.view_scale)


func _draw_world_extra() -> void:
	super()
	# tirs du joueur
	for s in pshots:
		if not s.alive: continue
		var sp: Vector2 = app._w2s(s.pos)
		if s.missile:
			draw_circle(sp, 7.0 * app.view_scale, Color("ff7043"))
			draw_circle(sp - (s.vel.normalized() * 10.0 * app.view_scale), 4.0 * app.view_scale, Color(1.0, 0.8, 0.4, 0.5))
		else:
			draw_circle(sp, 5.0 * app.view_scale, Color("9be7ff"))
			draw_circle(sp, 2.5 * app.view_scale, Color.WHITE)
