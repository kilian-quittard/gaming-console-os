extends PlatformerTemplate
class_name TopDownTemplate
# Template VUE DE DESSUS. Réutilise tout le générique du platformer (fond, formes,
# lissage, projectiles, FSM de boss, comportements volant/chasseur, _interactions,
# rendu) et n'override que le GAMEPLAY : déplacement 8 directions (sans gravité),
# combat épée + tir, et le dessin (joueur orienté + overlays).

const TD_SPEED := 240.0     # vitesse de déplacement (px/s)
const TD_ATK_DUR := 0.18    # durée visuelle du coup d'épée
const TD_ATK_CD := 0.32     # cooldown épée
const TD_SHOOT_CD := 0.32   # cooldown tir
const TD_ATK_REACH := 30.0  # portée de l'arc d'épée

var face := Vector2.RIGHT   # direction regardée
var pshots := []            # projectiles DU JOUEUR {pos, vel, alive}
var atk_t := 0.0            # temps restant d'animation d'épée
var atk_cd := 0.0
var shoot_cd := 0.0

# palette de l'éditeur pour ce genre (mur = GROUND solide ; sol = case vide)
const TD_CATS := [
	{"name": "Mur",     "tiles": [GROUND, BREAKABLE]},
	{"name": "Repères", "tiles": [SPAWN, GOAL, DOOR, CHECKPOINT]},
	{"name": "Items",   "tiles": [COIN, KEY]},
	{"name": "Ennemis", "tiles": [ENEMY, CHASER, FLYER, SHOOTER, BOSS]},
	{"name": "Décor",   "tiles": [PALM, TREE, BUSH, FLOWER]},
]
func categories() -> Array: return TD_CATS
func movplat_tile() -> int: return -1   # pas de plateforme mobile en top-down
func default_hp() -> int: return 3      # PV par défaut en top-down (cœurs activés)
func _wants_parallax() -> bool: return false   # top-down : fond plat (pas de collines)


# sol dallé automatique sous TOUT le niveau (les objets se posent dessus sans l'écraser)
func _draw_ground(_clip_r: Rect2) -> void:
	var vp := get_viewport_rect().size
	var vs: float = app.view_scale
	var w_tl: Vector2 = app._s2w(Vector2.ZERO)
	var w_br: Vector2 = app._s2w(vp)
	var cx0: int = maxi(int(floor(w_tl.x / CELL)), 0)
	var cx1: int = mini(int(floor(w_br.x / CELL)) + 1, app.cols - 1)
	var cy0: int = maxi(int(floor(w_tl.y / CELL)), 0)
	var cy1: int = mini(int(floor(w_br.y / CELL)) + 1, app.rows - 1)
	var fc: Color = COLORS[FLOOR]
	var join: Color = fc.darkened(0.12)
	var cs: float = CELL * vs
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var p: Vector2 = app._w2s(Vector2(cx * CELL, cy * CELL))
			draw_rect(Rect2(p, Vector2(cs, cs)), fc)
			draw_line(p, p + Vector2(cs, 0), join, 1.0)
			draw_line(p, p + Vector2(0, cs), join, 1.0)

# pas de saut : l'action A déclenche l'épée (lue en direct dans _physics_process)
func jump_pressed() -> void: pass
func jump_released() -> void: pass


func seed_demo() -> void:
	app.grid.clear()
	var w := 26; var h := 14
	for x in range(w):
		app.grid[Vector2i(x, 0)] = GROUND
		app.grid[Vector2i(x, h - 1)] = GROUND
	for y in range(h):
		app.grid[Vector2i(0, y)] = GROUND
		app.grid[Vector2i(w - 1, y)] = GROUND
	# (sol dessiné automatiquement par _draw_ground — pas besoin de le peindre)
	# quelques obstacles
	for y in range(4, 8): app.grid[Vector2i(10, y)] = GROUND
	app.grid[Vector2i(3, 7)] = SPAWN
	app.grid[Vector2i(w - 3, 7)] = GOAL
	app.grid[Vector2i(15, 6)] = CHASER
	app.grid[Vector2i(18, 9)] = COIN
	app.cursor = Vector2i(3, 7)


func start_play(from_cursor: bool) -> void:
	super(from_cursor)
	face = Vector2.RIGHT; pshots = []; atk_t = 0.0; atk_cd = 0.0; shoot_cd = 0.0


