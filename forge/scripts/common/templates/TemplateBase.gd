extends Node2D
class_name TemplateBase
# BASE de tous les templates de genre (platformer, top-down, ...).
# Contient les SERVICES PARTAGÉS : données de tuiles, état joueur générique
# (PV/dash/i-frames), clés/portes/interrupteurs/dalles, ennemis communs
# (volant/fantôme/boss FSM), projectiles, rendu du monde (tuiles/parallax/
# formes de fond) et helpers de grille.
# Un genre hérite et override : _physics_process, categories(), seed_demo(),
# et les hooks (_draw_player, _build_extra, _touch_spring, ...).

signal player_died     # émis au début de la mort (avant le timer de respawn)
signal level_won       # émis quand le joueur touche l'arrivée
signal coin_collected  # émis à chaque pièce ramassée

const CELL := 48

# --- tuiles (sémantique partagée par les genres) ---
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
	BOSS, FLOOR, PLATE, PUSHBLOCK, WARP,
	ITEM_DJUMP, ITEM_MORPH, ITEM_MISSILE, ENERGY, DOOR_BEAM, DOOR_MISSILE, MORPH_TUBE,
	MODE25, MODE3D }
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
	BOSS: "Boss", FLOOR: "Sol", PLATE: "Dalle", PUSHBLOCK: "Bloc poussable",
	WARP: "Sortie (warp)",
	ITEM_DJUMP: "Double-saut", ITEM_MORPH: "Morph ball", ITEM_MISSILE: "Missiles (+5)",
	ENERGY: "Réservoir énergie", DOOR_BEAM: "Porte (tir)", DOOR_MISSILE: "Porte (missile)",
	MORPH_TUBE: "Conduit (morph)",
	MODE25: "Zone 2.5D", MODE3D: "Zone 3D"
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
	BOSS: Color("8e1a3d"), FLOOR: Color("6b5d4f"), PLATE: Color("d4a017"), PUSHBLOCK: Color("8d6e63"),
	WARP: Color("9b59f5"),
	ITEM_DJUMP: Color("4cd6b3"), ITEM_MORPH: Color("ffb74d"), ITEM_MISSILE: Color("ff7043"),
	ENERGY: Color("ff5e8a"), DOOR_BEAM: Color("42a5f5"), DOOR_MISSILE: Color("ef5350"),
	MORPH_TUBE: Color("78909c"),
	MODE25: Color("26c6da"), MODE3D: Color("ab47bc")
}
const KEY_COLORS := {"or": Color("f1c40f"), "rouge": Color("e74c3c"), "bleu": Color("3498db"), "vert": Color("2ecc71"), "rose": Color("ff6ec7")}

# --- constantes de gameplay partagées (les genres lisent celles qui les concernent) ---
const PSIZE := Vector2(36, 36)
const GRAVITY := 1900.0
const MAX_FALL := 1300.0
const DEADZONE := 0.35
const ESIZE := 36
const ESPEED := 85.0
const EFLY_SPEED := 75.0    # volant : vitesse horizontale
const EFLY_BOB_A := 20.0    # volant : amplitude du bobbing vertical (px)
const EFLY_BOB_F := 3.2     # volant : fréquence du bobbing
const CHASE_SPEED := 92.0   # fantôme : vitesse de poursuite (lente → esquivable)
const SHOOT_INTERVAL := 1.8 # tourelle : délai entre tirs
const PROJ_SPEED := 250.0   # projectile : vitesse
const PROJ_SIZE := 14.0     # projectile : diamètre
const FIREBAR_LEN := 3      # barre de feu : nombre de flammes
const BOSS_SIZE := 88.0     # boss : taille (px)
const BOSS_HP := 5          # boss : nombre de coups à encaisser
const BOSS_ENRAGE_HP := 2   # boss : passe en phase 2 (enrage) à ce nb de PV
const BOSS_SPEED := 80.0
const BOSS_BOB_A := 26.0
const BOSS_BOB_F := 1.8
const BOSS_SHOOT := 1.5
const BOSS_INV := 0.7       # boss : invulnérabilité après un coup (s)
const BOSS_TELE := 0.6      # boss : durée du télégraphe avant une attaque
const BOSS_RECOVER := 1.2   # boss : fenêtre vulnérable après une attaque
const BOSS_CHARGE_SPD := 460.0
const AIR_MAX := 8.0        # secondes d'air avant noyade (lu par le HUD)
# dash / esquive (tous les genres) : burst + i-frames + cooldown
const DASH_SPEED := 720.0
const DASH_DUR := 0.16
const DASH_CD := 0.5
const DASH_IFRAME := 0.22
const HURT_IFRAME := 1.0    # invulnérabilité après un coup encaissé (PV)

