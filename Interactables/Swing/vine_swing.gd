@tool
extends Node2D
## A swinging vine (or chain). Jump into its bottom end to grab it.
##   Left / Right : pump to swing higher
##   Jump         : let go, flying off with the swing's momentum
## Letting go gives a small upward kick and refills the double jump, so you
## can fly from one swing to the next.
##
## HOW TO USE: put the node where the swing hangs from (e.g. under a ceiling)
## and set "Length". Pick "Vine" or "Chain" in "Style" - they work the same.

enum Style { VINE, CHAIN }

const ART := {
	Style.VINE: ["res://Interactables/Swing/art/vine_top.png",
		"res://Interactables/Swing/art/vine_seg.png",
		"res://Interactables/Swing/art/vine_tip.png"],
	Style.CHAIN: ["res://Interactables/Swing/art/chain_top.png",
		"res://Interactables/Swing/art/chain_seg.png",
		"res://Interactables/Swing/art/chain_tip.png"],
}
const SwingMomentum := preload("res://Interactables/Swing/swing_momentum.gd")

## Emitted when the player grabs / lets go.
signal grabbed(player: Node)
signal released(player: Node)

## Vine or chain. Only the look changes.
@export var style: Style = Style.VINE:
	set(value):
		style = value
		_load_art()
		queue_redraw()
## How long the swing is, from the anchor to the handle (pixels).
@export_range(24, 320, 1) var length: float = 72.0:
	set(value):
		length = value
		queue_redraw()

@export_group("Unlock")
## The swing only appears once this color is unlocked (Green by default).
## Untick everything to have it there from the start.
@export_flags("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta") var required_color: int = 4
## How long it takes to drop down from the ceiling (seconds).
@export var drop_time: float = 0.9
## Wait this long after the color unlocks before dropping (seconds).
@export var drop_delay: float = 0.3
## Testing only: drop as soon as the level starts. Untick before shipping!
@export var test_drop_on_start: bool = false

@export_group("Swing Feel")
## How hard left/right pumps the swing.
@export var pump_strength: float = 3.5
## How fast the swing loses speed while you hang on it (0 = never).
@export var damping: float = 0.15
## The swing can't go higher than this angle (degrees from straight down).
@export_range(20.0, 89.0, 1.0) var max_angle: float = 80.0
## Extra speed when letting go (1 = exactly the swing's speed).
@export var release_boost: float = 0.95
## Upward kick when letting go (pixels/second).
@export var release_kick: float = 110.0
## Letting go refills the double jump (if unlocked).
@export var refill_double_jump: bool = true
## After letting go you can't grab THIS swing again for this long (seconds).
## Other swings can be grabbed right away.
@export var regrab_delay: float = 0.4
## How far below the handle the robot hangs (pixels).
@export var hang_offset: float = 9.0
## How close the robot has to get to the handle to grab it (pixels).
@export var grab_radius: float = 14.0

@export_group("Idle Sway")
## How much the empty swing sways on its own (degrees). 0 = hangs still.
@export_range(0.0, 45.0, 0.5) var idle_sway: float = 6.0
## Start the level already swinging this far (degrees, + = right).
@export_range(-80.0, 80.0, 1.0) var start_angle: float = 0.0
## How much the rope bends while swinging (just for looks).
@export_range(0.0, 0.3, 0.01) var bend: float = 0.06

var angle: float = 0.0
var angular_velocity: float = 0.0
var player: CharacterBody2D = null

var _top: Texture2D
var _seg: Texture2D
var _tip: Texture2D
var _tip_local: Vector2 = Vector2.ZERO
var _tip_angle: float = 0.0
var _grab_area: Area2D
var _no_grab_until_ms: int = 0
var _time: float = 0.0
var _gravity: float = 980.0
## How much of the rope is out right now. -1 = all of it.
var _shown_length: float = -1.0


## True once the swing has fully dropped down and can be grabbed.
func is_out() -> bool:
	return _shown_length < 0.0 or _shown_length >= length * 0.9


func _visible_length() -> float:
	return length if _shown_length < 0.0 else _shown_length


