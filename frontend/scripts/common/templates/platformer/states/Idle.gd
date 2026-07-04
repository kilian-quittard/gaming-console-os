extends State
# Locomotion : à l'arrêt (friction)


func _on_update(delta: float) -> void:
	var t = target
	t.pvel.x = move_toward(t.pvel.x, 0.0, (t.FRICTION if t.on_floor else t.ACCEL_AIR) * delta)
	if t.input_x != 0:
		change_state("Run")
