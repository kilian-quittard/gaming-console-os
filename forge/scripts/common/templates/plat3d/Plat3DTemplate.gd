extends TemplateBase
class_name Plat3DTemplate
# PLATEFORMER 3D : édité en VUE DE DESSUS (grille 2D existante : X = X monde,
# Y grille = Z monde), joué en vraie 3D (monde de blocs généré au lancement,
# Camera3D active sous le chrome 2D). Les blocs ont une hauteur configurable
# (inspecteur). Tuiles "Zone 2.5D" (axe X ou Z verrouillé, caméra de côté) et
# "Zone 3D" (libre, caméra épaule) pour ALTERNER les modes dans le niveau.

const U := 1.0              # 1 case grille = 1 unité 3D
const SPEED3 := 5.2
const GRAV3 := 24.0
const JUMP3 := 9.5
const STEP3 := 0.55         # marche franchissable sans saut
const PHALF := 0.32         # demi-largeur du joueur (XZ)

var pos3 := Vector3.ZERO
var vel3 := Vector3.ZERO
var grounded3 := false
var jb3 := 0.0              # jump buffer
var move_mode := "3d"       # "3d" | "x" (2.5D le long de X) | "z"
var cam_yaw := 0.0          # cap caméra third-person (mode 3D)
var planets3 := []          # {c: Vector3 centre, r: float} — champs de gravité radiaux
var on_planet = null        # planète sur laquelle on marche (null = gravité normale)
var pl_head := Vector3.FORWARD   # cap tangent (avant) en mode planète
var look_dx := 0.0          # delta souris accumulé (appliqué selon le mode)
var lock_coord := 0.0       # coordonnée verrouillée en 2.5D (z ou x, en unités)
var enemies3 := []          # {node, x, z, dir, min, max}
var world3: Node3D = null
var cam3: Camera3D = null
var player3: MeshInstance3D = null
var mesh_by_cell := {}      # Vector2i -> Array[Node3D] (libérés si la tuile disparaît)
var coin_nodes := []        # pour l'animation de rotation
var _mats := {}             # cache Color -> StandardMaterial3D
var cursor3: MeshInstance3D = null   # surbrillance de la case en édition
var ghost3: MeshInstance3D = null    # aperçu translucide de la tuile active
var _world_sig := -1                 # signature du grid (rebuild si changement)
var _rebuild_t := 0.0                # throttle de reconstruction (édition)
var cam_focus3 := Vector3.ZERO       # point regardé par la caméra d'ÉDITION (libre)
var _focus_init := false

const P3_CATS := [
	{"name": "Sol",     "tiles": [FLOOR]},
	{"name": "Blocs",   "tiles": [GROUND]},
	{"name": "Mode",    "tiles": [MODE25, MODE3D, PLANET]},
	{"name": "Items",   "tiles": [COIN]},
	{"name": "Danger",  "tiles": [SPIKE]},
	{"name": "Ennemis", "tiles": [ENEMY]},
	{"name": "Reperes", "tiles": [SPAWN, GOAL, CHECKPOINT, WARP]},
]
func categories() -> Array: return P3_CATS
func default_hp() -> int: return 3
func _wants_parallax() -> bool: return false
func wants_2d_world() -> bool: return false    # ÉDITION AUSSI en 3D (curseur 2D masqué)


const OBJ_TILES := [COIN, SPIKE, SPAWN, GOAL, CHECKPOINT, WARP, MODE25, MODE3D, ENEMY]


# on ne ramasse que si la tuile visée = la tuile active (sinon on POSE par-dessus)
func can_grab(c: Vector2i) -> bool:
	return app.grid.get(c, EMPTY) == app._active_tile()


