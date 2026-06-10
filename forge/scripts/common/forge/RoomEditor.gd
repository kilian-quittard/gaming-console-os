extends RefCounted
class_name RoomEditor
# ÉDITION DES SALLES (rectangles style Celeste) : tracé A/clic, suppression X,
# rendu overlay. Les données (app.rooms) et la caméra restent dans ForgeApp.

var app   # ForgeApp
var c0 := Vector2i(-1, -1)   # 1er coin du rectangle en cours


func _init(forge_app) -> void:
	app = forge_app


func open() -> void:
	app.room_edit = true
	c0 = Vector2i(-1, -1)


func input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		app.aim = (e as InputEventMouseMotion).position
		app._sync_cursor_from_aim(); app.queue_redraw(); return
	if app._press(e, [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_BACK, JOY_BUTTON_B]):
		app.room_edit = false; c0 = Vector2i(-1, -1)
		app._save_current(); app.queue_redraw(); app._redraw_world(); return
	if e is InputEventMouseButton and e.pressed:
		app.aim = e.position; app._sync_cursor_from_aim()
	# A / clic gauche : pose un coin puis le coin opposé → crée la salle
	if app._press(e, [KEY_ENTER, KEY_SPACE], [JOY_BUTTON_A]) or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed):
		if c0.x < 0:
			c0 = app.cursor
		else:
			var x0 := mini(c0.x, app.cursor.x); var y0 := mini(c0.y, app.cursor.y)
			var x1 := maxi(c0.x, app.cursor.x); var y1 := maxi(c0.y, app.cursor.y)
			app.rooms.append(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
			c0 = Vector2i(-1, -1); app._play("coin")
		app.queue_redraw(); return
	# X / clic droit : supprime la salle sous le curseur
	if app._press(e, [KEY_X, KEY_DELETE], [JOY_BUTTON_X]) or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT and e.pressed):
		for i in range(app.rooms.size() - 1, -1, -1):
			if (app.rooms[i] as Rect2i).has_point(app.cursor):
				app.rooms.remove_at(i); app._play("death"); break
		c0 = Vector2i(-1, -1); app.queue_redraw(); return
	# déplacement curseur clavier/manette
	var d := Vector2i.ZERO
	if app._press(e, [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]): d = Vector2i(-1, 0)
	elif app._press(e, [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]): d = Vector2i(1, 0)
	elif app._press(e, [KEY_UP], [JOY_BUTTON_DPAD_UP]): d = Vector2i(0, -1)
	elif app._press(e, [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]): d = Vector2i(0, 1)
	if d != Vector2i.ZERO:
		app.cursor.x = clampi(app.cursor.x + d.x, 0, app.cols - 1)
		app.cursor.y = clampi(app.cursor.y + d.y, 0, app.rows - 1)
		app.aim = app._w2s(Vector2((app.cursor.x + 0.5) * app.CELL, (app.cursor.y + 0.5) * app.CELL))
		app.queue_redraw()


func draw(vp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var cell: float = float(app.CELL)
	# bandeau bas
	app.draw_rect(Rect2(Vector2(0, vp.y - 30), Vector2(vp.x, 30)), Color(13.0/255, 17.0/255, 23.0/255, 0.9))
	app._text(f, Vector2(12, vp.y - 10), "ÉDITER SALLES — A: poser coin/valider · X: supprimer · B: fini   (salles: %d)" % app.rooms.size(), Color("ecf0f1"), 13)
	# salles existantes
	for i in app.rooms.size():
		var r: Rect2i = app.rooms[i]
		var sr := Rect2(app._w2s(Vector2(r.position) * cell), Vector2(r.size) * cell * app.view_scale)
		app.draw_rect(sr, Color(0.2, 0.8, 1.0, 0.10))
		app.draw_rect(sr, Color("3cb4e8"), false, 2.0)
		app._text(f, sr.position + Vector2(4, 16), "S%d" % (i + 1), Color("3cb4e8"), 13)
	# rectangle en cours (1er coin posé)
	if c0.x >= 0:
		var x0 := mini(c0.x, app.cursor.x); var y0 := mini(c0.y, app.cursor.y)
		var x1 := maxi(c0.x, app.cursor.x); var y1 := maxi(c0.y, app.cursor.y)
		var pr := Rect2(app._w2s(Vector2(x0 * cell, y0 * cell)), Vector2((x1 - x0 + 1) * cell, (y1 - y0 + 1) * cell) * app.view_scale)
		app.draw_rect(pr, Color(1.0, 0.6, 0.1, 0.18))
		app.draw_rect(pr, Color("f39c12"), false, 2.0)
	# curseur
	var cp: Vector2 = app._w2s(Vector2(app.cursor.x * cell, app.cursor.y * cell))
	app.draw_rect(Rect2(cp, Vector2(cell, cell) * app.view_scale), Color("f39c12"), false, 2.0)
