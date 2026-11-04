@tool
extends Node2D
## Water geyser vent. A jet of water shoots up and carries the player with it.
## Put the node's position on TOP of the floor, in the middle of the vent.
##
## Two kinds (pick "Mode" in the Inspector):
##   AUTO   - fires by itself on a rhythm. Open grate that bubbles while idle
##            and rumbles right before it fires.
##   WRENCH - sealed with a valve wheel, hazard stripes and a floating wrench
##            icon. Hit it with the thrown wrench to make it fire.
## Both stay dry until Blue (water) has been restored.

enum Mode { AUTO, WRENCH }

## AUTO fires by itself. WRENCH waits for a wrench hit.
@export var mode: Mode = Mode.AUTO:
	set(value):
		mode = value
		queue_redraw()
## How high the water jet reaches (pixels). The player keeps flying a bit
## higher after leaving the top.
@export var column_height: float = 160.0:
	set(value):
		column_height = value
		queue_redraw()
		_layout()
## How fast the jet carries the player up (pixels per second).
@export var lift_speed: float = 260.0
## How quickly the player reaches that speed. Higher = snappier.
@export var lift_accel: float = 2200.0
## Which color brings the water back. Default: Blue.
@export_flags("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta") var required_color: int = 16
## Testing only: work even before the color is unlocked.
@export var test_ignore_color: bool = false

@export_group("Auto Timing")
## Seconds of calm between bursts.
@export var rest_time: float = 1.4
## Seconds of rumbling (warning) before it fires.
@export var warn_time: float = 0.7
## Seconds the jet stays up.
@export var burst_time: float = 1.8
## Shift this vent's rhythm so several vents don't fire together (seconds).
@export var start_offset: float = 0.0

@export_group("Wrench")
## Seconds the jet stays up after a wrench hit.
@export var wrench_burst_time: float = 3.0
@export_group("")

const COLUMN_WIDTH := 14.0
const SHADER := preload("res://Interactables/Geyser/geyser_column.gdshader")
const WRENCH_ICON := preload("res://characters/Player/Wrench/Wrench_Item.png")

enum State { IDLE, WARN, BURST }

var _state: State = State.IDLE
var _timer: float = 0.0
var _jet: float = 0.0          # 0..1, how far up the jet currently reaches
var _time: float = 0.0

var _column: ColorRect
var _material: ShaderMaterial
var _lift: Area2D
var _lift_shape: RectangleShape2D
var _lift_shape_node: CollisionShape2D
var _spray: CPUParticles2D
var _splash: CPUParticles2D
var _bubbles: CPUParticles2D


func _ready() -> void:
	_build()
	_timer = -start_offset
	_layout()


## True once the water is back (or when testing).
func is_powered() -> bool:
	if Engine.is_editor_hint():
		return true
	return test_ignore_color or ColorManager.is_unlocked(required_color)


## The thrown wrench calls this when it hits the vent.
func on_wrench_hit(_wrench: Node) -> void:
	if mode != Mode.WRENCH:
		return
	if not is_powered():
		_puff_dust()  # dry clank, nothing happens yet
		return
	if _state == State.BURST:
		_timer = 0.0  # hit again: keep it going longer
	elif _state == State.IDLE:
		_state = State.WARN
		_timer = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var powered := is_powered()
	_timer += delta

	if not powered:
		_state = State.IDLE
	elif mode == Mode.AUTO:
		match _state:
			State.IDLE:
				if _timer >= rest_time:
					_state = State.WARN
					_timer = 0.0
			State.WARN:
				if _timer >= warn_time:
					_state = State.BURST
					_timer = 0.0
			State.BURST:
				if _timer >= burst_time:
					_state = State.IDLE
					_timer = 0.0
	else:
		match _state:
			State.WARN:
				if _timer >= 0.3:
					_state = State.BURST
					_timer = 0.0
			State.BURST:
				if _timer >= wrench_burst_time:
					_state = State.IDLE
					_timer = 0.0

	# Grow fast, shrink a bit slower. A tiny spurt while warning.
	var target := 0.0
	if _state == State.BURST:
		target = 1.0
	elif _state == State.WARN:
		target = 0.06
	var rate := 6.0 if target > _jet else 2.5
	_jet = move_toward(_jet, target, rate * delta)

	_bubbles.emitting = powered and mode == Mode.AUTO and _state != State.BURST
	_bubbles.speed_scale = 2.0 if _state == State.WARN else 1.0
	_layout()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _jet < 0.25:
		return
	for body in _lift.get_overlapping_bodies():
		if body is CharacterBody2D:
			body.velocity.y = move_toward(body.velocity.y, -lift_speed, lift_accel * delta)
			# Riding a geyser gives the double jump back.
			if "_air_jumps_left" in body and "max_air_jumps" in body:
				body._air_jumps_left = body.max_air_jumps


