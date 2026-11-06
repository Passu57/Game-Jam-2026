extends Node
## Dash ability. Lives as a child of the Player ("DashAbility").
## Press "dash" (Shift) for a quick horizontal burst in the direction you're
## holding (or facing). One dash in the air until you land again.
## Leaves cyan afterimages and thruster sparks behind.
##
## Locked until GameProgress.unlock(&"dash") - e.g. from a Dash pickup.
## Tick "Needs Unlock" off to have it from the start.

## Emitted every time a dash starts.
signal dashed(direction: float)

const ABILITY := &"dash"
const ACTION := &"dash"
const SwingMomentum := preload("res://Interactables/Swing/swing_momentum.gd")
@onready var dash_sound: AudioStreamPlayer2D = $"../DashSound"

## Only works after picking up the Dash ability.
@export var needs_unlock: bool = true
## Dash speed (pixels/second).
@export var dash_speed: float = 340.0
## How long the dash lasts (seconds). Distance = speed x time.
@export var dash_time: float = 0.16
## Time before you can dash again (seconds).
@export var cooldown: float = 0.45
## How many dashes you get in the air before landing.
@export var air_dashes: int = 1
## After the dash, keep this much of its speed for a moment (0..1).
@export_range(0.0, 1.0, 0.05) var carry_after: float = 0.45

@export_group("Effect")
## Afterimage color.
@export var trail_color: Color = Color(0.4, 0.95, 1.0, 0.75)
## How often an afterimage is left behind (seconds).
@export var trail_interval: float = 0.025
## How long each afterimage takes to fade (seconds).
@export var trail_fade: float = 0.28
## Tiny camera nudge when dashing (pixels, 0 = off).
@export var shake: float = 1.5

var is_dashing: bool = false

var _player: CharacterBody2D
var _sprite: Sprite2D
var _dir: float = 1.0
var _time_left: float = 0.0
var _cooldown_left: float = 0.0
var _air_dashes_left: int = 0
var _trail_timer: float = 0.0


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	_sprite = _player.get_node_or_null("Sprite2D") as Sprite2D
	_air_dashes_left = air_dashes
	# Run after the player's own movement code.
	process_physics_priority = 50


func is_unlocked() -> bool:
	return not needs_unlock or GameProgress.has(ABILITY)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if is_dashing:
		_update_dash(delta)
		return

	if _player.is_on_floor():
		_air_dashes_left = air_dashes

	if Input.is_action_just_pressed(ACTION) and _can_dash():
		_start_dash()


func _can_dash() -> bool:
	if not is_unlocked() or _cooldown_left > 0.0:
		return false
	if _player.get("is_dead") == true:
		return false
	# Not while hanging on a swing (the swing turns the player's physics off).
	if not _player.is_physics_processing():
		return false
	return _player.is_on_floor() or _air_dashes_left > 0


func _start_dash() -> void:
	var input := Input.get_axis("move_left", "move_right")
	if input != 0.0:
		_dir = signf(input)
	elif _sprite != null:
		_dir = -1.0 if _sprite.flip_h else 1.0
	if not _player.is_on_floor():
		_air_dashes_left -= 1

	is_dashing = true
	dash_sound.play()
	_time_left = dash_time
	_trail_timer = 0.0
	SwingMomentum.stop(_player)
	# Take over movement while dashing: straight line, no gravity.
	_player.set_physics_process(false)
	if _sprite != null:
		_sprite.flip_h = _dir < 0.0
	var anim := _player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null:
		anim.play("Run")

	# Kick-off effects.
	_player.modulate = Color(1.8, 2.2, 2.4)
	var t := _player.create_tween()
	t.tween_property(_player, "modulate", Color(1, 1, 1), 0.2)
	_thruster_burst()
	if _player.is_on_floor():
		_dust_puff()
	_nudge_camera()
	_spawn_afterimage()
	dashed.emit(_dir)


func _update_dash(delta: float) -> void:
	if _player.get("is_dead") == true:
		_end_dash(false)  # died mid-dash: the respawn turns physics back on
		return
	_player.velocity = Vector2(_dir * dash_speed, 0.0)
	_player.move_and_slide()

	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = trail_interval
		_spawn_afterimage()

	_time_left -= delta
	if _time_left <= 0.0 or _player.is_on_wall():
		_end_dash(true)


## Gives back all air dashes (e.g. after a wall jump).
func refill() -> void:
	_air_dashes_left = air_dashes
	_cooldown_left = 0.0


## Stops a dash without handing movement back (e.g. a swing caught the robot).
func cancel() -> void:
	if is_dashing:
		_end_dash(false)


func _end_dash(restore: bool) -> void:
	is_dashing = false
	_cooldown_left = cooldown
	if not restore:
		return
	_player.velocity = Vector2(0.0, 0.0)
	_player.set_physics_process(true)
	if carry_after > 0.0 and not _player.is_on_wall():
		SwingMomentum.launch(_player, _dir * dash_speed * carry_after)


# --- Effects ---------------------------------------------------------------

# A faded, tinted copy of the robot's current frame left behind.
func _spawn_afterimage() -> void:
	var scene := get_tree().current_scene
	if scene == null or _sprite == null:
		return
	for src_name in ["Sprite2D", "WrenchSprite"]:
		var src := _player.get_node_or_null(src_name) as Sprite2D
		if src == null or not src.visible:
			continue
		var ghost := Sprite2D.new()
		ghost.texture = src.texture
		ghost.hframes = src.hframes
		ghost.vframes = src.vframes
		ghost.frame = src.frame
		ghost.flip_h = src.flip_h
		ghost.offset = src.offset
		ghost.centered = src.centered
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.modulate = trail_color
		ghost.z_index = _player.z_index - 1
		scene.add_child(ghost)
		ghost.global_position = src.global_position
		var t := ghost.create_tween()
		t.tween_property(ghost, "modulate:a", 0.0, trail_fade)
		t.tween_callback(ghost.queue_free)


# Sparks shooting out behind the robot, like a thruster.
func _thruster_burst() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 16
	p.lifetime = 0.35
	p.direction = Vector2(-_dir, 0)
	p.spread = 25.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.damping_min = 120.0
	p.damping_max = 200.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
	p.color_ramp = g
	_spawn(p, _player.global_position + Vector2(-_dir * 6.0, 4.0))


# Dust kicked up from the floor when dashing off the ground.
func _dust_puff() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 8
	p.lifetime = 0.45
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(4, 1)
	p.direction = Vector2(-_dir, -0.4)
	p.spread = 30.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.damping_min = 60.0
	p.damping_max = 90.0
	p.gravity = Vector2(0, -20)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.82, 0.77, 0.8))
	g.set_color(1, Color(0.85, 0.82, 0.77, 0.0))
	p.color_ramp = g
	_spawn(p, _player.global_position + Vector2(0, 16))


func _nudge_camera() -> void:
	if shake <= 0.0:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var base := cam.offset
	var t := cam.create_tween()
	t.tween_property(cam, "offset", base + Vector2(-_dir * shake, 0), 0.04)
	t.tween_property(cam, "offset", base, 0.08)


func _spawn(p: CPUParticles2D, at: Vector2) -> void:
	p.z_index = 20
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
