extends State
# Locomotion : course (accélération vers la vitesse cible)


func _on_update(delta: float) -> void:
	var t = target
	t.pvel.x = move_toward(t.pvel.x, t.input_x * t.SPEED, (t.ACCEL_GROUND if t.on_floor else t.ACCEL_AIR) * delta)
	if t.input_x == 0:
		change_state("Idle")
