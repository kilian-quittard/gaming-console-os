extends Node2D
class_name GameShell
# Coquille générique de jeu — titre, sélection, jeu, résultats, game over.
# Fournit l'interface "app" attendue par les templates (même duck-typing que ForgeApp).
# Ne contient aucune logique de genre : délègue tout au template actif.

const CELL := 48
const HUD_H := 44
const BG_THEMES := [
	[Color("1b2838"), Color("223349")], [Color("2c1b38"), Color("3a2349")],
	[Color("1b3826"), Color("224935")], [Color("382b1b"), Color("493a23")]
]
const DEADZONE := 0.35

# --- interface "app" (duck-typing avec ForgeApp, lue par les templates) ---
var screen := "edit"           # toujours "edit" (templates lisent cette valeur)
var mode := "edit"             # "play" = physique active / "edit" = pause
var grid := {}
var level_props := {}           # propriétés de niveau (autorun, ...) lues par le template
var cols := 40
var rows := 14
var cursor := Vector2i.ZERO
var view_origin := Vector2.ZERO
var view_scale := 1.0
var dezoom := false
var particles := []
var shake_t := 0.0
var shake_mag := 0.0
var squash := Vector2.ONE
var sel_mode := false
var sel_anchor := Vector2i(-1, -1)
var pal := 0
var cursor_mode := "rapide"
var bg_theme := 0
var hide_editor_chrome := true  # empêche le template de dessiner le chrome éditeur

# --- config projet ---
var project_title := "MON JEU"
var project_levels: Array = []  # [{name, cols, bg, tiles: {"x,y": int}}]
var project_screens := {}        # données déco/tampons/textes/style par écran
enum SelectMode { LINEAR, LIST, FREE }
var select_mode_type: int = SelectMode.LINEAR

# --- état shell ---
var shell_screen := "title"
var sel_idx := 0
var anim_t := 0.0

# --- état de jeu ---
var current_level := 0
var lives := 3
var coins_got := 0
var coins_total := 0
var level_time := 0.0
var stars_got := 0
var progress := {}  # str(idx) → {stars: int, best_time: float}

# --- audio ---
var sfx := {}

# --- template actif (null hors jeu) ---
var tmpl = null
const PLATFORMER_PLAY := preload("res://scenes/game/PlatformerPlay.tscn")

@onready var states: State = $States


func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	_build_audio()
	if project_levels.is_empty():
		_build_demo_project()


func setup(config: Dictionary) -> void:
	project_title = config.get("title", "MON JEU")
	project_levels = config.get("levels", [])
	select_mode_type = config.get("select_mode", SelectMode.LINEAR)
	progress = config.get("progress", {})
	bg_theme = config.get("bg_theme", 0)
	project_screens = config.get("screens", {})


# =================================================== demo standalone
func _build_demo_project() -> void:
	project_title = "DEMO SPARK"
	project_levels = [_make_demo_level(0, "Prairie", 0), _make_demo_level(1, "Désert", 1)]


func _make_demo_level(seed_offset: int, lname: String, bg: int) -> Dictionary:
	var c := 40; var r := 14
	var tiles := {}
	for x in c: tiles["%d,%d" % [x, r - 1]] = 1          # GROUND
	for x in range(8 + seed_offset, 12 + seed_offset): tiles["%d,%d" % [x, r - 4]] = 1
	for x in range(16, 19): tiles["%d,%d" % [x, r - 6]] = 1
	tiles["%d,%d" % [2, r - 2]] = 2                       # SPAWN
	tiles["%d,%d" % [9 + seed_offset, r - 5]] = 3         # COIN
	tiles["%d,%d" % [10 + seed_offset, r - 5]] = 3
	tiles["%d,%d" % [17, r - 7]] = 3
	tiles["%d,%d" % [13 + seed_offset, r - 2]] = 4        # ENEMY
	tiles["%d,%d" % [22, r - 2]] = 6                      # SPRING
	tiles["%d,%d" % [26, r - 2]] = 7                      # SPIKE
	tiles["%d,%d" % [c - 2, r - 2]] = 5                   # GOAL
	return {"name": lname, "cols": c, "bg": bg, "tiles": tiles}