# SUPERPOSITION : objets gardent le terrain dessous ; bloc sur bloc = empile
func place_tile(c: Vector2i, t: int, fresh: bool) -> void:
	var cur: int = app.grid.get(c, EMPTY)
	var cfg: Dictionary = app.cell_cfg.get(c, {})
	if t == GROUND:
		if cur == GROUND and fresh:
			cfg["h"] = mini(int(cfg.get("h", 1)) + 1, 3)   # re-clic = +1 étage
			app.cell_cfg[c] = cfg
		elif cur != GROUND:
			var bh := int(cfg.get("base_h", 0))
			app.grid[c] = GROUND
			app.cell_cfg[c] = {"h": maxi(1, bh)}
		return
	if t == FLOOR:
		app.grid[c] = FLOOR
		app.cell_cfg.erase(c)
		return
	if OBJ_TILES.has(t):
		var bh2 := 0
		if cur == GROUND: bh2 = int(cfg.get("h", 1))          # objet posé SUR le bloc
		elif OBJ_TILES.has(cur): bh2 = int(cfg.get("base_h", 0))
		app.grid[c] = t
		if bh2 > 0: app.cell_cfg[c] = {"base_h": bh2}
		else: app.cell_cfg.erase(c)
		return
	app.grid[c] = t


# effacement PROGRESSIF : objet → bloc → sol → vide
func erase_tile(c: Vector2i) -> void:
	var cur: int = app.grid.get(c, EMPTY)
	var cfg: Dictionary = app.cell_cfg.get(c, {})
	if OBJ_TILES.has(cur) and int(cfg.get("base_h", 0)) > 0:
		app.grid[c] = GROUND
		app.cell_cfg[c] = {"h": int(cfg["base_h"])}
		return
	if cur == GROUND:
		var h := int(cfg.get("h", 1))
		if h > 1: app.cell_cfg[c] = {"h": h - 1}
		else:
			app.grid[c] = FLOOR; app.cell_cfg.erase(c)
		return
	if OBJ_TILES.has(cur):
		app.grid[c] = FLOOR; app.cell_cfg.erase(c)
		return
	app.grid.erase(c); app.cell_cfg.erase(c)


# souris/pointeur -> case : raycast caméra sur le plan du sol (y = 0)
func screen_to_cell(sp: Vector2) -> Vector2i:
	if cam3 == null or not cam3.current:
		return super(sp)
	var from := cam3.project_ray_origin(sp)
	var dir := cam3.project_ray_normal(sp)
	if absf(dir.y) < 0.0001: return app.cursor
	var t := -from.y / dir.y
	if t < 0.0: return app.cursor
	var hit := from + dir * t
	return Vector2i(int(floor(hit.x)), int(floor(hit.z)))


func play_badges() -> Array:
	return [["←→↑↓", "Bouger"], ["A", "Sauter"], ["Y", "Rejouer"], ["ST", "Éditeur"]]


func play_hud_text() -> String:
	match move_mode:
		"x": return "MODE 2.5D (axe X)"
		"z": return "MODE 2.5D (axe Z)"
	return "MODE 3D"


# hauteur de bloc configurable + axe des zones 2.5D
func config_fields(t: int) -> Array:
	if t == GROUND:
		return [{"key": "h", "label": "Hauteur", "opts": [1, 2, 3], "def": 1}]
	if t == MODE25:
		return [{"key": "axe", "label": "Axe", "opts": ["X", "Z"], "def": "X"}]
	if t == PLANET:
		return [{"key": "r", "label": "Rayon", "opts": [2, 3, 4], "def": 3}]
	return super(t)


func seed_demo() -> void:
	var grid: Dictionary = app.grid
	grid.clear()
	# couloir 2.5D (axe X) puis plaza 3D
	for x in range(2, 16):
		for z in range(6, 9):
			grid[Vector2i(x, z)] = FLOOR
	grid[Vector2i(3, 7)] = SPAWN
	grid[Vector2i(4, 7)] = MODE25
	grid[Vector2i(7, 7)] = GROUND
	grid[Vector2i(10, 6)] = COIN
	grid[Vector2i(10, 8)] = COIN
	grid[Vector2i(12, 7)] = SPIKE
	# plaza 3D
	for x in range(16, 28):
		for z in range(2, 13):
			grid[Vector2i(x, z)] = FLOOR
	grid[Vector2i(16, 7)] = MODE3D
	grid[Vector2i(20, 4)] = GROUND
	grid[Vector2i(21, 4)] = GROUND
	grid[Vector2i(20, 10)] = ENEMY
	grid[Vector2i(24, 7)] = COIN
	grid[Vector2i(26, 7)] = GOAL
	app.cursor = Vector2i(3, 7)


