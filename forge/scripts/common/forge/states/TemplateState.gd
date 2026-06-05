extends State
# Écran : choix du template (nouveau projet)


func _on_enter(_args) -> void:
	target.screen = "template"
	target.sel = 0
	target.queue_redraw()
