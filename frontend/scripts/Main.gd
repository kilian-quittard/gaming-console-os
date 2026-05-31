extends Control
## Gaming Console OS — home. Two content-first MODES, toggled with X.
## Theme: "Indie Playful". Decoupled front-end (launching is the OS session
## layer's job, kept out here so the front-end stays swappable).

const MODE_NAMES := ["GAMING", "TRAVAIL"]
const MODE_ACCENTS := [
	Color(1.0, 0.45, 0.45),   # GAMING  — coral
	Color(0.18, 0.82, 0.71),  # TRAVAIL — teal
]
# GAMING = warm/energetic (plum→magenta).  TRAVAIL = cool/calm (blue-teal).
const MODE_BG_TOP := [Color(0.21, 0.11, 0.21), Color(0.08, 0.14, 0.20)]
const MODE_BG_BOTTOM := [Color(0.10, 0.07, 0.13), Color(0.05, 0.08, 0.13)]

const AMBER := Color(1.0, 0.74, 0.28)
const X_BLUE := Color(0.30, 0.55, 0.98)
const TILE_SIZE := Vector2(240, 300)

# Content per mode. kind drives the icon style. (All placeholders for now.)
const CONTENT := [
	[ # GAMING
		{"title": "CARTOUCHE", "sub": "Insérez une cartouche", "kind": "cartridge"},
		{"title": "Jeu 1", "sub": "Digital", "kind": "game"},
		{"title": "Jeu 2", "sub": "Digital", "kind": "game"},
		{"title": "Store", "sub": "Ajouter", "kind": "store"},
	],
	[ # TRAVAIL
		{"title": "FORGE", "sub": "Godot", "kind": "forge"},
		{"title": "Pixel Art", "sub": "Éditeur", "kind": "pixel"},
		{"title": "Docs Web", "sub": "Navigateur", "kind": "web"},
		{"title": "Store", "sub": "Ajouter", "kind": "store"},
	],
]

# Demo "cartridge" the simulated slot reveals when "inserted" (key C / Y button).
const CARTRIDGE_GAME := {"title": "INDIE QUEST", "sub": "Cartouche", "kind": "game"}

var _mode := 0
var _selected := 0
var _cartridge_inserted := false
var _tiles: Array[Panel] = []
var _tweens: Array = []

# Persistent nodes
var _bg: TextureRect
var _motif: Control
var _tab_labels: Array[Label] = []
var _toggle_badge: Panel
var _toggle_label: Label
var _row: HBoxContainer
var _status: Label


func _ready() -> void:
	_build_chrome()
	_populate_mode(true)


# ---- Static chrome (top bar, toggle button, hints) -------------------------

func _build_chrome() -> void:
	_bg = TextureRect.new()
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Subtle per-mode background motif (drawn above gradient, below content).
	# GAMING: diagonal energy lines.  TRAVAIL: graph-paper grid (creative canvas).
	_motif = Control.new()
	_motif.set_anchors_preset(Control.PRESET_FULL_RECT)
	_motif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motif.draw.connect(_draw_motif)
	add_child(_motif)

	# Top-left: mode tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 28)
	tabs.position = Vector2(70, 56)
	add_child(tabs)
	for i in MODE_NAMES.size():
		var lbl := Label.new()
		lbl.text = MODE_NAMES[i]
		lbl.add_theme_font_size_override("font_size", 34)
		tabs.add_child(lbl)
		_tab_labels.append(lbl)

	# Top-right: contextual toggle button  [X] Mode ...
	var toggle := HBoxContainer.new()
	toggle.add_theme_constant_override("separation", 14)
	toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle.position = Vector2(-380, 60)
	toggle.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(toggle)

	_toggle_badge = _make_glyph_badge("X", X_BLUE)
	toggle.add_child(_toggle_badge)

	_toggle_label = Label.new()
	_toggle_label.add_theme_font_size_override("font_size", 26)
	_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toggle.add_child(_toggle_label)

	# Center: content row
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 140
	center.offset_bottom = -90
	add_child(center)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 44)
	center.add_child(_row)

	# Bottom hints
	_status = Label.new()
	_status.text = "‹ ›  Naviguer      A  Lancer      X  Mode      C  Cartouche (démo)"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	_status.modulate = Color(0.65, 0.62, 0.72)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -70
	_status.offset_bottom = -34
	add_child(_status)


func _draw_motif() -> void:
	var sz := _motif.size
	var col: Color = MODE_ACCENTS[_mode]
	col.a = 0.06
	if _mode == 0:
		# GAMING — diagonal energy lines
		var step := 100.0
		var x := -sz.y
		while x < sz.x:
			_motif.draw_line(Vector2(x, 0), Vector2(x + sz.y, sz.y), col, 3.0)
			x += step
	else:
		# TRAVAIL — graph-paper grid (creative canvas)
		var step := 64.0
		var gx := 0.0
		while gx < sz.x:
			_motif.draw_line(Vector2(gx, 0), Vector2(gx, sz.y), col, 1.5)
			gx += step
		var gy := 0.0
		while gy < sz.y:
			_motif.draw_line(Vector2(0, gy), Vector2(sz.x, gy), col, 1.5)
			gy += step


