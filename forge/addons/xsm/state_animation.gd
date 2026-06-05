# MIT LICENSE Copyright 2020-2026 Etienne Blanc - ATN
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
@tool
@icon("res://addons/xsm/icons/state_animation.png")
extends State
class_name StateAnimation

# StateAnimation is there for all your States that play an animation on enter
#
# The usual way of using this class is to add a StateAnimation in your tree
# Then, you can chose an anim_on_enter and how much time it will play
# In on_anim_finished in the inspector, you can define what you want to do next
#
# You have additionnal functions to inherit:
#  _on_anim_finished(_name)
#	 where _name is the name of the animation
#	 You can differentiate between animations played (using play() below)
#
# There are additionnal functions to call in your StateAnimation:
#  play(anim: String, custom_speed: float = 1.0, from_end: bool = false) -> void:
#  play_backwards(anim: String) -> void:
#  play_blend(anim: String, custom_blend: float, custom_speed: float = 1.0,
#  play_sync(anim: String, custom_speed: float = 1.0,
#  pause() -> void:
#  queue(anim: String) -> void:
#  stop(reset: bool = true) -> void:
#  is_playing(anim: String) -> bool:


enum {ANIM_SPRITE, ANIM_PLAYER}
enum {LOOP_NONE, LOOP_N_TIMES, LOOP_FOREVER, LOOP_SYNC}
enum {FINISHED_CALLBACK_ONLY, FINISHED_GOTO_NEXT, FINISHED_ASK_PARENT}


# EXPORTS
#
# Is exported in "_get_property_list():"
var anim_on_enter := "NONE":
	set(value):
		anim_on_enter = value
		notify_property_list_changed()
var loop_mode := LOOP_NONE:
	set(value):
		loop_mode = value
		notify_property_list_changed()
var nb_of_loops := 1
var on_finished := FINISHED_CALLBACK_ONLY

var animator_type := ANIM_SPRITE
var animation_source: NodePath = NodePath():
	set(value):
		animation_source = value
		notify_property_list_changed()
		update_configuration_warnings()


var current_loop := 0


#
# INIT
#
func _ready() -> void:
	super ()

	if Engine.is_editor_hint() and not renamed.is_connected(_on_StateAnimation_renamed):
		renamed.connect(_on_StateAnimation_renamed)

	guess_animation_source()


func _get_configuration_warning() -> String:
	if animation_source == null or animation_source.is_empty():
		var warning := "Warning : Your StateAnimation does not have an AnimationPlayer set up.\n"
		warning += "Either set it in the inspector or have an AnimationPlayer be a sibling of your XSM's root"
		return warning
	return ""


# We want to add some export variables in their categories
# And separate those of the root state
func _get_property_list():
	var properties = []

	# Will guess the AnimationPlayer each time \
	# the inspector loads for this Node and the source is empty
	guess_animation_source()
	var anim_source = get_node_or_null(animation_source)

	properties.append({
		name = "animation_source",
		type = TYPE_NODE_PATH
	})

	if anim_source:
		var anims_hint = "NONE"
		# Will fill the anim list and guess the animation to play
		match animator_type:
			ANIM_SPRITE:
				if anim_source.sprite_frames.has_animation(name) and anim_on_enter == "":
					anim_on_enter = name
				for anim in anim_source.sprite_frames.get_animation_names():
					anims_hint = "%s,%s" % [anims_hint, anim]
			ANIM_PLAYER:
				if anim_source.has_animation(name) and anim_on_enter == "":
					anim_on_enter = name
				for anim in anim_source.get_animation_list():
					anims_hint = "%s,%s" % [anims_hint, anim]
		properties.append({
			name = "anim_on_enter",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_ENUM,
			hint_string = anims_hint
		})

		if anim_on_enter != "NONE" and anim_on_enter != "":
			properties.append({
				name = "loop_mode",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "None, N Times, Forever"
			})
			if loop_mode == LOOP_N_TIMES:
				properties.append({
					name = "nb_of_loops",
					type = TYPE_INT,
					hint = PROPERTY_HINT_RANGE,
					hint_string = "1,10,or_greater"
				})
			if loop_mode != LOOP_FOREVER:
				properties.append({
					name = "on_finished",
					type = TYPE_INT,
					hint = PROPERTY_HINT_ENUM,
					hint_string = "Callback Only:0, Goto Next:1, Parent's Choice:2"
				})

	update_configuration_warnings()
	return properties


func _property_can_revert(property):
	if property == "animation_source":
		return true
	if property == "anim_on_enter":
		return true
	if property == "nb_of_loops":
		return true
	if property == "on_finished":
		return true
	return super (property)


func _property_get_revert(property):
	if property == "animation_source":
		return NodePath()
	if property == "anim_on_enter":
		return "NONE"
	if property == "nb_of_loops":
		return 1
	if property == "on_finished":
		return FINISHED_CALLBACK_ONLY
	return super (property)


#
# FUNCTIONS TO INHERIT
#
func _on_anim_finished() -> void:
	pass

func _on_loop_finished() -> void:
	pass


#
# FUNCTIONS TO CALL IN INHERITED STATES
#
func play(anim: String, custom_speed: float = 1.0, from_end: bool = false) -> void:
	if disabled or status != ACTIVE:
		return
	var animator_node = get_node_or_null(animation_source)
	if animator_node:
		if animator_type == ANIM_PLAYER and animator_node.has_animation(anim) \
				and (not animator_node.is_playing() or animator_node.current_animation != anim):
			animator_node.play(anim, -1, custom_speed, from_end)
		elif animator_type == ANIM_SPRITE and animator_node.sprite_frames.has_animation(anim) \
				and (not animator_node.is_playing() or animator_node.animation != anim):
			animator_node.play(anim, custom_speed, from_end)