func _physics_process(delta: float) -> void:
	if app == null or app.screen != "edit" or app.mode != "play" or won:
		return
	if dead:
		death_t -= delta
		if death_t <= 0.0:
			dead = false
			_build_entities()
			_place_player(respawn_cell)
			pvel = Vector2.ZERO
			pinv = 0.0; dashing = 0.0; dash_cd = 0.0; hearts = max_hearts
		queue_redraw(); app.queue_redraw()
		return

	# déplacement 8 directions (croix + stick), sans gravité
	var mv := Vector2(float(_dir_x()), float(_dir_y()))
	if mv.length() > 0.0:
		mv = mv.normalized()
		face = mv
	# dash / roulade : burst dans la direction regardée (i-frames)
	_tick_player_timers(delta)
	if dashing <= 0.0 and dash_cd <= 0.0 and _dash_input():
		_start_dash(face)
	if dashing > 0.0:
		_td_move(dash_dir, delta * (DASH_SPEED / TD_SPEED))   # même collision, vitesse dash
	else:
		_td_move(mv, delta)

	# combat
	if atk_t > 0.0: atk_t -= delta
	if atk_cd > 0.0: atk_cd -= delta
	if shoot_cd > 0.0: shoot_cd -= delta
	switch_cd -= delta
	_td_attack_input()
	_td_update_pshots(delta)
	_td_enemies(delta)
	_update_projectiles(delta)   # tirs ennemis vs joueur (générique réutilisé)
	_interactions(delta)         # pièces / clé / porte / arrivée / chrono (réutilisé)
	queue_redraw(); app.queue_redraw()


# déplacement + collision par axe contre les cases solides (murs)
func _td_move(mv: Vector2, delta: float) -> void:
	var step := mv * TD_SPEED * delta
	ppos.x += step.x
	for c in _cells(Rect2(ppos, PSIZE)):
		if _is_full_solid(app.grid.get(c, EMPTY)):
			var r := _cell_rect(c)
			if Rect2(ppos, PSIZE).intersects(r):
				if step.x > 0: ppos.x = r.position.x - PSIZE.x
				elif step.x < 0: ppos.x = r.position.x + r.size.x
	ppos.y += step.y
	for c in _cells(Rect2(ppos, PSIZE)):
		if _is_full_solid(app.grid.get(c, EMPTY)):
			var r := _cell_rect(c)
			if Rect2(ppos, PSIZE).intersects(r):
				if step.y > 0: ppos.y = r.position.y - PSIZE.y
				elif step.y < 0: ppos.y = r.position.y + r.size.y
	ppos.x = clampf(ppos.x, 0, app.cols * CELL - PSIZE.x)
	ppos.y = clampf(ppos.y, 0, app.rows * CELL - PSIZE.y)


func _td_attack_input() -> void:
	var sword := Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var shoot := Input.is_key_pressed(KEY_X) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	if sword and atk_cd <= 0.0:
		atk_t = TD_ATK_DUR; atk_cd = TD_ATK_CD
		_td_sword()
	if shoot and shoot_cd <= 0.0:
		shoot_cd = TD_SHOOT_CD
		_td_shoot()


# coup d'épée : zone devant le joueur dans la direction regardée
func _td_sword() -> void:
	var c := ppos + PSIZE * 0.5 + face * (PSIZE.x * 0.5 + TD_ATK_REACH * 0.5)
	var hit := Rect2(c - Vector2(TD_ATK_REACH, TD_ATK_REACH), Vector2(TD_ATK_REACH, TD_ATK_REACH) * 2.0)
	for en in enemies:
		if not en.alive: continue
		var esz: float = BOSS_SIZE if en.type == "boss" else float(ESIZE)
		if hit.intersects(Rect2(en.pos, Vector2(esz, esz))):
			_td_damage(en)
	app._play("stomp")


func _td_shoot() -> void:
	var c := ppos + PSIZE * 0.5
	pshots.append({"pos": c + face * PSIZE.x * 0.5, "vel": face * PROJ_SPEED, "alive": true})
	app._play("jump")