# =================================================== process
func _process(delta: float) -> void:
	anim_t += delta
	_update_fx(delta)
	if mode == "play":
		level_time += delta
	queue_redraw()


# =================================================== input
func _press(e: InputEvent, keys: Array, btns: Array) -> bool:
	if e is InputEventKey and e.pressed and not e.echo:
		return keys.has(e.keycode)
	if e is InputEventJoypadButton and e.pressed:
		return btns.has(e.button_index)
	return false


func _unhandled_input(e: InputEvent) -> void:
	match shell_screen:
		"title":    _title_input(e)
		"select":   _select_input(e)
		"playing":  _play_input(e)
		"pause":    _pause_input(e)
		"complete": _complete_input(e)
		"gameover": _gameover_input(e)


func _title_input(e: InputEvent) -> void:
	if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		if project_levels.is_empty(): return
		if select_mode_type == SelectMode.LINEAR:
			_enter_level(0)
		else:
			sel_idx = 0; states.change_state("SelectState")
	elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		get_tree().quit()


func _select_input(e: InputEvent) -> void:
	var n := project_levels.size()
	if _press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		sel_idx = (sel_idx + 1) % n; queue_redraw()
	elif _press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		sel_idx = (sel_idx - 1 + n) % n; queue_redraw()
	elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		states.change_state("TitleState")
	elif _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		_enter_level(sel_idx)


func _play_input(e: InputEvent) -> void:
	if tmpl == null: return
	if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		tmpl.jump_pressed()
	elif e is InputEventKey and not e.pressed and e.keycode == KEY_SPACE:
		tmpl.jump_released()
	elif e is InputEventJoypadButton and not e.pressed and e.button_index == JOY_BUTTON_A:
		tmpl.jump_released()
	elif _press(e, [KEY_ESCAPE], [JOY_BUTTON_START, JOY_BUTTON_BACK]):
		states.change_state("PauseState")


func _pause_input(e: InputEvent) -> void:
	if _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B, JOY_BUTTON_START]):
		states.change_state("PlayingState")  # PlayingState._on_enter remet mode="play"
	elif _press(e, [KEY_R], [JOY_BUTTON_Y]):
		_restart_level()
	elif _press(e, [KEY_Q], [JOY_BUTTON_X]):
		_unload_template()
		if select_mode_type == SelectMode.LINEAR:
			states.change_state("TitleState")
		else:
			sel_idx = current_level; states.change_state("SelectState")


func _complete_input(e: InputEvent) -> void:
	if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		var next := current_level + 1
		if next >= project_levels.size():
			states.change_state("TitleState")
		elif select_mode_type == SelectMode.LINEAR:
			_enter_level(next)
		else:
			sel_idx = next; states.change_state("SelectState")
	elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		if select_mode_type == SelectMode.LINEAR:
			states.change_state("TitleState")
		else:
			sel_idx = current_level; states.change_state("SelectState")


func _gameover_input(e: InputEvent) -> void:
	if _press(e, [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A]):
		lives = 3; _enter_level(current_level)
	elif _press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B]):
		lives = 3; states.change_state("TitleState")


# =================================================== gestion niveaux
func _enter_level(idx: int) -> void:
	current_level = idx
	_load_level_data(idx)
	_start_template_new()
	states.change_state("PlayingState")


func _load_level_data(idx: int) -> void:
	if idx >= project_levels.size(): return
	var lvl: Dictionary = project_levels[idx]
	cols = int(lvl.get("cols", 40))
	bg_theme = int(lvl.get("bg", 0)) % BG_THEMES.size()
	var pr = lvl.get("props", {})
	level_props = pr if typeof(pr) == TYPE_DICTIONARY else {}
	grid.clear()
	for k in lvl.get("tiles", {}):
		var parts: PackedStringArray = String(k).split(",")
		grid[Vector2i(int(parts[0]), int(parts[1]))] = int(lvl["tiles"][k])
	level_time = 0.0
	coins_got = 0
	coins_total = 0


