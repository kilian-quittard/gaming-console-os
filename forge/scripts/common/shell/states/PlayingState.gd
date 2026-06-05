extends State
# Ne gère PAS le template — appelé après _start_template_new() ou pour reprendre depuis pause.


func _on_enter(_args) -> void:
	target.shell_screen = "playing"
	target.mode = "play"
	target.queue_redraw()
