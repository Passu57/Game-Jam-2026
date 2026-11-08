extends Area2D
## The thrown wrench. Flies in an arc, bonks the first thing it hits,
## then flies back to the player.
##
## To make something react to the wrench (a switch, a machine, a stuck gear),
## give its script this function:
##     func on_wrench_hit(wrench) -> void:

## Emitted when the wrench is back in the player's hands.
signal returned

enum State { FLYING, RETURNING }

## How fast it flies back to the player (pixels per second).
@export var return_speed: float = 420.0
## How fast it spins in the air.
@export var spin_speed: float = 20.0
## How hard it nudges boxes and other physics objects it hits.
@export var push_strength: float = 0.25

@onready var sprite: Sprite2D = $Sprite2D

var velocity: Vector2 = Vector2.ZERO
var thrower: Node2D

var _state: State = State.FLYING
var _gravity: float = 600.0
var _flight_time_left: float = 1.2


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Called by the player right after spawning the wrench.
func launch(from: Vector2, start_velocity: Vector2, gravity_strength: float,
		max_flight_time: float, by: Node2D, flipped: bool = false) -> void:
	sprite.flip_h = flipped  # match the way the robot was holding it
	global_position = from
	velocity = start_velocity
	_gravity = gravity_strength
	_flight_time_left = max_flight_time
	thrower = by


func _physics_process(delta: float) -> void:
	var spin_dir := 1.0 if velocity.x >= 0.0 else -1.0
	rotation += spin_speed * spin_dir * delta

	if _state == State.FLYING:
		# Same math as the aiming preview, so it follows the dotted line.
		velocity.y += _gravity * delta
		global_position += velocity * delta
		_flight_time_left -= delta
		if _flight_time_left <= 0.0:
			_start_return()
	else:
		if not is_instance_valid(thrower):
			queue_free()
			return
		# Fly back into the hand (falls back to the player's center).
		var target := thrower.global_position
		if thrower.has_method("_wrench_hand_position"):
			target = thrower._wrench_hand_position()
		var to_player := target - global_position
		if to_player.length() < 4.0:
			returned.emit()
			queue_free()
			return
		global_position += to_player.normalized() * minf(return_speed * delta, to_player.length())


func _on_body_entered(body: Node) -> void:
	if _state != State.FLYING or body == thrower:
		return
	if body is RigidBody2D:
		body.apply_central_impulse(velocity * push_strength)
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	# Only things that care about the wrench stop it (not hazards, triggers...).
	# Walks up from the hitbox, so a lever's InteractionArea counts as the lever.
	if _state != State.FLYING:
		return
	var target := _find_wrench_target(area)
	if target != null:
		_hit(target)


func _find_wrench_target(node: Node) -> Node:
	while node != null:
		if node == thrower:
			return null
		if node.has_method("on_wrench_hit"):
			return node
		node = node.get_parent()
	return null


func _hit(target: Node) -> void:
	if target.has_method("on_wrench_hit"):
		target.on_wrench_hit(self)
	_start_return()


func _start_return() -> void:
	_state = State.RETURNING
	# Fly through walls on the way back so it never gets stuck.
	set_deferred("monitoring", false)