func _ready() -> void:
	_load_art()
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	angle = deg_to_rad(start_angle)
	_time = randf() * 10.0
	if Engine.is_editor_hint():
		return
	# Hidden until its color is unlocked, then it drops from the ceiling.
	if required_color != 0 and not ColorManager.is_unlocked(required_color):
		_shown_length = 0.0
		ColorManager.colors_unlocked.connect(_on_colors_unlocked)
		if test_drop_on_start:
			_on_colors_unlocked(required_color)
	_grab_area = Area2D.new()
	_grab_area.monitorable = false
	_grab_area.collision_layer = 0
	_grab_area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = grab_radius
	shape.shape = circle
	_grab_area.add_child(shape)
	add_child(_grab_area, false, Node.INTERNAL_MODE_FRONT)


func _on_colors_unlocked(mask: int) -> void:
	if mask & required_color and _shown_length == 0.0:
		_drop_in()


# The rope unrolls down from the ceiling, overshoots a little and settles,
# with some leaves (or rust flakes) falling from where it was hanging.
func _drop_in() -> void:
	_shown_length = 0.001
	var t := create_tween()
	t.tween_interval(drop_delay)
	t.tween_callback(func():
		_burst(global_position + Vector2(0, 2), 14, true)
		angular_velocity = randf_range(-0.6, 0.6))
	t.tween_method(func(v: float): _shown_length = v, 0.001, length, drop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		_shown_length = -1.0
		angular_velocity += 0.8 * (1.0 if randf() < 0.5 else -1.0))  # little swing as it lands


func _load_art() -> void:
	var paths: Array = ART[style]
	_top = load(paths[0])
	_seg = load(paths[1])
	_tip = load(paths[2])


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var omega0 := sqrt(_gravity / length)  # natural swing speed

	var acc := -(_gravity / length) * sin(angle)
	var damp := damping
	if player != null:
		if not is_instance_valid(player) or player.get("is_dead") == true:
			_drop()
		else:
			# Pumping like on a playground swing: pushing in the direction
			# you're already moving adds energy, so each pass gets bigger.
			var input := Input.get_axis("move_left", "move_right")
			if input != 0.0 and (signf(input) == signf(angular_velocity) or absf(angular_velocity) < 0.4):
				acc += input * pump_strength
	if player == null:
		# Empty swing: settles down, plus a gentle push at its natural rhythm
		# so it keeps swaying a little (like wind).
		damp = 0.9
		acc += deg_to_rad(idle_sway) * damp * omega0 * sin(omega0 * _time)

	angular_velocity += acc * delta
	angular_velocity *= maxf(0.0, 1.0 - damp * delta)
	angle += angular_velocity * delta
	var limit := deg_to_rad(max_angle)
	if absf(angle) > limit:
		angle = clampf(angle, -limit, limit)
		angular_velocity = 0.0

	_update_tip()
	_grab_area.position = _tip_local

	if player != null:
		_hold_player()
		if Input.is_action_just_pressed("jump"):
			_release()
	else:
		_try_grab()
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_tip()
		queue_redraw()


# --- Grabbing & letting go ------------------------------------------------

func _try_grab() -> void:
	if Time.get_ticks_msec() < _no_grab_until_ms or not is_out():
		return
	for body in _grab_area.get_overlapping_bodies():
		if not (body is CharacterBody2D) or not body.has_method("die"):
			continue
		if body.get("is_dead") == true or body.is_on_floor():
			continue
		if not body.is_physics_processing():
			continue  # already hanging on another swing (or dying)
		_grab(body)
		return


func _grab(p: CharacterBody2D) -> void:
	player = p
	SwingMomentum.stop(p)
	p.set_physics_process(false)
	# Keep some of the robot's speed: jumping into a swing pushes it.
	var tangent := Vector2(cos(angle), -sin(angle))
	angular_velocity += p.velocity.dot(tangent) / length * 0.8
	p.velocity = Vector2.ZERO
	var anim := p.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null:
		anim.play("Jump")
		anim.seek(0.1, true)
		anim.pause()  # hold one pose while hanging
	_burst(global_position + _tip_local)
	grabbed.emit(p)


