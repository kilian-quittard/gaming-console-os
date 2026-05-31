extends Control
## Gaming Console OS — home. Two content-first MODES, toggled with X.
## Theme: "Indie Playful". Decoupled front-end (launching is the OS session
## layer's job, kept out here so the front-end stays swappable).

const MODE_NAMES := ["GAMING", "TRAVAIL"]

# A theme = a [gaming, travail] palette set (accent + bg gradient). Switchable
# in Settings. Index 0 stays the original "Indie" look.
var THEMES := [
	{
		"name": "Indie",
		"accent": [Color(1.0, 0.45, 0.45), Color(0.18, 0.82, 0.71)],
		"bg_top": [Color(0.21, 0.11, 0.21), Color(0.08, 0.14, 0.20)],
		"bg_bottom": [Color(0.10, 0.07, 0.13), Color(0.05, 0.08, 0.13)],
	},
	{
		"name": "Spark",  # brand: bright sunshine — GAMING orange/coral vs TRAVAIL yellow/gold
		"accent": [Color(1.0, 0.52, 0.10), Color(1.0, 0.86, 0.16)],
		"bg_top": [Color(0.62, 0.30, 0.08), Color(0.66, 0.46, 0.10)],
		"bg_bottom": [Color(0.30, 0.13, 0.06), Color(0.32, 0.22, 0.07)],
		"light_tiles": true,
		"diag": true,
		"grad": [
			[Color(1.0, 0.62, 0.14), Color(0.97, 0.38, 0.12), Color(0.80, 0.18, 0.24)],  # GAMING — orange→coral→red
			[Color(1.0, 0.91, 0.34), Color(1.0, 0.74, 0.20), Color(0.97, 0.52, 0.12)],   # TRAVAIL — yellow→gold→orange
		],
	},
	{
		"name": "Ember",  # deeper warm: red-orange + amber gold
		"accent": [Color(0.97, 0.36, 0.26), Color(1.0, 0.68, 0.30)],
		"bg_top": [Color(0.18, 0.07, 0.07), Color(0.17, 0.11, 0.06)],
		"bg_bottom": [Color(0.08, 0.04, 0.04), Color(0.09, 0.06, 0.04)],
	},
]

const AMBER := Color(1.0, 0.74, 0.28)
const X_BLUE := Color(0.30, 0.55, 0.98)
const TILE_SIZE := Vector2(240, 268)
const VISIBLE_TILES := 4   # how many tiles fill the row at once (rest scroll in)
const ROW_SEP := 40
const GUTTER := 40         # inner side padding so a hovered edge tile isn't clipped

