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
	SLOPE_R, SLOPE_L, GSL_R_LO, GSL_R_HI, GSL_L_HI, GSL_L_LO,
	ONEWAY, LADDER, ICE, CONV_R, CONV_L, SWITCH, GATE,
	CURVE_RU_CV, CURVE_RU_CC, CURVE_RD_CV, CURVE_RD_CC,
	LOOP_CENTER,
	PALM, TREE, BUSH, FLOWER,
	LAVA, WATER,
	FLYER, FISH, SPIKER,
	CHASER, HOPPER, BOUNCER, SHOOTER,
	FALLBLOCK, FIREBAR, CRUMBLE,
	BOSS, FLOOR }
const PALETTE := [GROUND, SPAWN, COIN, ENEMY, GOAL, SPRING, SPIKE, BREAKABLE, MOVPLAT, CHECKPOINT, KEY, DOOR,
	SLOPE_R, SLOPE_L, GSL_R_LO, GSL_R_HI, GSL_L_HI, GSL_L_LO,
	CURVE_RU_CV, CURVE_RU_CC, CURVE_RD_CV, CURVE_RD_CC,
	ONEWAY, LADDER, ICE, CONV_R, CONV_L, SWITCH, GATE, LOOP_CENTER,
	PALM, TREE, BUSH, FLOWER, LAVA, WATER, FLYER, FISH, SPIKER,
	CHASER, HOPPER, BOUNCER, SHOOTER, FALLBLOCK, FIREBAR, CRUMBLE, BOSS]
const SLOPES := [SLOPE_R, SLOPE_L, GSL_R_LO, GSL_R_HI, GSL_L_HI, GSL_L_LO,
	CURVE_RU_CV, CURVE_RU_CC, CURVE_RD_CV, CURVE_RD_CC]
const NAMES := {
	GROUND: "Sol", SPAWN: "Spawn", COIN: "Pièce", ENEMY: "Ennemi", GOAL: "Arrivée",
	SPRING: "Ressort", SPIKE: "Piques", BREAKABLE: "Cassable", MOVPLAT: "Plateforme",
	CHECKPOINT: "Checkpoint", KEY: "Clé", DOOR: "Porte",
	SLOPE_R: "Pente45 ↗", SLOPE_L: "Pente45 ↖", GSL_R_LO: "Pente↗ bas", GSL_R_HI: "Pente↗ haut",
	GSL_L_HI: "Pente↖ haut", GSL_L_LO: "Pente↖ bas",
	ONEWAY: "Plateforme 1-sens", LADDER: "Échelle", ICE: "Glace",
	CONV_R: "Tapis →", CONV_L: "Tapis ←", SWITCH: "Interrupteur", GATE: "Grille",
	CURVE_RU_CV: "Courbe ↗ bombée", CURVE_RU_CC: "Courbe ↗ creuse",
	CURVE_RD_CV: "Courbe ↘ bombée", CURVE_RD_CC: "Courbe ↘ creuse",
	LOOP_CENTER: "Looping",
	PALM: "Palmier", TREE: "Arbre", BUSH: "Buisson", FLOWER: "Fleur",
	LAVA: "Lave", WATER: "Eau",
	FLYER: "Volant", FISH: "Poisson", SPIKER: "Piquant",
	CHASER: "Fantôme", HOPPER: "Sauteur", BOUNCER: "Rebond", SHOOTER: "Tourelle",
	FALLBLOCK: "Bloc tombant", FIREBAR: "Barre de feu", CRUMBLE: "Plateforme friable",
	BOSS: "Boss", FLOOR: "Sol"
}
const COLORS := {
	GROUND: Color("6b4a2b"), SPAWN: Color("2ecc71"), COIN: Color("f1c40f"),
	ENEMY: Color("e74c3c"), GOAL: Color("3498db"), SPRING: Color("e67e22"),
	SPIKE: Color("95a5a6"), BREAKABLE: Color("a0522d"), MOVPLAT: Color("16a085"),
	CHECKPOINT: Color("9b59b6"), KEY: Color("f1c40f"), DOOR: Color("7f5539"),
	SLOPE_R: Color("6b4a2b"), SLOPE_L: Color("6b4a2b"), GSL_R_LO: Color("6b4a2b"),
	GSL_R_HI: Color("6b4a2b"), GSL_L_HI: Color("6b4a2b"), GSL_L_LO: Color("6b4a2b"),
	ONEWAY: Color("c8924a"), LADDER: Color("d8b365"), ICE: Color("aee3f0"),
	CONV_R: Color("566573"), CONV_L: Color("566573"), SWITCH: Color("e91e8c"), GATE: Color("8e44ad"),
	CURVE_RU_CV: Color("6b4a2b"), CURVE_RU_CC: Color("6b4a2b"),
	CURVE_RD_CV: Color("6b4a2b"), CURVE_RD_CC: Color("6b4a2b"),
	LOOP_CENTER: Color("6b4a2b"),
	PALM: Color("27ae60"), TREE: Color("1e8449"), BUSH: Color("2ecc71"), FLOWER: Color("e74c3c"),
	LAVA: Color("e8521f"), WATER: Color("2e86de"),
	FLYER: Color("9b59b6"), FISH: Color("e67e22"), SPIKER: Color("c0392b"),
	CHASER: Color("ecf0f1"), HOPPER: Color("16a085"), BOUNCER: Color("e84393"), SHOOTER: Color("34495e"),
	FALLBLOCK: Color("7f8c8d"), FIREBAR: Color("e8521f"), CRUMBLE: Color("b08968"),
	BOSS: Color("8e1a3d"), FLOOR: Color("6b5d4f")
}
const CONV_SPEED := 95.0
const CLIMB_SPEED := 200.0
const ICE_FRICTION := 0.04   # 0 = patine à fond, 1 = stop net

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
const EFLY_SPEED := 75.0    # volant : vitesse horizontale
const EFLY_BOB_A := 20.0    # volant : amplitude du bobbing vertical (px)
const EFLY_BOB_F := 3.2     # volant : fréquence du bobbing
const EFISH_SPEED := 65.0   # poisson : vitesse de nage
const FISH_HOP_V := -560.0  # poisson hors de l'eau : impulsion de sursaut (magicarpe)
const FISH_HOP_VX := 70.0   # poisson hors de l'eau : dérive horizontale en l'air
const CHASE_SPEED := 92.0   # fantôme : vitesse de poursuite (lente → esquivable)
const HOP_INTERVAL := 1.3   # sauteur : délai entre bonds
const HOP_V := -700.0       # sauteur : impulsion verticale
const HOP_VX := 135.0       # sauteur : vitesse horizontale en saut
const BOUNCE_SPEED := 165.0 # rebondisseur : vitesse diagonale
const SHOOT_INTERVAL := 1.8 # tourelle : délai entre tirs
const PROJ_SPEED := 250.0   # projectile : vitesse
const PROJ_SIZE := 14.0     # projectile : diamètre
const FIREBAR_LEN := 3      # barre de feu : nombre de flammes
const FIREBAR_SPEED := 2.0  # barre de feu : vitesse de rotation (rad/s)
const CRUMBLE_DELAY := 0.45 # friable : délai avant rupture sous le joueur
const FALL_DELAY := 0.35    # bloc tombant : délai avant chute quand on passe dessous
const BOSS_SIZE := 88.0     # boss : taille (px)
const BOSS_HP := 5          # boss : nombre de coups (stomp) à encaisser
const BOSS_ENRAGE_HP := 2   # boss : passe en phase 2 (enrage) à ce nb de PV
const BOSS_SPEED := 80.0    # boss : vitesse horizontale
const BOSS_BOB_A := 26.0    # boss : amplitude bobbing
const BOSS_BOB_F := 1.8     # boss : fréquence bobbing
const BOSS_SHOOT := 1.5     # boss : délai entre tirs
const BOSS_INV := 0.7       # boss : invulnérabilité après un coup (s)
const BOSS_TELE := 0.6      # boss : durée du télégraphe avant une attaque
const BOSS_RECOVER := 1.2   # boss : fenêtre vulnérable après une attaque
const BOSS_CHARGE_SPD := 460.0  # boss : vitesse de charge
const SLOPE_SNAP_UP := 22.0
const SLOPE_SNAP_DOWN := 16.0
const STEP_UP := 24.0   # marche franchie sans saut ; ≈ demi-largeur joueur (jonction pente 45°↔bloc), < bloc plein 48px

# eau : nage (gravité réduite, descente lente, brasse vers le haut, traînée horizontale)
const WATER_GRAV := 0.30    # fraction de gravité sous l'eau
const WATER_SINK := 150.0   # vitesse de descente max
const WATER_RISE := -280.0  # vitesse de montée max
const WATER_SWIM := -310.0  # impulsion de brasse (répétable)
const WATER_DRAG := 0.86    # amortissement horizontal par frame
const AIR_MAX := 8.0        # secondes d'air avant noyade (si noyade activée)
# dash / esquive (les 2 genres) : burst + i-frames + cooldown
const DASH_SPEED := 720.0
const DASH_DUR := 0.16
const DASH_CD := 0.5
const DASH_IFRAME := 0.22
const HURT_IFRAME := 1.0    # invulnérabilité après un coup encaissé (PV)

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
var keys := {}            # clés ramassées par couleur : {"rouge":1,...}
const KEY_COLORS := {"or": Color("f1c40f"), "rouge": Color("e74c3c"), "bleu": Color("3498db"), "vert": Color("2ecc71")}
var spawn_cell := Vector2i(4, 8)
var respawn_cell := Vector2i(4, 8)
var last_from_cursor := false
var enemies := []
var projectiles := []   # tirs des tourelles {pos, vel, alive}
var hazards := []       # barres de feu + blocs en chute {type, ...}
var crumbled := {}      # cases de plateforme friable déjà rompues
var crumble_t := {}     # compte à rebours de rupture par case friable
var fb_trig := {}       # cases de bloc tombant déjà déclenchées
var fb_t := {}          # compte à rebours de déclenchement par bloc tombant
var plats := []
var testing := false
var test_dir := 0
# nouvelles mécaniques
var on_ladder := false
var climbing := false
var on_ice := false
var was_in_water := false
var air_t := 8.0          # réserve d'air courante (noyade)
var time_left := 0.0      # chrono restant (0 = pas de limite)
var hearts := 0           # PV courants (0 = système désactivé → mort instantanée)
var max_hearts := 0
var pinv := 0.0           # invulnérabilité joueur (i-frames, ex: dash)
var dash_cd := 0.0
var dashing := 0.0        # temps restant du dash en cours
var dash_dir := Vector2.RIGHT
var prev_vx := 0.0
var gates_open := false
var switch_cd := 0.0
var autorun_dir := 1
# mode Sonic (physique à momentum, activé par level_props.sonic)
var gsp := 0.0           # vitesse le long du sol (tangente)
var gangle := 0.0        # angle du sol (radians)
var sonic_grounded := false
var land_debug := ""
var active_loops: Array = []
var loop_exit_cd := 0.0   # cooldown post-loop : empêche la re-entrée immédiate
var _on_loop := false     # joueur était sur le mur du loop au frame précédent
const SONIC_ACC := 1500.0
const SONIC_DEC := 4200.0      # freinage (sens opposé)
const SONIC_FRIC := 1100.0
const SONIC_TOP := 760.0
const SONIC_SLOPE := 800.0     # force de la pente sur gsp (≤850 requis pour boucler R=144)
const SONIC_JUMP := 660.0
const SONIC_AIR_ACC := 1500.0
const STICK_TOL := 26.0        # tolérance pour rester collé au sol
const LAND_TOL := 30.0
const LOOP_R := 3.0 * CELL     # rayon looping (144px = 6 tiles de diamètre)
const LOOP_WALL := CELL * 0.3  # épaisseur mur looping (14px)
const LOOP_OPEN := 0.5236      # demi-angle ouverture bas (30°) — cercle quasi-complet


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

