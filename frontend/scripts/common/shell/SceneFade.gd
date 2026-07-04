extends RefCounted
class_name SceneFade
# TRANSITIONS du shell — sobres et propres.
# swap() : cross-fade doux avec micro-zoom (façon consoles modernes) — l'écran
#   courant est capturé, la scène change dessous, la capture fond en bougeant
#   à peine (±3 %). Aucun écran noir, aucun effet gadget.
# run()  : fondu noir simple (fallback / cas génériques).

static var _busy := false   # anti double-déclenchement (spam HOME/A)


# ZOOM TUILE, version propre : zoom UNIFORME (aucun étirement), pivot au centre
# de la tuile. entering=true : home → app, on plonge DANS la tuile. entering=false :
# app → home, l'app se rétracte dans sa tuile. Fallback cross-fade si tuile inconnue.
static func zoom(tree: SceneTree, switch: Callable, tile: Rect2, entering: bool, dur := 0.3) -> void:
	if _busy:
		return
	if tile.size.x < 1.0 or tile.size.y < 1.0:
		swap(tree, switch, entering)
		return
	_busy = true
	var vp := tree.root.get_visible_rect().size
	var tex := ImageTexture.create_from_image(tree.root.get_texture().get_image())
	var layer := CanvasLayer.new()
	layer.layer = 128
	var shot := TextureRect.new()
	shot.texture = tex
	shot.stretch_mode = TextureRect.STRETCH_SCALE
	shot.position = Vector2.ZERO
	shot.size = vp
	shot.pivot_offset = tile.get_center()   # le zoom s'ancre sur la tuile
	layer.add_child(shot)
	tree.root.add_child(layer)
	switch.call_deferred()   # le swap se fait SOUS la capture, hors du callstack d'input
	# facteur couvrant : la tuile remplit l'écran sans déformer
	var s := maxf(vp.x / tile.size.x, vp.y / tile.size.y)
	var tw := shot.create_tween()
	tw.set_parallel(true)
	if entering:
		# on plonge dans la tuile : la capture du home accélère en grossissant, puis fond
		tw.tween_property(shot, "scale", Vector2(s, s), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(shot, "modulate:a", 0.0, dur * 0.45).set_delay(dur * 0.55)
	else:
		# l'app se rétracte uniformément vers sa tuile, puis fond
		tw.tween_property(shot, "scale", Vector2(1.0 / s, 1.0 / s), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(shot, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		_busy = false
		layer.queue_free())


# cross-fade doux avec micro-zoom (fallback quand la tuile n'est pas connue)
static func swap(tree: SceneTree, switch: Callable, entering: bool, dur := 0.26) -> void:
	if _busy:
		return
	_busy = true
	var vp := tree.root.get_visible_rect().size
	var tex := ImageTexture.create_from_image(tree.root.get_texture().get_image())
	var layer := CanvasLayer.new()
	layer.layer = 128
	var shot := TextureRect.new()
	shot.texture = tex
	shot.stretch_mode = TextureRect.STRETCH_SCALE
	shot.position = Vector2.ZERO
	shot.size = vp
	shot.pivot_offset = vp * 0.5
	layer.add_child(shot)
	tree.root.add_child(layer)
	switch.call_deferred()   # le swap se fait SOUS la capture, hors du callstack d'input
	var target := Vector2(0.97, 0.97) if entering else Vector2(1.03, 1.03)
	var tw := shot.create_tween()
	tw.set_parallel(true)
	tw.tween_property(shot, "scale", target, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(shot, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		_busy = false
		layer.queue_free())


# fondu noir simple (utilisé si jamais une transition sans capture est préférable)
static func run(tree: SceneTree, switch: Callable, dur := 0.18) -> void:
	if _busy:
		return
	_busy = true
	var layer := CanvasLayer.new()
	layer.layer = 128
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)
	tree.root.add_child(layer)
	var tw := veil.create_tween()
	tw.tween_property(veil, "color:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(switch)
	tw.tween_interval(0.06)
	tw.tween_property(veil, "color:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_busy = false
		layer.queue_free())
