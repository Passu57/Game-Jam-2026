extends CharacterBody2D

## How fast the player runs left/right (pixels per second).
@export var speed: float = 100.0
## How strong the jump is. Bigger = higher jump.
@export var jump_velocity: float = -260.0
@onready var interaction_controller: Node2D = $InteractionController

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer


func _physics_process(delta: float) -> void:
	# Fall down when in the air.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Jump only when standing on the ground.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	if Input.is_action_just_pressed("interact"):
		interaction_controller.interact()
	# Left/right movement: -1 = left, 1 = right, 0 = no key.
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * speed
		sprite.flip_h = direction < 0  # face the way we're moving
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
	_update_animation(direction)


func _update_animation(direction: float) -> void:
	if not is_on_floor():
		_play("Jump")
	elif direction != 0:
		_play("Run")
	else:
		_play("Idle")


func _play(anim_name: String) -> void:
	# assigned_animation remembers the last one even after Jump finishes,
	# so Jump plays once per jump instead of restarting.
	if anim.assigned_animation != anim_name:
		anim.play(anim_name)