# Content per mode. kind drives the icon style. (All placeholders for now.)
const CONTENT := [
	[ # GAMING
		{"title": "CARTOUCHE", "sub": "Insérez une cartouche", "kind": "cartridge"},
		{"title": "Pixel Racer", "sub": "Digital", "kind": "game"},
		{"title": "Star Forge", "sub": "Digital", "kind": "game"},
		{"title": "Cave Dive", "sub": "Digital", "kind": "game"},
		{"title": "Neon Drift", "sub": "Digital", "kind": "game"},
		{"title": "Loop Hero+", "sub": "Digital", "kind": "game"},
		{"title": "Bit Brawl", "sub": "Digital", "kind": "game"},
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

const BRAND_NAME := "SPARK"
const BRAND_COLOR := Color(1.0, 0.55, 0.16)  # spark orange

const SETTINGS_KINDS := ["theme", "volume", "bright", "wifi", "account"]
const SETTINGS_LABELS := ["Thème", "Volume", "Luminosité", "Wi-Fi", "Compte"]
const SETTINGS_ACCENT := Color(0.30, 0.55, 0.98)

var _mode := 0
var _theme := 1
var _selected := 0
var _cartridge_inserted := false

# Screen-stack depth: home menu <-> preview/settings overlay
var _in_preview := false
var _preview_layer: Control = null
var _preview_item: Dictionary = {}

var _in_settings := false
var _settings_layer: Control = null
var _settings_sel := 0
var _settings_rows: Array = []  # built in _open_settings

# Settings state (placeholder values)
var _vol := 70
var _bright := 80
var _wifi := true

var _booting := true
var _wave_node: Control = null
var _wave_phase := 0.0
var _scroll: ScrollContainer = null
var _clock: Label = null
var _name_label: Label = null
var _brand_star: Control = null
var _brand_label: Label = null
var _arrow_left: Control = null
var _arrow_right: Control = null
var _scroll_tween: Tween = null
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
	_show_splash()


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

	# Top-center: brand logo (spark) + name
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 12)
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.set_anchors_preset(Control.PRESET_CENTER_TOP)
	brand.grow_horizontal = Control.GROW_DIRECTION_BOTH
	brand.offset_top = 40
	add_child(brand)
	_brand_star = Control.new()
	_brand_star.custom_minimum_size = Vector2(30, 30)
	_brand_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_brand_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand_star.draw.connect(func() -> void: _draw_brand_star(_brand_star))
	brand.add_child(_brand_star)
	_brand_label = Label.new()
	_brand_label.text = BRAND_NAME
	_brand_label.add_theme_font_size_override("font_size", 28)
	_brand_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand.add_child(_brand_label)

	# Top-right: contextual toggle button — badge + label inside one rounded
	# panel so it reads as a single cohesive button.
	var toggle_panel := PanelContainer.new()
	var tstyle := StyleBoxFlat.new()
	tstyle.bg_color = Color(0.98, 0.97, 0.96, 0.95)
	tstyle.set_corner_radius_all(16)
	tstyle.content_margin_left = 16
	tstyle.content_margin_right = 22
	tstyle.content_margin_top = 12
	tstyle.content_margin_bottom = 12
	tstyle.set_border_width_all(1)
	tstyle.border_color = Color(0, 0, 0, 0.10)
	toggle_panel.add_theme_stylebox_override("panel", tstyle)
	toggle_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toggle_panel.grow_vertical = Control.GROW_DIRECTION_END
	toggle_panel.offset_right = -48
	toggle_panel.offset_top = 110
	add_child(toggle_panel)

	var thb := HBoxContainer.new()
	thb.add_theme_constant_override("separation", 14)
	thb.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle_panel.add_child(thb)

	_toggle_badge = _make_glyph_badge("X", X_BLUE)
	thb.add_child(_toggle_badge)

	_toggle_label = Label.new()
	_toggle_label.add_theme_font_size_override("font_size", 26)
	_toggle_label.add_theme_color_override("font_color", Color(0.16, 0.14, 0.18))
	_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thb.add_child(_toggle_label)

	# Top-right corner: status bar (avatar, name, clock, network)
	var status_bar := HBoxContainer.new()
	status_bar.add_theme_constant_override("separation", 16)
	status_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	status_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	status_bar.offset_right = -48
	status_bar.offset_top = 46
	add_child(status_bar)

	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(40, 40)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var asb := StyleBoxFlat.new()
	asb.bg_color = X_BLUE
	asb.set_corner_radius_all(20)
	avatar.add_theme_stylebox_override("panel", asb)
	var ai := Label.new()
	ai.text = "K"
	ai.set_anchors_preset(Control.PRESET_FULL_RECT)
	ai.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ai.add_theme_font_size_override("font_size", 20)
	avatar.add_child(ai)
	status_bar.add_child(avatar)

	_name_label = Label.new()
	_name_label.text = "Joueur"
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_bar.add_child(_name_label)

	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 24)
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.modulate = Color(0.78, 0.76, 0.84)
	status_bar.add_child(_clock)

	var net := Panel.new()
	net.custom_minimum_size = Vector2(14, 14)
	net.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color(0.40, 0.82, 0.45)
	nsb.set_corner_radius_all(7)
	net.add_theme_stylebox_override("panel", nsb)
	status_bar.add_child(net)

	_update_clock()
	var ctimer := Timer.new()
	ctimer.wait_time = 10.0
	ctimer.autostart = true
	add_child(ctimer)
	ctimer.timeout.connect(_update_clock)

	# Center: horizontally-scrolling content row (scrollbar hidden)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Start below the top-right toggle button (avoids tiles covering it) and
	# leave enough height so the scaled selected tile isn't clipped at the top.
	_scroll.offset_top = 185
	_scroll.offset_bottom = -60
	_scroll.offset_left = 70
	_scroll.offset_right = -70
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", ROW_SEP)
	# Fill the viewport so the row centers when it fits, scrolls when it overflows.
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Taller than a tile so the scaled selected tile stays centered (no top clip).
	_row.custom_minimum_size.y = 340
	_scroll.add_child(_row)

	# Scroll affordance arrows in the side margins (shown when more to explore).
	_arrow_left = _make_arrow(true)
	_arrow_left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_arrow_left.offset_left = 8
	_arrow_left.offset_right = 8 + 60
	_arrow_left.offset_top = 185
	_arrow_left.offset_bottom = -60
	add_child(_arrow_left)

	_arrow_right = _make_arrow(false)
	_arrow_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_arrow_right.offset_right = -8
	_arrow_right.offset_left = -8 - 60
	_arrow_right.offset_top = 185
	_arrow_right.offset_bottom = -60
	add_child(_arrow_right)

	# Bottom hint bar: coloured button badges on a dark translucent pill so it
	# stays readable on any theme.
	var hintbar := PanelContainer.new()
	var hpill := StyleBoxFlat.new()
	hpill.bg_color = Color(0.0, 0.0, 0.0, 0.36)
	hpill.set_corner_radius_all(22)
	hpill.content_margin_left = 24
	hpill.content_margin_right = 24
	hpill.content_margin_top = 9
	hpill.content_margin_bottom = 9
	hintbar.add_theme_stylebox_override("panel", hpill)
	hintbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hintbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hintbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hintbar.offset_bottom = -26
	add_child(hintbar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hintbar.add_child(hbox)

	var green := Color(0.40, 0.80, 0.45)
	var yellow := Color(0.97, 0.82, 0.22)
	var grey := Color(0.55, 0.56, 0.64)
	var navc := Color(0.62, 0.64, 0.72)
	var hints := [
		{"g": "‹›", "c": navc, "w": 44.0, "t": "Naviguer"},
		{"g": "A", "c": green, "w": 30.0, "t": "Lancer"},
		{"g": "Y", "c": yellow, "w": 30.0, "t": "Aperçu"},
		{"g": "X", "c": X_BLUE, "w": 30.0, "t": "Mode"},
		{"g": "S", "c": grey, "w": 30.0, "t": "Réglages"},
		{"g": "C", "c": grey, "w": 30.0, "t": "Cartouche"},
	]
	for it in hints:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 7)
		cell.add_child(_make_glyph_badge(it["g"], it["c"], it["w"], 30.0, 17))
		var l := Label.new()
		l.text = it["t"]
		l.add_theme_font_size_override("font_size", 18)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(l)
		hbox.add_child(cell)

	# Transient feedback label (launch / cartridge messages), above the hint bar.
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 20)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -120
	_status.offset_bottom = -90
	add_child(_status)