# =================================================== monde 3D
func _ready() -> void:
	super()
	world3 = Node3D.new(); world3.name = "World3D"
	add_child(world3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var skm := ProceduralSkyMaterial.new()
	skm.sky_top_color = Color("2a5d9c")
	skm.sky_horizon_color = Color("ffd9a0")
	skm.ground_bottom_color = Color("2a2e38")
	skm.ground_horizon_color = Color("e8b27d")
	skm.sun_angle_max = 30.0
	var sky := Sky.new(); sky.sky_material = skm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.1
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.1
	e.fog_enabled = true
	e.fog_light_color = Color("cfa97e")
	e.fog_density = 0.012
	e.fog_sky_affect = 0.2
	env.environment = e
	world3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color("fff2dd")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world3.add_child(sun)
	cam3 = Camera3D.new()
	cam3.current = false
	world3.add_child(cam3)
	# curseur d'édition : cadre translucide sur la case visée
	cursor3 = MeshInstance3D.new()
	var cb := BoxMesh.new(); cb.size = Vector3(1.02, 0.25, 1.02)
	cursor3.mesh = cb
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.62, 0.07, 0.55)
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor3.material_override = cmat
	world3.add_child(cursor3)
	ghost3 = MeshInstance3D.new()
	ghost3.mesh = cb
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1, 1, 1, 0.25)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost3.material_override = gmat
	world3.add_child(ghost3)


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%.1f" % [c.to_html(), glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.82
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


func _box_glow(size: Vector3, at: Vector3, c: Color, glow: float) -> MeshInstance3D:
	var mi := _box(size, at, c)
	mi.material_override = _mat(c, glow)
	return mi


