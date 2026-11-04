@tool
extends Node2D
## Water that fills a pool once a color (Blue by default) is unlocked.
## It rises smoothly from the bottom instead of appearing at once.
## The robot short-circuits if it falls in (sparks + electric death).
##
## HOW TO USE: put this node at the BOTTOM-LEFT corner of the pool and set
## "Size" to the pool's width and how deep the water should get.
## Boxes with "Floats" ticked will rise on top of it.

## Width and full depth of the water, in pixels.
@export var size: Vector2 = Vector2(384, 120):
	set(value):
		size = value
		_refresh()

## Which color makes the water appear. Default: Blue.
@export_flags("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta") var required_color: int = 16
## How long the pool takes to fill up (seconds).
@export var fill_time: float = 4.0
## Wait this long after the color unlocks before filling (seconds).
@export var fill_delay: float = 0.5
## Testing only: fill the pool as soon as the level starts, without
## needing the color. Untick before you ship the game!
@export var test_fill_on_start: bool = false

@export_group("Danger")
## Falling into the water short-circuits the robot (it dies and respawns).
@export var deadly: bool = true
## How far below the surface the player's center must sink before dying
## (pixels). Stops deaths from just touching the surface or standing on a box.
@export var kill_depth: float = 6.0
## Color of the sparks that fly off the robot.
@export var spark_color: Color = Color(1.0, 0.95, 0.55)

@export_group("Look")
@export var shallow_color: Color = Color(0.30, 0.48, 0.98, 0.72):
	set(value):
		shallow_color = value
		_refresh()
@export var deep_color: Color = Color(0.08, 0.14, 0.50, 0.88):
	set(value):
		deep_color = value
		_refresh()
@export var foam_color: Color = Color(0.80, 0.88, 1.0, 0.95):
	set(value):
		foam_color = value
		_refresh()
## How tall the waves are (pixels).
@export var wave_height: float = 1.5:
	set(value):
		wave_height = value
		_refresh()
@export var wave_speed: float = 1.5:
	set(value):
		wave_speed = value
		_refresh()
## Little bubbles rising from the bottom.
@export var bubbles: bool = true
@export_group("")

const SHADER := preload("res://Interactables/Water/water.gdshader")
const WAVE_PAD := 4.0

## Current water height in pixels (0 = empty, size.y = full).
var level: float = 0.0

var _rect: ColorRect
var _material: ShaderMaterial
var _bubbles: CPUParticles2D
var _area: Area2D
var _area_shape_node: CollisionShape2D
var _area_shape: RectangleShape2D


func _ready() -> void:
	add_to_group("water")
	_build()
	if Engine.is_editor_hint():
		level = size.y  # show it full in the editor so it's easy to place
	else:
		level = size.y if ColorManager.is_unlocked(required_color) else 0.0
		ColorManager.colors_unlocked.connect(_on_colors_unlocked)
		if test_fill_on_start:
			_on_colors_unlocked(required_color)
	_refresh()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not deadly or not is_filled():
		return
	for body in _area.get_overlapping_bodies():
		# Only things that can die (the player), not boxes.
		if not body.has_method("die"):
			continue
		if body.get("is_dead") == true:
			continue
		if body.global_position.y > surface_y() + kill_depth:
			_short_circuit(body)


# The robot touches water: sparks fly, then the electric death plays.
func _short_circuit(body: Node2D) -> void:
	_spawn_sparks(body.global_position)
	# A few more crackles while it flickers.
	for i in 2:
		get_tree().create_timer(0.12 * (i + 1)).timeout.connect(
			func(): if is_instance_valid(body): _spawn_sparks(body.global_position))
	if body.has_method("on_shocked"):
		body.on_shocked(self)  # same blue-white electric flash as electric floors
	else:
		body.die()


func _spawn_sparks(at: Vector2) -> void:
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = 16
	sparks.lifetime = 0.45
	sparks.direction = Vector2(0, -1)
	sparks.spread = 80.0
	sparks.gravity = Vector2(0, 300)
	sparks.initial_velocity_min = 50.0
	sparks.initial_velocity_max = 110.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(spark_color.r, spark_color.g, spark_color.b, 0.0))
	ramp.add_point(0.3, spark_color)
	sparks.color_ramp = ramp
	sparks.z_index = 20
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)


func _on_colors_unlocked(mask: int) -> void:
	if mask & required_color and level < size.y:
		var tween := create_tween()
		tween.tween_interval(fill_delay)
		tween.tween_method(_set_level, level, size.y, fill_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_level(value: float) -> void:
	level = value
	_refresh()


## World-space height of the water surface.
func surface_y() -> float:
	return global_position.y - level


## Is this x position (world space) inside the pool?
func covers_x(x: float) -> bool:
	return x >= global_position.x and x <= global_position.x + size.x


## Is there any water yet?
func is_filled() -> bool:
	return level > 0.5


func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)

	_bubbles = CPUParticles2D.new()
	_bubbles.amount = 10
	_bubbles.lifetime = 2.0
	_bubbles.randomness = 0.5
	_bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bubbles.direction = Vector2(0, -1)
	_bubbles.spread = 8.0
	_bubbles.gravity = Vector2.ZERO
	_bubbles.initial_velocity_min = 12.0
	_bubbles.initial_velocity_max = 22.0
	_bubbles.scale_amount_min = 1.0
	_bubbles.scale_amount_max = 2.0
	_bubbles.color = Color(0.85, 0.92, 1.0, 0.7)
	_bubbles.emitting = false
	add_child(_bubbles)

	# Hitbox covering the water. It grows with the water level.
	_area = Area2D.new()
	_area.monitorable = false
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area_shape = RectangleShape2D.new()
	_area_shape_node = CollisionShape2D.new()
	_area_shape_node.shape = _area_shape
	_area.add_child(_area_shape_node)
	add_child(_area)


func _refresh() -> void:
	if _rect == null:
		return
	visible = level > 0.5
	_rect.position = Vector2(0, -level - WAVE_PAD)
	_rect.size = Vector2(size.x, level + WAVE_PAD)
	_material.set_shader_parameter("rect_size", _rect.size)
	_material.set_shader_parameter("wave_pad", WAVE_PAD)
	_material.set_shader_parameter("wave_height", wave_height)
	_material.set_shader_parameter("wave_speed", wave_speed)
	_material.set_shader_parameter("shallow_color", shallow_color)
	_material.set_shader_parameter("deep_color", deep_color)
	_material.set_shader_parameter("foam_color", foam_color)
	# Fade in over the first few pixels so it doesn't pop in.
	_material.set_shader_parameter("fade", clampf(level / 12.0, 0.0, 1.0))

	# Hitbox matches the water (at least 1 px tall so the shape stays valid).
	var h := maxf(level, 1.0)
	_area_shape.size = Vector2(size.x, h)
	_area_shape_node.position = Vector2(size.x * 0.5, -h * 0.5)

	# Bubbles start at the bottom and pop just under the surface.
	_bubbles.position = Vector2(size.x * 0.5, -2.0)
	_bubbles.emission_rect_extents = Vector2(size.x * 0.5 - 4.0, 1.0)
	var bubble_life := maxf(0.2, (level - 6.0) / 17.0)
	if absf(bubble_life - _bubbles.lifetime) > 0.25:
		_bubbles.lifetime = bubble_life
	_bubbles.emitting = bubbles and level > 12.0