# catégories de palette de l'éditeur (par genre). ForgeApp appelle tmpl.categories().
const CATEGORIES := [
	{"name": "Terrain",  "tiles": [1, 13, 14, 15, 16, 17, 18, 26, 27, 28, 29, 8, 21, 19, 30]},
	{"name": "Danger",   "tiles": [7, 35, 36, 44, 45, 46]},
	{"name": "Ennemis",  "tiles": [4, 37, 38, 39, 40, 41, 42, 43, 47]},
	{"name": "Items",    "tiles": [3, 11, 6]},
	{"name": "Mecanique","tiles": [9, 20, 22, 23, 24, 25, 12]},
	{"name": "Reperes",  "tiles": [2, 10, 5]},
	{"name": "Decor",    "tiles": [31, 32, 33, 34]},
]
func categories() -> Array: return CATEGORIES
func movplat_tile() -> int: return MOVPLAT   # tuile configurable (cfg) ; -1 si aucune


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
	dead = false; won = false; death_t = 0.0; has_key = false; keys = {}
	on_floor = false; was_floor = false; coyote_t = 0.0; jbuf = 0.0
	pvel = Vector2.ZERO; input_x = 0
	on_ladder = false; climbing = false; on_ice = false; prev_vx = 0.0
	was_in_water = false; air_t = AIR_MAX
	time_left = _time_limit()
	pinv = 0.0; dashing = 0.0; dash_cd = 0.0
	max_hearts = int(app.level_props.get("player_hp", default_hp()))
	hearts = max_hearts
	gates_open = false; switch_cd = 0.0; autorun_dir = 1
	gsp = 0.0; gangle = 0.0; sonic_grounded = false
	_build_entities()
	_place_player(spawn_cell)
	if player_sm:
		player_sm.change_state("Grounded")
		player_sm.change_state("Idle")


# (re)construit ennemis/plateformes/grilles à leur état initial — appelé au start ET au respawn
func _build_entities() -> void:
	enemies.clear(); plats.clear(); active_loops.clear(); projectiles.clear()
	hazards.clear(); crumbled.clear(); crumble_t.clear(); fb_trig.clear(); fb_t.clear()
	gates_open = false
	for k in app.grid:
		if app.grid[k] == ENEMY:
			enemies.append({"type": "walker", "pos": Vector2(k.x * CELL + 6, k.y * CELL + (CELL - ESIZE)), "dir": -1, "alive": true, "vy": 0.0})
		elif app.grid[k] == SPIKER:
			enemies.append({"type": "spiker", "pos": Vector2(k.x * CELL + 6, k.y * CELL + (CELL - ESIZE)), "dir": -1, "alive": true, "vy": 0.0})
		elif app.grid[k] == FLYER:
			var fy: float = float(k.y * CELL) + 6.0
			enemies.append({"type": "flyer", "pos": Vector2(float(k.x * CELL) + 6.0, fy), "dir": -1, "alive": true,
				"base_y": fy, "phase": 0.0, "min": float((k.x - 4) * CELL), "max": float((k.x + 4) * CELL)})
		elif app.grid[k] == FISH:
			var wy: float = float(k.y * CELL) + 6.0
			enemies.append({"type": "fish", "pos": Vector2(float(k.x * CELL) + 6.0, wy), "dir": -1, "alive": true,
				"base_y": wy, "phase": 0.0, "vy": 0.0, "hop_t": 0.4})
		elif app.grid[k] == CHASER:
			enemies.append({"type": "chaser", "pos": Vector2(float(k.x * CELL) + 6.0, float(k.y * CELL) + 6.0),
				"dir": -1, "alive": true, "phase": 0.0})
		elif app.grid[k] == HOPPER:
			enemies.append({"type": "hopper", "pos": Vector2(float(k.x * CELL) + 6.0, float(k.y * CELL) + (CELL - ESIZE)),
				"dir": -1, "alive": true, "vy": 0.0, "hop_t": HOP_INTERVAL})
		elif app.grid[k] == BOUNCER:
			enemies.append({"type": "bouncer", "pos": Vector2(float(k.x * CELL) + 6.0, float(k.y * CELL) + 6.0),
				"dir": -1, "alive": true, "vel": Vector2(BOUNCE_SPEED, BOUNCE_SPEED)})
		elif app.grid[k] == SHOOTER:
			enemies.append({"type": "shooter", "pos": Vector2(float(k.x * CELL) + 6.0, float(k.y * CELL) + (CELL - ESIZE)),
				"dir": -1, "alive": true, "vy": 0.0, "shoot_t": SHOOT_INTERVAL})
		elif app.grid[k] == BOSS:
			var bx := float(k.x * CELL) + (CELL - BOSS_SIZE) * 0.5
			var by := float(k.y * CELL) + 6.0
			enemies.append({"type": "boss", "pos": Vector2(bx, by), "dir": -1, "alive": true,
				"hp": BOSS_HP, "base_y": by, "phase": 0, "inv": 0.0,
				"state": "intro", "st": 0.0, "atk": "", "fired": false, "tele": false, "vx": 0.0,
				"queue": [], "enraged": false,
				"min": float((k.x - 5) * CELL), "max": float((k.x + 5) * CELL)})
		elif app.grid[k] == FIREBAR:
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


# ---- dash / esquive (partagé par les genres) ----
func _tick_player_timers(delta: float) -> void:
	if pinv > 0.0: pinv -= delta
	if dash_cd > 0.0: dash_cd -= delta
	if dashing > 0.0: dashing -= delta


func _dash_input() -> bool:
	return Input.is_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)


func _start_dash(dir: Vector2) -> void:
	if dir.length() < 0.1: dir = Vector2(1, 0)
	dashing = DASH_DUR; dash_cd = DASH_CD; pinv = DASH_IFRAME
	dash_dir = dir.normalized()
	app._emit(ppos + PSIZE * 0.5, 8, Color("9be7ff"), 200.0, 0.3, false, 3.0)
	app._shake(2.0, 0.08); app._play("jump")


func _process(_delta: float) -> void:
	# En play : redraw continu (perso/ennemis/fx bougent).
	# En édition : le monde est statique ; ForgeApp déclenche tmpl.queue_redraw()
	# uniquement quand le monde change (case éditée, pan, dézoom, thème...).
	if app != null and app.screen == "edit" and app.mode == "play":
		queue_redraw()


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
		queue_redraw(); app.queue_redraw()
		return

	input_x = _dir_x()
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
	queue_redraw()
	app.queue_redraw()


# =================================================== simulation helpers
func _autorun() -> bool:
	if testing: return false
	var ap = app.get("level_props")
	return ap != null and ap.get("autorun", false)


func _dir_x() -> int:
	if testing: return test_dir
	if _autorun():
		return autorun_dir
	var v := 0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): v -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): v += 1
	var ax := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	if absf(ax) > DEADZONE: v += int(signf(ax))
	return clampi(v, -1, 1)


func _dir_y() -> int:
	if testing: return 0
	var v := 0
	if Input.is_key_pressed(KEY_UP) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP): v -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN): v += 1
	var ay := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(ay) > DEADZONE: v += int(signf(ay))
	return clampi(v, -1, 1)


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
		var t: int = app.grid.get(c, EMPTY)
		# friable rompue / bloc tombant déclenché → plus solides
		if crumbled.has(c) or fb_trig.has(c):
			continue
		if _is_full_solid(t) and not _under_slope(c):
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


func _is_full_solid(t: int) -> bool:
	if t == GROUND or t == BREAKABLE or t == DOOR or t == ICE or t == CONV_R or t == CONV_L: return true
	if t == FALLBLOCK or t == CRUMBLE: return true
	if t == GATE and not gates_open: return true
	return false


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


# volant : pas de gravité, va-et-vient horizontal entre bornes + bobbing sinus
func _enemy_flyer(en: Dictionary, delta: float) -> void:
	en.phase += delta
	var nx: float = en.pos.x + en.dir * EFLY_SPEED * delta
	var col := int((nx + (ESIZE if en.dir > 0 else 0)) / CELL)
	var row := int((en.pos.y + ESIZE * 0.5) / CELL)
	if _solid_tile(Vector2i(col, row)) or nx < en.min or nx > en.max:
		en.dir = -en.dir
	else:
		en.pos.x = nx
	en.pos.y = en.base_y + sin(en.phase * EFLY_BOB_F) * EFLY_BOB_A


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


# fantôme : poursuite lente du joueur, traverse tout (vol libre), stompable
func _enemy_chaser(en: Dictionary, delta: float) -> void:
	en.phase += delta
	var ec: Vector2 = en.pos + Vector2(ESIZE, ESIZE) * 0.5
	var target: Vector2 = ppos + PSIZE * 0.5
	var to := target - ec
	if to.length() > 2.0:
		en.pos += to.normalized() * CHASE_SPEED * delta
	en.pos.y += sin(en.phase * 3.0) * 0.4   # léger flottement


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


# ============================================================ BOSS (FSM exemple)
# Machine à états d'un boss volant. Pensée pour être TUNÉE/ÉTENDUE :
#  - phases = nombre de PV perdus (en.phase) → attaques + agressives quand il faiblit
#  - le choix d'attaque est dans _boss_choose() (pondéré par phase)
#  - chaque état = une fonction _boss_<nom>() ; pour en ajouter un :
#       1) ajoute "mon_etat" dans le match de _enemy_boss
#       2) écris func _boss_mon_etat(en, delta)
#       3) entre-y via _boss_to(en, "mon_etat")
#  - constantes de réglage : BOSS_* (vitesse, télégraphe, fenêtre vulnérable...)
#
# Cycle : intro → (choose) → telegraph → [shoot|charge] → recover(vulnérable) → choose
#         hurt (quand stompé) → choose
func _enemy_boss(en: Dictionary, delta: float) -> void:
	if en.inv > 0.0: en.inv -= delta
	en.st += delta
	en.phase = BOSS_HP - int(en.hp)   # 0 (plein) → 2 (presque mort)
	match en.get("state", "intro"):
		"intro":     _boss_intro(en, delta)
		"enrage":    _boss_enrage(en, delta)
		"telegraph": _boss_telegraph(en, delta)
		"shoot":     _boss_shoot(en, delta)
		"charge":    _boss_charge(en, delta)
		"slam":      _boss_slam(en, delta)
		"recover":   _boss_recover(en, delta)
		"hurt":      _boss_hurt(en, delta)


