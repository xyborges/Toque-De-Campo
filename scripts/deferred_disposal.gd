extends Node
class_name DeferredDisposal
var pending: Array[Node] = []
var budget_usec := 650
var max_batch := 12

func retire(node: Node) -> void:
	if not is_instance_valid(node): return
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is Node3D: node.hide()
	if node.get_parent(): node.get_parent().remove_child(node)
	_collect(node)

func _collect(node: Node) -> void:
	for child in node.get_children(): _collect(child)
	pending.append(node)

func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	var amount := 0
	while not pending.is_empty() and amount<max_batch and Time.get_ticks_usec()-started<budget_usec:
		var node: Node = pending.pop_front()
		if is_instance_valid(node): node.free()
		amount+=1

func _exit_tree() -> void:
	for node in pending:
		if is_instance_valid(node): node.free()
	pending.clear()
