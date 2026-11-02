extends Node2D
## Lets the player interact with things (like machines).
## When the player's InteractionArea overlaps an interactable's hitbox
## and E ("interact") is pressed, that object's interact() is called.

@onready var area: Area2D = $InteractionArea

func interact() -> void:
	print("LEL")
	var target := get_current_target()
	if target != null:
		target.interact(owner)

## Returns the interactable the player is standing in, or null.
func get_current_target() -> Node:
	for other in area.get_overlapping_areas():
		var target := _find_interactable(other)
		if target != null:
			return target
	return null


# Walks up from the touched hitbox until it finds a node with interact().
func _find_interactable(node: Node) -> Node:
	while node != null:
		if node.has_method("interact"):
			return node
		node = node.get_parent()
	return null