func _make_icon(kind: String, color: Color, sz: Vector2) -> Control:
	var c := Control.new()
	c.custom_minimum_size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): _draw_icon(c, kind, color))
	return c


func _draw_icon(c: Control, kind: String, color: Color) -> void:
	match kind:
		"game": _draw_play(c, color)
		"cartridge": _draw_cartridge(c, color, false)
		"cartridge_in": _draw_cartridge(c, color, true)
		"forge": _draw_anvil(c, color)
		"pixel": _draw_pixel(c, color)
		"web": _draw_web(c, color)
		"store": _draw_plus(c, color)
		_: _draw_play(c, color)


func _draw_play(c: Control, color: Color) -> void:
	var s := c.size
	var ctr := s * 0.5
	var w := s.x * 0.28
	var h := s.y * 0.34
	c.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-w * 0.7, -h), ctr + Vector2(-w * 0.7, h), ctr + Vector2(w * 1.1, 0.0),
	]), color)


func _draw_cartridge(c: Control, color: Color, filled: bool) -> void:
	var s := c.size
	var p := Vector2(s.x * 0.12, s.y * 0.06)
	var body := Rect2(p, s - p * 2.0)
	if filled:
		c.draw_rect(body, color, true)
		var band := Rect2(body.position + Vector2(body.size.x * 0.15, body.size.y * 0.16),
			Vector2(body.size.x * 0.7, body.size.y * 0.26))
		c.draw_rect(band, color.darkened(0.45), true)
		var pin_y := body.position.y + body.size.y * 0.82
		for i in 4:
			var px := body.position.x + body.size.x * (0.22 + i * 0.18)
			c.draw_rect(Rect2(px, pin_y, body.size.x * 0.10, body.size.y * 0.12), color.darkened(0.45), true)
	else:
		c.draw_rect(body, color, false, 3.0)
		var slot := Rect2(body.position + Vector2(body.size.x * 0.28, body.size.y * 0.2),
			Vector2(body.size.x * 0.44, body.size.y * 0.10))
		c.draw_rect(slot, color, false, 2.0)


func _draw_anvil(c: Control, color: Color) -> void:
	var s := c.size
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(s.x * 0.16, s.y * 0.34), Vector2(s.x * 0.86, s.y * 0.34),
		Vector2(s.x * 0.72, s.y * 0.52), Vector2(s.x * 0.30, s.y * 0.52),
	]), color)
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(s.x * 0.16, s.y * 0.34), Vector2(s.x * 0.04, s.y * 0.42), Vector2(s.x * 0.16, s.y * 0.46),
	]), color)
	c.draw_rect(Rect2(s.x * 0.42, s.y * 0.52, s.x * 0.16, s.y * 0.20), color, true)
	c.draw_rect(Rect2(s.x * 0.28, s.y * 0.72, s.x * 0.44, s.y * 0.12), color, true)


func _draw_pixel(c: Control, color: Color) -> void:
	var s := c.size
	var n := 3
	var gap := s.x * 0.09
	var cell := (s.x - gap * (n + 1)) / n
	var on := [true, false, true, false, true, false, true, false, true]
	for r in n:
		for col in n:
			var pos := Vector2(gap + (cell + gap) * col, gap + (cell + gap) * r)
			var cc := color if on[r * n + col] else color.darkened(0.55)
			c.draw_rect(Rect2(pos, Vector2(cell, cell)), cc, true)


func _draw_web(c: Control, color: Color) -> void:
	var s := c.size
	var ctr := s * 0.5
	var r := minf(s.x, s.y) * 0.42
	c.draw_arc(ctr, r, 0.0, TAU, 48, color, 3.0)
	c.draw_line(ctr + Vector2(-r, 0), ctr + Vector2(r, 0), color, 2.0)
	c.draw_line(ctr + Vector2(0, -r), ctr + Vector2(0, r), color, 2.0)
	c.draw_line(ctr + Vector2(-r * 0.85, -r * 0.5), ctr + Vector2(r * 0.85, -r * 0.5), color, 1.5)
	c.draw_line(ctr + Vector2(-r * 0.85, r * 0.5), ctr + Vector2(r * 0.85, r * 0.5), color, 1.5)


func _draw_plus(c: Control, color: Color) -> void:
	var s := c.size
	var ctr := s * 0.5
	var ln := minf(s.x, s.y) * 0.5
	var th := ln * 0.22
	c.draw_rect(Rect2(ctr.x - th * 0.5, ctr.y - ln * 0.5, th, ln), color, true)
	c.draw_rect(Rect2(ctr.x - ln * 0.5, ctr.y - th * 0.5, ln, th), color, true)