var app: Node = null                    # ForgeApp (grille, vue, fx, audio)
@onready var player_sm := $PlayerSM      # XSM (utilisé par le platformer ; no-op ailleurs)

# --- état joueur générique ---
var ppos := Vector2.ZERO
var pvel := Vector2.ZERO
var on_floor := false      # écrit par le platformer ; lu par le boss (anti-air)
var was_floor := false
var coins_got := 0
var coins_total := 0
var dead := false
var won := false
var death_t := 0.0
var has_key := false
var keys := {}             # clés ramassées par couleur : {"rouge":1,...}
var spawn_cell := Vector2i(4, 8)
var respawn_cell := Vector2i(4, 8)
var last_from_cursor := false
var testing := false
var test_dir := 0
var time_left := 0.0       # chrono restant (0 = pas de limite)
var air_t := 8.0           # réserve d'air (noyade, géré par le platformer ; lu par le HUD)
var hearts := 0            # PV courants (0 = système désactivé → mort instantanée)
var max_hearts := 0
var pinv := 0.0            # invulnérabilité joueur (i-frames)
var dash_cd := 0.0
var dashing := 0.0
var dash_dir := Vector2.RIGHT
var pos_hist := []         # historique de position (ghosting GBA)
var autorun_dir := 1
var switch_cd := 0.0

# --- entités / mécaniques partagées ---
var enemies := []
var projectiles := []      # tirs ennemis {pos, vel, alive}
var crumbled := {}         # cases friables rompues (lues par la solidité)
var fb_trig := {}          # blocs tombants déclenchés (idem)
var gates_open := false
var plate_open := false    # (visuel) au moins une dalle enfoncée
var plate_cells := []      # positions des dalles (snapshot au start)
var sw_open := {}          # interrupteurs par couleur : couleur -> bool
var open_gate_cells := {}  # cellules de grille ouvertes ce frame (par groupe couleur)
var push_home := []        # positions initiales des blocs poussables


func _ready() -> void:
	show_behind_parent = true
	# XSM piloté manuellement par le genre qui l'utilise
	if player_sm:
		player_sm.set_physics_process(false)


func setup(forge_app: Node) -> void:
	app = forge_app


# =================================================== contrat du genre (hooks)
func tile_name(t: int) -> String: return NAMES.get(t, "")
func tile_color(t: int) -> Color: return COLORS.get(t, Color.GRAY)
func categories() -> Array: return []           # palette de l'éditeur, par genre
func movplat_tile() -> int: return -1            # tuile "plateforme mobile" configurable
func default_hp() -> int: return 0               # PV par défaut (0 = mort instantanée)
func seed_demo() -> void: pass                   # contenu du nouveau projet
func wants_room_camera() -> bool: return false   # caméra par salles (top-down)
func debug_text() -> String: return ""           # texte debug HUD (ex: sonic)
func play_hud_text() -> String: return ""        # texte HUD en jeu (ex: missiles)
func jump_pressed() -> void: pass                # entrées transmises par ForgeApp
func jump_released() -> void: pass
func _wants_parallax() -> bool: return true      # false = fond plat (top-down)
func _draw_ground(_clip_r: Rect2) -> void: pass  # couche de sol auto (top-down)
func _build_extra() -> void: pass                # entités spécifiques au genre
func _touch_spring(_c: Vector2i) -> void: pass   # effet du ressort (platformer)
func _draw_world_extra() -> void: pass           # rendu jeu spécifique (loops, hazards)
func _draw_edit_extra(_cx0: int, _cx1: int, _cy0: int, _cy1: int) -> void: pass


# badges d'aide affichés par le HUD en mode test (par genre)
func play_badges() -> Array:
	return [["←→", "Bouger"], ["A", "Sauter"], ["R1", "Dash"], ["Y", "Rejouer"], ["ST", "Éditeur"]]


