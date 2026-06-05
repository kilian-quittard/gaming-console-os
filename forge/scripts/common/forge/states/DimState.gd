extends State
# Écran : choix 2D / 3D


func _on_enter(_args) -> void:
	target.screen = "dim"
	target.sel = (0 if target.cur_dim == "2D" else 1)
	target.queue_redraw()