func play_backwards(anim: String) -> void:
	play(anim, -1.0, true)


func play_blend(anim: String, custom_blend: float, custom_speed: float = 1.0,
		from_end: bool = false) -> void:
	var animator_node = get_node_or_null(animation_source)
	if status == ACTIVE and animator_node != null:
		if animator_type == ANIM_SPRITE:
			play(anim)
		elif animator_node.has_animation(anim) and animator_node.current_animation != anim:
			animator_node.play(anim, custom_blend, custom_speed, from_end)


func play_sync(anim: String, custom_speed: float = 1.0,
		from_end: bool = false) -> void:
	var animator_node = get_node_or_null(animation_source)
	if status == ACTIVE and animator_node != null:
		if animator_type == ANIM_SPRITE:
			if animator_node.sprite_frames.has_animation(anim):
				var curr_anim: String = animator_node.animation
				if curr_anim != anim and curr_anim != "":
					var curr_anim_pos: float = animator_node.get_frame()
					var curr_anim_progress: float = animator_node.get_frame_progress()
					play(anim, custom_speed, from_end)
					animator_node.set_frame_and_progress(curr_anim_pos, curr_anim_progress)
		elif animator_node.has_animation(anim):
			var curr_anim: String = animator_node.current_animation
			if curr_anim != anim and curr_anim != "":
				var curr_anim_pos: float = animator_node.current_animation_position
				var curr_anim_length: float = animator_node.current_animation_length
				var ratio: float = curr_anim_pos / curr_anim_length
				play(anim, custom_speed, from_end)
				animator_node.seek(ratio * animator_node.current_animation_length)


func pause() -> void:
	var animator_node = get_node_or_null(animation_source)
	if status == ACTIVE and animator_node != null:
		animator_node.pause()


func queue(anim: String) -> void:
	var animator_node = get_node_or_null(animation_source)
	if status == ACTIVE and animator_node != null and animator_node.has_animation(anim):
		animator_node.queue(anim)


func stop(reset: bool = true) -> void:
	var animator_node = get_node_or_null(animation_source)
	if status == ACTIVE and animator_node != null:
		if animator_type == ANIM_SPRITE:
			animator_node.stop()
		else:
			animator_node.stop(reset)


func is_playing(anim: String) -> bool:
	var animator_node = get_node_or_null(animation_source)
	if animator_node != null:
		return animator_node.current_animation == anim
	return false


#
# PRIVATE FUNCTIONS
#
func guess_animation_source() -> void:
	if animation_source != null and not animation_source.is_empty():
		var anim_source = get_node_or_null(animation_source)
		set_animator_type(anim_source)
		return
	if not state_root: # To avoid bugs on Engine startup
		animation_source = NodePath()
		return
	for c in state_root.get_parent().get_children():
		if set_animator_type(c):
			animation_source = get_path_to(c)
			return
	animation_source = NodePath()


func set_animator_type(node_to_check) -> bool:
	if node_to_check is AnimationPlayer:
		animator_type = ANIM_PLAYER
		for anim in node_to_check.get_animation_list():
			node_to_check.get_animation(anim).set_loop_mode(0) # avoid looping in animation player
		return true
	if node_to_check is AnimatedSprite2D or node_to_check is AnimatedSprite3D:
		animator_type = ANIM_SPRITE
		for anim in node_to_check.sprite_frames.get_animation_names():
			node_to_check.sprite_frames.set_animation_loop(anim, false)
		return true
	return false


func exit(args = null) -> void:
	current_loop = 0
	var animator_node = get_node_or_null(animation_source)
	if animator_node and animator_node.animation_finished.is_connected(_on_Animator_animation_finished):
		animator_node.animation_finished.disconnect(_on_Animator_animation_finished)
	super (args)


func enter(args = null) -> void:
	super (args)
	var animator_node = get_node_or_null(animation_source)
	set_loops_off(animator_node)
	if animator_node and not animator_node.animation_finished.is_connected(_on_Animator_animation_finished):
		animator_node.animation_finished.connect(_on_Animator_animation_finished)
	if anim_on_enter != "" and anim_on_enter != "NONE":
		play(anim_on_enter)


func set_loops_off(node_to_check) -> void:
	if not node_to_check:
		return
	if animator_type == ANIM_PLAYER:
		for anim in node_to_check.get_animation_list():
			node_to_check.get_animation(anim).set_loop_mode(0) # avoid looping in animation player
	elif animator_type == ANIM_SPRITE:
		for anim in node_to_check.sprite_frames.get_animation_names():
			node_to_check.sprite_frames.set_animation_loop(anim, false)


func _on_Animator_animation_finished(finished_animation := ""):
	var past_animation = finished_animation
	var animator_node = get_node_or_null(animation_source)
	if finished_animation == "":
		past_animation = animator_node.animation
	if past_animation == anim_on_enter:
		_on_anim_finished()
		match loop_mode:
			LOOP_NONE:
				match on_finished:
					FINISHED_GOTO_NEXT:
						change_to_next()
					FINISHED_ASK_PARENT:
						get_parent().change_to_next_substate()
			LOOP_FOREVER:
				play(past_animation)
			LOOP_N_TIMES:
				current_loop += 1
				if current_loop >= nb_of_loops:
					_on_loop_finished()
					match on_finished:
						FINISHED_GOTO_NEXT:
							change_to_next()
						FINISHED_ASK_PARENT:
							get_parent().change_to_next_substate()
				else:
					play(past_animation)


func _on_StateAnimation_renamed():
	# Will guess the animation to play
	var anim_source = get_node_or_null(animation_source)
	if anim_source and anim_source.has_animation(name) and anim_on_enter == "":
		anim_on_enter = name