func _box(size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = at
	world3.add_child(mi)
	return mi


func _cell_h(c: Vector2i) -> float:
	# hauteur du support d'une case ; -1000 = vide (trou)
	var t: int = app.grid.get(c, EMPTY)
	if t == EMPTY: return -1000.0
	if t == GROUND:
		return float(app.cell_cfg.get(c, {}).get("h", 1))
	return float(app.cell_cfg.get(c, {}).get("base_h", 0))   # objet : hauteur du bloc dessous


func _build_world() -> void:
	for k in mesh_by_cell:
		for n in mesh_by_cell[k]: n.queue_free()
	mesh_by_cell.clear(); coin_nodes.clear(); planets3.clear()
	for en in enemies3: en.node.queue_free()
	enemies3.clear()
	for k in app.grid:
		var t: int = app.grid[k]
		var cx := float(k.x) + 0.5
		var cz := float(k.y) + 0.5
		var col: Color = COLORS.get(t, Color.GRAY)
		var nodes := []
		if t == GROUND:
			var h := _cell_h(k)
			nodes.append(_box(Vector3(U, h, U), Vector3(cx, h * 0.5, cz), Color("8d6e63")))
		else:
			# support : bloc (objet posé dessus) OU dalle de sol
			var bh := float(app.cell_cfg.get(k, {}).get("base_h", 0))
			if bh > 0.0:
				nodes.append(_box(Vector3(U, bh, U), Vector3(cx, bh * 0.5, cz), Color("8d6e63")))
			else:
				var slab_c := (Color("a8b0b8") if (k.x + k.y) % 2 == 0 else Color("939ba3")) 					if t == FLOOR else col.lerp(Color("9e9e9e"), 0.4)
				nodes.append(_box(Vector3(U, 0.16, U), Vector3(cx, -0.08, cz), slab_c))
			match t:
				PLANET:
					var pr := float(app.cell_cfg.get(k, {}).get("r", 3))
					var pc := Vector3(cx, pr + 1.0, cz)
					var sm := SphereMesh.new(); sm.radius = pr; sm.height = pr * 2.0
					var pmi := MeshInstance3D.new(); pmi.mesh = sm
					pmi.material_override = _mat(Color("5c9ded"))
					pmi.position = pc
					world3.add_child(pmi)
					nodes.append(pmi)
					var band := MeshInstance3D.new()
					var tm := TorusMesh.new(); tm.inner_radius = pr * 1.04; tm.outer_radius = pr * 1.1
					band.mesh = tm; band.position = pc
					band.material_override = _mat(Color("8fc2ff"), 0.8)
					world3.add_child(band)
					nodes.append(band)
					planets3.append({"c": pc, "r": pr})
				COIN:
					var cn := _box_glow(Vector3(0.36, 0.36, 0.08), Vector3(cx, bh + 0.5, cz), Color("f1c40f"), 1.6)
					coin_nodes.append(cn); nodes.append(cn)
				SPIKE:
					nodes.append(_box(Vector3(0.5, 0.45, 0.5), Vector3(cx, bh + 0.22, cz), Color("e74c3c")))
				GOAL:
					nodes.append(_box(Vector3(0.1, 1.8, 0.1), Vector3(cx, bh + 0.9, cz), Color("ecf0f1")))
					nodes.append(_box(Vector3(0.5, 0.3, 0.06), Vector3(cx + 0.25, bh + 1.5, cz), Color("3498db")))
				MODE25, MODE3D:
					nodes.append(_box_glow(Vector3(0.16, 0.9, 0.16), Vector3(cx, bh + 0.45, cz), col, 1.2))
				ENEMY:
					var en := _box(Vector3(0.6, 0.6, 0.6), Vector3(cx, bh + 0.3, cz), Color("e74c3c"))
					enemies3.append({"node": en, "x": cx, "z": cz, "dir": 1.0, "y": bh,
						"min": cx - 3.0, "max": cx + 3.0})
					nodes.append(en)
		mesh_by_cell[k] = nodes
	if player3 == null:
		player3 = MeshInstance3D.new()
		var cm := CapsuleMesh.new(); cm.radius = 0.3; cm.height = 0.9
		player3.mesh = cm
		player3.material_override = _mat(Color("ff9f43"))
		world3.add_child(player3)
	player3.visible = true


func start_play(from_cursor: bool) -> void:
	super(from_cursor)
	_build_world()
	_world_sig = -1   # l'édition re-rebuildera après les mutations du test
	pos3 = Vector3(float(spawn_cell.x) + 0.5, 0.6, float(spawn_cell.y) + 0.5)
	vel3 = Vector3.ZERO
	move_mode = "3d"; jb3 = 0.0; cam_yaw = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # souris = caméra (relâchée au stop)
	cam3.current = true
	cam3.position = pos3 + Vector3(sin(cam_yaw), 0.0, cos(cam_yaw)) * 6.0 + Vector3(0, 3.0, 0)


func stop_play() -> void:
	super()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player3: player3.visible = false


func jump_pressed() -> void:
	if not dead and not won: jb3 = 0.12


func _unhandled_input(e: InputEvent) -> void:
	if app == null or app.screen != "edit" or app.mode != "play": return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_dx += (e as InputEventMouseMotion).relative.x


func _process(delta: float) -> void:
	super(delta)
	if app == null or app.screen != "edit":
		if cam3 and cam3.current: cam3.current = false
		return
	if app.mode == "edit":
		if not cam3.current: cam3.current = true
		# rebuild si la grille a changé — throttlé (la peinture mute chaque frame)
		_rebuild_t -= delta
		if _rebuild_t <= 0.0:
			_rebuild_t = 0.15
			var sig := 0
			for k in app.grid:
				sig = (sig + (k.x * 73856093) ^ (k.y * 19349663) ^ (int(app.grid[k]) * 83492791)) & 0x7FFFFFFF
			sig = (sig + app.cell_cfg.size() * 7919) & 0x7FFFFFFF
			if sig != _world_sig:
				_world_sig = sig
				_build_world()
				if player3: player3.visible = false
		# curseur 3D sur la case visée (posé au sommet de la colonne)
		var c: Vector2i = app.cursor
		var h: float = maxf(_cell_h(c), 0.0)
		cursor3.visible = true
		cursor3.position = Vector3(float(c.x) + 0.5, h + 0.13, float(c.y) + 0.5)
		ghost3.visible = false
		# CAMÉRA LIBRE (jamais asservie au curseur : sinon boucle caméra↔raycast).
		# Pan : pousser le pointeur contre un bord (stick/flèches). R2 = dézoom.
		if not _focus_init:
			# entre en édition : curseur sur le spawn (ou 1re tuile) → caméra sur le niveau
			var sp := _find(SPAWN)
			if sp == Vector2i(-1, -1) and not app.grid.is_empty():
				sp = app.grid.keys()[0]
			if sp != Vector2i(-1, -1):
				app.cursor = sp
				c = sp
			cam_focus3 = Vector3(float(c.x) + 0.5, 0.0, float(c.y) + 0.5)
			_focus_init = true
			cam3.position = cam_focus3 + Vector3(0, 9.0, 7.0)
			cam3.look_at(cam_focus3)
			# aligne le pointeur sur le curseur (sinon le 1er input le téléporte)
			app.aim = cam3.unproject_position(cam_focus3)
		var vp := get_viewport_rect().size
		var margin := 40.0
		var push: Vector2 = app._stick() + Vector2(app._dpad_held())
		var pan := Vector3.ZERO
		if app.aim.x < margin and push.x < -0.2: pan.x = -1.0
		elif app.aim.x > vp.x - margin and push.x > 0.2: pan.x = 1.0
		if app.aim.y < app.TOPBAR + margin and push.y < -0.2: pan.z = -1.0
		elif app.aim.y > vp.y - app.BOTTOM - margin and push.y > 0.2: pan.z = 1.0
		cam_focus3 += pan * 11.0 * delta
		cam_focus3.x = clampf(cam_focus3.x, 0.0, float(app.cols))
		cam_focus3.z = clampf(cam_focus3.z, 0.0, float(app.rows))
		var zoom := 22.0 if app.dezoom else 9.0
		var cpos := cam_focus3 + Vector3(0, zoom * 0.95, zoom * 0.75)
		cam3.position = cam3.position.lerp(cpos, clampf(10.0 * delta, 0.0, 1.0))
		cam3.look_at(cam_focus3)
	else:
		cursor3.visible = false
		ghost3.visible = false
		_focus_init = false


# =================================================== simulation
func _physics_process(delta: float) -> void:
	if app == null or app.screen != "edit" or app.mode != "play" or won:
		return
	if dead:
		death_t -= delta
		if death_t <= 0.0:
			dead = false
			_build_world()
			pos3 = Vector3(float(respawn_cell.x) + 0.5, 0.6, float(respawn_cell.y) + 0.5)
			vel3 = Vector3.ZERO
			hearts = max_hearts
		app.queue_redraw()
		return
	jb3 -= delta
	_tick_player_timers(delta)
	# rotation caméra : souris (accumulée) + stick droit — axe selon le mode
	var yaw_in := look_dx * 0.0045
	look_dx = 0.0
	var rs := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(rs) > 0.18: yaw_in += rs * 2.8 * delta
	# === GRAVITÉ RADIALE (planètes, façon Mario Galaxy) ===
	if _planet_step(delta, yaw_in):
		return
	if move_mode == "3d":
		cam_yaw -= yaw_in
	# changement de mode : tuile sous les pieds
	var here := Vector2i(int(pos3.x), int(pos3.z))
	match int(app.grid.get(here, EMPTY)):
		MODE25:
			var ax := str(app.cell_cfg.get(here, {}).get("axe", "X"))
			if move_mode != ax.to_lower():
				move_mode = ax.to_lower()
				lock_coord = (float(here.y) + 0.5) if move_mode == "x" else (float(here.x) + 0.5)
				app._play("key")
		MODE3D:
			if move_mode != "3d":
				move_mode = "3d"; app._play("key")
				var o := cam3.position - pos3
				cam_yaw = atan2(o.x, o.z)   # continuité caméra au changement de mode
	# entrées selon le mode
	var dx := float(_dir_x()); var dz := float(_dir_y())
	match move_mode:
		"x":
			vel3.x = dx * SPEED3
			vel3.z = clampf((lock_coord - pos3.z) * 8.0, -SPEED3, SPEED3)
		"z":
			vel3.z = -dx * SPEED3
			vel3.x = clampf((lock_coord - pos3.x) * 8.0, -SPEED3, SPEED3)
		_:
			# THIRD PERSON : stick haut = s'éloigner de la caméra
			var off := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))   # caméra derrière = +off
			var fwd := -off
			var right := fwd.cross(Vector3.UP)
			var mv := fwd * (-dz) + right * dx
			if mv.length() > 0.1:
				mv = mv.normalized()
			vel3.x = mv.x * SPEED3
			vel3.z = mv.z * SPEED3
	# saut + gravité
	if grounded3 and jb3 > 0.0:
		vel3.y = JUMP3; jb3 = 0.0; grounded3 = false
		app._play("jump")
	vel3.y -= GRAV3 * delta
	# déplacement par axe avec collision sur les colonnes
	_move_axis(0, vel3.x * delta)
	_move_axis(2, vel3.z * delta)
	pos3.y += vel3.y * delta
	# atterrissage sur le support le plus haut sous l'empreinte
	var sup := _support()
	grounded3 = false
	if vel3.y <= 0.0 and pos3.y <= sup + 0.45 and sup > -100.0:
		pos3.y = sup + 0.45
		vel3.y = 0.0
		grounded3 = true
	if pos3.y < -6.0:
		_kill()
	# synchronise la position 2D fantôme → réutilise les interactions de la base
	ppos = Vector2(pos3.x * CELL - PSIZE.x * 0.5, pos3.z * CELL - PSIZE.y * 0.5)
	if pos3.y - sup < 0.9:
		_interactions(delta)
	_sweep_removed_meshes()
	_update_enemies3(delta)
	# rendu
	player3.position = pos3 + Vector3(0, 0.15, 0)
	_update_camera(delta)
	for cn in coin_nodes:
		if is_instance_valid(cn): cn.rotate_y(delta * 3.0)
	app.queue_redraw()