func _boss_to(en: Dictionary, st: String) -> void:
	en.state = st; en.st = 0.0; en.fired = false
	en.tele = (st == "telegraph")


func _boss_center(en: Dictionary) -> Vector2:
	return en.pos + Vector2(BOSS_SIZE, BOSS_SIZE) * 0.5


func _boss_hover(en: Dictionary, y_off: float) -> void:
	# flottement sinusoïdal autour de base_y (+ décalage selon l'état)
	en.pos.y = en.base_y + y_off + sin(en.st * BOSS_BOB_F) * BOSS_BOB_A


func _boss_intro(en: Dictionary, _delta: float) -> void:
	_boss_hover(en, 0.0)
	if en.st > 1.0: _boss_choose(en)


# construit une SÉQUENCE d'attaques (combo) selon le contexte + la phase, puis l'enchaîne.
# La fenêtre vulnérable (recover) n'arrive qu'à la FIN du combo.
func _boss_choose(en: Dictionary) -> void:
	en.queue = _boss_build_queue(en)
	_boss_next(en)


# enchaîne l'attaque suivante du combo ; si fini → fenêtre vulnérable (recover)
func _boss_next(en: Dictionary) -> void:
	if en.queue.is_empty():
		_boss_to(en, "recover")
	else:
		en.atk = en.queue.pop_front()
		_boss_to(en, "telegraph")


# choix CONTEXTUEL : lit la distance + si le joueur est en l'air pour décider.
func _boss_pick_ctx(en: Dictionary) -> String:
	var pc := ppos + PSIZE * 0.5
	var bc := _boss_center(en)
	var dist: float = absf(pc.x - bc.x)
	var airborne: bool = not on_floor or pc.y < bc.y - CELL
	if airborne:
		return "shoot"                       # anti-air : tir visé (suit le joueur)
	if dist > 6.0 * CELL:
		return "charge" if randf() < 0.6 else "shoot"   # loin : fonce ou canarde
	# proche au sol : slam si la phase le permet, sinon mix
	if en.enraged or en.phase >= 1:
		return "slam" if randf() < 0.6 else "charge"
	return "shoot" if randf() < 0.5 else "charge"


# longueur du combo : 1 normalement, 2-3 enragé → moveset qui s'enchaîne
func _boss_build_queue(en: Dictionary) -> Array:
	var n := 1
	if en.enraged: n = 3 if randf() < 0.5 else 2
	elif en.phase >= 2: n = 2 if randf() < 0.45 else 1
	var q := []
	var last := ""
	for _i in n:
		var a := _boss_pick_ctx(en)
		if a == "slam" and last == "slam": a = "charge"   # évite double-slam
		q.append(a); last = a
	return q


# PHASE 2 : rugissement (flash + shake), puis devient enragé (combos longs, télégraphe court)
func _boss_enrage(en: Dictionary, _delta: float) -> void:
	en.inv = 0.3   # invulnérable pendant le rugissement
	_boss_hover(en, 0.0)
	if int(en.st * 12.0) % 2 == 0:
		app._emit(_boss_center(en), 3, COLORS[BOSS].lightened(0.4), 200.0, 0.25, true, 4.0)
	if en.st > 1.0:
		en.enraged = true
		app._shake(8.0, 0.3); app._play("win")
		_boss_choose(en)


# télégraphe : clignote sur place, prévient le joueur, puis lance l'attaque
func _boss_telegraph(en: Dictionary, _delta: float) -> void:
	_boss_hover(en, 0.0)
	var dur: float = maxf(0.2, (BOSS_TELE * 0.55) if en.enraged else (BOSS_TELE - float(en.phase) * 0.06))
	if en.st >= dur:
		_boss_to(en, en.atk)


# attaque tir : salve en éventail vers le joueur (1 / 3 / 5 selon phase)
func _boss_shoot(en: Dictionary, _delta: float) -> void:
	_boss_hover(en, 0.0)
	if not en.fired:
		var n: int = [1, 3, 5][mini(int(en.phase), 2)]
		_boss_volley(en, n, deg_to_rad(16.0))
		en.fired = true
	if en.st > 0.4:
		_boss_next(en)


func _boss_volley(en: Dictionary, n: int, spread: float) -> void:
	var ctr := _boss_center(en)
	var base := (ppos + PSIZE * 0.5) - ctr
	if base.length() < 1.0: base = Vector2(en.dir, 0.2)
	base = base.normalized()
	var a0 := base.angle()
	for i in n:
		var a := a0 + (float(i) - float(n - 1) * 0.5) * spread
		projectiles.append({"pos": ctr, "vel": Vector2(cos(a), sin(a)) * PROJ_SPEED, "alive": true})
	app._emit(ctr, 6, COLORS[BOSS].lightened(0.4), 140.0, 0.25, false, 3.0)
	app._play("spring")


# attaque charge : fonce horizontalement vers le côté du joueur
func _boss_charge(en: Dictionary, delta: float) -> void:
	if not en.fired:
		en.vx = BOSS_CHARGE_SPD * (1.0 if ppos.x > en.pos.x else -1.0)
		en.fired = true
		app._shake(2.0, 0.1)
	en.pos.x += en.vx * delta
	en.pos.y = en.base_y + sin(en.st * 8.0) * 4.0   # léger tremblement
	if en.pos.x <= en.min or en.pos.x >= en.max or en.st > 1.3:
		en.pos.x = clampf(en.pos.x, en.min, en.max)
		app._shake(3.0, 0.12)
		_boss_next(en)


# attaque slam : se place au-dessus du joueur, monte, puis s'écrase → onde de choc au sol
func _boss_slam(en: Dictionary, delta: float) -> void:
	if not en.fired:
		en.sub = "rise"; en.vy = 0.0; en.fired = true
	if en.sub == "rise":
		# se cale au-dessus du joueur + prend de la hauteur
		en.pos.x = move_toward(en.pos.x, clampf(ppos.x - BOSS_SIZE * 0.5, en.min, en.max), 320.0 * delta)
		en.pos.y = move_toward(en.pos.y, en.base_y - 90.0, 640.0 * delta)
		if absf(en.pos.y - (en.base_y - 90.0)) < 4.0 or en.st > 0.8:
			en.sub = "drop"; en.vy = 0.0
	else:
		en.vy = min(en.vy + GRAVITY * 1.3 * delta, 1600.0)
		en.pos.y += en.vy * delta
		var fy := _boss_floor(en)
		if en.pos.y + BOSS_SIZE >= fy:
			en.pos.y = fy - BOSS_SIZE
			_boss_impact(en)
			_boss_next(en)


# trouve le Y du sol sous le boss (sinon bas du niveau)
func _boss_floor(en: Dictionary) -> float:
	var col := int((en.pos.x + BOSS_SIZE * 0.5) / CELL)
	var r0 := int((en.pos.y + BOSS_SIZE) / CELL)
	for row in range(maxi(r0, 0), app.rows + 1):
		if _solid_tile(Vector2i(col, row)):
			return float(row * CELL)
	return float(app.rows * CELL)


# impact du slam : shake + onde de choc (2 projectiles rasants gauche/droite)
func _boss_impact(en: Dictionary) -> void:
	app._shake(9.0, 0.35); app._play("break")
	var cx: float = en.pos.x + BOSS_SIZE * 0.5
	var fy: float = en.pos.y + BOSS_SIZE - PROJ_SIZE
	app._emit(Vector2(cx, en.pos.y + BOSS_SIZE), 20, COLORS[BOSS].lightened(0.2), 260.0, 0.5, true, 4.0)
	projectiles.append({"pos": Vector2(cx - BOSS_SIZE * 0.5, fy), "vel": Vector2(-PROJ_SPEED, 0.0), "alive": true})
	projectiles.append({"pos": Vector2(cx + BOSS_SIZE * 0.5, fy), "vel": Vector2(PROJ_SPEED, 0.0), "alive": true})


# récupération : descend + ralentit = fenêtre pour le stomper
func _boss_recover(en: Dictionary, _delta: float) -> void:
	_boss_hover(en, 40.0)   # plus bas → plus facile à atteindre
	if en.st > BOSS_RECOVER:
		_boss_choose(en)


# touché : recule à l'opposé du joueur (quitte la zone sous ses pieds) avant de reprendre.
# Empêche le boss de spammer un tir point-blank pendant qu'on est sur sa tête.
func _boss_hurt(en: Dictionary, delta: float) -> void:
	if not en.fired:
		en.vx = -260.0 if ppos.x > en.pos.x else 260.0
		en.fired = true
	en.pos.x = clampf(en.pos.x + en.vx * delta, en.min, en.max)
	_boss_hover(en, -18.0)
	# attend de s'être suffisamment éloigné du joueur ET un délai mini avant de reprendre
	var far_enough: bool = absf(_boss_center(en).x - (ppos.x + PSIZE.x * 0.5)) > BOSS_SIZE
	if en.st > 0.7 and (far_enough or en.st > 1.3):
		_boss_choose(en)


func _update_projectiles(delta: float) -> void:
	if projectiles.is_empty(): return
	var pr := Rect2(ppos, PSIZE)
	for pj in projectiles:
		if not pj.alive: continue
		pj.pos += pj.vel * delta
		var c := Vector2i(int(pj.pos.x / CELL), int(pj.pos.y / CELL))
		if _solid_tile(c) or pj.pos.x < 0 or pj.pos.x > app.cols * CELL:
			pj.alive = false; continue
		var pjr := Rect2(pj.pos - Vector2(PROJ_SIZE, PROJ_SIZE) * 0.5, Vector2(PROJ_SIZE, PROJ_SIZE))
		if pr.intersects(pjr):
			pj.alive = false; _die()
	projectiles = projectiles.filter(func(p): return p.alive)


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


func _solid_tile(c: Vector2i) -> bool:
	if crumbled.has(c) or fb_trig.has(c): return false
	var t: int = app.grid.get(c, EMPTY)
	return _is_full_solid(t) or t == ONEWAY


func _is_slope(t: int) -> bool:
	return SLOPES.has(t)


