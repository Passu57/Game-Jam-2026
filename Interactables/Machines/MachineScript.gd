extends StaticBody2D
## A machine that starts broken. The player fixes it by standing in its
## InteractionArea and pressing E. Fixing it brings back the colors
## chosen in "Unlocks Colors" (Inspector).

## Emitted once when the machine gets fixed.
signal fixed

## Which colors this machine brings back when fixed.
## Tick one or more boxes in the Inspector. Default: Yellow.
@export_flags("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta") var unlocks_colors: int = 2

var is_fixed: bool = false

@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	anim.play("Broken")


## Called by the player's InteractionController when E is pressed.
func interact(_player: Node) -> void:
	if is_fixed:
		return
	is_fixed = true
	anim.play("Fixed")
	ColorManager.unlock(unlocks_colors)
	fixed.emit()
