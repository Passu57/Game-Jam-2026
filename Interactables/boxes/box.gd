extends RigidBody2D
## A box the player can push (onto buttons, into gaps...).
## It only slides while the player pushes it, never rolls over, and falls
## with gravity. Untick "Pushable" to lock it in place (you can still stand on it).

## Can the player push this box? Untick to make it immovable.
@export var pushable: bool = true:
	set(value):
		pushable = value
		if is_node_ready():
			freeze = not pushable and not floats

## How fast the box slides while being pushed (pixels per second).
@export var push_speed: float = 60.0

@export_group("Floating")
## Tick to make the box float on water (see Water node). Works together with
## "Pushable": untick Pushable for a box that only the water can move.
@export var floats: bool = false:
	set(value):
		floats = value
		if is_node_ready():
			freeze = not pushable and not floats
## How strongly water pushes it up. 2 = floats about half under water.
@export var buoyancy: float = 2.2
## How quickly bobbing calms down in water. Higher = calmer.
@export var water_drag: float = 6.0
@export_group("")

var _push_dir: float = 0.0
var _half_height: float = 8.0


func _ready() -> void:
	lock_rotation = true                      # boxes slide, they don't roll
	can_sleep = false                         # always ready to be pushed
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	# A floating box must stay a physics body so water can lift it,
	# even when the player isn't allowed to push it.
	freeze = not pushable and not floats
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		_half_height = shape_node.shape.size.y * 0.5

## Called by the player while walking into the box: -1 = left, 1 = right.
func push(dir: float) -> void:
	if pushable:
		_push_dir = dir


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Slide only while pushed; stop right away when the player lets go.
	var v := state.linear_velocity
	v.x = _push_dir * push_speed
	if floats:
		v.y = _apply_water(state, v.y)
	state.linear_velocity = v
	_push_dir = 0.0


# Pushes the box up depending on how much of it is under water.
func _apply_water(state: PhysicsDirectBodyState2D, vy: float) -> float:
	var water := _find_water()
	if water == null:
		return vy
	var bottom := global_position.y + _half_height
	var submerged := clampf((bottom - water.surface_y()) / (_half_height * 2.0), 0.0, 1.0)
	if submerged <= 0.0:
		return vy
	var g := state.total_gravity.y
	vy -= g * buoyancy * submerged * state.step
	vy *= 1.0 - clampf(water_drag * submerged * state.step, 0.0, 1.0)
	return vy


func _find_water() -> Node:
	for water in get_tree().get_nodes_in_group("water"):
		if water.is_filled() and water.covers_x(global_position.x) \
				and global_position.y - _half_height <= water.global_position.y:
			return water
	return null
