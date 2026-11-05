extends Sprite2D
## The wrench in the robot's hand. Stays hidden until the wrench has been
## found, if the player's "Wrench Needs Unlock" is ticked.
## (Runs after the player's own _process, so it has the final say.)


func _process(_delta: float) -> void:
	var player := get_parent()
	if player == null or not ("wrench_needs_unlock" in player):
		return
	if player.wrench_needs_unlock and not GameProgress.has(GameProgress.WRENCH_THROW):
		visible = false