# pas de simulation en gravité radiale. true = géré (saute la physique normale).
func _planet_step(delta: float, yaw_in: float) -> bool:
	# planète d'influence la plus proche
	var pl = null; var bd := 1e9
	for p in planets3:
		var d: float = (pos3 - p.c).length()
		if d < p.r + 6.0 and d < bd: bd = d; pl = p
	if on_planet != null: pl = on_planet
	if pl == null: return false
	var up: Vector3 = (pos3 - pl.c).normalized()
	if on_planet != null:
		# === collé à la surface : on marche AUTOUR de la sphère ===
		pl_head = (pl_head - up * pl_head.dot(up)).normalized()
		pl_head = pl_head.rotated(up, -yaw_in)
		var right: Vector3 = pl_head.cross(up)
		var mv: Vector3 = pl_head * (-float(_dir_y())) + right * float(_dir_x())
		if mv.length() > 0.1:
			pos3 += mv.normalized() * SPEED3 * delta
		pos3 = pl.c + (pos3 - pl.c).normalized() * (pl.r + 0.45)
		up = (pos3 - pl.c).normalized()
		grounded3 = true
		if jb3 > 0.0:
			jb3 = 0.0
			vel3 = up * JUMP3 + (mv.normalized() * SPEED3 if mv.length() > 0.1 else Vector3.ZERO)
			on_planet = null; grounded3 = false
			app._play("jump")
	else:
		# === en l'air dans le champ : chute vers le centre ===
		vel3 += -up * GRAV3 * 0.9 * delta
		pos3 += vel3 * delta
		var d2: float = (pos3 - pl.c).length()
		if d2 <= pl.r + 0.45 and vel3.dot(up) <= 0.0:
			pos3 = pl.c + (pos3 - pl.c).normalized() * (pl.r + 0.45)
			on_planet = pl
			grounded3 = true
			vel3 = Vector3.ZERO
			# cap initial = tangent de la vitesse d'approche (sinon garde l'ancien)
			var t := (pl_head - up * pl_head.dot(up))
			pl_head = t.normalized() if t.length() > 0.05 else Vector3.FORWARD.cross(up).cross(up) * -1.0
			app._play("stomp")
		if pos3.y < -6.0:
			_kill(); return true
	# caméra : derrière le cap, "haut" = haut local (LE truc Galaxy)
	var ct: Vector3 = pos3 + up * 2.6 - pl_head * 6.0
	cam3.position = cam3.position.lerp(ct, clampf(7.0 * delta, 0.0, 1.0))
	cam3.look_at(pos3 + up * 0.8, up)
	# interactions/rendu communs
	player3.position = pos3 + up * 0.15
	ppos = Vector2(pos3.x * CELL - PSIZE.x * 0.5, pos3.z * CELL - PSIZE.y * 0.5)
	_sweep_removed_meshes()
	for cn in coin_nodes:
		if is_instance_valid(cn): cn.rotate_y(delta * 3.0)
	app.queue_redraw()
	return true


