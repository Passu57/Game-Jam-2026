@tool
extends Sprite2D
## A wooden help sign. Pick which icon it shows in "Sign Type" in the Inspector.
## The node's origin is the bottom of the post: place it right on the floor.

enum SignType {
	WRENCH_THROW,
	ARROW_RIGHT,
	ARROW_LEFT,
	ARROW_UP,
	ARROW_DOWN,
	ARROW_UP_RIGHT,
	ARROW_UP_LEFT,
	ARROW_DOWN_RIGHT,
	ARROW_DOWN_LEFT,
	DROWNING_WARNING,
	EXCLAMATION,
}

@export var sign_type: SignType = SignType.ARROW_RIGHT:
	set(value):
		sign_type = value
		frame = int(value)


func _ready() -> void:
	frame = int(sign_type)
