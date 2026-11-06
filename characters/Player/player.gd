extends CharacterBody2D

## How fast the player runs left/right (pixels per second).
@export var speed: float = 100.0
## How strong the jump is. Bigger = higher jump.
@export var jump_velocity: float = -260.0
@onready var interaction_controller: Node2D = $InteractionController
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var throw_sound: AudioStreamPlayer2D = $ThrowSound
@onready var dash_sound: AudioStreamPlayer2D = $DashSound
@onready var running_sound: AudioStreamPlayer2D = $RunningSound
@export var run_step_interval: float = 0.32
var _run_step_timer: float = 0.0


@export_group("Jump Feel")
## Coyote time: you can still jump this long after running off a ledge (seconds).
@export var coyote_time: float = 0.1
## Jump buffer: pressing jump this long BEFORE landing still jumps the moment
## you touch the ground (seconds).
@export var jump_buffer_time: float = 0.12
@export_group("")

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@export_group("Double Jump")
## How strong the second (air) jump is. Bigger negative = higher.
@export var double_jump_velocity: float = -260.0
## How many extra jumps you get in the air once double jump is unlocked.
@export var max_air_jumps: int = 1
## Testing shortcut: tick this to have double jump without unlocking it.
@export var debug_always_double_jump: bool = false
@export_group("")

var _air_jumps_left: int = 0
@onready var double_jump_particles: CPUParticles2D = $DoubleJumpParticles
@onready var run_dust: CPUParticles2D = $RunDustParticles

@export_group("Wrench Throw")
## Hold this button to aim, release to throw (right mouse by default).
const THROW_ACTION := &"throw"
## How fast the wrench leaves your hand (pixels per second).
@export var wrench_throw_speed: float = 300.0
## How strongly the wrench falls while flying. 0 = flies in a straight line.
@export var wrench_gravity: float = 500.0
## How long the wrench flies before it comes back on its own (seconds).
@export var wrench_flight_time: float = 1.0
## Where the wrench sits in the hand, relative to the player's center
## (for the robot facing right; it's mirrored automatically when facing left).
@export var wrench_hand_offset: Vector2 = Vector2(-7.5, 8)
## Tick this if the wrench should only work after unlocking it
## with GameProgress.unlock(GameProgress.WRENCH_THROW).
@export var wrench_needs_unlock: bool = false
@export_group("")

const WRENCH_SCENE := preload("res://characters/Player/Wrench/Wrench.tscn")
const WrenchAim := preload("res://characters/Player/Wrench/wrench_aim.gd")

var _wrench_out: Node2D = null  # the wrench in the air, if any
var _wrench_aim: Node2D
## The wrench drawn in the robot's hand (same frames as the robot sheet).
@onready var wrench_sprite: Sprite2D = $WrenchSprite

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer


func _physics_process(delta: float) -> void:
	# Fall down when in the air.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Landing refills the air jumps.
	if is_on_floor():
		_air_jumps_left = max_air_jumps

	# Coyote time: keep "ground jump allowed" for a moment after leaving a ledge.
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# Jump buffer: remember a jump press for a moment, so pressing a little
	# too early (just before landing) still jumps as soon as possible.
	var jump_pressed := Input.is_action_just_pressed("jump")
	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			# Normal ground jump (also works a moment after leaving a ledge).
			velocity.y = jump_velocity
			jump_sound.play()
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0  # no second coyote jump
		elif jump_pressed and _can_double_jump() and not _about_to_land():
			_double_jump()
			_jump_buffer_timer = 0.0
	
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
	# Running sound
	if is_on_floor() and direction != 0:
		_run_step_timer -= delta
		if _run_step_timer <= 0.0 and not running_sound.playing:
			running_sound.play()
			_run_step_timer = run_step_interval
	else:
		_run_step_timer = 0.0
	_push_objects()
	_update_animation(direction)
	_update_run_dust(direction)
	_update_wrench()


# Kicks up dust behind the feet while running on the ground.
func _update_run_dust(direction: float) -> void:
	
	var running := is_on_floor() and absf(velocity.x) > 1.0
	run_dust.emitting = running
	if running:
		# Dust flies backwards, away from where we're running.
		run_dust.direction.x = -signf(direction)