func _support() -> float:
	var best := -1000.0
	for cx in [int(pos3.x - PHALF), int(pos3.x + PHALF)]:
		for cz in [int(pos3.z - PHALF), int(pos3.z + PHALF)]:
			var h := _cell_h(Vector2i(cx, cz))
			if h > -100.0 and h <= pos3.y + STEP3 and h > best:
				best = h
	return best


func _move_axis(axis: int, amount: float) -> void:
	if amount == 0.0: return
	var np := pos3
	np[axis] += amount
	# bloqué si une colonne trop haute occupe la case visée
	for cx in [int(np.x - PHALF), int(np.x + PHALF)]:
		for cz in [int(np.z - PHALF), int(np.z + PHALF)]:
			var h := _cell_h(Vector2i(cx, cz))
			if h > pos3.y + STEP3:
				return   # mur : on n'avance pas sur cet axe
	pos3 = np


func _update_camera(delta: float) -> void:
	var target: Vector3
	match move_mode:
		"x": target = Vector3(pos3.x, pos3.y + 2.2, lock_coord + 8.5)
		"z": target = Vector3(lock_coord + 8.5, pos3.y + 2.2, pos3.z)
		_:
			var off := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
			target = pos3 + off * 6.0 + Vector3(0, 3.0, 0)
	cam3.position = cam3.position.lerp(target, clampf(7.0 * delta, 0.0, 1.0))
	cam3.look_at(pos3 + Vector3(0, 1.0, 0))