# décalage vertical (depuis le haut de la case, en pixels CELL) de la surface d'une rampe courbe
func _curve_offset(t: int, lx: float) -> float:
	var R := float(CELL)
	match t:
		CURVE_RU_CV: return sqrt(maxf(0.0, R * R - lx * lx))
		CURVE_RU_CC: return CELL - sqrt(maxf(0.0, R * R - (R - lx) * (R - lx)))
		CURVE_RD_CV: return sqrt(maxf(0.0, R * R - (R - lx) * (R - lx)))
		CURVE_RD_CC: return CELL - sqrt(maxf(0.0, R * R - lx * lx))
	return 0.0


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
		if _is_slope(t):
			var lx: float = clampf(p.x - c.x * CELL, 0.0, CELL)
			if p.y >= _slope_surface(t, c, lx): return true
	for pl in plats:   # plateformes mobiles : solides aussi en mode Sonic
		if Rect2(pl.pos, Vector2(int(pl.get("w", 1)) * CELL, 14)).has_point(p):
			return true
	if check_loops and loop_exit_cd <= 0.0 and not active_loops.is_empty():
		for lp in active_loops:
			var lc: Vector2 = lp.center
			var lr: float = lp.radius
			var d: float = (p - lc).length()
			if d >= lr - LOOP_WALL and d <= lr:
				var theta: float = atan2(p.y - lc.y, p.x - lc.x)
				if absf(wrapf(theta - PI * 0.5, -PI, PI)) > LOOP_OPEN:
					return true
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


func _sonic_physics(delta: float) -> void:
	input_x = _dir_x()
	jbuf -= delta
	switch_cd -= delta
	loop_exit_cd = maxf(0.0, loop_exit_cd - delta)
	var ix := autorun_dir if _autorun() else input_x
	var pc := ppos + PSIZE * 0.5
	land_debug = "gsp=%.0f ang=%.0f° %s%s" % [
		gsp, rad_to_deg(gangle),
		"LOOP " if _on_loop else "",
		("lcd=%.1f" % loop_exit_cd) if loop_exit_cd > 0.0 else ""
	]

	var in_water := _in_water()
	if in_water != was_in_water:
		app._emit(pc, 10, Color("aee3f0"), 170.0, 0.35, true, 3.0)
		app._shake(2.0, 0.08)
	was_in_water = in_water
	_update_air(delta, in_water)

	if sonic_grounded:
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


# capte le sol : mode analytique sur loop (cercle exact), sinon sondes. recale ppos+gangle.
func _ground_sense(pc: Vector2) -> bool:
	# === mode analytique : joueur collé au cercle du loop ===
	if _on_loop and loop_exit_cd <= 0.0 and not active_loops.is_empty():
		for lp in active_loops:
			var lc: Vector2 = lp.center
			var lr: float = lp.radius
			var target_d := lr - LOOP_WALL - PSIZE.y * 0.5   # 111.6px : centre→surface interne
			var theta := atan2(pc.y - lc.y, pc.x - lc.x)
			var in_opening := absf(wrapf(theta - PI * 0.5, -PI, PI)) <= LOOP_OPEN
			if in_opening:
				# joueur revenu dans l'ouverture → sortie normale du loop
				_on_loop = false
				loop_exit_cd = 1.5
				gangle = 0.0   # reset pour que le capteur sol retrouve le plancher proprement
				break
			var d: float = (pc - lc).length()
			if absf(d - target_d) < 36.0:
				# colle au cercle, gangle = tangente CCW (classique Sonic)
				pc = lc + Vector2(cos(theta), sin(theta)) * target_d
				gangle = wrapf(atan2(-cos(theta), sin(theta)), -PI, PI)
				ppos = pc - PSIZE * 0.5
				return true
		# dérivé trop loin du cercle OU sortie par l'ouverture → retomber en mode capteur
		_on_loop = false

	# === mode capteur standard (sol plat / pentes / entry loop) ===
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

	# entrée loop : mur trouvé au-dessus du sol + côté cohérent avec gsp
	# (gsp > 0 = va à droite → entrée valide seulement côté droit, theta < 90°)
	if not _on_loop and loop_exit_cd <= 0.0 and not active_loops.is_empty() and dc < PSIZE.y * 0.5 - 2.0:
		for lp in active_loops:
			var lc: Vector2 = lp.center
			var lr: float = lp.radius
			var target_d := lr - LOOP_WALL - PSIZE.y * 0.5
			var d: float = (pc - lc).length()
			if absf(d - target_d) < 24.0:
				var theta := atan2(pc.y - lc.y, pc.x - lc.x)
				if absf(wrapf(theta - PI * 0.5, -PI, PI)) > LOOP_OPEN:
					# entrée valide seulement du bon côté selon direction du joueur
					var valid_side := theta < PI * 0.5 if gsp >= 0.0 else theta > PI * 0.5
					if valid_side:
						_on_loop = true
						gangle = wrapf(atan2(-cos(theta), sin(theta)), -PI, PI)
						pc = lc + Vector2(cos(theta), sin(theta)) * target_d
						ppos = pc - PSIZE * 0.5
						return true

	var off := 10.0
	var oa := pc + fw * (-off)
	var ob := pc + fw * (off)
	var da := _cast(oa, dn, reach + 12.0)
	var db := _cast(ob, dn, reach + 12.0)
	if da != INF and db != INF and absf(da - db) < CELL:
		var ha := oa + dn * da
		var hb := ob + dn * db
		var raw := atan2(hb.y - ha.y, hb.x - ha.x)
		var step: float = clampf(angle_difference(gangle, raw), -deg_to_rad(18.0), deg_to_rad(18.0))
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


# PV par défaut du genre (override : top-down = 3). 0 = mort instantanée.
func default_hp() -> int: return 0


# dégât encaissé : perd un cœur si PV actifs (i-frames), sinon mort réelle
func _die() -> void:
	if dead or pinv > 0.0: return   # i-frames (dash/dégât) → invulnérable
	if max_hearts > 0 and hearts > 1:
		hearts -= 1; pinv = HURT_IFRAME
		app._emit(ppos + PSIZE * 0.5, 10, Color("e74c3c"), 220.0, 0.4, false, 4.0)
		app._shake(5.0, 0.2); Input.start_joy_vibration(0, 0.5, 0.3, 0.15); app._play("death")
		return
	_kill()


# mort réelle (chute / chrono / dernier cœur)
func _kill() -> void:
	if dead: return
	dead = true; death_t = 0.7; hearts = 0
	app._emit(ppos + PSIZE * 0.5, 16, Color("ecf0f1"), 260.0, 0.5, true, 4.0)
	app._shake(9.0, 0.30)
	Input.start_joy_vibration(0, 0.6, 0.7, 0.30); app._play("death")
	player_died.emit()


func _interactions(delta: float) -> void:
	# chrono : si une limite est posée, décompte et mort si épuisé
	if time_left > 0.0:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			app._shake(6.0, 0.2); _kill()
			return
	for c in _cells(Rect2(ppos, PSIZE)):
		match app.grid.get(c, EMPTY):
			COIN:
				app.grid.erase(c); coins_got += 1
				app._emit(_cell_center(c), 8, COLORS[COIN], 160.0, 0.35, false, 3.0)
				Input.start_joy_vibration(0, 0.25, 0.0, 0.04); app._play("coin")
				coin_collected.emit()
			KEY:
				var kcol := _cell_color(c)
				keys[kcol] = int(keys.get(kcol, 0)) + 1
				has_key = true
				app.grid.erase(c); app.cell_cfg.erase(c)
				app._emit(_cell_center(c), 10, KEY_COLORS.get(kcol, COLORS[KEY]), 180.0, 0.4, false, 3.0)
				app._play("key")
			SPIKE:
				_die()
			LAVA:
				_die()
			SPRING:
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
			SWITCH:
				if switch_cd <= 0.0:
					gates_open = not gates_open
					switch_cd = 0.4
					app._emit(_cell_center(c), 12, COLORS[SWITCH], 200.0, 0.4, true, 4.0)
					app._shake(3.0, 0.1); app._play("key")
			CHECKPOINT:
				if respawn_cell != c:
					respawn_cell = c
					app._emit(_cell_center(c), 12, COLORS[CHECKPOINT], 200.0, 0.5, false, 3.0)
					app._play("coin")
			GOAL:
				if not won:
					if _goal_unlocked():
						won = true
						app._emit(_cell_center(c), 24, COLORS[GOAL], 240.0, 0.7, false, 4.0)
						app._play("win")
						level_won.emit()
					else:
						app._set_toast(_goal_reason())
	# portes : ouvre si on a une clé de la BONNE couleur (consommée)
	for c in _cells(Rect2(ppos - Vector2(5, 5), PSIZE + Vector2(10, 10))):
		if app.grid.get(c, EMPTY) == DOOR:
			var dcol := _cell_color(c)
			if int(keys.get(dcol, 0)) > 0:
				keys[dcol] = int(keys[dcol]) - 1
				has_key = _has_any_key()
				app.grid.erase(c); app.cell_cfg.erase(c)
				app._emit(_cell_center(c), 14, KEY_COLORS.get(dcol, COLORS[DOOR]), 200.0, 0.45, true, 4.0)
				app._play("key"); app._shake(3.0, 0.1)
				break


func _cell_color(c: Vector2i) -> String:
	var cfg = app.cell_cfg.get(c, {})
	return str(cfg.get("color", "or"))


func _has_any_key() -> bool:
	for k in keys:
		if int(keys[k]) > 0: return true
	return false


func _in_water() -> bool:
	var c := Vector2i(int((ppos.x + PSIZE.x * 0.5) / CELL), int((ppos.y + PSIZE.y * 0.5) / CELL))
	return app.grid.get(c, EMPTY) == WATER


func _time_limit() -> float:
	var ap = app.get("level_props")
	return float(ap.get("time_limit", 0)) if ap != null else 0.0


# nombre d'ennemis tuables encore vivants (exclut piquant/poisson/rebond non-tuables)
func _enemies_left() -> int:
	var n := 0
	for en in enemies:
		if en.alive and en.type != "spiker" and en.type != "fish" and en.type != "bouncer":
			n += 1
	return n


# l'Arrivée est-elle déverrouillée ? (pièces requises + tuer tous)
func _goal_unlocked() -> bool:
	var ap = app.get("level_props")
	if ap == null: return true
	if coins_got < int(ap.get("win_coins", 0)): return false
	if ap.get("win_killall", false) and _enemies_left() > 0: return false
	return true


