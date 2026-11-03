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
	_push_objects()
	_update_animation(direction)


# Pushes boxes (anything with a push() function) we walk into from the side.
# Standing on top of a box doesn't push it.
func _push_objects() -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var obj := hit.get_collider()
		if obj and obj.has_method("push") and absf(hit.get_normal().x) > 0.7:
			obj.push(-hit.get_normal().x)


# --- Dying & respawning --------------------------------------------------

## Emitted when the player dies (spikes, electricity...).
signal died

## How long the death flash lasts before respawning, in seconds.
@export var death_time: float = 0.5

## After respawning the player can't die for this long (seconds).
@export var respawn_protection: float = 0.5

var is_dead: bool = false
var _protected_until_ms: int = 0


## Kills the player: freeze, flash, then respawn at the level's SpawnPoint.
## Hazards call this. flash_color tints the flash (red for spikes, etc.).
func die(flash_color: Color = Color(2.0, 0.35, 0.35)) -> void:
	if is_dead or Time.get_ticks_msec() < _protected_until_ms:
		return
	is_dead = true
	died.emit()
	set_physics_process(false)
	velocity = Vector2.ZERO
	var tween := create_tween()
	for i in 3:
		tween.tween_property(self, "modulate", flash_color, death_time / 6.0)
		tween.tween_property(self, "modulate", Color(1, 1, 1), death_time / 6.0)
	await tween.finished
	_respawn()


## Electric puddles call this; it's a death with a blue flash.
func on_shocked(_source: Node) -> void:
	die(Color(0.6, 1.6, 2.0))


func _respawn() -> void:
	var level := get_tree().current_scene
	var spawn := level.get_node_or_null("SpawnPoint") if level else null
	if spawn is Node2D:
		global_position = spawn.global_position
	velocity = Vector2.ZERO
	modulate = Color(1, 1, 1)
	_protected_until_ms = Time.get_ticks_msec() + int(respawn_protection * 1000.0)
	is_dead = false
	set_physics_process(true)


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