# champs du panneau "Configurer objet" pour une tuile (par instance)
func config_fields(t: int) -> Array:
	if t == movplat_tile() and t != -1:
		return [
			{"key": "width", "label": "Largeur", "opts": [1, 2, 3, 4, 5],           "def": 1},
			{"key": "axis",  "label": "Axe",     "opts": ["H", "V"],                 "def": "H"},
			{"key": "dir",   "label": "Sens",    "opts": ["+", "-"],                 "def": "+"},
			{"key": "span",  "label": "Portée",  "opts": [1, 2, 3, 4, 5, 6],         "def": 3},
			{"key": "speed", "label": "Vitesse", "opts": ["lent", "normal", "rapide"], "def": "normal"},
		]
	# objets liés par couleur (clé/porte + interrupteur/grille/dalle)
	if t == KEY or t == DOOR or t == SWITCH or t == GATE or t == PLATE:
		return [{"key": "color", "label": "Couleur", "opts": ["or", "rouge", "bleu", "vert", "rose"], "def": "or"}]
	# sortie/warp : sa propre porte n° + destination (niveau + porte d'arrivée)
	if t == WARP:
		var lvls: Array = app.level_ids()
		return [
			{"key": "id",   "label": "Porte n°",     "opts": [1, 2, 3, 4], "def": 1},
			{"key": "dest", "label": "Vers niveau",  "opts": lvls,          "def": lvls[0] if not lvls.is_empty() else "1"},
			{"key": "door", "label": "Porte arrivée", "opts": [1, 2, 3, 4], "def": 1},
		]
	return []


# =================================================== play (générique)
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
	pvel = Vector2.ZERO
	time_left = _time_limit()
	air_t = AIR_MAX
	pinv = 0.0; dashing = 0.0; dash_cd = 0.0; pos_hist = []
	max_hearts = int(app.level_props.get("player_hp", default_hp()))
	hearts = max_hearts
	plate_cells = []
	for k in app.grid:
		if app.grid[k] == PLATE: plate_cells.append(k)
	sw_open = {}; open_gate_cells = {}
	gates_open = false; switch_cd = 0.0; autorun_dir = 1
	_build_entities()
	_place_player(spawn_cell)


# (re)construit les entités génériques + délègue au genre (_build_extra)
func _build_entities() -> void:
	enemies.clear(); projectiles.clear()
	crumbled.clear(); fb_trig.clear()
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
				"dir": -1, "alive": true, "vy": 0.0, "hop_t": 1.3})
		elif app.grid[k] == BOUNCER:
			enemies.append({"type": "bouncer", "pos": Vector2(float(k.x * CELL) + 6.0, float(k.y * CELL) + 6.0),
				"dir": -1, "alive": true, "vel": Vector2(165.0, 165.0)})
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
	_build_extra()


func stop_play() -> void:
	Input.stop_joy_vibration(0)


func _place_player(c: Vector2i) -> void:
	ppos = Vector2(c.x * CELL + (CELL - PSIZE.x) * 0.5, c.y * CELL + (CELL - PSIZE.y))
	pvel = Vector2.ZERO


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
	# En édition : ForgeApp déclenche tmpl.queue_redraw() seulement quand le monde change.
	if app != null and app.screen == "edit" and app.mode == "play":
		# ghosting GBA : mémorise les dernières positions (joueur + ennemis + projectiles)
		if int(app.level_props.get("gfx", 0)) == 3:
			pos_hist.push_front(ppos)
			while pos_hist.size() > 5: pos_hist.pop_back()
			for en in enemies:
				en["gh"] = ([en.pos] + en.get("gh", [])).slice(0, 4)
			for pj in projectiles:
				pj["gh"] = ([pj.pos] + pj.get("gh", [])).slice(0, 4)
		elif not pos_hist.is_empty():
			pos_hist.clear()
		queue_redraw()


# directions d'entrée (croix + stick) — partagées par les genres
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


# =================================================== solidité / mécaniques
func _is_full_solid(t: int) -> bool:
	if t == GROUND or t == BREAKABLE or t == DOOR or t == ICE or t == CONV_R or t == CONV_L: return true
	if t == FALLBLOCK or t == CRUMBLE or t == PUSHBLOCK: return true
	if t == DOOR_BEAM or t == DOOR_MISSILE or t == MORPH_TUBE: return true
	return false