func _make_glyph_badge(letter: String, color: Color) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(40, 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = letter
	l.add_theme_font_size_override("font_size", 24)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(l)
	return badge


# ---- Per-mode content ------------------------------------------------------

func _populate_mode(instant := false) -> void:
	# Background tint for this mode
	var grad := Gradient.new()
	grad.set_color(0, MODE_BG_TOP[_mode])
	grad.set_color(1, MODE_BG_BOTTOM[_mode])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	_bg.texture = tex
	_motif.queue_redraw()

	# Tabs highlight
	for i in _tab_labels.size():
		_tab_labels[i].modulate = Color(1, 1, 1) if i == _mode else Color(0.5, 0.5, 0.56)

	# Toggle button shows the OTHER mode
	var other := 1 - _mode
	_toggle_label.text = "Mode %s" % MODE_NAMES[other].capitalize()

	# Rebuild tiles
	for c in _row.get_children():
		c.queue_free()
	_tiles.clear()
	_tweens.clear()
	var items: Array = CONTENT[_mode].duplicate(true)
	# GAMING slot 0 reveals the inserted cartridge game (plug & play demo).
	if _mode == 0 and _cartridge_inserted:
		items[0] = CARTRIDGE_GAME.duplicate()
		items[0]["kind"] = "cartridge_in"
	for item in items:
		var tile := _make_tile(item)
		_row.add_child(tile)
		_tiles.append(tile)
		_tweens.append(null)

	_selected = 0
	_status.text = "‹ ›  Naviguer      A  Lancer      X  Mode      C  Cartouche (démo)"
	_status.modulate = Color(0.65, 0.62, 0.72)
	await get_tree().process_frame  # let layout settle so scale pivots are right
	_update_selection(instant)


func _icon_color(kind: String) -> Color:
	match kind:
		"cartridge", "cartridge_in": return AMBER
		"store": return Color(0.55, 0.56, 0.64)
		_: return MODE_ACCENTS[_mode]


func _make_tile(item: Dictionary) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = TILE_SIZE
	panel.pivot_offset = TILE_SIZE * 0.5

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var icon_wrap := CenterContainer.new()
	vb.add_child(icon_wrap)
	var is_cart_kind: bool = item.kind == "cartridge" or item.kind == "cartridge_in"
	var isz := Vector2(74, 98) if is_cart_kind else Vector2(96, 96)
	var icon := _make_icon(item.kind, _icon_color(item.kind), isz)
	icon_wrap.add_child(icon)

	var t := Label.new()
	t.text = item.title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.clip_text = true
	t.custom_minimum_size.x = TILE_SIZE.x - 24
	vb.add_child(t)

	var s := Label.new()
	s.text = item.sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 16)
	s.modulate = Color(0.70, 0.68, 0.76)
	vb.add_child(s)

	panel.set_meta("kind", item.kind)
	return panel


func _tile_style(is_selected: bool, is_cartridge: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.19, 0.27) if is_selected else Color(0.13, 0.13, 0.19)
	sb.set_corner_radius_all(26)
	var accent: Color = AMBER if is_cartridge else MODE_ACCENTS[_mode]
	sb.set_border_width_all(5 if is_selected else (2 if is_cartridge else 0))
	sb.border_color = accent if is_selected else Color(accent, 0.4)
	if is_selected:
		sb.shadow_color = Color(accent, 0.35)
		sb.shadow_size = 24
	return sb


func _update_selection(instant := false) -> void:
	for i in _tiles.size():
		var tile := _tiles[i]
		var on := (i == _selected)
		var k: String = tile.get_meta("kind")
		var is_cart: bool = k == "cartridge" or k == "cartridge_in"
		tile.add_theme_stylebox_override("panel", _tile_style(on, is_cart))
		tile.modulate = Color(1, 1, 1) if on else Color(0.82, 0.82, 0.86)

		var target := Vector2(1.12, 1.12) if on else Vector2(0.96, 0.96)
		if instant:
			tile.scale = target
			continue
		if _tweens[i] != null and _tweens[i].is_valid():
			_tweens[i].kill()
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "scale", target, 0.26)
		_tweens[i] = tw


# ---- Input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_cartridge"):
		_cartridge_inserted = not _cartridge_inserted
		if _mode == 0:
			_populate_mode()
		if _cartridge_inserted:
			_status.text = "Cartouche détectée : %s" % CARTRIDGE_GAME.title
			_status.modulate = AMBER
		else:
			_status.text = "Cartouche retirée"
			_status.modulate = Color(0.65, 0.62, 0.72)
	elif event.is_action_pressed("toggle_mode"):
		_mode = 1 - _mode
		_populate_mode()
	elif event.is_action_pressed("ui_right"):
		_selected = (_selected + 1) % _tiles.size()
		_update_selection()
	elif event.is_action_pressed("ui_left"):
		_selected = (_selected - 1 + _tiles.size()) % _tiles.size()
		_update_selection()
	elif event.is_action_pressed("ui_accept"):
		_activate(_selected)


func _activate(index: int) -> void:
	var item: Dictionary = CONTENT[_mode][index]
	_status.text = "→  %s" % item.title
	_status.modulate = MODE_ACCENTS[_mode]
	var tile := _tiles[index]
	if _tweens[index] != null and _tweens[index].is_valid():
		_tweens[index].kill()
	var tw := create_tween()
	tw.tween_property(tile, "scale", Vector2(1.0, 1.0), 0.08)
	tw.tween_property(tile, "scale", Vector2(1.12, 1.12), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens[index] = tw
