extends State


func _on_enter(_args) -> void:
	target.screen = "screenedit"
	target.queue_redraw()