# solidité par CELLULE : gère les grilles par groupe de couleur (ouvertes = non solides)
func _cell_solid(c: Vector2i) -> bool:
	if crumbled.has(c) or fb_trig.has(c): return false
	var t: int = app.grid.get(c, EMPTY)
	if t == GATE: return not open_gate_cells.has(c)
	return _is_full_solid(t)


# tuile solide pour les ENTITÉS (inclut plateformes 1-sens)
func _solid_tile(c: Vector2i) -> bool:
	if crumbled.has(c) or fb_trig.has(c): return false
	var t: int = app.grid.get(c, EMPTY)
	return _cell_solid(c) or t == ONEWAY


func _is_slope(t: int) -> bool:
	return SLOPES.has(t)


# puzzle : grilles ouvertes par GROUPE DE COULEUR.
# une grille couleur C s'ouvre si l'interrupteur C est ON, OU si toutes les dalles C sont enfoncées.
func _update_plates() -> void:
	open_gate_cells = {}
	var pr := Rect2(ppos, PSIZE)
	plate_open = false
	var all_pressed := {}   # couleur -> bool
	for c in plate_cells:
		var col := _cell_color(c)
		if not all_pressed.has(col): all_pressed[col] = true
		var on: bool = pr.intersects(_cell_rect(c)) or int(app.grid.get(c, EMPTY)) == PUSHBLOCK
		if on: plate_open = true
		else: all_pressed[col] = false
	for k in app.grid:
		if app.grid[k] == GATE:
			var gc := _cell_color(k)
			if bool(sw_open.get(gc, false)) or bool(all_pressed.get(gc, false)):
				open_gate_cells[k] = true


# =================================================== ennemis communs
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


# fantôme : poursuite lente du joueur, traverse tout (vol libre)
func _enemy_chaser(en: Dictionary, delta: float) -> void:
	en.phase += delta
	var ec: Vector2 = en.pos + Vector2(ESIZE, ESIZE) * 0.5
	var target: Vector2 = ppos + PSIZE * 0.5
	var to := target - ec
	if to.length() > 2.0:
		en.pos += to.normalized() * CHASE_SPEED * delta
	en.pos.y += sin(en.phase * 3.0) * 0.4


# ============================================================ BOSS (FSM exemple)
# Machine à états d'un boss volant. Pensée pour être TUNÉE/ÉTENDUE :
#  - phases = nombre de PV perdus (en.phase) → attaques + agressives quand il faiblit
#  - le choix d'attaque est dans _boss_choose() (pondéré par phase)
#  - chaque état = une fonction _boss_<nom>() ; pour en ajouter un :
#       1) ajoute "mon_etat" dans le match de _enemy_boss
#       2) écris func _boss_mon_etat(en, delta)
#       3) entre-y via _boss_to(en, "mon_etat")
# Cycle : intro → (choose) → telegraph → [shoot|charge|slam] → recover(vulnérable) → choose
#         hurt (quand touché) → choose
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
	en.pos.y = en.base_y + y_off + sin(en.st * BOSS_BOB_F) * BOSS_BOB_A


func _boss_intro(en: Dictionary, _delta: float) -> void:
	_boss_hover(en, 0.0)
	if en.st > 1.0: _boss_choose(en)


# construit une SÉQUENCE d'attaques (combo) selon le contexte + la phase, puis l'enchaîne.
func _boss_choose(en: Dictionary) -> void:
	en.queue = _boss_build_queue(en)
	_boss_next(en)


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
		return "shoot"
	if dist > 6.0 * CELL:
		return "charge" if randf() < 0.6 else "shoot"
	if en.enraged or en.phase >= 1:
		return "slam" if randf() < 0.6 else "charge"
	return "shoot" if randf() < 0.5 else "charge"


func _boss_build_queue(en: Dictionary) -> Array:
	var n := 1
	if en.enraged: n = 3 if randf() < 0.5 else 2
	elif en.phase >= 2: n = 2 if randf() < 0.45 else 1
	var q := []
	var last := ""
	for _i in n:
		var a := _boss_pick_ctx(en)
		if a == "slam" and last == "slam": a = "charge"
		q.append(a); last = a
	return q


