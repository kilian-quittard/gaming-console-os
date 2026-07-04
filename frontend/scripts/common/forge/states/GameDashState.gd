extends State


func _on_enter(_args) -> void:
	target.screen = "gamedash"
	target.queue_redraw()
