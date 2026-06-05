extends State


func _on_enter(_args) -> void:
	target.shell_screen = "complete"
	target.mode = "edit"
	target.queue_redraw()