func _boss_enrage(en: Dictionary, _delta: float) -> void:
	en.inv = 0.3
	_boss_hover(en, 0.0)
	if int(en.st * 12.0) % 2 == 0:
		app._emit(_boss_center(en), 3, COLORS[BOSS].lightened(0.4), 200.0, 0.25, true, 4.0)
	if en.st > 1.0:
		en.enraged = true
		app._shake(8.0, 0.3); app._play("win")
		_boss_choose(en)


func _boss_telegraph(en: Dictionary, _delta: float) -> void:
	_boss_hover(en, 0.0)
	var dur: float = maxf(0.2, (BOSS_TELE * 0.55) if en.enraged else (BOSS_TELE - float(en.phase) * 0.06))
	if en.st >= dur:
		_boss_to(en, en.atk)


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


func _boss_charge(en: Dictionary, delta: float) -> void:
	if not en.fired:
		en.vx = BOSS_CHARGE_SPD * (1.0 if ppos.x > en.pos.x else -1.0)
		en.fired = true
		app._shake(2.0, 0.1)
	en.pos.x += en.vx * delta
	en.pos.y = en.base_y + sin(en.st * 8.0) * 4.0
	if en.pos.x <= en.min or en.pos.x >= en.max or en.st > 1.3:
		en.pos.x = clampf(en.pos.x, en.min, en.max)
		app._shake(3.0, 0.12)
		_boss_next(en)


func _boss_slam(en: Dictionary, delta: float) -> void:
	if not en.fired:
		en.sub = "rise"; en.vy = 0.0; en.fired = true
	if en.sub == "rise":
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


func _boss_floor(en: Dictionary) -> float:
	var col := int((en.pos.x + BOSS_SIZE * 0.5) / CELL)
	var r0 := int((en.pos.y + BOSS_SIZE) / CELL)
	for row in range(maxi(r0, 0), app.rows + 1):
		if _solid_tile(Vector2i(col, row)):
			return float(row * CELL)
	return float(app.rows * CELL)


func _boss_impact(en: Dictionary) -> void:
	app._shake(9.0, 0.35); app._play("break")
	var cx: float = en.pos.x + BOSS_SIZE * 0.5
	var fy: float = en.pos.y + BOSS_SIZE - PROJ_SIZE
	app._emit(Vector2(cx, en.pos.y + BOSS_SIZE), 20, COLORS[BOSS].lightened(0.2), 260.0, 0.5, true, 4.0)
	projectiles.append({"pos": Vector2(cx - BOSS_SIZE * 0.5, fy), "vel": Vector2(-PROJ_SPEED, 0.0), "alive": true})
	projectiles.append({"pos": Vector2(cx + BOSS_SIZE * 0.5, fy), "vel": Vector2(PROJ_SPEED, 0.0), "alive": true})


func _boss_recover(en: Dictionary, _delta: float) -> void:
	_boss_hover(en, 40.0)
	if en.st > BOSS_RECOVER:
		_boss_choose(en)


# touché : recule à l'opposé du joueur avant de reprendre (anti point-blank)
func _boss_hurt(en: Dictionary, delta: float) -> void:
	if not en.fired:
		en.vx = -260.0 if ppos.x > en.pos.x else 260.0
		en.fired = true
	en.pos.x = clampf(en.pos.x + en.vx * delta, en.min, en.max)
	_boss_hover(en, -18.0)
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


# =================================================== mort / interactions
# dégât encaissé : perd un cœur si PV actifs (i-frames), sinon mort réelle
func _die() -> void:
	if dead or pinv > 0.0: return
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
				_touch_spring(c)
			WARP:
				app._warp_play(c)
			SWITCH:
				if switch_cd <= 0.0:
					var scol := _cell_color(c)
					sw_open[scol] = not bool(sw_open.get(scol, false))
					switch_cd = 0.4
					app._emit(_cell_center(c), 12, KEY_COLORS.get(scol, COLORS[SWITCH]), 200.0, 0.4, true, 4.0)
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


func _time_limit() -> float:
	var ap = app.get("level_props")
	return float(ap.get("time_limit", 0)) if ap != null else 0.0


# nombre d'ennemis tuables encore vivants (exclut piquant/poisson/rebond)
func _enemies_left() -> int:
	var n := 0
	for en in enemies:
		if en.alive and en.type != "spiker" and en.type != "fish" and en.type != "bouncer":
			n += 1
	return n


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