func _make_arrow(left: bool) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	c.draw.connect(func() -> void: _draw_arrow(c, left))
	return c


func _draw_arrow(c: Control, left: bool) -> void:
	var ctr := Vector2(c.size.x * 0.5, c.size.y * 0.5)
	# Circular backing so the arrow pops against any tile/background.
	c.draw_circle(ctr, 28.0, Color(0.0, 0.0, 0.0, 0.45))
	c.draw_arc(ctr, 28.0, 0.0, TAU, 40, Color(1, 1, 1, 0.22), 2.0)
	var w := 16.0
	var h := 30.0
	var col := Color(1, 1, 1, 0.92)
	if left:
		c.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(w * 0.45, -h * 0.5), ctr + Vector2(w * 0.45, h * 0.5), ctr + Vector2(-w * 0.55, 0),
		]), col)
	else:
		c.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(-w * 0.45, -h * 0.5), ctr + Vector2(-w * 0.45, h * 0.5), ctr + Vector2(w * 0.55, 0),
		]), col)


func _make_gutter() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(GUTTER, 0)
	return c


func _process(delta: float) -> void:
	if _wave_node != null and is_instance_valid(_wave_node):
		_wave_phase += delta * 1.7
		_wave_node.queue_redraw()


func _draw_waves(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var layers := [
		{"base": h * 0.66, "amp": 36.0, "freq": 0.0055, "sp": 0.6, "col": Color(1.0, 0.90, 0.45, 0.55)},
		{"base": h * 0.74, "amp": 30.0, "freq": 0.0075, "sp": 0.95, "col": Color(1.0, 0.68, 0.22, 0.60)},
		{"base": h * 0.82, "amp": 24.0, "freq": 0.0105, "sp": 1.35, "col": Color(0.93, 0.44, 0.12, 0.72)},
	]
	for L in layers:
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= w:
			pts.append(Vector2(x, L["base"] + sin(x * L["freq"] + _wave_phase * L["sp"]) * L["amp"]))
			x += 14.0
		pts.append(Vector2(w, h))
		pts.append(Vector2(0.0, h))
		c.draw_colored_polygon(pts, L["col"])


func _sparkle_points(ctr: Vector2, long: float, short: float, inner: float) -> PackedVector2Array:
	# 16 vertices: long cardinal arms + short diagonal arms, concave dips between.
	var pts := PackedVector2Array()
	for i in 16:
		var ang := deg_to_rad(-90.0 + i * 22.5)
		var r: float
		if i % 2 == 1:
			r = inner
		elif (i / 2) % 2 == 0:
			r = long
		else:
			r = short
		pts.append(ctr + Vector2(cos(ang), sin(ang)) * r)
	return pts


func _draw_brand_star(c: Control) -> void:
	var ctr := c.size * 0.5
	var outer := 15.0
	var inner := 5.0
	var pts := PackedVector2Array()
	for i in 8:
		var ang := deg_to_rad(-90.0 + i * 45.0)
		var r := outer if i % 2 == 0 else inner
		pts.append(ctr + Vector2(cos(ang), sin(ang)) * r)
	c.draw_colored_polygon(pts, Color(1, 1, 1))  # white; tinted via modulate per theme


func _draw_spark(c: Control) -> void:
	var ctr := c.size * 0.5
	# dark medallion so the spark pops on the bright splash
	c.draw_circle(ctr, 54.0, Color(0.20, 0.08, 0.02, 0.92))
	# main sparkle (bright gold) + small accent sparkle
	c.draw_colored_polygon(_sparkle_points(ctr, 40.0, 19.0, 7.0), Color(1.0, 0.82, 0.28))
	c.draw_colored_polygon(_sparkle_points(ctr + Vector2(26, -22), 11.0, 5.0, 2.0), Color(1.0, 0.90, 0.45))


func _show_splash() -> void:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layer)

	# Bright warm diagonal gradient background (brand colours)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.74, 0.30))
	grad.set_color(1, Color(0.95, 0.42, 0.14))
	grad.add_point(0.5, Color(1.0, 0.56, 0.18))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(1, 1)
	var bg := TextureRect.new()
	bg.texture = gtex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	# Animated warm waves at the bottom
	_wave_phase = 0.0
	_wave_node = Control.new()
	_wave_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wave_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_node.draw.connect(func() -> void: _draw_waves(_wave_node))
	layer.add_child(_wave_node)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	center.add_child(vb)

	var spark := Control.new()
	spark.custom_minimum_size = Vector2(96, 96)
	spark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spark.modulate = Color(1, 1, 1, 0)
	spark.draw.connect(func() -> void: _draw_spark(spark))
	vb.add_child(spark)

	var title := Label.new()
	title.text = BRAND_NAME
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.30, 0.11, 0.03))  # dark on bright bg
	title.modulate = Color(1, 1, 1, 0)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "PLAY · CREATE"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.modulate = Color(0.46, 0.16, 0.03, 0.0)
	vb.add_child(sub)

	var barbg := Panel.new()
	barbg.custom_minimum_size = Vector2(300, 8)
	barbg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.30, 0.14, 0.05, 0.45)
	bs.set_corner_radius_all(4)
	barbg.add_theme_stylebox_override("panel", bs)
	vb.add_child(barbg)
	var fill := Panel.new()
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_right = 0.0
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.55, 0.20, 0.04)
	fsb.set_corner_radius_all(4)
	fill.add_theme_stylebox_override("panel", fsb)
	barbg.add_child(fill)

	var tw := create_tween()
	tw.tween_property(spark, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(title, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.4)
	tw.tween_property(fill, "anchor_right", 1.0, 0.85)
	tw.tween_interval(0.2)
	tw.tween_property(layer, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		layer.queue_free()
		_wave_node = null
		_booting = false
	)


func _play_insert_anim() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if _tiles.is_empty():
		return
	var t := _tiles[0]
	if _tweens.size() > 0 and _tweens[0] != null and _tweens[0].is_valid():
		_tweens[0].kill()
	t.scale = Vector2(0.7, 0.7)
	t.modulate = Color(1.7, 1.7, 1.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(t, "scale", Vector2(1.08, 1.08), 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate", Color(1, 1, 1), 0.5)
	_tweens[0] = tw


func _update_clock() -> void:
	if _clock == null:
		return
	var t := Time.get_time_dict_from_system()
	_clock.text = "%02d:%02d" % [t.hour, t.minute]


func _draw_motif() -> void:
	var sz := _motif.size
	var col: Color = _accent(_mode)
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


func _make_glyph_badge(letter: String, color: Color, w := 40.0, h := 40.0, font := 24) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(w, h)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(9)
	badge.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = letter
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(l)
	return badge


# ---- Per-mode content ------------------------------------------------------

func _populate_mode(instant := false) -> void:
	# Background tint for this mode
	var th: Dictionary = THEMES[_theme]
	var grad := Gradient.new()
	var tex := GradientTexture2D.new()
	if th.has("grad"):
		var cols: Array = th["grad"][_mode]
		grad.set_color(0, cols[0])
		grad.set_color(1, cols[cols.size() - 1])
		for i in range(1, cols.size() - 1):
			grad.add_point(float(i) / float(cols.size() - 1), cols[i])
	else:
		grad.set_color(0, _bg_top(_mode))
		grad.set_color(1, _bg_bottom(_mode))
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 1) if th.get("diag", false) else Vector2(0, 1)
	_bg.texture = tex
	_motif.queue_redraw()

	# Chrome text adapts to bright (light-tile) themes for readability.
	var ct: Color = Color(0.16, 0.11, 0.06) if _light_tiles() else Color(1, 1, 1)
	for i in _tab_labels.size():
		_tab_labels[i].add_theme_color_override("font_color", ct)
		_tab_labels[i].modulate = Color(1, 1, 1) if i == _mode else Color(1, 1, 1, 0.45)
	if _name_label:
		_name_label.add_theme_color_override("font_color", ct)
	if _clock:
		_clock.add_theme_color_override("font_color", ct)
		_clock.modulate = Color(1, 1, 1, 0.85)
	if _brand_label:
		_brand_label.add_theme_color_override("font_color", ct)
	if _brand_star:
		_brand_star.modulate = ct

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
	_row.add_child(_make_gutter())  # leading padding so edge tile isn't clipped
	for item in items:
		var tile := _make_tile(item)
		_row.add_child(tile)
		_tiles.append(tile)
		_tweens.append(null)
	_row.add_child(_make_gutter())  # trailing padding
	if _scroll:
		_scroll.scroll_horizontal = 0

	_selected = 0
	_status.text = ""
	await get_tree().process_frame  # let layout settle so we know the row width
	_size_tiles_to_fit()
	await get_tree().process_frame  # let the resize settle before scaling
	_update_selection(instant)


# Size tiles so exactly VISIBLE_TILES fill the row width (no partial tiles at
# the edges); extra tiles scroll in one full tile at a time.
func _size_tiles_to_fit() -> void:
	if _scroll == null or _tiles.is_empty():
		return
	var avail := _scroll.size.x
	var tw := (avail - 2 * GUTTER - (VISIBLE_TILES - 1) * ROW_SEP) / float(VISIBLE_TILES)
	tw = maxf(tw, 160.0)
	for tile in _tiles:
		tile.custom_minimum_size.x = tw
		tile.pivot_offset = Vector2(tw, TILE_SIZE.y) * 0.5


func _accent(mode: int) -> Color:
	return THEMES[_theme]["accent"][mode]


func _light_tiles() -> bool:
	return THEMES[_theme].get("light_tiles", false)


func _bg_top(mode: int) -> Color:
	return THEMES[_theme]["bg_top"][mode]


func _bg_bottom(mode: int) -> Color:
	return THEMES[_theme]["bg_bottom"][mode]


func _icon_color(kind: String) -> Color:
	match kind:
		"cartridge", "cartridge_in": return AMBER
		"store": return Color(0.55, 0.56, 0.64)
		_: return _accent(_mode)


func _make_tile(item: Dictionary) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = TILE_SIZE
	panel.pivot_offset = TILE_SIZE * 0.5
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # stay centered in scroll band

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var light := _light_tiles()
	var icon_wrap := CenterContainer.new()
	vb.add_child(icon_wrap)
	var is_cart_kind: bool = item.kind == "cartridge" or item.kind == "cartridge_in"
	var isz := Vector2(74, 98) if is_cart_kind else Vector2(96, 96)
	var icol := _icon_color(item.kind)
	if light and item.kind != "store":
		icol = icol.darkened(0.18)  # keep contrast on the light tile
	var icon := _make_icon(item.kind, icol, isz)
	icon_wrap.add_child(icon)

	var t := Label.new()
	t.text = item.title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	# Hard guarantee the title can never overflow the tile: clip + ellipsis,
	# width pinned to the tile, no horizontal expand.
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size.x = TILE_SIZE.x - 28
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if light:
		t.add_theme_color_override("font_color", Color(0.13, 0.11, 0.12))
	vb.add_child(t)

	var s := Label.new()
	s.text = item.sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 16)
	s.modulate = Color(0.38, 0.36, 0.40) if light else Color(0.70, 0.68, 0.76)
	vb.add_child(s)

	panel.set_meta("kind", item.kind)
	return panel


func _tile_style(is_selected: bool, is_cartridge: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var accent: Color = AMBER if is_cartridge else _accent(_mode)
	if _light_tiles():
		sb.bg_color = Color(1, 1, 1) if is_selected else Color(0.96, 0.94, 0.91)
	else:
		sb.bg_color = Color(0.20, 0.19, 0.27) if is_selected else Color(0.13, 0.13, 0.19)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(5 if is_selected else (2 if is_cartridge else 0))
	sb.border_color = accent if is_selected else Color(accent, 0.4)
	if is_selected:
		sb.shadow_color = Color(accent, 0.5 if _light_tiles() else 0.35)
		sb.shadow_size = 20
	return sb


func _update_selection(instant := false) -> void:
	for i in _tiles.size():
		var tile := _tiles[i]
		var on := (i == _selected)
		var k: String = tile.get_meta("kind")
		var is_cart: bool = k == "cartridge" or k == "cartridge_in"
		tile.add_theme_stylebox_override("panel", _tile_style(on, is_cart))
		var dim: Color = Color(0.93, 0.93, 0.94) if _light_tiles() else Color(0.82, 0.82, 0.86)
		tile.modulate = Color(1, 1, 1) if on else dim

		var target := Vector2(1.08, 1.08) if on else Vector2(0.95, 0.95)
		if instant:
			tile.scale = target
			continue
		if _tweens[i] != null and _tweens[i].is_valid():
			_tweens[i].kill()
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "scale", target, 0.26)
		_tweens[i] = tw

	_update_scroll_and_arrows()


# Scroll so the selected tile keeps a GUTTER margin from both edges (never
# clipped when hovered/scaled), and toggle the left/right "more" arrows.
func _update_scroll_and_arrows() -> void:
	if _scroll == null or _selected >= _tiles.size():
		return
	var tile := _tiles[_selected]
	var view_w := _scroll.size.x
	var max_scroll := maxf(_row.size.x - view_w, 0.0)
	var sx := float(_scroll.scroll_horizontal)
	var tleft := tile.position.x
	var tright := tile.position.x + tile.size.x
	if tleft - GUTTER < sx:
		sx = tleft - GUTTER
	elif tright + GUTTER > sx + view_w:
		sx = tright + GUTTER - view_w
	sx = clampf(sx, 0.0, max_scroll)

	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(_scroll, "scroll_horizontal", int(round(sx)), 0.18)

	# EPS avoids spurious arrows from sub-pixel rounding when the row fits.
	var eps := 8.0
	if _arrow_left:
		_arrow_left.visible = sx > eps
	if _arrow_right:
		_arrow_right.visible = max_scroll > eps and sx < max_scroll - eps


# ---- Input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _booting:
		return  # ignore input during the boot splash

	# Preview overlay captures input while open: A launches, B closes.
	if _in_preview:
		if event.is_action_pressed("ui_cancel"):
			_close_preview()
		elif event.is_action_pressed("ui_accept"):
			_preview_launch()
		return

	# Settings overlay: up/down navigate, left/right adjust, A toggle, B close.
	if _in_settings:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("settings"):
			_close_settings()
		elif event.is_action_pressed("ui_down"):
			_settings_sel = (_settings_sel + 1) % SETTINGS_KINDS.size()
			_refresh_settings()
		elif event.is_action_pressed("ui_up"):
			_settings_sel = (_settings_sel - 1 + SETTINGS_KINDS.size()) % SETTINGS_KINDS.size()
			_refresh_settings()
		elif event.is_action_pressed("ui_right"):
			_settings_adjust(1)
		elif event.is_action_pressed("ui_left"):
			_settings_adjust(-1)
		elif event.is_action_pressed("ui_accept"):
			_settings_activate()
		return

	if event.is_action_pressed("settings"):
		_open_settings()
	elif event.is_action_pressed("toggle_cartridge"):
		_cartridge_inserted = not _cartridge_inserted
		if _mode == 0:
			_populate_mode()
		if _cartridge_inserted:
			_status.text = "Cartouche détectée : %s" % CARTRIDGE_GAME.title
			_status.modulate = AMBER
			if _mode == 0:
				_play_insert_anim()
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
	elif event.is_action_pressed("preview"):
		_preview_selected()
	elif event.is_action_pressed("ui_accept"):
		_launch_selected()


# Resolve the selected item (GAMING slot 0 may be the inserted cartridge game).
func _resolve_item(index: int) -> Dictionary:
	var item: Dictionary = CONTENT[_mode][index].duplicate(true)
	if _mode == 0 and index == 0 and _cartridge_inserted:
		item = CARTRIDGE_GAME.duplicate()
		item["kind"] = "cartridge_in"
	return item


func _bounce(index: int) -> void:
	var tile := _tiles[index]
	if _tweens[index] != null and _tweens[index].is_valid():
		_tweens[index].kill()
	var tw := create_tween()
	tw.tween_property(tile, "scale", Vector2(1.02, 1.02), 0.07)
	tw.tween_property(tile, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens[index] = tw


# A — launch directly (no detail hop).
func _launch_selected() -> void:
	_bounce(_selected)
	var item := _resolve_item(_selected)
	if _action_label(item) == "":
		_status.text = "Insérez une cartouche"
		_status.modulate = AMBER
		return
	_status.text = "→  %s  (lancement à câbler)" % item.title
	_status.modulate = _icon_color(item.kind)


# Y — open the media preview.
func _preview_selected() -> void:
	var item := _resolve_item(_selected)
	if item.kind == "cartridge":
		_status.text = "Insérez une cartouche"
		_status.modulate = AMBER
		return
	_open_preview(item)


# ---- Preview overlay (media) -----------------------------------------------

func _desc_for(item: Dictionary) -> String:
	match item.kind:
		"cartridge": return "Insérez une cartouche dans la fente pour révéler et lancer le jeu (plug & play)."
		"cartridge_in", "game": return "Jeu indé. Appuyez sur Jouer pour lancer."
		"forge": return "Ouvre l'éditeur Godot pour créer tes propres jeux."
		"pixel": return "Éditeur de pixel art pour tes sprites et tilesets."
		"web": return "Navigateur en mode kiosque pour la documentation."
		"store": return "Parcours le catalogue indé et l'abonnement."
		_: return ""


func _action_label(item: Dictionary) -> String:
	match item.kind:
		"cartridge": return ""  # nothing to launch on an empty slot
		"game", "cartridge_in": return "Jouer"
		"store": return "Voir le catalogue"
		_: return "Ouvrir"


func _hint_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.modulate = Color(0.65, 0.62, 0.72)
	return l


func _star5_points(ctr: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := deg_to_rad(-90.0 + i * 36.0)
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(ctr + Vector2(cos(ang), sin(ang)) * rr)
	return pts


func _make_rating(value: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(5 * 24, 22)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var gold := Color(1.0, 0.78, 0.20)
		var empty := Color(0.55, 0.55, 0.60, 0.45)
		for i in 5:
			var ctr := Vector2(11 + i * 24, c.size.y * 0.5)
			var col := empty
			if i < int(floor(value)):
				col = gold
			elif value - i >= 0.5:
				col = Color(1.0, 0.78, 0.20, 0.55)
			c.draw_colored_polygon(_star5_points(ctr, 9.0), col)
	)
	return c


func _make_comment(author: String, text: String, light: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.91, 0.87) if light else Color(0.16, 0.16, 0.22)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	card.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 11)
	card.add_child(hb)

	var palette := [Color(1.0, 0.55, 0.30), Color(0.45, 0.70, 1.0), Color(0.55, 0.80, 0.50), Color(0.85, 0.55, 0.95)]
	var av := Panel.new()
	av.custom_minimum_size = Vector2(38, 38)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var asb := StyleBoxFlat.new()
	asb.bg_color = palette[abs(author.hash()) % palette.size()]
	asb.set_corner_radius_all(19)
	av.add_theme_stylebox_override("panel", asb)
	var ai := Label.new()
	ai.text = author.substr(0, 1).to_upper()
	ai.set_anchors_preset(Control.PRESET_FULL_RECT)
	ai.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ai.add_theme_color_override("font_color", Color(1, 1, 1))
	av.add_child(ai)
	hb.add_child(av)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var nm := Label.new()
	nm.text = author
	nm.add_theme_font_size_override("font_size", 16)
	nm.add_theme_color_override("font_color", Color(0.20, 0.16, 0.12) if light else Color(0.95, 0.93, 0.80))
	col.add_child(nm)
	var tx := Label.new()
	tx.text = text
	tx.add_theme_font_size_override("font_size", 17)
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.add_theme_color_override("font_color", Color(0.30, 0.27, 0.30) if light else Color(0.80, 0.80, 0.85))
	col.add_child(tx)
	return card


func _open_preview(item: Dictionary) -> void:
	_in_preview = true
	_preview_item = item
	var accent: Color = _icon_color(item.kind)
	var light := _light_tiles()
	var is_game: bool = item.kind == "game" or item.kind == "cartridge_in"
	var txt: Color = Color(0.14, 0.11, 0.10) if light else Color(0.95, 0.95, 0.97)
	var muted: Color = Color(0.42, 0.40, 0.44) if light else Color(0.72, 0.70, 0.78)

	_preview_layer = Control.new()
	_preview_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_layer.modulate = Color(1, 1, 1, 0)
	add_child(_preview_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.06, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_layer.add_child(center)

	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.97, 0.95, 0.92) if light else Color(0.12, 0.12, 0.18)
	cs.set_corner_radius_all(24)
	cs.content_margin_left = 40
	cs.content_margin_right = 40
	cs.content_margin_top = 30
	cs.content_margin_bottom = 26
	cs.set_border_width_all(3)
	cs.border_color = accent
	cs.shadow_color = Color(accent, 0.30)
	cs.shadow_size = 26
	card.add_theme_stylebox_override("panel", cs)
	if is_game:
		card.custom_minimum_size = Vector2(900, 0)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	var al := _action_label(item)

	if not is_game:
		# Simple page for FORGE / apps / store: icon + title + desc + action.
		var iw := CenterContainer.new()
		vb.add_child(iw)
		iw.add_child(_make_icon(item.kind, accent if not light else accent.darkened(0.18), Vector2(120, 120)))
		var st := Label.new()
		st.text = item.title
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.add_theme_font_size_override("font_size", 38)
		st.add_theme_color_override("font_color", txt)
		vb.add_child(st)
		var sd := Label.new()
		sd.text = _desc_for(item)
		sd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sd.add_theme_font_size_override("font_size", 18)
		sd.add_theme_color_override("font_color", muted)
		sd.custom_minimum_size.x = 460
		vb.add_child(sd)
		if al != "":
			vb.add_child(_make_play_button(al, accent))
		vb.add_child(_make_preview_hints(al))
		var tw0 := create_tween()
		tw0.tween_property(_preview_layer, "modulate:a", 1.0, 0.18)
		return

	# --- Enriched game page: two columns ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 26)
	vb.add_child(top)

	# Left column: media + thumbnails
	var leftc := VBoxContainer.new()
	leftc.add_theme_constant_override("separation", 10)
	top.add_child(leftc)

	var media := Panel.new()
	media.custom_minimum_size = Vector2(380, 214)
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.09, 0.08, 0.11)
	msb.set_corner_radius_all(14)
	media.add_theme_stylebox_override("panel", msb)
	leftc.add_child(media)
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.draw.connect(func() -> void:
		var c := ov.size * 0.5
		c.y -= 12.0
		ov.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-20, -26), c + Vector2(-20, 26), c + Vector2(32, 0),
		]), Color(1, 1, 1, 0.85))
	)
	media.add_child(ov)
	var mlabel := Label.new()
	mlabel.text = "Bande-annonce"
	mlabel.add_theme_font_size_override("font_size", 15)
	mlabel.modulate = Color(1, 1, 1, 0.55)
	mlabel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mlabel.offset_left = 16
	mlabel.offset_top = -30
	mlabel.offset_bottom = -8
	media.add_child(mlabel)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 10)
	leftc.add_child(strip)
	var thumbs: Array[Panel] = []
	for i in 4:
		var tp := Panel.new()
		tp.custom_minimum_size = Vector2(86, 50)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(accent, 0.22)
		tsb.set_corner_radius_all(9)
		tp.add_theme_stylebox_override("panel", tsb)
		strip.add_child(tp)
		thumbs.append(tp)
	var frame := [0]
	var timer := Timer.new()
	timer.wait_time = 0.9
	timer.autostart = true
	_preview_layer.add_child(timer)
	timer.timeout.connect(func() -> void:
		frame[0] = (frame[0] + 1) % thumbs.size()
		for i in thumbs.size():
			var t2 := StyleBoxFlat.new()
			t2.set_corner_radius_all(9)
			if i == frame[0]:
				t2.bg_color = Color(accent, 0.6)
				t2.set_border_width_all(2)
				t2.border_color = accent
			else:
				t2.bg_color = Color(accent, 0.22)
			thumbs[i].add_theme_stylebox_override("panel", t2)
	)

	# Right column: title, rating, meta, desc, play
	var rightc := VBoxContainer.new()
	rightc.add_theme_constant_override("separation", 10)
	rightc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rightc)

	var t := Label.new()
	t.text = item.title
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", txt)
	rightc.add_child(t)

	var rating := 4.0 + float(abs(item.title.hash()) % 11) / 10.0  # 4.0–5.0
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 10)
	rightc.add_child(rrow)
	rrow.add_child(_make_rating(rating))
	var rl := Label.new()
	rl.text = "%.1f" % rating
	rl.add_theme_font_size_override("font_size", 18)
	rl.add_theme_color_override("font_color", muted)
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rrow.add_child(rl)

	var genres := ["Action", "Aventure", "Plateforme", "Rogue-lite", "Puzzle"]
	var meta := Label.new()
	meta.text = "Indé · %s   ·   %.1f Go" % [genres[abs(item.title.hash()) % genres.size()], 0.6 + float(abs(item.title.hash()) % 35) / 10.0]
	meta.add_theme_font_size_override("font_size", 17)
	meta.add_theme_color_override("font_color", muted)
	rightc.add_child(meta)

	var d := Label.new()
	d.text = _desc_for(item)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 17)
	d.add_theme_color_override("font_color", muted)
	d.custom_minimum_size.x = 360
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rightc.add_child(d)

	if al != "":
		rightc.add_child(_make_play_button(al, accent))

	# --- Community comments (Miiverse-style) ---
	var clabel := Label.new()
	clabel.text = "✦  Communauté"
	clabel.add_theme_font_size_override("font_size", 20)
	clabel.add_theme_color_override("font_color", txt)
	vb.add_child(clabel)

	var comments := [
		{"n": "Kiki", "t": "Le pixel art est magnifique, gros coup de cœur."},
		{"n": "Léo", "t": "Boss final corsé mais super satisfaisant."},
		{"n": "Mina", "t": "Mon indé de l'année, sans hésiter."},
	]
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 14)
	vb.add_child(crow)
	for cm in comments:
		crow.add_child(_make_comment(cm["n"], cm["t"], light))

	vb.add_child(_make_preview_hints(al))

	var tw := create_tween()
	tw.tween_property(_preview_layer, "modulate:a", 1.0, 0.18)