func _goal_reason() -> String:
	var ap = app.get("level_props")
	if ap == null: return ""
	var need: int = int(ap.get("win_coins", 0))
	if coins_got < need:
		return "Pièces : %d / %d" % [coins_got, need]
	if ap.get("win_killall", false) and _enemies_left() > 0:
		return "Ennemis restants : %d" % _enemies_left()
	return ""


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
	var lvl_r := Rect2(app._w2s(Vector2.ZERO), lvl * app.view_scale)
	_draw_parallax(vp, lvl_r)

	# mode "édition du fond" : on n'affiche QUE le parallax (objets/tuiles cachés)
	if app.get("bg_edit") == true:
		return

	# culling : bornes de cases visibles à l'écran (gros niveaux = 140+ cols)
	var w_tl: Vector2 = app._s2w(Vector2.ZERO)
	var w_br: Vector2 = app._s2w(vp)
	var cx0: int = maxi(int(floor(w_tl.x / CELL)) - 1, 0)
	var cx1: int = mini(int(floor(w_br.x / CELL)) + 1, app.cols)
	var cy0: int = maxi(int(floor(w_tl.y / CELL)) - 1, 0)
	var cy1: int = mini(int(floor(w_br.y / CELL)) + 1, app.rows)

	var _hide_chrome: bool = app.get("hide_editor_chrome") == true
	if app.mode == "edit" and not app.dezoom and not _hide_chrome:
		var gcol := Color(1, 1, 1, 0.06)
		for x in range(cx0, cx1 + 1):
			draw_line(app._w2s(Vector2(x * CELL, cy0 * CELL)), app._w2s(Vector2(x * CELL, (cy1 + 1) * CELL)), gcol)
		for y in range(cy0, cy1 + 1):
			draw_line(app._w2s(Vector2(cx0 * CELL, y * CELL)), app._w2s(Vector2((cx1 + 1) * CELL, y * CELL)), gcol)

	for k in app.grid:
		if k.x < cx0 or k.x > cx1 or k.y < cy0 or k.y > cy1:
			continue
		var tk: int = app.grid[k]
		if app.mode == "play" and (tk == ENEMY or tk == MOVPLAT or tk == FLYER or tk == FISH or tk == SPIKER \
				or tk == CHASER or tk == HOPPER or tk == BOUNCER or tk == SHOOTER or tk == FIREBAR \
				or tk == BOSS or crumbled.has(k) or fb_trig.has(k)):
			continue
		# autotile vertical (eau/lave) : surface = pas la même tuile juste au-dessus
		var surf: bool = app.grid.get(Vector2i(k.x, k.y - 1), EMPTY) != tk
		draw_tile(self, app._w2s(Vector2(k.x * CELL, k.y * CELL)), tk, app.view_scale, 1.0, true, surf)
		# pastille de couleur sur clés/portes (énigmes : couleur = paire clé↔porte)
		if tk == KEY or tk == DOOR:
			var kc: Color = KEY_COLORS.get(str(app.cell_cfg.get(k, {}).get("color", "or")), Color.WHITE)
			draw_circle(app._w2s(Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL)), CELL * 0.16 * app.view_scale, kc)

	# rendu des loopings (edit : depuis grid, play : depuis active_loops)
	if app.mode == "play":
		for lp in active_loops:
			_draw_loop_ring(app._w2s(lp.center), lp.radius * app.view_scale)
	else:
		# rayon looping = 3 cases → fenêtre élargie de 4
		for k in app.grid:
			if app.grid[k] != LOOP_CENTER:
				continue
			if k.x < cx0 - 4 or k.x > cx1 + 4 or k.y < cy0 - 4 or k.y > cy1 + 4:
				continue
			_draw_loop_ring(app._w2s(Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL)), LOOP_R * app.view_scale)

	for p in app.particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		var c: Color = p.col; c.a = a
		draw_circle(app._w2s(p.pos), p.size * app.view_scale, c)

	# NOTE: le curseur d'édition (sél/fantôme/boîte) est dessiné par ForgeApp (overlay),
	# pas ici, pour que bouger le pointeur ne force PAS un redraw du monde.

	if app.mode == "play":
		for p in plats:
			for wi in int(p.get("w", 1)):
				draw_tile(self, app._w2s(p.pos + Vector2(wi * CELL, 0)), MOVPLAT, app.view_scale)
		for en in enemies:
			if not en.alive: continue
			if en.type == "boss":
				var bctr: Vector2 = app._w2s(_boss_center(en))
				# enragé (phase 2) : aura rouge pulsante
				if en.get("enraged", false) or en.get("state", "") == "enrage":
					var ar: float = (BOSS_SIZE * 0.72 + sin(app.anim_t * 9.0) * 6.0) * app.view_scale
					draw_arc(bctr, ar, 0.0, TAU, 30, Color("e74c3c", 0.6), 4.0 * app.view_scale)
				# télégraphe : anneau qui pulse avant une attaque (prévient le joueur)
				if en.get("tele", false):
					var pr: float = (BOSS_SIZE * 0.6 + sin(en.st * 18.0) * 8.0) * app.view_scale
					draw_arc(bctr, pr, 0.0, TAU, 28, Color("ffde59", 0.8), 3.0 * app.view_scale)
				# clignote pendant l'invulnérabilité
				if en.inv > 0.0 and int(en.inv * 20.0) % 2 == 0:
					pass
				else:
					draw_tile(self, app._w2s(en.pos), BOSS, (BOSS_SIZE / float(CELL)) * app.view_scale)
				# barre de PV au-dessus
				var bw: float = BOSS_SIZE * app.view_scale
				var bp: Vector2 = app._w2s(en.pos) - Vector2(0, 12 * app.view_scale)
				draw_rect(Rect2(bp, Vector2(bw, 6 * app.view_scale)), Color(0, 0, 0, 0.5))
				draw_rect(Rect2(bp, Vector2(bw * float(en.hp) / float(BOSS_HP), 6 * app.view_scale)), Color("e74c3c"))
				continue
			var et := ENEMY
			match en.get("type", "walker"):
				"flyer": et = FLYER
				"fish":  et = FISH
				"spiker": et = SPIKER
				"chaser": et = CHASER
				"hopper": et = HOPPER
				"bouncer": et = BOUNCER
				"shooter": et = SHOOTER
			draw_tile(self, app._w2s(en.pos - Vector2(6, 6)), et, app.view_scale)
		for pj in projectiles:
			if pj.alive:
				draw_circle(app._w2s(pj.pos), PROJ_SIZE * 0.5 * app.view_scale, Color("ffce54"))
				draw_circle(app._w2s(pj.pos), PROJ_SIZE * 0.28 * app.view_scale, Color("fff3c4"))
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
		var ps: Vector2 = PSIZE * app.squash
		if _sonic():
			# perso tourné selon l'angle du sol (gangle)
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
		else:
			var anchor: Vector2 = app._w2s(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y))
			var pr := Rect2(anchor - Vector2(ps.x * 0.5, ps.y) * app.view_scale, ps * app.view_scale)
			draw_rect(pr, Color("ffffff")); draw_rect(pr, Color("2c3e50"), false, 2.0)
			if has_key:
				draw_circle(pr.position + Vector2(pr.size.x * 0.5, -8), 5, COLORS[KEY])


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


# ================================================================ PARALLAX
# un genre peut désactiver le parallax (collines/nuages) → fond plat
func _wants_parallax() -> bool: return true
# couche de sol automatique sous tout (override par genre, ex: top-down)
func _draw_ground(_clip_r: Rect2) -> void: pass


func _draw_parallax(_vp: Vector2, lvl_r: Rect2) -> void:
	var vo: Vector2 = app.view_origin; var vs: float = app.view_scale
	var bt: float = lvl_r.position.y + lvl_r.size.y
	# fenêtre visible à l'écran (clip horizontal) : évite de générer des polygones de
	# collines sur toute la largeur du niveau (6720px) à chaque frame.
	var vx0: float = maxf(lvl_r.position.x, 0.0)
	var vx1: float = minf(lvl_r.position.x + lvl_r.size.x, _vp.x)
	var clip_r := Rect2(Vector2(vx0, lvl_r.position.y), Vector2(maxf(vx1 - vx0, 0.0), lvl_r.size.y))
	# couches du thème (couleur de fond + descripteurs de couches, triés par profondeur)
	var layers := []
	match app.bg_theme:
		0:
			draw_rect(lvl_r, Color("5dade2"))
			layers.append({"f": 0.06, "k": "clouds", "c": Color(1, 1, 1, 0.82)})
			layers.append({"f": 0.14, "k": "hill", "c": Color("a9dfb5"), "h": 0.54, "fr": 0.0040, "ph": 0.0})
			layers.append({"f": 0.34, "k": "hill", "c": Color("27ae60"), "h": 0.38, "fr": 0.0065, "ph": 2.1})
			layers.append({"f": 0.60, "k": "hill", "c": Color("1a7a3c"), "h": 0.24, "fr": 0.0095, "ph": 4.7})
		1:
			draw_rect(lvl_r, Color("0f0225"))
			layers.append({"f": 0.04, "k": "stars"})
			layers.append({"f": 0.14, "k": "hill", "c": Color("2e1152"), "h": 0.58, "fr": 0.0032, "ph": 1.0})
			layers.append({"f": 0.34, "k": "hill", "c": Color("1a0a35"), "h": 0.42, "fr": 0.0058, "ph": 3.2})
			layers.append({"f": 0.60, "k": "hill", "c": Color("0d0018"), "h": 0.28, "fr": 0.0085, "ph": 5.5})
		2:
			draw_rect(lvl_r, Color("cce8f4"))
			layers.append({"f": 0.06, "k": "clouds", "c": Color(1, 1, 1, 0.72)})
			layers.append({"f": 0.14, "k": "hill", "c": Color("81c784"), "h": 0.52, "fr": 0.0038, "ph": 0.5})
			layers.append({"f": 0.34, "k": "hill", "c": Color("388e3c"), "h": 0.38, "fr": 0.0062, "ph": 2.8})
			layers.append({"f": 0.60, "k": "hill", "c": Color("1b5e20"), "h": 0.26, "fr": 0.0088, "ph": 5.1})
		3:
			draw_rect(lvl_r, Color("f5b349"))
			layers.append({"f": 0.14, "k": "hill", "c": Color("f0d080"), "h": 0.40, "fr": 0.0030, "ph": 0.8})
			layers.append({"f": 0.34, "k": "hill", "c": Color("c68642"), "h": 0.30, "fr": 0.0050, "ph": 2.5})
			layers.append({"f": 0.60, "k": "hill", "c": Color("8b4513"), "h": 0.20, "fr": 0.0078, "ph": 4.2})
		_:
			draw_rect(lvl_r, Color("223349"))
	# fond plat (ex: top-down) : on garde la couleur + les décors, mais pas collines/nuages
	if not _wants_parallax():
		layers.clear()
	# couche de sol auto (ex: top-down dessine un sol dallé sous tout) — base : rien
	_draw_ground(clip_r)
	# décors du créateur ajoutés comme couches (selon leur profondeur)
	for dd in app.bg_deco:
		layers.append({"f": float(dd["factor"]), "k": "deco", "d": dd})
	# index d'insertion pour un tri stable (à profondeur égale : ordre conservé)
	for i in layers.size(): layers[i]["i"] = i
	layers.sort_custom(func(a, b): return a["i"] < b["i"] if a["f"] == b["f"] else a["f"] < b["f"])
	# far (factor petit) dessiné en premier = derrière
	for L in layers:
		match L["k"]:
			"clouds": _px_clouds(L["c"], L["f"], clip_r, vo, vs)
			"stars":  _px_stars(clip_r, vo, vs)
			"hill":   _px_hills(L["c"], L["f"], L["h"], L["fr"], L["ph"], clip_r, vo, vs, bt)
			"deco":   _draw_one_deco(L["d"], vo, vs)