func _build() -> void:
	z_index = 9
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_column = ColorRect.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.material = _material
	_column.show_behind_parent = true  # jet comes out from behind the vent's mouth
	add_child(_column)

	# Lifts the player. Only detects, never blocks.
	_lift = Area2D.new()
	_lift.collision_layer = 0
	_lift.collision_mask = 1
	_lift.monitorable = false
	_lift_shape = RectangleShape2D.new()
	_lift_shape_node = CollisionShape2D.new()
	_lift_shape_node.shape = _lift_shape
	_lift.add_child(_lift_shape_node)
	add_child(_lift)

	# Hitbox the wrench can hit (on the vent itself).
	var hitbox := Area2D.new()
	hitbox.collision_layer = 1
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var hit_shape := RectangleShape2D.new()
	hit_shape.size = Vector2(28, 30)  # covers the base and the valve wheel
	var hit_node := CollisionShape2D.new()
	hit_node.shape = hit_shape
	hit_node.position = Vector2(0, -15)
	hitbox.add_child(hit_node)
	add_child(hitbox)

	_spray = _make_particles(16, 0.6, Vector2(0, -1), 70.0, 400.0, 40.0, 95.0)
	_splash = _make_particles(10, 0.4, Vector2(0, -1), 85.0, 320.0, 25.0, 60.0)
	_splash.position = Vector2(0, -4)
	_bubbles = _make_particles(4, 0.55, Vector2(0, -1), 20.0, 120.0, 12.0, 28.0)
	_splash.position = Vector2(0, -10)
	_bubbles.position = Vector2(0, -10)  # out of the grate's mouth
	_bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bubbles.emission_rect_extents = Vector2(5, 0.5)


func _make_particles(amount: int, life: float, dir: Vector2, spread: float,
		grav: float, vmin: float, vmax: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2(0, grav)
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.92, 0.96, 1.0, 1.0))
	ramp.set_color(1, Color(0.45, 0.62, 1.0, 0.0))
	p.color_ramp = ramp
	p.emitting = false
	add_child(p)
	return p


func _layout() -> void:
	if _column == null:
		return
	var h := column_height * _jet
	_column.visible = h >= 1.0
	_column.position = Vector2(-COLUMN_WIDTH * 0.5, -h)
	_column.size = Vector2(COLUMN_WIDTH, maxf(h, 1.0))
	_material.set_shader_parameter("rect_size", _column.size)
	_material.set_shader_parameter("strength", clampf(_jet * 4.0, 0.0, 1.0))

	_lift_shape.size = Vector2(COLUMN_WIDTH + 4.0, maxf(h, 1.0))
	_lift_shape_node.position = Vector2(0, -maxf(h, 1.0) * 0.5)
	_lift_shape_node.disabled = h < 4.0

	_spray.position = Vector2(0, -h)
	_spray.emitting = _jet > 0.3
	_splash.emitting = _jet > 0.3


# Dry vent hit by the wrench: a little grey puff.
func _puff_dust() -> void:
	var p := _make_particles(8, 0.4, Vector2(0, -1), 60.0, 80.0, 15.0, 35.0)
	p.position = Vector2(0, -8)
	p.one_shot = true
	p.explosiveness = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.7, 0.7, 0.7, 0.9))
	ramp.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	p.color_ramp = ramp
	p.emitting = true
	p.finished.connect(p.queue_free)


# --- Drawing the vent (pixel-art sprites) --------------------------------
# geyser_vents.png holds 4 frames of 32x32:
#   0, 1 = auto vent (water shimmering in the grate)
#   2, 3 = wrench vent (valve wheel in two spoke poses, swapped to "spin")

const VENTS := preload("res://Interactables/Geyser/geyser_vents.png")
const FRAME := Vector2(32, 32)


func _draw() -> void:
	var frame := 0
	if mode == Mode.AUTO:
		# Shimmer slowly while idle, fast while rumbling.
		var speed := 10.0 if _state == State.WARN else 3.0
		frame = int(_time * speed) % 2 if is_powered() else 0
	else:
		# The wheel spins (swaps spoke pose) while the vent is open.
		frame = 2
		if _state != State.IDLE:
			frame = 2 + int(_time * 16.0) % 2

	# Rumble: shake 1 pixel sideways right before firing.
	var shake := 0.0
	if _state == State.WARN:
		shake = 1.0 if int(_time * 30.0) % 2 == 0 else -1.0

	var src := Rect2(Vector2(frame * FRAME.x, 0), FRAME)
	var dst := Rect2(Vector2(-16 + shake, -32), FRAME)
	draw_texture_rect_region(VENTS, dst, src)

	# Wrench vent: your wrench bobs above it while it waits for a hit.
	if mode == Mode.WRENCH and _state == State.IDLE:
		var bob := roundf(sin(_time * 3.0) * 1.5)
		var blink := 0.7 + 0.3 * sin(_time * 3.0)
		draw_texture(WRENCH_ICON, Vector2(-4, -38 + bob), Color(1, 1, 1, blink))

	# Editor helper: show how high the jet reaches.
	if Engine.is_editor_hint():
		draw_rect(Rect2(-COLUMN_WIDTH * 0.5, -column_height, COLUMN_WIDTH, column_height),
			Color(0.5, 0.7, 1.0, 0.5), false, 1.0)
