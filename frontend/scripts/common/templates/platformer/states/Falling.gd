extends State
# Air : chute (revient au sol au contact)


func _on_update(_delta: float) -> void:
	if target.on_floor:
		change_state("Grounded")
