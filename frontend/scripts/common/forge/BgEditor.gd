extends RefCounted
class_name BgEditor
# ÉDITEUR DE FOND : vue parallax seule + placement de formes (stamps) et de
# polygones libres, profondeur/plan, réordonnancement. Les données (app.bg_deco)
# et le drapeau app.bg_edit restent dans ForgeApp (lus par les templates).

const SHAPES := ["nuage", "montagne", "colline", "soleil", "lune", "etoile", "arbre", "sapin"]
const DEPTHS := [0.08, 0.28, 0.55, 0.85]
const DEPTH_NAMES := ["loin", "moyen", "proche", "devant"]
const SCALES := [0.6, 1.0, 1.6, 2.4]
const COLORS := ["3a8f4f", "2e7d32", "1b5e20", "c68642", "8b4513", "7f8c8d", "5a6978", "2e1152", "e8a04b", "ecf0f1"]
const THEME_NAMES := ["Ciel", "Espace", "Neige", "Désert"]

var app                  # ForgeApp
var tool := 0            # 0 = formes (stamps), 1 = polygone libre (dessin)
var pts := []            # points du polygone en cours [[x,y]] (coords monde)
var shape := 0           # forme sélectionnée (index SHAPES)
var col := 0             # couleur sélectionnée (polygone)
var scale_i := 1         # taille (index SCALES)
var depth := 1           # profondeur (index DEPTHS)
var trig_l := false      # debounce gâchette L2 (reculer)
var trig_r := false      # debounce gâchette R2 (avancer)


func _init(forge_app) -> void:
	app = forge_app


func open() -> void:
	app.bg_edit = true; app.queue_redraw(); app._redraw_world()


func input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		app.aim = (e as InputEventMouseMotion).position; app.queue_redraw(); return
	if app._press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_BACK, JOY_BUTTON_B]):
		app.bg_edit = false; pts.clear(); app.queue_redraw(); app._redraw_world(); return
	# bascule d'outil
	if app._press(e, [KEY_TAB], [JOY_BUTTON_LEFT_STICK]):
		tool = 1 - tool; pts.clear(); app.queue_redraw(); return
	# valider le polygone en cours
	if tool == 1 and app._press(e, [KEY_ENTER], [JOY_BUTTON_START]):
		commit_poly(); return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		var rects := icon_rects()
		for i in rects.size():
			if (rects[i] as Rect2).has_point(e.position):
				if tool == 0: shape = i
				else: col = i % COLORS.size()
				app.queue_redraw(); return
		place(); return
	if app._press(e, [KEY_SPACE], [JOY_BUTTON_A]):
		place(); return
	if app._press(e, [KEY_DELETE, KEY_X], [JOY_BUTTON_X]) or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT and e.pressed):
		if tool == 1 and not pts.is_empty(): pts.pop_back(); app.queue_redraw()
		else: erase()
		return
	if app._press(e, [KEY_BRACKETLEFT, KEY_A], [JOY_BUTTON_LEFT_SHOULDER]):
		if tool == 0: shape = (shape - 1 + SHAPES.size()) % SHAPES.size()
		else: col = (col - 1 + COLORS.size()) % COLORS.size()
		app.queue_redraw()
	elif app._press(e, [KEY_BRACKETRIGHT, KEY_E], [JOY_BUTTON_RIGHT_SHOULDER]):
		if tool == 0: shape = (shape + 1) % SHAPES.size()
		else: col = (col + 1) % COLORS.size()
		app.queue_redraw()
	elif app._press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]):
		if tool == 0: scale_i = mini(scale_i + 1, SCALES.size() - 1)
		else: col = (col + 1) % COLORS.size()
		app.queue_redraw()
	elif app._press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]):
		if tool == 0: scale_i = maxi(scale_i - 1, 0)
		else: col = (col - 1 + COLORS.size()) % COLORS.size()
		app.queue_redraw()
	elif app._press(e, [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]):
		depth = maxi(depth - 1, 0); app.queue_redraw()
	elif app._press(e, [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]):
		depth = mini(depth + 1, DEPTHS.size() - 1); app.queue_redraw()
	elif app._press(e, [KEY_PAGEUP], []):
		reorder(1)
	elif app._press(e, [KEY_PAGEDOWN], []):
		reorder(-1)
	elif app._press(e, [KEY_Y], [JOY_BUTTON_Y]):
		app.bg_theme = (app.bg_theme + 1) % app.BG_THEMES.size(); app.queue_redraw(); app._redraw_world()


