extends Node
## Wall jump ability. Lives as a child of the Player ("WallJumpAbility").
##   - In the air, hold toward a wall to slide down it slowly.
##   - Press jump while touching a wall to kick off it, up and away.
## Kept fair (not overpowered):
##   - You must alternate walls: you can't kick off the same wall twice in a
##     row (land, or touch the other wall, to reset). No climbing one wall.
##   - The kick pushes you away from the wall, so you need a second wall.
##   - It doesn't refill the double jump (but doesn't use it up either).
##
## Locked until GameProgress.unlock(&"wall_jump") - e.g. a Wall Jump pickup.

## Emitted when kicking off a wall. direction = -1 (to the left) or 1.
signal wall_jumped(direction: float)

const ABILITY := &"wall_jump"
const SwingMomentum := preload("res://Interactables/Swing/swing_momentum.gd")

## Only works after picking up the Wall Jump ability.
@export var needs_unlock: bool = true
## How high the wall jump goes (multiplies the normal jump strength).
@export_range(0.5, 1.5, 0.05) var jump_strength: float = 0.95
## How hard you're pushed away from the wall (pixels/second).
@export var push_speed: float = 170.0
## Max falling speed while sliding down a wall (pixels/second).
@export var slide_speed: float = 45.0
## You can still wall jump this long after leaving a wall (seconds).
@export var wall_coyote_time: float = 0.1
## Allow kicking off the same wall twice in a row (makes it easier).
@export var allow_same_wall: bool = false
## A wall jump gives back your air dash(es), so you can dash again.
@export var refill_dash: bool = true

@export_group("Effect")
@export var dust_color: Color = Color(0.85, 0.82, 0.77, 0.9)
## Tiny camera nudge on the kick (pixels, 0 = off).
@export var shake: float = 1.0

## True while sliding down a wall.
var is_sliding: bool = false

var _player: CharacterBody2D
var _sprite: Sprite2D
var _wall_dir: int = 0          # wall we're touching: -1 left, 1 right, 0 none
var _last_wall_dir: int = 0     # last wall touched (for coyote time)
var _wall_timer: float = 0.0
var _last_jumped_wall: int = 0  # wall we last kicked off (alternate rule)
var _prev_air_jumps: int = -1
var _slide_dust: CPUParticles2D
var _slide_timer: float = 0.0


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	_sprite = _player.get_node_or_null("Sprite2D") as Sprite2D
	# Run AFTER the player's own movement code.
	process_physics_priority = 60
	_build_slide_dust()


func is_unlocked() -> bool:
	return not needs_unlock or GameProgress.has(ABILITY)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var air_jumps_before := _prev_air_jumps
	_prev_air_jumps = int(_player.get("_air_jumps_left")) if "_air_jumps_left" in _player else -1

	is_sliding = false
	_slide_dust.emitting = false
	if not is_unlocked() or not _player.is_physics_processing() or _player.get("is_dead") == true:
		_wall_dir = 0
		return
	if _player.is_on_floor():
		_last_jumped_wall = 0  # landing resets the alternate-walls rule
		_wall_dir = 0
		_wall_timer = 0.0
		return

	_wall_dir = _touching_wall()
	if _wall_dir != 0:
		_last_wall_dir = _wall_dir
		_wall_timer = wall_coyote_time
		# Touching the OTHER wall resets the alternate-walls rule.
		if _last_jumped_wall != 0 and _wall_dir != _last_jumped_wall:
			_last_jumped_wall = 0
	else:
		_wall_timer = maxf(_wall_timer - delta, 0.0)

	var input := Input.get_axis("move_left", "move_right")

	# Wall slide: falling + holding toward the wall = slow slide.
	if _wall_dir != 0 and _player.velocity.y > 0.0 and signf(input) == float(_wall_dir):
		is_sliding = true
		_player.velocity.y = minf(_player.velocity.y, slide_speed)
		if _sprite != null:
			_sprite.flip_h = _wall_dir > 0  # face away from the wall while sliding
		_slide_dust.position = Vector2(_wall_dir * 7.0, 4.0)
		_slide_dust.emitting = true

	# Wall jump.
	if Input.is_action_just_pressed("jump") and _wall_timer > 0.0:
		var wall := _last_wall_dir
		if allow_same_wall or wall != _last_jumped_wall:
			_wall_jump(wall, air_jumps_before)


