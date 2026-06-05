extends State
# Air : au sol (déclenche le saut depuis le buffer, sinon chute si plus de sol)


func _on_update(_delta: float) -> void:
	var t = target
	if t.jbuf > 0.0 and (t.on_floor or t.coyote_t > 0.0):
		t.do_jump()
		change_state("Jumping")
	elif not t.on_floor:
		change_state("Falling")