func _draw_one_deco(dd: Dictionary, vo: Vector2, vs: float) -> void:
	var fac: float = float(dd["factor"])
	if str(dd["shape"]) == "poly":
		var outline := PackedVector2Array()
		for p in dd["pts"]:
			outline.append(Vector2(float(p[0]) * vs + vo.x * fac, float(p[1]) * vs + vo.y * fac))
		fill_poly_closed(self, outline, Color(str(dd["col"])))
	else:
		var sp := Vector2(float(dd["x"]) * vs + vo.x * fac, float(dd["y"]) * vs + vo.y * fac)
		draw_bg_shape(self, str(dd["shape"]), sp, float(dd["scale"]) * vs, Color(str(dd["col"])))


# lisse une boucle FERMÉE (Catmull-Rom) → contour arrondi
func smooth_closed(pts: PackedVector2Array) -> PackedVector2Array:
	var n := pts.size()
	if n < 3: return pts
	var out := PackedVector2Array()
	var steps := 6
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for s in steps:
			var t := float(s) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (
				(2.0 * p1) + (-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


# remplit un polygone FERMÉ libre. Triangulation via Geometry2D (renvoie vide si
# auto-sécant → on ne dessine rien, AUCUNE erreur). Rendu en triangles (draw_primitive).
func fill_poly_closed(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3: return
	var loop := smooth_closed(pts)
	var idx := Geometry2D.triangulate_polygon(loop)
	if idx.is_empty():
		loop = pts
		idx = Geometry2D.triangulate_polygon(loop)
		if idx.is_empty(): return
	var cols := PackedColorArray([col, col, col])
	var no_uv := PackedVector2Array()
	var i := 0
	while i < idx.size():
		ci.draw_primitive(PackedVector2Array([loop[idx[i]], loop[idx[i + 1]], loop[idx[i + 2]]]), cols, no_uv)
		i += 3


# lisse une courbe ouverte (Catmull-Rom) à travers des points triés
func smooth_open(pts: Array) -> PackedVector2Array:
	var n := pts.size()
	if n < 3:
		return PackedVector2Array(pts)
	var out := PackedVector2Array()
	var steps := 8
	for i in range(n - 1):
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for s in steps:
			var t := float(s) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (
				(2.0 * p1) +
				(-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


# silhouette de colline : contour (haut) trié par x, lissé, rempli jusqu'au sol.
# Rempli par LIGNES VERTICALES (jamais de triangulation → aucune erreur possible,
# quelle que soit la forme du contour).
func fill_silhouette(ci: CanvasItem, outline: PackedVector2Array, baseline_y: float, col: Color) -> void:
	var arr := []
	for p in outline: arr.append(p)
	if arr.size() < 2: return
	arr.sort_custom(func(a, b): return a.x < b.x)
	var sm := smooth_open(arr)
	# nettoie : x strictement croissants (le lissage peut revenir en arrière)
	var top := PackedVector2Array()
	for p in sm:
		if top.is_empty() or p.x > top[top.size() - 1].x + 0.5:
			top.append(p)
	if top.size() < 2: return
	var step := 2.0
	for i in range(top.size() - 1):
		var a: Vector2 = top[i]
		var b: Vector2 = top[i + 1]
		var span: float = b.x - a.x
		if span <= 0.0: continue
		var x := a.x
		while x <= b.x:
			var t: float = (x - a.x) / span
			var ty: float = lerpf(a.y, b.y, t)
			ci.draw_line(Vector2(x, ty), Vector2(x, baseline_y), col, step + 0.6)
			x += step


# couleur par défaut d'une forme de fond (teintée un peu par le thème)
func bg_shape_color(shape: String, theme: int) -> Color:
	match shape:
		"nuage":    return Color("ecf0f1") if theme != 1 else Color("bfc7d5")
		"montagne": return Color("7f8c8d") if theme != 3 else Color("9c6b3f")
		"colline":  return Color("3a8f4f") if theme != 1 else Color("2e1152")
		"soleil":   return Color("ffd35b")
		"lune":     return Color("eef2f7")
		"etoile":   return Color("fff7cc")
		"arbre":    return Color("2e7d32")
		"sapin":    return Color("1f6b3a")
	return Color("ffffff")


# dessine une forme de fond centrée en c, taille unité s (≈ multiplicateur), couleur col
func draw_bg_shape(ci: CanvasItem, shape: String, c: Vector2, s: float, col: Color) -> void:
	var u := s * 44.0
	match shape:
		"nuage":
			ci.draw_circle(c, u * 0.55, col)
			ci.draw_circle(c + Vector2(u * 0.6, u * 0.12), u * 0.42, col)
			ci.draw_circle(c - Vector2(u * 0.6, -u * 0.14), u * 0.40, col)
			ci.draw_circle(c + Vector2(u * 0.18, -u * 0.22), u * 0.40, col)
		"montagne":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-u, u * 0.8), c + Vector2(0, -u), c + Vector2(u, u * 0.8)]), col)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-u * 0.26, -u * 0.32), c + Vector2(0, -u), c + Vector2(u * 0.26, -u * 0.32)]), Color(1, 1, 1, col.a * 0.9))
		"colline":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * float(i) / 12.0
				pts.append(c + Vector2(-cos(a) * u * 1.3, -sin(a) * u * 0.7 + u * 0.5))
			ci.draw_colored_polygon(pts, col)
		"soleil":
			for i in 12:
				var a := TAU * float(i) / 12.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * u * 0.7, c + Vector2(cos(a), sin(a)) * u * 1.1, col, maxf(1.5, u * 0.06))
			ci.draw_circle(c, u * 0.62, col)
		"lune":
			ci.draw_circle(c, u * 0.6, col)
			ci.draw_circle(c + Vector2(u * 0.22, -u * 0.12), u * 0.12, Color(col.r * 0.85, col.g * 0.85, col.b * 0.85, col.a))
			ci.draw_circle(c + Vector2(-u * 0.18, u * 0.2), u * 0.09, Color(col.r * 0.85, col.g * 0.85, col.b * 0.85, col.a))
		"etoile":
			ci.draw_line(c - Vector2(u * 0.5, 0), c + Vector2(u * 0.5, 0), col, maxf(1.5, u * 0.08))
			ci.draw_line(c - Vector2(0, u * 0.5), c + Vector2(0, u * 0.5), col, maxf(1.5, u * 0.08))
			ci.draw_circle(c, u * 0.16, col)
		"arbre":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.1, 0), Vector2(u * 0.2, u * 0.7)), Color("5d4037", col.a))
			ci.draw_circle(c + Vector2(0, -u * 0.2), u * 0.5, col)
		"sapin":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.08, u * 0.5), Vector2(u * 0.16, u * 0.4)), Color("5d4037", col.a))
			for i in 3:
				var yy := -u * 0.6 + i * u * 0.45
				var w := u * (0.5 + i * 0.28)
				ci.draw_colored_polygon(PackedVector2Array([
					c + Vector2(-w, yy + u * 0.5), c + Vector2(0, yy - u * 0.25), c + Vector2(w, yy + u * 0.5)]), col)


func _px_hills(color: Color, factor: float, h_ratio: float, freq: float, phase: float,
			   lvl_r: Rect2, vo: Vector2, vs: float, bt: float) -> void:
	if not app.level_props.get("bg_hills", true): return
	var hill_h := lvl_r.size.y * h_ratio
	var x0 := lvl_r.position.x
	var x1 := lvl_r.position.x + lvl_r.size.x
	var step := maxf(3.0, 3.0 * vs)
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, bt + 4.0))
	var x := x0
	while x < x1:
		var lx := (x - vo.x * factor) / vs
		pts.append(Vector2(x, bt - hill_h * (0.5 + 0.5 * sin(lx * freq + phase))))
		x = minf(x + step, x1)
	var lx1 := (x1 - vo.x * factor) / vs
	pts.append(Vector2(x1, bt - hill_h * (0.5 + 0.5 * sin(lx1 * freq + phase))))
	pts.append(Vector2(x1, bt + 4.0))
	draw_colored_polygon(pts, color)


func _px_clouds(color: Color, factor: float, lvl_r: Rect2, vo: Vector2, vs: float) -> void:
	if not app.level_props.get("bg_sky", true): return
	var TILE_W := 1400.0
	var defs: Array = [
		[0.08, 0.10, 1.1], [0.27, 0.06, 0.75], [0.49, 0.13, 1.3],
		[0.68, 0.08, 0.90], [0.86, 0.11, 1.0]
	]
	var sky_h := lvl_r.size.y * 0.45
	for cd: Array in defs:
		var base_sx := vo.x * factor + float(cd[0]) * TILE_W * vs
		var tw_s := TILE_W * vs
		var cy := lvl_r.position.y + float(cd[1]) * sky_h
		var r := float(cd[2]) * 26.0 * vs
		var n0 := floori((lvl_r.position.x - base_sx - r * 2.5) / tw_s)
		var n1 := ceili((lvl_r.position.x + lvl_r.size.x - base_sx + r * 2.5) / tw_s)
		for n in range(n0, n1 + 1):
			var cx := base_sx + float(n) * tw_s
			if cx + r * 3.0 < lvl_r.position.x or cx - r * 3.0 > lvl_r.position.x + lvl_r.size.x:
				continue
			draw_circle(Vector2(cx, cy), r, color)
			draw_circle(Vector2(cx + r * 0.82, cy + r * 0.22), r * 0.70, color)
			draw_circle(Vector2(cx - r * 0.80, cy + r * 0.28), r * 0.64, color)
			draw_circle(Vector2(cx + r * 0.28, cy - r * 0.26), r * 0.52, color)


func _px_stars(lvl_r: Rect2, vo: Vector2, vs: float) -> void:
	if not app.level_props.get("bg_sky", true): return
	var GS := 88.0; var factor := 0.04
	var px := vo.x * factor
	var sky_h := lvl_r.size.y * 0.60
	var gsv := GS * vs
	var gx0 := floori((lvl_r.position.x - px) / gsv) - 1
	var gx1 := ceili((lvl_r.position.x + lvl_r.size.x - px) / gsv) + 1
	var gy0 := floori(lvl_r.position.y / gsv)
	var gy1 := ceili((lvl_r.position.y + sky_h) / gsv)
	for gx in range(gx0, gx1 + 1):
		for gy in range(gy0, gy1 + 1):
			var rval := sin(float(gx) * 127.1 + float(gy) * 311.7) * 43758.5453
			var h := int(abs(rval)) % 1000
			var sx := px + (float(gx) + float(h % 89) / 89.0) * gsv
			var sy := lvl_r.position.y + (float(gy - gy0) + float((h / 89) % 89) / 89.0) * gsv
			if sy > lvl_r.position.y + sky_h or sx < lvl_r.position.x or sx > lvl_r.position.x + lvl_r.size.x:
				continue
			var r := (float(h % 3) * 0.4 + 0.7) * vs
			draw_circle(Vector2(sx, sy), r, Color(1.0, 1.0, 0.85 + float(h % 2) * 0.15, 0.7 + float(h % 4) * 0.08))