# gâchettes : reculer (L2) / avancer (R2) le décor visé — sur front montant
func process_triggers() -> void:
	var tr := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.6
	var tl := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.6
	if tr and not trig_r: reorder(1)
	if tl and not trig_l: reorder(-1)
	trig_r = tr; trig_l = tl


func place() -> void:
	var d: float = DEPTHS[depth]
	var wx: float = (app.aim.x - app.view_origin.x * d) / app.view_scale
	var wy: float = (app.aim.y - app.view_origin.y * d) / app.view_scale
	if tool == 1:
		pts.append([wx, wy]); app.queue_redraw(); return
	app.bg_deco.append({"shape": SHAPES[shape], "x": wx, "y": wy,
		"scale": SCALES[scale_i], "factor": d, "col": app.tmpl.bg_shape_color(SHAPES[shape], app.bg_theme).to_html(false)})
	app.queue_redraw(); app._redraw_world()


func commit_poly() -> void:
	if pts.size() < 3:
		app._set_toast("Polygone : place au moins 3 points"); return
	app.bg_deco.append({"shape": "poly", "factor": DEPTHS[depth],
		"col": COLORS[col], "pts": pts.duplicate(true)})
	pts.clear()
	app.queue_redraw(); app._redraw_world()


func pick() -> int:
	# décor le plus proche du pointeur (ancre = position stamp ou centroïde du polygone)
	var best := -1; var bestd := 80.0
	for i in app.bg_deco.size():
		var dd: Dictionary = app.bg_deco[i]
		var f: float = float(dd["factor"])
		var sp: Vector2
		if str(dd.get("shape", "")) == "poly":
			var c := Vector2.ZERO
			var ppts: Array = dd["pts"]
			for p in ppts: c += Vector2(float(p[0]), float(p[1]))
			c /= float(max(1, ppts.size()))
			sp = Vector2(c.x * app.view_scale + app.view_origin.x * f, c.y * app.view_scale + app.view_origin.y * f)
		else:
			sp = Vector2(float(dd["x"]) * app.view_scale + app.view_origin.x * f, float(dd["y"]) * app.view_scale + app.view_origin.y * f)
		var dist: float = sp.distance_to(app.aim)
		if dist < bestd: bestd = dist; best = i
	return best


func reorder(dir: int) -> void:
	# change la PROFONDEUR du décor visé (= son plan vs collines + parallax).
	var i := pick()
	if i < 0:
		app._set_toast("Vise un décor pour changer son plan"); return
	var dd: Dictionary = app.bg_deco[i]
	var cur: float = float(dd["factor"])
	var ci := 0; var cd := 1e9
	for j in DEPTHS.size():
		var diff: float = absf(float(DEPTHS[j]) - cur)
		if diff < cd: cd = diff; ci = j
	ci = clampi(ci + dir, 0, DEPTHS.size() - 1)
	dd["factor"] = DEPTHS[ci]
	# garde un ordre de tableau cohérent : devant = fin, derrière = début
	app.bg_deco.remove_at(i)
	if dir > 0: app.bg_deco.append(dd)
	else: app.bg_deco.insert(0, dd)
	app._set_toast("Plan : %s" % DEPTH_NAMES[ci])
	app.queue_redraw(); app._redraw_world()


func erase() -> void:
	var i := pick()
	if i >= 0:
		app.bg_deco.remove_at(i); app.queue_redraw(); app._redraw_world()


