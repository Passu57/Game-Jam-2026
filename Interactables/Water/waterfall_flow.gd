@tool
extends Node2D
## A waterfall that starts flowing once a color (Blue by default) is unlocked,
## then keeps flowing forever.
##
## HOW TO USE: put this node where the water pours out (top center), e.g.
## right under a rock ceiling. Drag the PoolWater node into "Pool" and the
## waterfall will always land on the pool's water surface (it gets shorter
## as the pool fills up). Without a pool it falls "Fallback Height" pixels.

## The pool it pours into (optional).
@export var pool: Node2D = null:
	set(value):
		pool = value
		_refresh()
## Width of the stream in pixels.
@export_range(4, 64, 1) var width: int = 12:
	set(value):
		width = value
		_refresh()
## How far it falls when no pool is set (pixels).
@export var fallback_height: float = 120.0:
	set(value):
		fallback_height = value
		_refresh()
## Which color makes it flow. Default: Blue.
@export_flags("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta") var required_color: int = 16
## Wait this long after the color unlocks before the water starts (seconds).
@export var start_delay: float = 0.2
## How fast the first water falls down when it starts (pixels/second).
@export var start_fall_speed: float = 220.0
## Testing only: start flowing when the level starts. Untick before shipping!
@export var test_flow_on_start: bool = false

@export_group("Look")
## Speed of the falling streaks (pixels per second).
@export var flow_speed: float = 70.0:
	set(value):
		flow_speed = value
		_refresh()
@export var water_color: Color = Color(0.30, 0.48, 0.98, 0.78):
	set(value):
		water_color = value
		_update_colors()
@export var dark_color: Color = Color(0.12, 0.22, 0.66, 0.85):
	set(value):
		dark_color = value
		_update_colors()
@export var foam_color: Color = Color(0.82, 0.90, 1.0, 0.95):
	set(value):
		foam_color = value
		_update_colors()
## Splashing droplets, mist and foam where it lands.
@export var splash: bool = true
## How big the splash/mist/foam is (1 = normal, 2 = twice as big).
@export_range(0.25, 3.0, 0.05) var splash_size: float = 1.0:
	set(value):
		splash_size = value
		_configure_splash()
@export_group("")

const SHADER := preload("res://Interactables/Water/waterfall.gdshader")

## Is the water flowing (or starting to)?
var is_flowing: bool = false
## How far down the water has reached so far (pixels from the top).
var reveal: float = 0.0

var _rect: ColorRect
var _material: ShaderMaterial
var _splash: CPUParticles2D
var _mist: CPUParticles2D
var _foam_left: CPUParticles2D
var _foam_right: CPUParticles2D
var _top_spray: CPUParticles2D
var _start_timer: float = -1.0


func _ready() -> void:
	_build()
	_update_colors()
	if Engine.is_editor_hint():
		is_flowing = true
		reveal = 99999.0  # show it fully in the editor so it's easy to place
	else:
		ColorManager.colors_unlocked.connect(_on_colors_unlocked)
		if ColorManager.is_unlocked(required_color):
			is_flowing = true
			reveal = 99999.0
		elif test_flow_on_start:
			_on_colors_unlocked(required_color)
	_refresh()


func _on_colors_unlocked(mask: int) -> void:
	if mask & required_color and not is_flowing and _start_timer < 0.0:
		_start_timer = start_delay


func _process(delta: float) -> void:
	if _start_timer >= 0.0:
		_start_timer -= delta
		if _start_timer < 0.0:
			is_flowing = true
			reveal = 0.0
	if is_flowing and reveal < _length():
		reveal += start_fall_speed * delta
	_refresh()


## How long the stream is right now (down to the pool's surface if set).
func _length() -> float:
	if is_instance_valid(pool) and pool.has_method("surface_y"):
		return maxf(4.0, pool.surface_y() - global_position.y)
	return fallback_height


func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect, false, Node.INTERNAL_MODE_FRONT)

	# Splash effects draw ABOVE the pool's water (pool is z 10, we're z 9),
	# otherwise the water covers them.
	_splash = _new_particles()
	_mist = _new_particles()
	_foam_left = _new_particles()
	_foam_right = _new_particles()

	# A few drops spitting out where it leaves the rock.
	_top_spray = _new_particles()
	_top_spray.z_index = 0
	_top_spray.amount = 4
	_top_spray.lifetime = 0.6
	_top_spray.direction = Vector2(0, 1)
	_top_spray.spread = 35.0
	_top_spray.initial_velocity_min = 10.0
	_top_spray.initial_velocity_max = 25.0
	_top_spray.gravity = Vector2(0, 300)

	_configure_splash()


func _new_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.z_index = 3  # relative: 9 + 3 = 12, above the pool water
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	add_child(p, false, Node.INTERNAL_MODE_FRONT)
	return p


