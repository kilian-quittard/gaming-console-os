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
@icon("res://addons/xsm/icons/state_rand.png")
extends State
class_name StateRand

# StateRand Can chose a random state based on priorities
# Call rand_state() to chose a random substate
# In this state's inspector, you can define priorities
# for your sub-States, to have some appear more often
#
# Call change_to_next_substate() selects randomly the next State


var randomized := true:
	set(value):
		randomized = value
		notify_property_list_changed()
# This seed will not be used if this state is randomized
var state_seed := 0
var priorities: Dictionary[NodePath, int]:
	set(value):
		# Those to block the user to edit the keys
		# [tips] Get_parent() is false during the init
		if value.size() != get_child_count() and get_parent():
			for k in value.keys():
				var n1 = get_node_or_null(k)
				if not n1:
					value.erase(k)
				elif not is_ancestor_of(n1):
					value.erase(k)
		if value.size() != get_child_count():
			for c in get_children():
				if c is State:
					value[NodePath(c.name)] = 1
		# No priority below 1
		for k in value.keys():
			if value[k] <= 0:
				value[k] = 1
		priorities = value
		notify_property_list_changed()
var is_ready := false

#
# INIT
#
func _ready():
	super ()

	if randomized:
		randomize()
	else:
		seed(state_seed)

	var _c1 = child_entered_tree.connect(_substate_entered)
	var _c2 = child_exiting_tree.connect(_substate_exiting)
	for c in get_children():
		if c is State and not c.renamed.has_connections():
			var _conn = c.renamed.connect(_substate_renamed.bind(c.get_path(), c))

	# Initialize the priorities
	if priorities.size() != get_child_count():
		for k in priorities.keys():
			var n1 = get_node_or_null(k)
			if not n1:
				priorities.erase(k)
	if priorities.size() != get_child_count():
		for c in get_children():
			if c is State:
				priorities[NodePath(c.name)] = 1


# We want to add some export variables in their categories
# And separate those of the root state
func _get_property_list():
	var properties = []

	properties.append({
		name = "randomized",
		type = TYPE_BOOL,
	})
	if not randomized:
		properties.append({
			name = "state_seed",
			type = TYPE_INT,
		})
	properties.append({
		name = "priorities",
		type = TYPE_DICTIONARY,
	})
	
	return properties


#
# PUBLIC FUNCTIONS
#
func change_to_next_substate():
	var rand_array: Array[NodePath] = []
	# Here, we populate an array with as much times a NodePath
	# as its priority, and then we randomly chose one of them
	for k in priorities.keys():
		for i in priorities[k]:
			rand_array.append(k)
	var rand_idx = randi() % rand_array.size()
	# We have to force it in case it is already running the state
	change_state_node_force(get_node_or_null(rand_array[rand_idx]))


#
# PRIVATE FUNCTIONS
#
func _substate_entered(node):
	if node is State:
		priorities[NodePath(node.name)] = 1
		var _c = node.renamed.connect(_substate_renamed.bind(NodePath(node.name), node))


func _substate_exiting(node):
	if node is State:
		priorities.erase(NodePath(node.name))


# in case a state child is renamed, update its name in priorities
# have to reconnect its signal
func _substate_renamed(old_path, node):
	var old_priority = priorities[old_path]
	priorities.erase(old_path)
	priorities[NodePath(node.name)] = old_priority
	# Has to reconnect the signal to update the bindings names
	node.renamed.disconnect(_substate_renamed)
	var _c = node.renamed.connect(_substate_renamed.bind(NodePath(node.name), node))