func _make_play_button(label: String, accent: Color) -> CenterContainer:
	var wrap := CenterContainer.new()
	var btn := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = accent
	bs.set_corner_radius_all(14)
	bs.content_margin_left = 40
	bs.content_margin_right = 40
	bs.content_margin_top = 11
	bs.content_margin_bottom = 11
	btn.add_theme_stylebox_override("panel", bs)
	var bl := Label.new()
	bl.text = label
	bl.add_theme_font_size_override("font_size", 24)
	bl.add_theme_color_override("font_color", Color(0.10, 0.08, 0.05))
	btn.add_child(bl)
	wrap.add_child(btn)
	return wrap


func _make_preview_hints(al: String) -> HBoxContainer:
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 12)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	if al != "":
		hint.add_child(_make_glyph_badge("A", Color(0.45, 0.80, 0.48)))
		hint.add_child(_hint_label(al + "      "))
	hint.add_child(_make_glyph_badge("B", Color(0.90, 0.36, 0.36)))
	hint.add_child(_hint_label("Retour"))
	return hint


func _preview_launch() -> void:
	if _action_label(_preview_item) == "":
		return
	# Placeholder: real launch is the OS session layer's job (Phase 5).
	_status.text = "→  %s  (lancement à câbler)" % _preview_item.title
	_status.modulate = _icon_color(_preview_item.kind)
	_close_preview()