func _update_enemies3(delta: float) -> void:
	for en in enemies3:
		if not is_instance_valid(en.node): continue
		var nx: float = en.x + en.dir * 1.8 * delta
		var front := Vector2i(int(nx + (PHALF if en.dir > 0 else -PHALF)), int(en.z))
		var h := _cell_h(front)
		var ey := float(en.get("y", 0))
		if h < -100.0 or absf(h - ey) > 0.6:
			en.dir = -en.dir
		else:
			en.x = nx
		en.node.position = Vector3(en.x, float(en.get("y", 0)) + 0.3, en.z)
		# contact joueur (si à hauteur)
		if absf(pos3.x - en.x) < 0.6 and absf(pos3.z - en.z) < 0.6 				and absf(pos3.y - (float(en.get("y", 0)) + 0.3)) < 0.9:
			_die()


# tuiles disparues du grid (pièces/clés prises) → libère leurs meshes
func _sweep_removed_meshes() -> void:
	for k in mesh_by_cell.keys():
		if not app.grid.has(k):
			for n in mesh_by_cell[k]:
				if is_instance_valid(n): n.queue_free()
			mesh_by_cell.erase(k)


# =================================================== rendu 2D
func _draw() -> void:
	# le monde est TOUJOURS rendu par la caméra 3D (édition incluse) ;
	# on garde seulement le calcul de vue pour le chrome 2D
	if app == null or app.screen != "edit":
		return
	app._compute_view()
