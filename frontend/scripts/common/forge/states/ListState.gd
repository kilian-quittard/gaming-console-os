extends State
# Écran : liste des projets (filtrée par dimension)


func _on_enter(_args) -> void:
	target.screen = "list"
	target._scan_projects(target.cur_dim)
	target.sel = 0
	target.queue_redraw()