func _close_preview() -> void:
	if _preview_layer == null:
		return
	var layer := _preview_layer
	_preview_layer = null
	_in_preview = false
	var tw := create_tween()
	tw.tween_property(layer, "modulate:a", 0.0, 0.14)
	tw.tween_callback(layer.queue_free)


# ---- Settings overlay ------------------------------------------------------

func _open_settings() -> void:
	_in_settings = true
	_settings_sel = 0

	_settings_layer = Control.new()
	_settings_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_layer.modulate = Color(1, 1, 1, 0)
	add_child(_settings_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.06, 0.85)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_layer.add_child(center)

	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.12, 0.12, 0.18)
	cs.set_corner_radius_all(24)
	cs.content_margin_left = 44
	cs.content_margin_right = 44
	cs.content_margin_top = 34
	cs.content_margin_bottom = 30
	cs.set_border_width_all(3)
	cs.border_color = SETTINGS_ACCENT
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var title := Label.new()
	title.text = "Réglages"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vb.add_child(title)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.name = "rows"
	vb.add_child(rows)

	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 12)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hint)
	hint.add_child(_hint_label("‹ ›  Régler        "))
	hint.add_child(_make_glyph_badge("B", Color(0.90, 0.36, 0.36)))
	hint.add_child(_hint_label("Fermer"))

	_refresh_settings()

	var tw := create_tween()
	tw.tween_property(_settings_layer, "modulate:a", 1.0, 0.18)


