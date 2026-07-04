extends State


func _on_enter(_args) -> void:
	target.shell_screen = "pause"
	target.mode = "edit"   # stoppe la physique du template
	target.queue_redraw()