# -1 = wall on the left, 1 = wall on the right, 0 = no wall.
func _touching_wall() -> int:
	var t := _player.global_transform
	if _player.test_move(t, Vector2(2, 0)):
		return 1
	if _player.test_move(t, Vector2(-2, 0)):
		return -1
	return 0


func _wall_jump(wall: int, air_jumps_before: int) -> void:
	var away := -float(wall)
	_last_jumped_wall = wall
	_wall_timer = 0.0

	# The player's own code may have just used the double jump on this same
	# press. Give it back: a wall jump shouldn't cost the double jump.
	if air_jumps_before >= 0 and "_air_jumps_left" in _player:
		_player.set("_air_jumps_left", maxi(air_jumps_before, int(_player.get("_air_jumps_left"))))
		_prev_air_jumps = int(_player.get("_air_jumps_left"))
	if "_jump_buffer_timer" in _player:
		_player.set("_jump_buffer_timer", 0.0)
	# Kicking off a wall recharges the dash.
	if refill_dash:
		var dash := _player.get_node_or_null("DashAbility")
		if dash != null and dash.has_method("refill"):
			dash.refill()

	var jump_v: float = _player.get("jump_velocity") if "jump_velocity" in _player else -300.0
	_player.velocity.y = jump_v * jump_strength
	SwingMomentum.launch(_player, away * push_speed)
	if _sprite != null:
		_sprite.flip_h = away < 0.0
	var anim := _player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null:
		anim.stop()
		anim.play("Jump")
	var jump_sound := _player.get_node_or_null("JumpSound") as AudioStreamPlayer2D
	if jump_sound != null:
		jump_sound.play()

	_kick_effect(wall)
	wall_jumped.emit(away)


# --- Effects ---------------------------------------------------------------

func _build_slide_dust() -> void:
	_slide_dust = CPUParticles2D.new()
	_slide_dust.emitting = false
	_slide_dust.amount = 6
	_slide_dust.lifetime = 0.4
	_slide_dust.direction = Vector2(0, -1)
	_slide_dust.spread = 30.0
	_slide_dust.gravity = Vector2(0, -10)
	_slide_dust.initial_velocity_min = 8.0
	_slide_dust.initial_velocity_max = 20.0
	_slide_dust.scale_amount_min = 1.0
	_slide_dust.scale_amount_max = 2.0
	var g := Gradient.new()
	g.set_color(0, dust_color)
	g.set_color(1, Color(dust_color.r, dust_color.g, dust_color.b, 0.0))
	_slide_dust.color_ramp = g
	_slide_dust.z_index = 6
	_player.add_child.call_deferred(_slide_dust)


# A puff of dust off the wall + a few sparks shooting away from it.
func _kick_effect(wall: int) -> void:
	var at := _player.global_position + Vector2(wall * 7.0, 4.0)

	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 10
	dust.lifetime = 0.45
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(1, 6)
	dust.direction = Vector2(-wall, -0.3)
	dust.spread = 45.0
	dust.initial_velocity_min = 20.0
	dust.initial_velocity_max = 50.0
	dust.damping_min = 50.0
	dust.damping_max = 80.0
	dust.gravity = Vector2(0, 40)
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, dust_color)
	g.set_color(1, Color(dust_color.r, dust_color.g, dust_color.b, 0.0))
	dust.color_ramp = g
	_spawn(dust, at)

	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 6
	sparks.lifetime = 0.3
	sparks.direction = Vector2(-wall, -1).normalized()
	sparks.spread = 20.0
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 110.0
	sparks.gravity = Vector2(0, 200)
	sparks.color = Color(1, 1, 1, 0.9)
	_spawn(sparks, at)

	if shake > 0.0:
		var cam := get_viewport().get_camera_2d()
		if cam != null:
			var base := cam.offset
			var t := cam.create_tween()
			t.tween_property(cam, "offset", base + Vector2(wall * shake, 0), 0.04)
			t.tween_property(cam, "offset", base, 0.08)


func _spawn(p: CPUParticles2D, at: Vector2) -> void:
	p.z_index = 20
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
