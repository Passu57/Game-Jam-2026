extends Area2D
## Drop this in a level. When the player touches it, the ability unlocks
## (through GameProgress) and the pickup disappears.

## Which ability this pickup gives. See the names in game_progress.gd.
@export var ability: StringName = GameProgress.DOUBLE_JUMP


func _ready() -> void:
	# Already have it (e.g. after respawning)? Then don't show the pickup.
	if GameProgress.has(ability):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.has_method("die"):  # only the player
		GameProgress.unlock(ability)
		queue_free()