# =================================================== helpers de grille
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

	# mode "édition du fond" : on n'affiche QUE le parallax
	if app.get("bg_edit") == true:
		return

	# culling : bornes de cases visibles à l'écran
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
				or tk == BOSS or crumbled.has(k) or fb_trig.has(k) or (tk == GATE and open_gate_cells.has(k))):
			continue
		# autotile vertical (eau/lave) : surface = pas la même tuile juste au-dessus
		var surf: bool = app.grid.get(Vector2i(k.x, k.y - 1), EMPTY) != tk
		draw_tile(self, app._w2s(Vector2(k.x * CELL, k.y * CELL)), tk, app.view_scale, 1.0, true, surf)
		# pastille de couleur : groupe d'énigme (clé/porte + interrupteur/grille/dalle)
		if tk == KEY or tk == DOOR or tk == SWITCH or tk == GATE or tk == PLATE:
			var kc: Color = KEY_COLORS.get(str(app.cell_cfg.get(k, {}).get("color", "or")), Color.WHITE)
			draw_circle(app._w2s(Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL)), CELL * 0.13 * app.view_scale, kc)

	if app.mode != "play":
		_draw_edit_extra(cx0, cx1, cy0, cy1)

	for p in app.particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		var c: Color = p.col; c.a = a
		draw_circle(app._w2s(p.pos), p.size * app.view_scale, c)

	if app.mode == "play":
		_draw_world_extra()   # rendu spécifique au genre (loops, plats, hazards...)
		for en in enemies:
			if not en.alive: continue
			if en.type == "boss":
				var bctr: Vector2 = app._w2s(_boss_center(en))
				if en.get("enraged", false) or en.get("state", "") == "enrage":
					var ar: float = (BOSS_SIZE * 0.72 + sin(app.anim_t * 9.0) * 6.0) * app.view_scale
					draw_arc(bctr, ar, 0.0, TAU, 30, Color("e74c3c", 0.6), 4.0 * app.view_scale)
				if en.get("tele", false):
					var prr: float = (BOSS_SIZE * 0.6 + sin(en.st * 18.0) * 8.0) * app.view_scale
					draw_arc(bctr, prr, 0.0, TAU, 28, Color("ffde59", 0.8), 3.0 * app.view_scale)
				if en.inv > 0.0 and int(en.inv * 20.0) % 2 == 0:
					pass
				else:
					draw_tile(self, app._w2s(en.pos), BOSS, (BOSS_SIZE / float(CELL)) * app.view_scale)
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
			if int(app.level_props.get("gfx", 0)) == 3 and en.has("gh"):
				for gi in range(1, en.gh.size()):
					draw_tile(self, app._w2s(en.gh[gi] - Vector2(6, 6)), et, app.view_scale, 0.16)
			draw_tile(self, app._w2s(en.pos - Vector2(6, 6)), et, app.view_scale)
		for pj in projectiles:
			if pj.alive:
				if int(app.level_props.get("gfx", 0)) == 3 and pj.has("gh"):
					for gi in range(1, pj.gh.size()):
						draw_circle(app._w2s(pj.gh[gi]), PROJ_SIZE * 0.4 * app.view_scale, Color(1, 0.9, 0.5, 0.14))
				draw_circle(app._w2s(pj.pos), PROJ_SIZE * 0.5 * app.view_scale, Color("ffce54"))
				draw_circle(app._w2s(pj.pos), PROJ_SIZE * 0.28 * app.view_scale, Color("fff3c4"))
		# ghosting GBA : images-fantômes du joueur
		if int(app.level_props.get("gfx", 0)) == 3 and pos_hist.size() > 1:
			for gi in range(1, pos_hist.size()):
				var ga: float = 0.22 * (1.0 - float(gi) / float(pos_hist.size()))
				var gp: Vector2 = app._w2s(pos_hist[gi])
				draw_rect(Rect2(gp, PSIZE * app.view_scale), Color(1, 1, 1, ga))
		_draw_player()