func _start_template_new() -> void:
	_unload_template()
	tmpl = PLATFORMER_PLAY.instantiate()
	add_child(tmpl)
	tmpl.setup(self)
	if tmpl.has_signal("player_died"):
		tmpl.player_died.connect(_on_player_died)
	if tmpl.has_signal("level_won"):
		tmpl.level_won.connect(_on_level_won)
	if tmpl.has_signal("coin_collected"):
		tmpl.coin_collected.connect(_on_coin_collected)
	tmpl.start_play(false)
	coins_total = tmpl.coins_total
	mode = "play"


func _unload_template() -> void:
	mode = "edit"
	if tmpl:
		if tmpl.has_signal("player_died") and tmpl.player_died.is_connected(_on_player_died):
			tmpl.player_died.disconnect(_on_player_died)
		if tmpl.has_signal("level_won") and tmpl.level_won.is_connected(_on_level_won):
			tmpl.level_won.disconnect(_on_level_won)
		if tmpl.has_signal("coin_collected") and tmpl.coin_collected.is_connected(_on_coin_collected):
			tmpl.coin_collected.disconnect(_on_coin_collected)
		tmpl.queue_free()
		tmpl = null


func _restart_level() -> void:
	_load_level_data(current_level)
	_start_template_new()
	states.change_state("PlayingState")


# =================================================== signaux template
func _on_player_died() -> void:
	lives -= 1
	if lives <= 0:
		_unload_template()
		states.change_state("GameOverState")
	else:
		_load_level_data(current_level)
		_start_template_new()


func _on_level_won() -> void:
	stars_got = _calc_stars()
	var key := str(current_level)
	var best: Dictionary = progress.get(key, {})
	if not best.has("stars") or int(best.get("stars", 0)) < stars_got:
		progress[key] = {"stars": stars_got, "best_time": level_time}
	_unload_template()
	states.change_state("CompleteState")


func _on_coin_collected() -> void:
	coins_got += 1


func _calc_stars() -> int:
	if coins_total == 0: return 3
	var r := float(coins_got) / float(coins_total)
	if r >= 1.0: return 3
	if r >= 0.5: return 2
	return 1


# =================================================== interface "app" (pour templates)
func _emit(pos: Vector2, count: int, col: Color, spd: float, life: float, grav := true, size := 4.0) -> void:
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * (spd * (0.4 + randf() * 0.6))
		particles.append({"pos": pos, "vel": v, "life": life, "max": life,
			"col": col, "size": size * (0.6 + randf() * 0.6), "grav": grav})


func _shake(mag: float, t: float) -> void:
	shake_mag = max(shake_mag, mag); shake_t = max(shake_t, t)


func _play(name: String) -> void:
	if sfx.has(name): sfx[name].play()


