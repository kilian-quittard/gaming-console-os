extends State
# Air : montée du saut (passe en chute quand la vitesse verticale repasse positive)


func _on_update(_delta: float) -> void:
	if target.pvel.y >= 0.0:
		change_state("Falling")