func _hold_player() -> void:
	var down := Vector2(sin(_tip_angle), cos(_tip_angle))
	player.global_position = global_position + _tip_local + down * hang_offset
	# Face the way we're swinging (or the way we're pushing).
	var input := Input.get_axis("move_left", "move_right")
	var s := player.get_node_or_null("Sprite2D") as Sprite2D
	if s != null:
		if input != 0.0:
			s.flip_h = input < 0.0
		elif absf(angular_velocity) > 0.3:
			s.flip_h = angular_velocity < 0.0


func _release() -> void:
	var p := player
	_drop()
	var tangent := Vector2(cos(angle), -sin(angle))
	var v := tangent * angular_velocity * length * release_boost
	v.y -= release_kick
	p.velocity = Vector2(0.0, v.y)
	if refill_double_jump and "_air_jumps_left" in p and "max_air_jumps" in p:
		p.set("_air_jumps_left", p.get("max_air_jumps"))
	var anim := p.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null:
		anim.play("Jump")
	# Hand control back next physics frame, so this same jump press isn't
	# also used as a double jump.
	await get_tree().physics_frame
	if is_instance_valid(p) and p.get("is_dead") != true:
		p.set_physics_process(true)
		SwingMomentum.launch(p, v.x)
	released.emit(p)


func _drop() -> void:
	_no_grab_until_ms = Time.get_ticks_msec() + int(regrab_delay * 1000.0)
	if is_instance_valid(player):
		var anim := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim != null and not anim.is_playing():
			anim.play()
	player = null


func _burst(at: Vector2, amount: int = 8, falling: bool = false) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9 if not falling else 0.6
	p.amount = amount
	p.lifetime = 0.5 if not falling else 1.2
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.gravity = Vector2(0, 160) if not falling else Vector2(0, 70)
	if falling:
		# Leaves drifting down from the ceiling, spread over the anchor.
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(8, 2)
		p.direction = Vector2(0, 1)
		p.spread = 50.0
		p.initial_velocity_min = 10.0
		p.initial_velocity_max = 30.0
		p.damping_min = 10.0
		p.damping_max = 20.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.45, 0.78, 0.3) if style == Style.VINE else Color(0.85, 0.88, 0.95)
	p.z_index = 20
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


# --- Drawing ---------------------------------------------------------------

# Walks down the rope segment by segment (bending a little while swinging)
# and remembers where the handle ends up.
func _segments() -> Array:
	var out := []
	if _seg == null:
		return out
	var shown := _visible_length()
	if shown <= 0.5:
		return out  # not dropped down yet
	var seg_h := float(_seg.get_height())
	var count := maxi(1, ceili(shown / seg_h))
	var pos := Vector2.ZERO
	for k in count:
		var t := float(k) / float(count)
		var a := angle - angular_velocity * bend * t
		var h := minf(seg_h, shown - k * seg_h)
		out.append([pos, a, h])
		pos += Vector2(sin(a), cos(a)) * h
	out.append([pos, angle - angular_velocity * bend, 0.0])
	return out


func _update_tip() -> void:
	var segs := _segments()
	if segs.is_empty():
		return
	var last: Array = segs[segs.size() - 1]
	_tip_local = last[0]
	_tip_angle = last[1]


func _draw() -> void:
	if _seg == null:
		return
	var segs := _segments()
	if segs.is_empty():
		return  # hidden until its color is unlocked
	var w := float(_seg.get_width())
	for i in segs.size() - 1:
		var s: Array = segs[i]
		draw_set_transform(s[0], -float(s[1]), Vector2.ONE)
		var h: float = s[2]
		draw_texture_rect_region(_seg, Rect2(-w * 0.5, 0, w, h), Rect2(0, 0, w, h))
	# Handle at the bottom.
	var tip: Array = segs[segs.size() - 1]
	draw_set_transform(tip[0], -float(tip[1]), Vector2.ONE)
	draw_texture(_tip, Vector2(-_tip.get_width() * 0.5, -2))
	# Anchor on top.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture(_top, Vector2(-_top.get_width() * 0.5, -4))