# rendu du joueur (override par genre : sonic tourné, disque top-down...)
func _draw_player() -> void:
	var ps: Vector2 = PSIZE * app.squash
	var anchor: Vector2 = app._w2s(ppos + Vector2(PSIZE.x * 0.5, PSIZE.y))
	var pr := Rect2(anchor - Vector2(ps.x * 0.5, ps.y) * app.view_scale, ps * app.view_scale)
	draw_rect(pr, Color("ffffff")); draw_rect(pr, Color("2c3e50"), false, 2.0)
	if has_key:
		draw_circle(pr.position + Vector2(pr.size.x * 0.5, -8), 5, COLORS[KEY])


# ================================================================ PARALLAX
func _draw_parallax(_vp: Vector2, lvl_r: Rect2) -> void:
	var vo: Vector2 = app.view_origin; var vs: float = app.view_scale
	var bt: float = lvl_r.position.y + lvl_r.size.y
	var vx0: float = maxf(lvl_r.position.x, 0.0)
	var vx1: float = minf(lvl_r.position.x + lvl_r.size.x, _vp.x)
	var clip_r := Rect2(Vector2(vx0, lvl_r.position.y), Vector2(maxf(vx1 - vx0, 0.0), lvl_r.size.y))
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
	# fond plat (ex: top-down) : couleur + décors, mais pas collines/nuages
	if not _wants_parallax():
		layers.clear()
	# couche de sol auto (top-down : sol dallé)
	_draw_ground(clip_r)
	# décors du créateur ajoutés comme couches (selon leur profondeur)
	for dd in app.bg_deco:
		layers.append({"f": float(dd["factor"]), "k": "deco", "d": dd})
	for i in layers.size(): layers[i]["i"] = i
	layers.sort_custom(func(a, b): return a["i"] < b["i"] if a["f"] == b["f"] else a["f"] < b["f"])
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


# remplit un polygone FERMÉ libre (triangulation Geometry2D, silencieux si auto-sécant)
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


# silhouette de colline : contour lissé rempli jusqu'au sol par lignes verticales
func fill_silhouette(ci: CanvasItem, outline: PackedVector2Array, baseline_y: float, col: Color) -> void:
	var arr := []
	for p in outline: arr.append(p)
	if arr.size() < 2: return
	arr.sort_custom(func(a, b): return a.x < b.x)
	var sm := smooth_open(arr)
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


# couleur par défaut d'une forme de fond (teintée par le thème)
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


# dessine une forme de fond centrée en c, taille unité s, couleur col
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


# décalage vertical de la surface d'une rampe courbe (utilisé par draw_tile)
func _curve_offset(t: int, lx: float) -> float:
	var R := float(CELL)
	match t:
		CURVE_RU_CV: return sqrt(maxf(0.0, R * R - lx * lx))
		CURVE_RU_CC: return CELL - sqrt(maxf(0.0, R * R - (R - lx) * (R - lx)))
		CURVE_RD_CV: return sqrt(maxf(0.0, R * R - (R - lx) * (R - lx)))
		CURVE_RD_CC: return CELL - sqrt(maxf(0.0, R * R - lx * lx))
	return 0.0