# True if we're falling and will hit the ground within the jump buffer window.
# Then an early jump press waits for a proper ground jump instead of
# wasting the double jump a few pixels above the floor.
func _about_to_land() -> bool:
	if velocity.y <= 0.0:
		return false
	var fall := maxf(velocity.y * jump_buffer_time, 2.0)
	return test_move(global_transform, Vector2(0, fall))


func _can_double_jump() -> bool:
	var unlocked := debug_always_double_jump or GameProgress.has(GameProgress.DOUBLE_JUMP)
	return unlocked and _air_jumps_left > 0


func _double_jump() -> void:
	_air_jumps_left -= 1
	velocity.y = double_jump_velocity
	double_jump_particles.restart()
	anim.stop()  # replay the jump animation from the start
	anim.play("Jump")


# --- Wrench throwing -----------------------------------------------------

func _ready() -> void:
	_wrench_aim = WrenchAim.new()
	_wrench_aim.name = "WrenchAim"
	add_child(_wrench_aim)
	_wrench_aim.hide_arc()
	died.connect(_wrench_aim.hide_arc)


# Keeps the in-hand wrench on the same animation frame as the robot,
# and hides it while the wrench is flying.
func _process(_delta: float) -> void:
	wrench_sprite.frame = sprite.frame
	wrench_sprite.flip_h = sprite.flip_h
	wrench_sprite.visible = _wrench_out == null


# The hand position in the world, mirrored when facing left.
func _wrench_hand_position() -> Vector2:
	var offset := wrench_hand_offset
	if sprite.flip_h:
		offset.x = -offset.x
	return global_position + offset


func _can_throw_wrench() -> bool:
	if _wrench_out != null:
		return false  # only one wrench at a time
	return not wrench_needs_unlock or GameProgress.has(GameProgress.WRENCH_THROW)


# Hold the throw button to aim (shows the arc), release to throw.
func _update_wrench() -> void:
	if not _can_throw_wrench():
		_wrench_aim.hide_arc()
		return

	var aiming := Input.is_action_pressed(THROW_ACTION)
	if aiming:
		# Face where we aim (this also moves the hand to that side).
		sprite.flip_h = get_global_mouse_position().x < global_position.x

	var start := _wrench_hand_position()
	var aim_dir := (get_global_mouse_position() - start).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	var start_velocity := aim_dir * wrench_throw_speed

	if aiming:
		var arc := _predict_wrench_arc(start, start_velocity)
		_wrench_aim.show_arc(arc.points, arc.hit)
	elif Input.is_action_just_released(THROW_ACTION):
		_wrench_aim.hide_arc()
		_throw_wrench(start, start_velocity)


func _throw_wrench(start: Vector2, start_velocity: Vector2) -> void:
	throw_sound.play()
	var wrench := WRENCH_SCENE.instantiate()
	# Add to the level, not the player, so it doesn't move with us.
	get_tree().current_scene.add_child(wrench)
	wrench.launch(start, start_velocity, wrench_gravity, wrench_flight_time, self, sprite.flip_h)
	wrench.tree_exited.connect(func(): _wrench_out = null)
	_wrench_out = wrench


# Simulates the throw step by step (the same way the wrench moves)
# and stops at the first wall/floor/box it would hit.
func _predict_wrench_arc(start: Vector2, start_velocity: Vector2) -> Dictionary:
	var points := PackedVector2Array([start])
	var space := get_world_2d().direct_space_state
	var dt := 1.0 / Engine.physics_ticks_per_second
	var steps := int(wrench_flight_time / dt)
	var pos := start
	var vel := start_velocity
	for i in steps:
		vel.y += wrench_gravity * dt
		var next := pos + vel * dt
		var query := PhysicsRayQueryParameters2D.create(pos, next, 1, [get_rid()])
		var result := space.intersect_ray(query)
		if result:
			points.append(result.position)
			return {"points": points, "hit": true}
		points.append(next)
		pos = next
	return {"points": points, "hit": false}

 
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
	death_sound.play()
	anim.play("die")
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