func _update_fx(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		if shake_t <= 0.0: shake_mag = 0.0
	squash = squash.lerp(Vector2.ONE, clampf(delta * 12.0, 0.0, 1.0))
	if particles.is_empty(): return
	var keep := []
	for p in particles:
		p.life -= delta
		if p.life <= 0.0: continue
		if p.grav: p.vel.y += 1100.0 * delta
		p.pos += p.vel * delta
		keep.append(p)
	particles = keep


func _w2s(wp: Vector2) -> Vector2:
	return view_origin + wp * view_scale


func _compute_view() -> void:
	if tmpl == null: return
	var vp := get_viewport_rect().size
	var area := Rect2(0.0, float(HUD_H), vp.x, vp.y - float(HUD_H))
	var lvl := Vector2(cols * CELL, rows * CELL)
	view_scale = 1.0
	view_origin = area.position + area.size * 0.5 - (tmpl.ppos + tmpl.PSIZE * 0.5) * view_scale
	var sw := lvl.x * view_scale
	var sh := lvl.y * view_scale
	if sw <= area.size.x:
		view_origin.x = area.position.x + (area.size.x - sw) * 0.5
	else:
		view_origin.x = clampf(view_origin.x, area.position.x + area.size.x - sw, area.position.x)
	if sh <= area.size.y:
		view_origin.y = area.position.y + (area.size.y - sh) * 0.5
	else:
		view_origin.y = clampf(view_origin.y, area.position.y + area.size.y - sh, area.position.y)
	if shake_t > 0.0:
		view_origin += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_mag


# =================================================== audio (PCM — même système que ForgeApp)
func _build_audio() -> void:
	sfx["jump"]   = _mk_player(_tone([520.0, 760.0], 0.10, 0.35, "square"))
	sfx["coin"]   = _mk_player(_tone([900.0, 1300.0], 0.09, 0.30, "square"))
	sfx["death"]  = _mk_player(_tone([400.0, 120.0], 0.35, 0.40, "square"))
	sfx["win"]    = _mk_player(_tone([660.0, 880.0, 1180.0], 0.40, 0.35, "square"))
	sfx["spring"] = _mk_player(_tone([300.0, 1000.0], 0.16, 0.40, "square"))
	sfx["break"]  = _mk_player(_tone([220.0, 90.0], 0.12, 0.35, "noise"))
	sfx["stomp"]  = _mk_player(_tone([700.0, 300.0], 0.10, 0.35, "square"))
	sfx["key"]    = _mk_player(_tone([800.0, 1200.0, 1000.0], 0.16, 0.30, "square"))


func _mk_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream; add_child(p); return p


func _tone(freqs: Array, dur: float, vol := 0.4, kind := "square") -> AudioStreamWAV:
	var rate := 22050; var n := int(rate * dur)
	var data := PackedByteArray(); data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var prog := float(i) / n
		var f: float = freqs[clampi(int(prog * freqs.size()), 0, freqs.size() - 1)]
		ph += f / rate
		var s: float
		if kind == "square": s = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		elif kind == "noise": s = randf() * 2.0 - 1.0
		else: s = sin(ph * TAU)
		var env := 1.0 - prog
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate
	w.stereo = false; w.data = data; return w


# =================================================== dessin
const C_BG    := Color("1b2838")
const C_TITLE := Color("f39c12")
const C_WHITE := Color.WHITE
const C_GRAY  := Color(0.55, 0.60, 0.70)
const C_GREEN := Color("2ecc71")
const C_RED   := Color("e74c3c")


func _draw() -> void:
	var vp := get_viewport_rect().size
	match shell_screen:
		"title":    _draw_title(vp)
		"select":   _draw_select(vp)
		"playing":  _draw_hud(vp)
		"pause":    _draw_hud(vp); _draw_pause(vp)
		"complete": _draw_complete(vp)
		"gameover": _draw_gameover(vp)


func _t(pos: Vector2, s: String, col: Color, size: int) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _ct(cx: float, y: float, s: String, col: Color, size: int) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(cx - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_title(vp: Vector2) -> void:
	var data: Dictionary = project_screens.get("title", ScreenArt.empty_screen())
	var ah := String(data.get("accent", "3498db"))
	var accent := Color(ah) if ah.length() == 6 else Color("3498db")
	var bi := int(data.get("bg", 0)) % BG_THEMES.size()
	var ctx := {"accent": accent, "bg": BG_THEMES[bi][0], "title_text": project_title,
		"subtitle": String(data.get("subtitle", "")), "anim_t": anim_t}
	ScreenArt.draw_title(self, Rect2(Vector2.ZERO, vp), data, ctx)
	_ct(vp.x * 0.5, vp.y - 40, "B → Quitter", C_GRAY, 16)


func _draw_select(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), C_BG)
	_ct(vp.x * 0.5, 65, project_title, C_TITLE, 30)
	_ct(vp.x * 0.5, 105, "CHOISIR UN NIVEAU", C_GRAY, 17)
	var cx := vp.x * 0.5; var y := 155.0
	for i in project_levels.size():
		var lvl: Dictionary = project_levels[i]
		var lname: String = lvl.get("name", "Niveau %d" % (i + 1))
		var stars_s: String = _star_str(i)
		var col: Color = C_WHITE if i == sel_idx else C_GRAY
		if i == sel_idx:
			draw_rect(Rect2(cx - 310, y - 26, 620, 40), Color(1, 1, 1, 0.07))
			draw_rect(Rect2(cx - 310, y - 26, 620, 40), C_TITLE, false, 2.0)
		_t(Vector2(cx - 290, y), ("▶ " if i == sel_idx else "  ") + lname, col, 22)
		_t(Vector2(cx + 210, y), stars_s, C_TITLE, 20)
		y += 48
		if y > vp.y - 80: break
	_ct(vp.x * 0.5, vp.y - 40, "▲▼ naviguer    A jouer    B retour", C_GRAY, 16)


func _star_str(lvl_idx: int) -> String:
	var key := str(lvl_idx)
	if not progress.has(key): return "☆☆☆"
	var s: int = int(progress[key].get("stars", 0))
	return "★".repeat(s) + "☆".repeat(3 - s)


func _draw_hud(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, HUD_H)), Color(0.06, 0.07, 0.12, 0.93))
	_t(Vector2(12, 30), "♥ × %d" % lives, C_RED, 20)
	_t(Vector2(130, 30), "● %d / %d" % [coins_got, max(coins_total, 1)], C_TITLE, 20)
	var lname := ""
	if current_level < project_levels.size():
		lname = project_levels[current_level].get("name", "Niveau %d" % (current_level + 1))
	_ct(vp.x * 0.5, 28, lname, C_GRAY, 16)
	var ts := "%.1f s" % level_time
	var tw := f.get_string_size(ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_t(Vector2(vp.x - tw - 12, 28), ts, C_WHITE, 18)


func _draw_pause(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
	var cx := vp.x * 0.5; var cy := vp.y * 0.5
	draw_rect(Rect2(cx - 230, cy - 140, 460, 280), Color(0.06, 0.07, 0.12, 0.97))
	draw_rect(Rect2(cx - 230, cy - 140, 460, 280), C_TITLE, false, 2.5)
	_ct(cx, cy - 100, "PAUSE", C_WHITE, 40)
	_ct(cx, cy - 30, "B / Start  →  Reprendre", C_GRAY, 18)
	_ct(cx, cy + 10, "Y  →  Recommencer le niveau", C_GRAY, 18)
	_ct(cx, cy + 50, "X  →  Quitter le niveau", C_GRAY, 18)


func _draw_complete(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), C_BG)
	var cx := vp.x * 0.5
	_ct(cx, 120, "NIVEAU TERMINÉ !", C_GREEN, 46)
	var lname := ""
	if current_level < project_levels.size():
		lname = project_levels[current_level].get("name", "Niveau %d" % (current_level + 1))
	_ct(cx, 180, lname, C_GRAY, 20)
	for i in 3:
		var star_col: Color = C_TITLE if i < stars_got else C_GRAY
		_ct(cx - 52 + i * 52, 268, "★", star_col, 56)
	_ct(cx, 340, "Pièces : %d / %d" % [coins_got, max(coins_total, 1)], C_WHITE, 22)
	_ct(cx, 378, "Temps : %.1f s" % level_time, C_WHITE, 22)
	var has_next := (current_level + 1) < project_levels.size()
	if has_next:
		_ct(cx, 440, "A  →  Niveau suivant          B  →  Retour", C_GRAY, 18)
	else:
		_ct(cx, 440, "🎉  Jeu terminé !   A  →  Titre", C_TITLE, 22)


func _draw_gameover(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), C_BG)
	var cx := vp.x * 0.5; var cy := vp.y * 0.5
	_ct(cx, cy - 60, "GAME OVER", C_RED, 54)
	_ct(cx, cy + 20, "A  →  Réessayer          B  →  Titre", C_WHITE, 22)