func draw_tile(ci: CanvasItem, p: Vector2, t: int, scale := 1.0, alpha := 1.0, world := false, surface := true) -> void:
	var col: Color = COLORS.get(t, Color.GRAY); col.a = alpha
	var cs := CELL * scale
	var pad := 3.0 * scale
	# styles basse-déf (GB/GBC) : blocs structurels PLATS (8-bit chunky), sans dégradés
	if app != null and int(app.level_props.get("gfx", 0)) in [1, 2]:
		if t == GROUND or t == BREAKABLE or t == DOOR or t == ICE or t == FALLBLOCK or t == CRUMBLE or t == PUSHBLOCK or t == FLOOR:
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col)
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col.darkened(0.35), false, maxf(1.0, scale))
			return
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
		PLATE:
			# dalle de pression encastrée (s'éclaire quand enfoncée)
			var pcol: Color = col.lightened(0.25) if plate_open else col
			ci.draw_rect(Rect2(p + Vector2(pad, cs * 0.5), Vector2(cs - pad * 2, cs * 0.45)), pcol.darkened(0.25))
			ci.draw_rect(Rect2(p + Vector2(pad * 2, cs * 0.42 if not plate_open else cs * 0.5), Vector2(cs - pad * 4, cs * 0.3)), pcol)
		PUSHBLOCK:
			ci.draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col)
			ci.draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col.darkened(0.35), false, 2.0 * scale)
			ci.draw_line(p + Vector2(pad, pad), p + Vector2(cs - pad, cs - pad), col.lightened(0.15), 1.5 * scale)
			ci.draw_line(p + Vector2(cs - pad, pad), p + Vector2(pad, cs - pad), col.lightened(0.15), 1.5 * scale)
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
		ITEM_DJUMP, ITEM_MORPH, ITEM_MISSILE, ENERGY:
			# capsule d'objet : socle + orbe colorée qui pulse
			var icc := p + Vector2(cs * 0.5, cs * 0.55)
			var it_t: float = float(app.anim_t) if app != null else 0.0
			ci.draw_rect(Rect2(p + Vector2(cs * 0.3, cs * 0.78), Vector2(cs * 0.4, cs * 0.16)), Color("455a64"))
			ci.draw_circle(icc, cs * (0.22 + 0.02 * sin(it_t * 4.0)), col)
			ci.draw_circle(icc + Vector2(-cs * 0.06, -cs * 0.06), cs * 0.07, Color(1, 1, 1, 0.8 * alpha))
			if t == ENERGY:
				ci.draw_rect(Rect2(icc - Vector2(cs * 0.05, cs * 0.12), Vector2(cs * 0.1, cs * 0.24)), Color(1, 1, 1, 0.9))
				ci.draw_rect(Rect2(icc - Vector2(cs * 0.12, cs * 0.05), Vector2(cs * 0.24, cs * 0.1)), Color(1, 1, 1, 0.9))
		DOOR_BEAM, DOOR_MISSILE:
			# porte gated : montants + iris coloré (tir ou missile pour ouvrir)
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), Color("37474f"))
			ci.draw_rect(Rect2(p + Vector2(cs * 0.18, 0), Vector2(cs * 0.64, cs)), col.darkened(0.35))
			ci.draw_circle(p + Vector2(cs * 0.5, cs * 0.5), cs * 0.2, col)
			ci.draw_circle(p + Vector2(cs * 0.5, cs * 0.5), cs * 0.09, col.lightened(0.4))
		MORPH_TUBE:
			# conduit : bloc hachuré (passable uniquement en morph ball)
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col.darkened(0.4))
			for i in 4:
				var hx := cs * (0.1 + i * 0.25)
				ci.draw_line(p + Vector2(hx, cs * 0.1), p + Vector2(hx + cs * 0.12, cs * 0.9), col.lightened(0.1), 2.0 * scale)
			ci.draw_rect(Rect2(p, Vector2(cs, cs)), col.darkened(0.55), false, maxf(1.0, scale))
		MODE25, MODE3D:
			# déclencheur de mode caméra/déplacement (plateformer 3D)
			ci.draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col.darkened(0.35))
			ci.draw_rect(Rect2(p + Vector2(pad, pad), Vector2(cs - pad * 2, cs - pad * 2)), col, false, 2.0 * scale)
			var mc := p + Vector2(cs, cs) * 0.5
			if t == MODE25:
				ci.draw_line(mc - Vector2(cs * 0.26, 0), mc + Vector2(cs * 0.26, 0), col.lightened(0.3), 3.0 * scale)
			else:
				ci.draw_line(mc - Vector2(cs * 0.24, 0), mc + Vector2(cs * 0.24, 0), col.lightened(0.3), 3.0 * scale)
				ci.draw_line(mc - Vector2(0, cs * 0.24), mc + Vector2(0, cs * 0.24), col.lightened(0.3), 3.0 * scale)
		WARP:
			# portail : double anneau + tourbillon
			var wc := p + Vector2(cs, cs) * 0.5
			var wt: float = float(app.anim_t) if app != null else 0.0
			ci.draw_arc(wc, cs * 0.36, 0, TAU, 20, col, 3.0 * scale)
			ci.draw_arc(wc, cs * 0.24, wt * 2.0, wt * 2.0 + TAU * 0.7, 14, col.lightened(0.3), 2.0 * scale)
			ci.draw_circle(wc, cs * 0.08, col.lightened(0.5))
		GATE:
			# barreaux fermés (les grilles OUVERTES sont sautées au rendu en play)
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