func _td_update_pshots(delta: float) -> void:
	if pshots.is_empty(): return
	for s in pshots:
		if not s.alive: continue
		s.pos += s.vel * delta
		var cc := Vector2i(int(s.pos.x / CELL), int(s.pos.y / CELL))
		if _is_full_solid(app.grid.get(cc, EMPTY)) or s.pos.x < 0 or s.pos.x > app.cols * CELL \
				or s.pos.y < 0 or s.pos.y > app.rows * CELL:
			s.alive = false; continue
		for en in enemies:
			if not en.alive: continue
			var esz: float = BOSS_SIZE if en.type == "boss" else float(ESIZE)
			if Rect2(en.pos, Vector2(esz, esz)).has_point(s.pos):
				s.alive = false; _td_damage(en); break
	pshots = pshots.filter(func(s): return s.alive)


# inflige un dégât : boss = -1 PV (avec i-frames/enrage) ; autres = mort directe
func _td_damage(en: Dictionary) -> void:
	if en.type == "boss":
		if en.inv > 0.0: return
		en.hp -= 1; en.inv = BOSS_INV
		app._emit(en.pos + Vector2(BOSS_SIZE, BOSS_SIZE) * 0.5, 14, COLORS[BOSS].lightened(0.3), 220.0, 0.4, true, 4.0)
		app._shake(5.0, 0.15); app._play("stomp")
		if en.hp <= 0:
			en.alive = false
			app._emit(en.pos + Vector2(BOSS_SIZE, BOSS_SIZE) * 0.5, 40, COLORS[BOSS], 320.0, 0.9, true, 6.0)
			app._shake(10.0, 0.4); app._play("win")
		elif not en.enraged and en.hp <= BOSS_ENRAGE_HP:
			en.state = "enrage"; en.st = 0.0; en.queue = []
		else:
			en.state = "hurt"; en.st = 0.0; en.queue = []
	else:
		en.alive = false
		app._emit(en.pos + Vector2(ESIZE, ESIZE) * 0.5, 10, COLORS[ENEMY], 200.0, 0.4, true, 4.0)
		app._shake(3.0, 0.1); app._play("stomp")


# ennemis : comportements sans gravité ; bloqués par les murs ; contact = mort
func _td_enemies(delta: float) -> void:
	var pr := Rect2(ppos, PSIZE)
	for en in enemies:
		if not en.alive: continue
		var t: String = en.get("type", "chaser")
		var prev: Vector2 = en.pos
		match t:
			"flyer":   _enemy_flyer(en, delta)
			"boss":    _enemy_boss(en, delta)
			"shooter": _td_shooter(en, delta)
			"walker":  _td_patrol(en, delta)
			_:         _enemy_chaser(en, delta)
		var esz: float = BOSS_SIZE if t == "boss" else float(ESIZE)
		# bloque sur les murs (sauf le boss qui vole/charge à travers)
		if t != "boss":
			var cc := Vector2i(int((en.pos.x + esz * 0.5) / CELL), int((en.pos.y + esz * 0.5) / CELL))
			if _is_full_solid(app.grid.get(cc, EMPTY)):
				en.pos = prev
		if pr.intersects(Rect2(en.pos, Vector2(esz, esz))):
			if en.type == "boss" and en.inv > 0.0:
				pass
			else:
				_die()


# patrouilleur top-down : avance en 4 directions, rebondit sur les murs (sans gravité)
func _td_patrol(en: Dictionary, delta: float) -> void:
	if not en.has("tdv"):
		var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
		en.tdv = dirs[randi() % 4]
	var np: Vector2 = en.pos + en.tdv * ESPEED * delta
	var cc := Vector2i(int((np.x + ESIZE * 0.5) / CELL), int((np.y + ESIZE * 0.5) / CELL))
	if _is_full_solid(app.grid.get(cc, EMPTY)) or np.x < 0 or np.y < 0 \
			or np.x > app.cols * CELL - ESIZE or np.y > app.rows * CELL - ESIZE:
		en.tdv = -en.tdv   # demi-tour au mur / bord
	else:
		en.pos = np


