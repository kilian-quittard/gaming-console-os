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
		{"title": "Pixel Art", "sub": "Éditeur", "kind": "app"},
		{"title": "Docs Web", "sub": "Navigateur", "kind": "app"},
		{"title": "Store", "sub": "Ajouter", "kind": "store"},
	],
]

var _mode := 0
var _selected := 0
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
	_status.text = "‹  ›   Naviguer        A   Lancer"
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
	var items: Array = CONTENT[_mode]
	for item in items:
		var tile := _make_tile(item)
		_row.add_child(tile)
		_tiles.append(tile)
		_tweens.append(null)

	_selected = 0
	_status.text = "‹  ›   Naviguer        A   Lancer"
	_status.modulate = Color(0.65, 0.62, 0.72)
	await get_tree().process_frame  # let layout settle so scale pivots are right
	_update_selection(instant)


func _icon_color(kind: String) -> Color:
	match kind:
		"cartridge": return AMBER
		"store": return Color(0.45, 0.46, 0.55)
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
	var icon := Panel.new()
	# Cartridge icon is tall (cartridge-shaped); others are square-ish
	icon.custom_minimum_size = Vector2(70, 96) if item.kind == "cartridge" else Vector2(92, 92)
	var istyle := StyleBoxFlat.new()
	istyle.bg_color = _icon_color(item.kind)
	istyle.set_corner_radius_all(14)
	if item.kind == "store":
		# hollow look for the "+" store tile
		istyle.bg_color = Color(0.16, 0.16, 0.22)
		istyle.set_border_width_all(3)
		istyle.border_color = Color(0.45, 0.46, 0.55)
	icon.add_theme_stylebox_override("panel", istyle)
	icon_wrap.add_child(icon)

	var t := Label.new()
	t.text = item.title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
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
		var is_cart: bool = tile.get_meta("kind") == "cartridge"
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
	if event.is_action_pressed("toggle_mode"):
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