func _refresh_settings() -> void:
	if _settings_layer == null:
		return
	var rows := _settings_layer.find_child("rows", true, false) as VBoxContainer
	if rows == null:
		return
	for c in rows.get_children():
		c.queue_free()
	for i in SETTINGS_KINDS.size():
		rows.add_child(_make_settings_row(i))


func _make_settings_row(i: int) -> PanelContainer:
	var on := (i == _settings_sel)
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.19, 0.27) if on else Color(0.10, 0.10, 0.15)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.set_border_width_all(2 if on else 0)
	sb.border_color = SETTINGS_ACCENT
	row.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	row.add_child(hb)

	var lbl := Label.new()
	lbl.text = SETTINGS_LABELS[i]
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(lbl)

	match SETTINGS_KINDS[i]:
		"theme":
			var v := _value_label("‹ %s ›" % THEMES[_theme]["name"])
			v.modulate = THEMES[_theme]["accent"][0]
			hb.add_child(v)
		"volume":
			hb.add_child(_make_bar(_vol))
			hb.add_child(_value_label("%d%%" % _vol))
		"bright":
			hb.add_child(_make_bar(_bright))
			hb.add_child(_value_label("%d%%" % _bright))
		"wifi":
			var v := _value_label("Activé" if _wifi else "Désactivé")
			v.modulate = Color(0.45, 0.82, 0.48) if _wifi else Color(0.7, 0.7, 0.75)
			hb.add_child(v)
		"account":
			hb.add_child(_value_label("Joueur"))
	return row


