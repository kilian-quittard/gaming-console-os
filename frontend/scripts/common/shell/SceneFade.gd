extends RefCounted
class_name SceneFade
# TRANSITION console entre le home et les apps : fondu noir rapide → switch
# (callable) → fondu retour. Le voile vit sur un CanvasLayer accroché à root,
# donc il survit au changement de scène et reste au-dessus de tout.

static var _busy := false   # anti double-déclenchement (spam HOME/A)


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
	tw.tween_callback(switch)          # le swap se fait sous le noir
	tw.tween_interval(0.06)            # laisse la nouvelle scène se poser une frame
	tw.tween_property(veil, "color:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_busy = false
		layer.queue_free())
