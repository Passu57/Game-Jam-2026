extends Node
## Autoload: MachineColorLink
## Connects machines to the ColorManager automatically.
## Any node with a "fixed" signal AND an "unlocks_colors" variable gets
## hooked up: when it emits "fixed", exactly those colors unlock.
## Machines without "unlocks_colors" are left alone (they handle colors
## themselves), so this never unlocks extra colors by accident.


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	if node.has_signal("fixed"):
		var callback := _on_machine_fixed.bind(node)
		if not node.is_connected("fixed", callback):
			node.connect("fixed", callback)


func _on_machine_fixed(machine: Node) -> void:
	var mask = machine.get("unlocks_colors")
	if mask == null:
		return
	var color_manager := get_node_or_null("/root/ColorManager")
	if color_manager:
		color_manager.unlock(mask)