# tourelle top-down : fixe (pas de gravité), tire vers le joueur à intervalle
func _td_shooter(en: Dictionary, delta: float) -> void:
	en.shoot_t = en.get("shoot_t", SHOOT_INTERVAL) - delta
	if en.shoot_t <= 0.0:
		en.shoot_t = SHOOT_INTERVAL
		var ctr: Vector2 = en.pos + Vector2(ESIZE, ESIZE) * 0.5
		var to: Vector2 = (ppos + PSIZE * 0.5) - ctr
		if to.length() < 1.0: to = Vector2(1, 0)
		projectiles.append({"pos": ctr, "vel": to.normalized() * PROJ_SPEED, "alive": true})
		app._emit(ctr, 4, COLORS[SHOOTER].lightened(0.4), 120.0, 0.2, false, 2.5)
		app._play("spring")


func _draw() -> void:
	super()   # monde + fond + ennemis + boss + joueur (carré) rendus par le parent
	if app == null or app.screen != "edit" or app.mode != "play":
		return
	var vs: float = app.view_scale
	# tirs du joueur (bleu clair, distincts des tirs ennemis jaunes)
	for s in pshots:
		if s.alive:
			draw_circle(app._w2s(s.pos), 7.0 * vs, Color("9be7ff"))
			draw_circle(app._w2s(s.pos), 4.0 * vs, Color("ffffff"))
	# clignote pendant l'invulnérabilité (dégât/dash) → saute le rendu 1 frame sur 2
	if pinv > 0.0 and int(pinv * 20.0) % 2 == 0:
		return
	# joueur vu de dessus : disque (recouvre le carré du parent) + regard + arme
	var ctr: Vector2 = app._w2s(ppos + PSIZE * 0.5)
	var rad: float = PSIZE.x * 0.5 * vs
	# traînée de dash
	if dashing > 0.0:
		for i in 3:
			draw_circle(ctr - dash_dir * float(i + 1) * 10.0 * vs, rad * (1.0 - i * 0.22), Color(0.6, 0.9, 1.0, 0.25))
	draw_circle(ctr, rad, Color("ecf0f1"))
	draw_circle(ctr, rad, Color("2c3e50"), false, 2.0 * vs)
	# 2 yeux orientés vers la direction regardée
	var fperp := Vector2(-face.y, face.x)
	for sgn in [-1.0, 1.0]:
		draw_circle(ctr + face * rad * 0.35 + fperp * sgn * rad * 0.4, rad * 0.18, Color("2c3e50"))
	# coup d'épée : lame qui balaie devant
	if atk_t > 0.0:
		var a0 := face.angle() - 0.95
		var a1 := face.angle() + 0.95
		draw_arc(ctr, (PSIZE.x * 0.5 + TD_ATK_REACH) * vs, a0, a1, 16, Color(1, 1, 1, 0.95), 5.0 * vs)
	else:
		# petite "arme" tenue dans la direction (indicateur statique)
		draw_line(ctr + face * rad * 0.6, ctr + face * (rad + 10.0 * vs), Color("bdc3c7"), 3.0 * vs)


# tuiles top-down : mur (GROUND) pierre dédiée + sol (FLOOR) dallé ; reste = parent
func draw_tile(ci: CanvasItem, p: Vector2, t: int, scale := 1.0, alpha := 1.0, world := false, surface := true) -> void:
	var cs := CELL * scale
	if t == GROUND:
		var c := Color("4a5568")
		ci.draw_rect(Rect2(p, Vector2(cs, cs)), c)
		ci.draw_rect(Rect2(p, Vector2(cs, maxf(2.0, cs * 0.16))), c.lightened(0.18))
		ci.draw_rect(Rect2(p + Vector2(0, cs * 0.84), Vector2(cs, maxf(2.0, cs * 0.16))), c.darkened(0.3))
		ci.draw_rect(Rect2(p, Vector2(cs, cs)), c.darkened(0.45), false, maxf(1.0, scale))
		return
	if t == FLOOR:
		var fc: Color = COLORS[FLOOR]
		ci.draw_rect(Rect2(p, Vector2(cs, cs)), fc)
		# joint de dalle (croix discrète)
		ci.draw_line(p + Vector2(cs * 0.5, 0), p + Vector2(cs * 0.5, cs), fc.darkened(0.12), maxf(1.0, scale))
		ci.draw_line(p + Vector2(0, cs * 0.5), p + Vector2(cs, cs * 0.5), fc.darkened(0.12), maxf(1.0, scale))
		return
	super(ci, p, t, scale, alpha, world, surface)