func draw_tile(ci: CanvasItem, p: Vector2, t: int, scale := 1.0, alpha := 1.0, world := false, surface := true) -> void:
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
		FLYER:
			var ctr := p + Vector2(cs * 0.5, cs * 0.5)
			# ailes
			var wing: Color = col.lightened(0.25); wing.a = alpha
			ci.draw_colored_polygon(PackedVector2Array([
				ctr, p + Vector2(pad, cs * 0.18), p + Vector2(pad, cs * 0.5)]), wing)
			ci.draw_colored_polygon(PackedVector2Array([
				ctr, p + Vector2(cs - pad, cs * 0.18), p + Vector2(cs - pad, cs * 0.5)]), wing)
			# corps + yeux
			ci.draw_circle(ctr, cs * 0.26, col)
			ci.draw_circle(ctr + Vector2(-cs * 0.09, -cs * 0.04), cs * 0.05, Color(1, 1, 1, alpha))
			ci.draw_circle(ctr + Vector2(cs * 0.09, -cs * 0.04), cs * 0.05, Color(1, 1, 1, alpha))
		FISH:
			var fc := p + Vector2(cs * 0.5, cs * 0.5)
			# queue
			ci.draw_colored_polygon(PackedVector2Array([
				fc + Vector2(cs * 0.18, 0), fc + Vector2(cs * 0.40, -cs * 0.16), fc + Vector2(cs * 0.40, cs * 0.16)]), col)
			# corps (losange allongé)
			ci.draw_colored_polygon(PackedVector2Array([
				fc + Vector2(-cs * 0.34, 0), fc + Vector2(0, -cs * 0.20),
				fc + Vector2(cs * 0.20, 0), fc + Vector2(0, cs * 0.20)]), col)
			ci.draw_circle(fc + Vector2(-cs * 0.18, -cs * 0.04), cs * 0.045, Color(1, 1, 1, alpha))
		SPIKER:
			var sc := p + Vector2(cs * 0.5, cs * 0.5)
			# piquants tout autour
			for i in 8:
				var a := TAU * float(i) / 8.0
				var dir := Vector2(cos(a), sin(a))
				ci.draw_colored_polygon(PackedVector2Array([
					sc + dir * cs * 0.46,
					sc + dir.rotated(0.32) * cs * 0.28,
					sc + dir.rotated(-0.32) * cs * 0.28]), col)
			ci.draw_circle(sc, cs * 0.28, col.darkened(0.1))
			ci.draw_circle(sc + Vector2(-cs * 0.08, -cs * 0.03), cs * 0.045, Color(1, 0.3, 0.3, alpha))
			ci.draw_circle(sc + Vector2(cs * 0.08, -cs * 0.03), cs * 0.045, Color(1, 0.3, 0.3, alpha))
		CHASER:
			var gc := p + Vector2(cs * 0.5, cs * 0.46)
			# corps fantôme : demi-cercle + bas ondulé
			ci.draw_circle(gc, cs * 0.30, col)
			ci.draw_rect(Rect2(p + Vector2(cs * 0.20, cs * 0.46), Vector2(cs * 0.60, cs * 0.30)), col)
			for i in 3:
				ci.draw_circle(p + Vector2(cs * (0.28 + i * 0.22), cs * 0.76), cs * 0.10, col)
			ci.draw_circle(gc + Vector2(-cs * 0.10, 0), cs * 0.055, Color("2c3e50", alpha))
			ci.draw_circle(gc + Vector2(cs * 0.10, 0), cs * 0.055, Color("2c3e50", alpha))
		HOPPER:
			# grenouille : corps bombé + 2 yeux sur le dessus + pattes
			ci.draw_rect(Rect2(p + Vector2(pad, cs * 0.45), Vector2(cs - pad * 2, cs * 0.5 - pad)), col)
			ci.draw_circle(p + Vector2(cs * 0.5, cs * 0.52), cs * 0.30, col)
			ci.draw_circle(p + Vector2(cs * 0.34, cs * 0.30), cs * 0.10, col.lightened(0.1))
			ci.draw_circle(p + Vector2(cs * 0.66, cs * 0.30), cs * 0.10, col.lightened(0.1))
			ci.draw_circle(p + Vector2(cs * 0.34, cs * 0.30), cs * 0.045, Color("2c3e50", alpha))
			ci.draw_circle(p + Vector2(cs * 0.66, cs * 0.30), cs * 0.045, Color("2c3e50", alpha))
		BOUNCER:
			var bc := p + Vector2(cs * 0.5, cs * 0.5)
			ci.draw_circle(bc, cs * 0.34, col)
			# petites pointes courtes tout autour
			for i in 6:
				var a := TAU * float(i) / 6.0
				var dir := Vector2(cos(a), sin(a))
				ci.draw_colored_polygon(PackedVector2Array([
					bc + dir * cs * 0.46, bc + dir.rotated(0.26) * cs * 0.32, bc + dir.rotated(-0.26) * cs * 0.32]), col)
			ci.draw_circle(bc, cs * 0.12, Color(1, 1, 1, 0.8 * alpha))
		SHOOTER:
			# tourelle : socle + canon orienté
			ci.draw_rect(Rect2(p + Vector2(pad, cs * 0.55), Vector2(cs - pad * 2, cs * 0.45 - pad)), col)
			ci.draw_circle(p + Vector2(cs * 0.5, cs * 0.55), cs * 0.26, col.lightened(0.12))
			ci.draw_rect(Rect2(p + Vector2(cs * 0.5, cs * 0.46), Vector2(cs * 0.42, cs * 0.16)), col.darkened(0.2))
			ci.draw_circle(p + Vector2(cs * 0.5, cs * 0.55), cs * 0.06, Color("ffce54", alpha))
		BOSS:
			# grosse bête : cornes + corps + gros yeux + dents
			var bc := p + Vector2(cs * 0.5, cs * 0.55)
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(cs * 0.18, cs * 0.12), p + Vector2(cs * 0.32, cs * 0.38), p + Vector2(cs * 0.10, cs * 0.36)]), col)
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(cs * 0.82, cs * 0.12), p + Vector2(cs * 0.68, cs * 0.38), p + Vector2(cs * 0.90, cs * 0.36)]), col)
			ci.draw_circle(bc, cs * 0.36, col)
			ci.draw_circle(p + Vector2(cs * 0.36, cs * 0.48), cs * 0.10, Color("ffde59", alpha))
			ci.draw_circle(p + Vector2(cs * 0.64, cs * 0.48), cs * 0.10, Color("ffde59", alpha))
			ci.draw_circle(p + Vector2(cs * 0.36, cs * 0.48), cs * 0.045, Color("2c3e50", alpha))
			ci.draw_circle(p + Vector2(cs * 0.64, cs * 0.48), cs * 0.045, Color("2c3e50", alpha))
			for di in 4:
				var dx := cs * (0.34 + di * 0.11)
				ci.draw_colored_polygon(PackedVector2Array([
					p + Vector2(dx, cs * 0.72), p + Vector2(dx + cs * 0.05, cs * 0.72), p + Vector2(dx + cs * 0.025, cs * 0.82)]), Color(1, 1, 1, alpha))
		FALLBLOCK:
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col)
			ci.draw_rect(Rect2(p, Vector2(cs, max(2.0, cs * 0.10))), col.darkened(0.25))
			# flèche bas (avertit qu'il tombe)
			var ac := p + Vector2(cs * 0.5, cs * 0.5)
			ci.draw_colored_polygon(PackedVector2Array([
				ac + Vector2(-cs * 0.16, -cs * 0.06), ac + Vector2(cs * 0.16, -cs * 0.06), ac + Vector2(0, cs * 0.20)]), col.darkened(0.35))
		FIREBAR:
			ci.draw_circle(p + Vector2(cs * 0.5, cs * 0.5), cs * 0.14, Color("c0392b", alpha))
			for i in 3:
				var fx := cs * (0.5 + 0.16 * (i + 1))
				ci.draw_circle(p + Vector2(fx, cs * 0.5), cs * (0.13 - i * 0.02), col)
				ci.draw_circle(p + Vector2(fx, cs * 0.5), cs * (0.07 - i * 0.012), Color("ffce54", alpha))
		CRUMBLE:
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col)
			ci.draw_line(p + Vector2(cs * 0.3, 0), p + Vector2(cs * 0.45, cs), col.darkened(0.3), 1.5 * scale)
			ci.draw_line(p + Vector2(cs * 0.7, 0), p + Vector2(cs * 0.55, cs), col.darkened(0.3), 1.5 * scale)
			ci.draw_line(p + Vector2(0, cs * 0.5), p + Vector2(cs, cs * 0.55), col.darkened(0.3), 1.5 * scale)
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
		CURVE_RU_CV, CURVE_RU_CC, CURVE_RD_CV, CURVE_RD_CC:
			var pts := PackedVector2Array()
			for i in 9:
				var lx := i / 8.0 * CELL
				pts.append(p + Vector2(lx * scale, _curve_offset(t, lx) * scale))
			pts.append(p + Vector2(cs, cs)); pts.append(p + Vector2(0, cs))
			ci.draw_colored_polygon(pts, col)
		ONEWAY:
			ci.draw_rect(Rect2(p + Vector2(0, 0), Vector2(cs, cs * 0.22)), col)
			ci.draw_line(p + Vector2(pad, cs * 0.45), p + Vector2(cs - pad, cs * 0.45), col.darkened(0.2), 1.5 * scale)
		LADDER:
			ci.draw_rect(Rect2(p + Vector2(cs * 0.18, 0), Vector2(cs * 0.1, cs)), col)
			ci.draw_rect(Rect2(p + Vector2(cs * 0.72, 0), Vector2(cs * 0.1, cs)), col)
			for i in 3:
				ci.draw_rect(Rect2(p + Vector2(cs * 0.18, cs * (0.2 + i * 0.3)), Vector2(cs * 0.64, cs * 0.08)), col)
		ICE:
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col)
			ci.draw_rect(Rect2(p, Vector2(cs, max(2.0, cs * 0.10))), Color(1, 1, 1, 0.5 * alpha))
			ci.draw_line(p + Vector2(cs * 0.2, cs * 0.3), p + Vector2(cs * 0.5, cs * 0.7), Color(1, 1, 1, 0.4 * alpha), 1.5 * scale)
		LAVA:
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col)
			var lt: float = float(app.anim_t) if app != null else 0.0
			if surface:
				# case de surface : croûte lumineuse ondulée + bulle
				var glow: Color = col.lightened(0.4); glow.a = alpha
				var ltop := PackedVector2Array()
				ltop.append(p + Vector2(0, 0)); ltop.append(p + Vector2(cs, 0))
				for i in range(8, -1, -1):
					var fx := i / 8.0
					ltop.append(p + Vector2(fx * cs, cs * (0.24 + 0.06 * sin(lt * 3.0 + fx * 7.0))))
				ci.draw_colored_polygon(ltop, glow)
				var bx := 0.25 + 0.5 * (0.5 + 0.5 * sin(lt * 1.7))
				ci.draw_circle(p + Vector2(cs * bx, cs * (0.55 + 0.12 * sin(lt * 2.3))), cs * 0.07, Color("ffd27f", alpha))
			else:
				# corps : magma sombre + filaments lumineux qui montent
				var streak: Color = col.lightened(0.18); streak.a = alpha
				for i in 2:
					var sx := cs * (0.32 + 0.4 * i)
					ci.draw_circle(p + Vector2(sx, cs * (0.5 + 0.35 * sin(lt * 1.5 + float(i) * 2.0))), cs * 0.05, streak)
		WATER:
			var wcol: Color = col; wcol.a = 0.6 * alpha   # même opacité surface/corps → rendu uni
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), wcol)
			var wt: float = float(app.anim_t) if app != null else 0.0
			if surface:
				# case de surface : ligne de vagues + reflet clair
				var wpts := PackedVector2Array()
				for i in 9:
					var fx := i / 8.0
					wpts.append(p + Vector2(fx * cs, cs * (0.12 + 0.05 * sin(wt * 2.5 + fx * 6.0))))
				ci.draw_polyline(wpts, Color(1, 1, 1, 0.4 * alpha), 2.0 * scale)
			else:
				# corps : bulles qui montent
				var bub: Color = Color(1, 1, 1, 0.18 * alpha)
				ci.draw_circle(p + Vector2(cs * 0.35, cs * (0.7 - 0.4 * fposmod(wt * 0.4, 1.0))), cs * 0.05, bub)
				ci.draw_circle(p + Vector2(cs * 0.68, cs * (0.9 - 0.4 * fposmod(wt * 0.4 + 0.5, 1.0))), cs * 0.04, bub)
		CONV_R, CONV_L:
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col)
			var dir := 1.0 if t == CONV_R else -1.0
			var midy := p.y + cs * 0.5
			var ax := p.x + cs * (0.3 if t == CONV_R else 0.7)
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(ax + dir * cs * 0.18, midy), Vector2(ax, midy - cs * 0.16),
				Vector2(ax, midy + cs * 0.16)]), Color("f1c40f", alpha))
		SWITCH:
			ci.draw_rect(Rect2(p + Vector2(pad, cs * 0.55), Vector2(cs - pad * 2, cs * 0.45 - pad)), col.darkened(0.2))
			ci.draw_rect(Rect2(p + Vector2(cs * 0.28, cs * 0.35), Vector2(cs * 0.44, cs * 0.22)), col)
		GATE:
			var open: bool = gates_open and app != null and app.mode == "play"
			if open:
				ci.draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col, false, 1.5 * scale)
			else:
				for i in 2:
					ci.draw_rect(Rect2(p + Vector2(cs * (0.22 + i * 0.4), 0), Vector2(cs * 0.16, cs)), col)
				ci.draw_rect(Rect2(p + Vector2(0, cs * 0.4), Vector2(cs, cs * 0.16)), col)
		LOOP_CENTER:
			var ctr := p + Vector2(cs, cs) * 0.5
			ci.draw_circle(ctr, cs * 0.12, col)
			ci.draw_arc(ctr, cs * 0.38, 0, TAU, 24, col, 2.0 * scale)
		PALM:
			var trunk := Color("8b6914"); var leaf := col
			if world:
				var base := p + Vector2(cs*0.5, cs)
				var lean := cs * 0.14; var th := cs * 2.2; var tw := cs * 0.09
				ci.draw_colored_polygon(PackedVector2Array([
					base+Vector2(-tw,0), base+Vector2(tw,0),
					base+Vector2(tw+lean,-th), base+Vector2(-tw+lean,-th)]), trunk)
				var tip := base + Vector2(lean, -th)
				ci.draw_circle(tip+Vector2(-cs*0.07,cs*0.05), cs*0.08, trunk.darkened(0.2))
				ci.draw_circle(tip+Vector2(cs*0.05,cs*0.07), cs*0.08, trunk.darkened(0.2))
				for i in 5:
					var a := deg_to_rad(-155.0 + i*38.0)
					var fl := cs*(0.75 + (i%2)*0.18); var fw := cs*0.11
					var fe := tip + Vector2(cos(a)*fl, sin(a)*fl)
					var perp := Vector2(-sin(a), cos(a))*fw
					ci.draw_colored_polygon(PackedVector2Array([tip+perp, tip-perp, fe]),
						leaf.darkened(float(i)*0.05))
			else:
				ci.draw_rect(Rect2(p+Vector2(cs*0.44,cs*0.38), Vector2(cs*0.12,cs*0.62)), trunk)
				var tip := p+Vector2(cs*0.5,cs*0.38)
				ci.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-cs*0.42,cs*0.04),tip+Vector2(-cs*0.32,cs*0.2)]), leaf)
				ci.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-cs*0.18,-cs*0.36),tip+Vector2(cs*0.06,-cs*0.18)]), leaf)
				ci.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(cs*0.42,cs*0.04),tip+Vector2(cs*0.32,cs*0.2)]), leaf)
				ci.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(cs*0.18,-cs*0.36),tip+Vector2(-cs*0.06,-cs*0.18)]), leaf)
				ci.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-cs*0.1,-cs*0.42),tip+Vector2(cs*0.1,-cs*0.42)]), leaf.lightened(0.1))
		TREE:
			var trunk := Color("6b4a2b"); var leaf := col
			if world:
				var base := p + Vector2(cs*0.5, cs)
				var th := cs*0.85; var tw := cs*0.12
				ci.draw_rect(Rect2(base+Vector2(-tw,-th), Vector2(tw*2,th)), trunk)
				var crown := base + Vector2(0,-th)
				ci.draw_colored_polygon(PackedVector2Array([
					crown+Vector2(-cs*0.75,0), crown+Vector2(cs*0.75,0), crown+Vector2(0,-cs*0.85)]),
					leaf.darkened(0.12))
				ci.draw_colored_polygon(PackedVector2Array([
					crown+Vector2(-cs*0.58,-cs*0.5), crown+Vector2(cs*0.58,-cs*0.5), crown+Vector2(0,-cs*1.45)]),
					leaf)
				ci.draw_colored_polygon(PackedVector2Array([
					crown+Vector2(-cs*0.3,-cs*1.0), crown+Vector2(cs*0.3,-cs*1.0), crown+Vector2(0,-cs*1.85)]),
					leaf.lightened(0.12))
			else:
				ci.draw_rect(Rect2(p+Vector2(cs*0.4,cs*0.58), Vector2(cs*0.2,cs*0.42)), trunk)
				ci.draw_colored_polygon(PackedVector2Array([p+Vector2(cs*0.5,pad),p+Vector2(cs-pad,cs*0.68),p+Vector2(pad,cs*0.68)]), leaf)
				ci.draw_colored_polygon(PackedVector2Array([p+Vector2(cs*0.5,pad),p+Vector2(cs*0.82,cs*0.46),p+Vector2(cs*0.18,cs*0.46)]), leaf.lightened(0.12))
		BUSH:
			var leaf := col
			if world:
				var base := p + Vector2(cs*0.5, cs)
				var r := cs*0.32
				ci.draw_circle(base+Vector2(0,-r*0.9), r, leaf)
				ci.draw_circle(base+Vector2(-r*0.95,-r*0.45), r*0.82, leaf)
				ci.draw_circle(base+Vector2(r*0.95,-r*0.45), r*0.82, leaf)
				ci.draw_circle(base+Vector2(-r*1.5,-r*0.1), r*0.62, leaf.darkened(0.1))
				ci.draw_circle(base+Vector2(r*1.5,-r*0.1), r*0.62, leaf.darkened(0.1))
			else:
				ci.draw_circle(p+Vector2(cs*0.5,cs*0.72), cs*0.24, leaf)
				ci.draw_circle(p+Vector2(cs*0.24,cs*0.78), cs*0.2, leaf)
				ci.draw_circle(p+Vector2(cs*0.76,cs*0.78), cs*0.2, leaf)
				ci.draw_rect(Rect2(p+Vector2(cs*0.14,cs*0.84), Vector2(cs*0.72,cs*0.16)), leaf.darkened(0.18))
		FLOWER:
			var stem_c := Color("27ae60"); var petal := col; var center := Color("f1c40f")
			if world:
				var base := p + Vector2(cs*0.5, cs)
				var sh := cs*0.75
				ci.draw_rect(Rect2(base+Vector2(-cs*0.04,-sh), Vector2(cs*0.08,sh)), stem_c)
				ci.draw_colored_polygon(PackedVector2Array([
					base+Vector2(0,-sh*0.4), base+Vector2(cs*0.28,-sh*0.58), base+Vector2(0,-sh*0.65)]), stem_c)
				var fc := base + Vector2(0,-sh); var pr := cs*0.2
				ci.draw_circle(fc+Vector2(0,-pr*1.25), pr, petal)
				ci.draw_circle(fc+Vector2(0, pr*1.25), pr, petal)
				ci.draw_circle(fc+Vector2(-pr*1.25,0), pr, petal)
				ci.draw_circle(fc+Vector2( pr*1.25,0), pr, petal)
				ci.draw_circle(fc+Vector2(-pr*0.88,-pr*0.88), pr*0.75, petal)
				ci.draw_circle(fc+Vector2( pr*0.88,-pr*0.88), pr*0.75, petal)
				ci.draw_circle(fc+Vector2(-pr*0.88, pr*0.88), pr*0.75, petal)
				ci.draw_circle(fc+Vector2( pr*0.88, pr*0.88), pr*0.75, petal)
				ci.draw_circle(fc, pr*0.8, center)
			else:
				ci.draw_rect(Rect2(p+Vector2(cs*0.46,cs*0.52), Vector2(cs*0.08,cs*0.48)), stem_c)
				var fc := p+Vector2(cs*0.5,cs*0.4); var pr := cs*0.13
				ci.draw_circle(fc+Vector2(0,-pr*1.5), pr, petal)
				ci.draw_circle(fc+Vector2(0, pr*1.5), pr, petal)
				ci.draw_circle(fc+Vector2(-pr*1.5,0), pr, petal)
				ci.draw_circle(fc+Vector2( pr*1.5,0), pr, petal)
				ci.draw_circle(fc, pr*0.9, center)
		_:
			ci.draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col)
