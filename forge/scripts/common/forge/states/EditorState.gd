extends State
# Écran : éditeur + test du projet ouvert


func _on_enter(_args) -> void:
	target.screen = "edit"
	target.mode = "edit"
	target.queue_redraw()