func _value_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _make_bar(value: int) -> Control:
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(180, 12)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.25, 0.25, 0.32)
	bgs.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", bgs)
	var fill := Panel.new()
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(value / 100.0, 0.0, 1.0)
	var fs := StyleBoxFlat.new()
	fs.bg_color = SETTINGS_ACCENT
	fs.set_corner_radius_all(6)
	fill.add_theme_stylebox_override("panel", fs)
	bg.add_child(fill)
	return bg


func _settings_adjust(dir: int) -> void:
	match SETTINGS_KINDS[_settings_sel]:
		"theme":
			_theme = (_theme + dir + THEMES.size()) % THEMES.size()
			_populate_mode()  # re-apply palette to the live home behind
		"volume": _vol = clampi(_vol + dir * 5, 0, 100)
		"bright": _bright = clampi(_bright + dir * 5, 0, 100)
		"wifi": _wifi = not _wifi
	_refresh_settings()


func _settings_activate() -> void:
	match SETTINGS_KINDS[_settings_sel]:
		"theme": _settings_adjust(1)
		"wifi":
			_wifi = not _wifi
			_refresh_settings()


func _close_settings() -> void:
	if _settings_layer == null:
		return
	var layer := _settings_layer
	_settings_layer = null
	_in_settings = false
	var tw := create_tween()
	tw.tween_property(layer, "modulate:a", 0.0, 0.14)
	tw.tween_callback(layer.queue_free)
