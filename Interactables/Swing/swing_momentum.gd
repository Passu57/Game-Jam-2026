extends Node
## Added to the player for a moment after letting go of a swing.
## The player's own movement resets sideways speed every frame, so this
## carries the swing's sideways momentum until the robot lands, hits a wall,
## or grabs another swing. Holding left/right still steers a bit.

const NODE_NAME := "SwingMomentum"

## How fast the carried speed fades in the air (pixels/second²).
var air_drag: float = 150.0
## How much left/right input adds while flying (0..1 of the run speed).
var steer: float = 0.6

var _player: CharacterBody2D
var _carry: float = 0.0
var _age: float = 0.0


## Starts (or restarts) carrying horizontal speed for this player.
static func launch(player: CharacterBody2D, vx: float) -> void:
	stop(player)
	var m: Node = load("res://Interactables/Swing/swing_momentum.gd").new()
	m.name = NODE_NAME
	m._player = player
	m._carry = vx
	player.add_child(m)


## Stops any carried momentum on this player (e.g. when grabbing a new swing).
static func stop(player: Node) -> void:
	var old := player.get_node_or_null(NODE_NAME)
	if old != null:
		old.name = "SwingMomentumOld"
		old.queue_free()


func _ready() -> void:
	# Run AFTER the player has moved this frame.
	process_physics_priority = 100


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(_player) or _player.get("is_dead") == true \
			or not _player.is_physics_processing():
		queue_free()
		return
	if _age > 0.05 and _player.is_on_floor():
		queue_free()
		return

	var input := Input.get_axis("move_left", "move_right")
	var run_speed: float = _player.get("speed") if "speed" in _player else 100.0
	# The player already moved input * run_speed this frame. Add whatever is
	# missing to reach the carried speed (+ a little steering).
	var desired := _carry + input * run_speed * steer
	var extra := desired - input * run_speed
	if absf(extra) > 0.01:
		var hit := _player.move_and_collide(Vector2(extra * delta, 0))
		if hit != null:
			queue_free()  # bumped into a wall
			return
	# Face the way we're flying when not steering.
	if input == 0.0 and "sprite" in _player and _player.sprite != null:
		_player.sprite.flip_h = _carry < 0.0

	_carry = move_toward(_carry, 0.0, air_drag * delta)
	if absf(_carry) < 8.0:
		queue_free()
