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
var lock_coord := 0.0       # coordonnée verrouillée en 2.5D (z ou x, en unités)
var enemies3 := []          # {node, x, z, dir, min, max}
var world3: Node3D = null
var cam3: Camera3D = null
var player3: MeshInstance3D = null
var mesh_by_cell := {}      # Vector2i -> Array[Node3D] (libérés si la tuile disparaît)
var coin_nodes := []        # pour l'animation de rotation
var _mats := {}             # cache Color -> StandardMaterial3D

const P3_CATS := [
	{"name": "Sol",     "tiles": [FLOOR]},
	{"name": "Blocs",   "tiles": [GROUND]},
	{"name": "Mode",    "tiles": [MODE25, MODE3D]},
	{"name": "Items",   "tiles": [COIN]},
	{"name": "Danger",  "tiles": [SPIKE]},
	{"name": "Ennemis", "tiles": [ENEMY]},
	{"name": "Reperes", "tiles": [SPAWN, GOAL, CHECKPOINT, WARP]},
]
func categories() -> Array: return P3_CATS
func default_hp() -> int: return 3
func _wants_parallax() -> bool: return false   # édition top-down : fond plat (vide = trou)


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
	var sky := Sky.new(); sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = e
	world3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	world3.add_child(sun)
	cam3 = Camera3D.new()
	cam3.current = false
	world3.add_child(cam3)


func _mat(c: Color) -> StandardMaterial3D:
	if not _mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		_mats[c] = m
	return _mats[c]


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
	return 0.0   # sol + marqueurs = plancher


func _build_world() -> void:
	for k in mesh_by_cell:
		for n in mesh_by_cell[k]: n.queue_free()
	mesh_by_cell.clear(); coin_nodes.clear()
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
			# plancher (dalle) — teinté par la tuile pour les marqueurs
			var slab_c := Color("9e9e9e") if t == FLOOR else col
			nodes.append(_box(Vector3(U, 0.16, U), Vector3(cx, -0.08, cz), slab_c))
			match t:
				COIN:
					var cn := _box(Vector3(0.36, 0.36, 0.08), Vector3(cx, 0.5, cz), Color("f1c40f"))
					coin_nodes.append(cn); nodes.append(cn)
				SPIKE:
					nodes.append(_box(Vector3(0.5, 0.45, 0.5), Vector3(cx, 0.22, cz), Color("e74c3c")))
				GOAL:
					nodes.append(_box(Vector3(0.1, 1.8, 0.1), Vector3(cx, 0.9, cz), Color("ecf0f1")))
					nodes.append(_box(Vector3(0.5, 0.3, 0.06), Vector3(cx + 0.25, 1.5, cz), Color("3498db")))
				MODE25, MODE3D:
					nodes.append(_box(Vector3(0.16, 0.9, 0.16), Vector3(cx, 0.45, cz), col))
				ENEMY:
					var en := _box(Vector3(0.6, 0.6, 0.6), Vector3(cx, 0.3, cz), Color("e74c3c"))
					enemies3.append({"node": en, "x": cx, "z": cz, "dir": 1.0,
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
	pos3 = Vector3(float(spawn_cell.x) + 0.5, 0.6, float(spawn_cell.y) + 0.5)
	vel3 = Vector3.ZERO
	move_mode = "3d"; jb3 = 0.0
	cam3.current = true
	cam3.position = pos3 + Vector3(0, 5.5, 7.0)


func stop_play() -> void:
	super()
	cam3.current = false
	if player3: player3.visible = false


func jump_pressed() -> void:
	if not dead and not won: jb3 = 0.12


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
			vel3.x = dx * SPEED3
			vel3.z = dz * SPEED3
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
		_:   target = pos3 + Vector3(0, 5.5, 7.0)
	cam3.position = cam3.position.lerp(target, clampf(7.0 * delta, 0.0, 1.0))
	cam3.look_at(pos3 + Vector3(0, 0.6, 0))


func _update_enemies3(delta: float) -> void:
	for en in enemies3:
		if not is_instance_valid(en.node): continue
		var nx: float = en.x + en.dir * 1.8 * delta
		var front := Vector2i(int(nx + (PHALF if en.dir > 0 else -PHALF)), int(en.z))
		var h := _cell_h(front)
		if h < -100.0 or h > 0.6:
			en.dir = -en.dir
		else:
			en.x = nx
		en.node.position = Vector3(en.x, 0.3, en.z)
		# contact joueur (si à hauteur)
		if absf(pos3.x - en.x) < 0.6 and absf(pos3.z - en.z) < 0.6 and pos3.y < 1.0:
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
	# en TEST : le monde est rendu par la caméra 3D, rien à dessiner en 2D
	if app != null and app.screen == "edit" and app.mode == "play":
		return
	super()
