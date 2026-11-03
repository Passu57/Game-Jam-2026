extends RigidBody2D
## A box the player can push (onto buttons, into gaps...).
## It only slides while the player pushes it, never rolls over, and falls
## with gravity. Untick "Pushable" to lock it in place (you can still stand on it).

## Can the player push this box? Untick to make it immovable.
@export var pushable: bool = true:
	set(value):
		pushable = value
		if is_node_ready():
			freeze = not pushable

## How fast the box slides while being pushed (pixels per second).
@export var push_speed: float = 60.0

var _push_dir: float = 0.0


func _ready() -> void:
	lock_rotation = true                      # boxes slide, they don't roll
	can_sleep = false                         # always ready to be pushed
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = not pushable


## Called by the player while walking into the box: -1 = left, 1 = right.
func push(dir: float) -> void:
	if pushable:
		_push_dir = dir


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Slide only while pushed; stop right away when the player lets go.
	var v := state.linear_velocity
	v.x = _push_dir * push_speed
	state.linear_velocity = v
	_push_dir = 0.0
