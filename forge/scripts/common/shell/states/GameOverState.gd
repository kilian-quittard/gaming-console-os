extends State


func _on_enter(_args) -> void:
	target.shell_screen = "gameover"
	target.mode = "edit"
	target.queue_redraw()