# Sizes/amounts of the splash effects (scaled by splash_size).
func _configure_splash() -> void:
	if _splash == null or _foam_left == null:
		return
	var s := splash_size

	# Droplets jumping up where the stream hits.
	_splash.amount = maxi(4, int(30 * s))
	_splash.lifetime = 0.7
	_splash.direction = Vector2(0, -1)
	_splash.spread = 60.0
	_splash.initial_velocity_min = 40.0 * sqrt(s)
	_splash.initial_velocity_max = 95.0 * sqrt(s)
	_splash.gravity = Vector2(0, 300)
	_splash.scale_amount_min = 1.0
	_splash.scale_amount_max = 2.0 + s

	# Big soft mist cloud rolling up from the impact.
	_mist.amount = maxi(4, int(28 * s))
	_mist.lifetime = 1.8
	_mist.direction = Vector2(0, -1)
	_mist.spread = 70.0
	_mist.initial_velocity_min = 8.0 * s
	_mist.initial_velocity_max = 22.0 * s
	_mist.damping_min = 4.0
	_mist.damping_max = 8.0
	_mist.gravity = Vector2(0, -6)
	_mist.scale_amount_min = 3.0 * s
	_mist.scale_amount_max = 6.0 * s
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.0))
	_mist.scale_amount_curve = grow

	# White foam spreading out across the surface, both ways.
	for side: float in [-1.0, 1.0]:
		var f: CPUParticles2D = _foam_left if side < 0.0 else _foam_right
		f.amount = maxi(4, int(18 * s))
		f.lifetime = 1.3
		f.direction = Vector2(side, -0.05)
		f.spread = 6.0
		f.initial_velocity_min = 10.0 * s
		f.initial_velocity_max = 34.0 * s
		f.damping_min = 12.0
		f.damping_max = 22.0
		f.gravity = Vector2.ZERO
		f.scale_amount_min = 2.0
		f.scale_amount_max = 2.0 + 2.0 * s


# Colors only change from the Inspector, so they're set separately
# (not every frame).
func _update_colors() -> void:
	if _rect == null or _foam_left == null:
		return
	_material.set_shader_parameter("water_color", water_color)
	_material.set_shader_parameter("dark_color", dark_color)
	_material.set_shader_parameter("foam_color", foam_color)

	var drop_ramp := Gradient.new()
	drop_ramp.set_color(0, Color(1, 1, 1, 1))
	drop_ramp.add_point(0.4, foam_color)
	drop_ramp.set_color(drop_ramp.get_point_count() - 1, Color(foam_color.r, foam_color.g, foam_color.b, 0.0))
	_splash.color_ramp = drop_ramp

	var f := foam_color
	var mist_ramp := Gradient.new()
	mist_ramp.set_color(0, Color(f.r, f.g, f.b, 0.0))
	mist_ramp.add_point(0.25, Color(f.r, f.g, f.b, 0.55))
	mist_ramp.set_color(mist_ramp.get_point_count() - 1, Color(f.r, f.g, f.b, 0.0))
	_mist.color_ramp = mist_ramp

	var foam_ramp := Gradient.new()
	foam_ramp.set_color(0, Color(1, 1, 1, 0.95))
	foam_ramp.add_point(0.5, Color(f.r, f.g, f.b, 0.8))
	foam_ramp.set_color(foam_ramp.get_point_count() - 1, Color(f.r, f.g, f.b, 0.0))
	_foam_left.color_ramp = foam_ramp
	_foam_right.color_ramp = foam_ramp

	_top_spray.color = Color(f.r, f.g, f.b, 0.8)


func _refresh() -> void:
	# (_foam_left can be missing right after the script is hot-reloaded in
	# the editor; reopening the scene fixes it.)
	if _rect == null or _foam_left == null:
		return
	var length := _length()
	visible = is_flowing
	_rect.position = Vector2(-width * 0.5, 0)
	_rect.size = Vector2(width, length)
	_material.set_shader_parameter("rect_size", _rect.size)
	_material.set_shader_parameter("reveal", reveal)
	_material.set_shader_parameter("speed", flow_speed)

	var on := splash and is_flowing and reveal >= length
	_splash.position = Vector2(0, length - 1.0)
	_splash.emission_rect_extents = Vector2(width * 0.5, 1)
	_splash.emitting = on

	_mist.position = Vector2(0, length - 3.0)
	_mist.emission_rect_extents = Vector2(width * 0.5 + 4.0 * splash_size, 2.0 * splash_size)
	_mist.emitting = on

	# Foam sits on the water line, starting from the stream's edges.
	_foam_left.position = Vector2(-width * 0.25, length + 1.0)
	_foam_right.position = Vector2(width * 0.25, length + 1.0)
	_foam_left.emission_rect_extents = Vector2(width * 0.25, 1)
	_foam_right.emission_rect_extents = Vector2(width * 0.25, 1)
	_foam_left.emitting = on
	_foam_right.emitting = on

	_top_spray.position = Vector2(0, 1)
	_top_spray.emission_rect_extents = Vector2(width * 0.5, 1)
	_top_spray.emitting = is_flowing