# ----------------------------------------------------------------- rendu
func draw(vp: Vector2) -> void:
	if tool == 0:
		# aperçu fantôme de la forme au pointeur
		if app.aim.x >= 0.0:
			var gs: float = SCALES[scale_i] * app.view_scale
			var gcol: Color = app.tmpl.bg_shape_color(SHAPES[shape], app.bg_theme); gcol.a = 0.55
			app.tmpl.draw_bg_shape(app, SHAPES[shape], app.aim, gs, gcol)
			app.draw_arc(app.aim, 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.8), 1.5)
	else:
		# forme fermée libre en cours : points dans l'ordre, fermeture auto
		var d: float = DEPTHS[depth]
		var pcol := Color(COLORS[col])
		var screen_pts := PackedVector2Array()
		for p in pts:
			screen_pts.append(Vector2(float(p[0]) * app.view_scale + app.view_origin.x * d, float(p[1]) * app.view_scale + app.view_origin.y * d))
		var preview := PackedVector2Array(screen_pts)
		if app.aim.x >= 0.0: preview.append(app.aim)
		if preview.size() >= 3:
			var fill := pcol; fill.a = 0.4
			app.tmpl.fill_poly_closed(app, preview, fill)
		var m := preview.size()
		for i in m:
			app.draw_line(preview[i], preview[(i + 1) % m], pcol, 2.0)
		for i in screen_pts.size():
			app.draw_circle(screen_pts[i], 4.0, Color("f39c12"))
		if app.aim.x >= 0.0:
			app.draw_arc(app.aim, 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.8), 1.5)
		app._text(ThemeDB.fallback_font, Vector2(app.aim.x + 10, app.aim.y - 8), "%d pts — Entrée pour fermer" % screen_pts.size(), Color(1, 1, 1, 0.7), 12)


func icon_rects() -> Array:
	# rectangles cliquables (formes en mode stamp, couleurs en mode polygone)
	var out := []
	var n: int = SHAPES.size() if tool == 0 else COLORS.size()
	var x := 150.0
	for i in n:
		out.append(Rect2(Vector2(x, 4), Vector2(44, 44)))
		x += 48.0
	return out


func draw_topbar(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	app.draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, app.TOPBAR)), Color("11161f"))
	app._text(f, Vector2(12, 22), "FOND", Color("f39c12"), 16)
	app._text(f, Vector2(12, 42), "Formes" if tool == 0 else "Polygone", Color(1, 1, 1, 0.7), 12)
	var rects := icon_rects()
	for i in rects.size():
		var box: Rect2 = rects[i]
		if tool == 0:
			var act := (i == shape)
			app.draw_rect(box, Color("223349") if act else Color("1a2233"))
			app.tmpl.draw_bg_shape(app, SHAPES[i], box.position + box.size * 0.5, 0.42, app.tmpl.bg_shape_color(SHAPES[i], app.bg_theme))
			app.draw_rect(box, Color("f39c12") if act else Color(1, 1, 1, 0.15), false, 3.0 if act else 1.0)
		else:
			var acc := (i == col)
			app.draw_rect(box, Color(COLORS[i]))
			app.draw_rect(box, Color("f39c12") if acc else Color(1, 1, 1, 0.2), false, 3.0 if acc else 1.0)
	var rx: float = rects[rects.size() - 1].end.x + 14.0
	app._text(f, Vector2(rx, 20), "Prof: %s   Taille: %.1f" % [DEPTH_NAMES[depth], SCALES[scale_i]], Color(1, 1, 1, 0.85), 12)
	app._text(f, Vector2(rx, 40), "Thème: %s   (TAB outil)" % [THEME_NAMES[app.bg_theme] if app.bg_theme < THEME_NAMES.size() else str(app.bg_theme)], Color(1, 1, 1, 0.6), 12)


func draw_hints(vp: Vector2) -> void:
	app.draw_rect(Rect2(Vector2(0, vp.y - app.BOTTOM), Vector2(vp.x, app.BOTTOM)), Color("131a14"))
	var x := 12.0
	var y: float = vp.y - app.BOTTOM + 6.0
	x = app._badge(x, y, "TAB", "Outil")
	if tool == 0:
		x = app._badge(x, y, "A", "Poser")
		x = app._badge(x, y, "X", "Effacer")
		x = app._badge(x, y, "A/E", "Forme")
		x = app._badge(x, y, "↑↓", "Taille")
	else:
		x = app._badge(x, y, "A", "Point")
		x = app._badge(x, y, "Enter", "Valider")
		x = app._badge(x, y, "X", "Retirer pt")
		x = app._badge(x, y, "A/E", "Couleur")
	x = app._badge(x, y, "←→", "Profondeur")
	x = app._badge(x, y, "L2/R2", "Arr./Av. plan")
	x = app._badge(x, y, "Y", "Thème")
	x = app._badge(x, y, "B", "Sortir")
