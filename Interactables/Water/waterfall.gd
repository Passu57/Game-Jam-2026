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
## Splashing droplets and mist where it lands.
@export var splash: bool = true
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

	# Droplets jumping up where the stream hits.
	_splash = CPUParticles2D.new()
	_splash.amount = 14
	_splash.lifetime = 0.5
	_splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_splash.direction = Vector2(0, -1)
	_splash.spread = 55.0
	_splash.initial_velocity_min = 30.0
	_splash.initial_velocity_max = 65.0
	_splash.gravity = Vector2(0, 260)
	_splash.scale_amount_min = 1.0
	_splash.scale_amount_max = 2.0
	_splash.emitting = false
	add_child(_splash, false, Node.INTERNAL_MODE_FRONT)

	# Soft mist drifting up from the splash.
	_mist = CPUParticles2D.new()
	_mist.amount = 10
	_mist.lifetime = 1.4
	_mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_mist.direction = Vector2(0, -1)
	_mist.spread = 40.0
	_mist.initial_velocity_min = 6.0
	_mist.initial_velocity_max = 14.0
	_mist.gravity = Vector2(0, -4)
	_mist.scale_amount_min = 2.0
	_mist.scale_amount_max = 3.0
	_mist.emitting = false
	add_child(_mist, false, Node.INTERNAL_MODE_FRONT)

	# A few drops spitting out where it leaves the rock.
	_top_spray = CPUParticles2D.new()
	_top_spray.amount = 4
	_top_spray.lifetime = 0.6
	_top_spray.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_top_spray.direction = Vector2(0, 1)
	_top_spray.spread = 35.0
	_top_spray.initial_velocity_min = 10.0
	_top_spray.initial_velocity_max = 25.0
	_top_spray.gravity = Vector2(0, 300)
	_top_spray.scale_amount_min = 1.0
	_top_spray.scale_amount_max = 1.0
	_top_spray.emitting = false
	add_child(_top_spray, false, Node.INTERNAL_MODE_FRONT)


# Colors only change from the Inspector, so they're set separately
# (not every frame).
func _update_colors() -> void:
	if _rect == null:
		return
	_material.set_shader_parameter("water_color", water_color)
	_material.set_shader_parameter("dark_color", dark_color)
	_material.set_shader_parameter("foam_color", foam_color)

	var drop_ramp := Gradient.new()
	drop_ramp.set_color(0, foam_color)
	drop_ramp.set_color(1, Color(water_color.r, water_color.g, water_color.b, 0.0))
	_splash.color_ramp = drop_ramp

	var f := foam_color
	var mist_ramp := Gradient.new()
	mist_ramp.set_color(0, Color(f.r, f.g, f.b, 0.0))
	mist_ramp.add_point(0.3, Color(f.r, f.g, f.b, 0.35))
	mist_ramp.set_color(mist_ramp.get_point_count() - 1, Color(f.r, f.g, f.b, 0.0))
	_mist.color_ramp = mist_ramp

	_top_spray.color = Color(f.r, f.g, f.b, 0.8)


func _refresh() -> void:
	if _rect == null:
		return
	var length := _length()
	visible = is_flowing
	_rect.position = Vector2(-width * 0.5, 0)
	_rect.size = Vector2(width, length)
	_material.set_shader_parameter("rect_size", _rect.size)
	_material.set_shader_parameter("reveal", reveal)
	_material.set_shader_parameter("speed", flow_speed)

	var landed := is_flowing and reveal >= length
	_splash.position = Vector2(0, length - 1.0)
	_splash.emission_rect_extents = Vector2(width * 0.5, 1)
	_splash.emitting = splash and landed

	_mist.position = Vector2(0, length - 3.0)
	_mist.emission_rect_extents = Vector2(width * 0.5 + 4.0, 2)
	_mist.emitting = splash and landed

	_top_spray.position = Vector2(0, 1)
	_top_spray.emission_rect_extents = Vector2(width * 0.5, 1)
	_top_spray.emitting = is_flowing
