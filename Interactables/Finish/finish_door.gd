extends Node2D
## Level exit door.
## Walk near it and the heavy door grinds open (dust + a small camera shake).
## Once open it stays open and white sparkles drift around the doorway.
## Stand in the doorway and press E (interact) to go to the next level.
##
## HOW TO USE: drop Finish.tscn into a level with its bottom on the floor,
## then pick the next level in "Next Level" in the Inspector.

## Emitted the moment the door starts opening.
signal opened
## Emitted when the player walks through (right before the level changes).
signal entered

## The level to load when the player goes through. Empty = back to the main menu.
@export_file("*.tscn") var next_level: String = ""
## How close the player has to get before the door opens (pixels).
@export var open_distance: float = 48.0
## Animation speed of the opening (lower = heavier, slower door).
@export var open_speed: float = 0.7
## How hard the camera shakes when the door unlocks (pixels).
@export var shake_strength: float = 2.0
## How long the screen takes to fade out when going through (seconds).
@export var fade_time: float = 0.6

const MAIN_MENU := "res://UI/MainMenu/MainMenu.tscn"
const DOOR_SIZE := Vector2(18, 32)

var is_open: bool = false
var is_entering: bool = false
## The InteractHighlighter skips objects that are "fixed": we only want the
## outline once the door is actually open (and not while walking through).
var is_fixed: bool:
	get:
		return not is_open or is_entering

var _sparkles: CPUParticles2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var proximity: Area2D = $ProximityArea


func _ready() -> void:
	sprite.frame = 0
	var shape := proximity.get_node("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		# Own copy so changing open_distance on one door doesn't change the others.
		shape.shape = shape.shape.duplicate()
		(shape.shape as CircleShape2D).radius = open_distance
	proximity.body_entered.connect(_on_body_near)


func _on_body_near(body: Node) -> void:
	if is_open or not body.has_method("die"):
		return  # only the player opens it, and only once
	open()


## Opens the door (once). It stays open for the rest of the level.
func open() -> void:
	if is_open:
		return
	is_open = true
	anim.play("Open", -1, open_speed)
	opened.emit()

	# The bolt releases: a jolt of the camera and dust from the floor.
	_shake_camera()
	var feet := global_position + Vector2(0, DOOR_SIZE.y * 0.5 - 1)
	_dust(feet + Vector2(-6, 0), Vector2(-1, -0.3))
	_dust(feet + Vector2(6, 0), Vector2(1, -0.3))
	# Bits of grit shaken loose from the frame top.
	_grit(global_position + Vector2(0, -DOOR_SIZE.y * 0.5 + 2))

	# When the door is fully open, light the doorway up.
	var length := anim.get_animation("Open").length / maxf(open_speed, 0.01)
	get_tree().create_timer(length * 0.6).timeout.connect(_start_sparkles)


## Called by the player's InteractionController when E is pressed.
func interact(by: Node = null) -> void:
	if not is_open or is_entering:
		return
	is_entering = true
	entered.emit()

	# Robot steps into the light and disappears.
	if by is Node2D:
		var player := by as Node2D
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		var t := create_tween().set_parallel(true)
		t.tween_property(player, "global_position:x", global_position.x, 0.25)
		t.tween_property(player, "modulate", Color(3, 3, 3, 0), 0.45)
	_burst_light()
	_fade_and_load()


func _fade_and_load() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().root.add_child(layer)

	# Fade to white, then to black while the next level loads.
	var t := create_tween()
	t.tween_property(rect, "color", Color(1, 1, 1, 1), fade_time * 0.6)
	t.tween_property(rect, "color", Color(0, 0, 0, 1), fade_time * 0.4)
	await t.finished

	var target := next_level if next_level != "" else MAIN_MENU
	if not ResourceLoader.exists(target):
		push_warning("Finish door: next level '%s' not found, going to the main menu." % target)
		target = MAIN_MENU
	# The fade layer lives on the root, so it survives the scene change and
	# fades the new level in by itself (this door gets freed with the old level).
	var back := layer.create_tween()
	back.tween_interval(0.15)
	back.tween_property(rect, "color", Color(0, 0, 0, 0), 0.4)
	back.tween_callback(layer.queue_free)
	get_tree().change_scene_to_file(target)


# ---------------------------------------------------------------- effects

func _shake_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or shake_strength <= 0.0:
		return
	var base := cam.offset
	var t := create_tween()
	for i in 6:
		var s := shake_strength * (1.0 - float(i) / 6.0)
		t.tween_property(cam, "offset", base + Vector2(randf_range(-s, s), randf_range(-s, s)), 0.04)
	t.tween_property(cam, "offset", base, 0.05)


# Heavy grey dust rolling out along the floor.
func _dust(at: Vector2, dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 14
	p.lifetime = 0.9
	p.direction = dir
	p.spread = 25.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.damping_min = 40.0
	p.damping_max = 60.0
	p.gravity = Vector2(0, -12)  # dust slowly lifts
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(3, 1)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.4))
	p.scale_amount_curve = curve
	p.color_ramp = _gradient([Color(0.78, 0.74, 0.68, 0.9), Color(0.55, 0.52, 0.5, 0.0)])
	_spawn(p, at)


# Small specks falling from the top of the frame.
func _grit(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 8
	p.lifetime = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(8, 1)
	p.direction = Vector2(0, 1)
	p.spread = 15.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 15.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.color_ramp = _gradient([Color(0.6, 0.55, 0.5, 1.0), Color(0.45, 0.42, 0.4, 0.0)])
	_spawn(p, at)


# Soft white motes drifting up around the open doorway, forever.
func _start_sparkles() -> void:
	if _sparkles != null:
		return
	_sparkles = CPUParticles2D.new()
	_sparkles.amount = 14
	_sparkles.lifetime = 2.2
	_sparkles.preprocess = 1.0
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparkles.emission_rect_extents = Vector2(DOOR_SIZE.x * 0.5 + 4, DOOR_SIZE.y * 0.5)
	_sparkles.direction = Vector2(0, -1)
	_sparkles.spread = 30.0
	_sparkles.gravity = Vector2(0, -6)
	_sparkles.initial_velocity_min = 3.0
	_sparkles.initial_velocity_max = 9.0
	_sparkles.orbit_velocity_min = -0.05  # a lazy wobble
	_sparkles.orbit_velocity_max = 0.05
	_sparkles.scale_amount_min = 1.0
	_sparkles.scale_amount_max = 1.0
	_sparkles.color_ramp = _gradient([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0),
			Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	_sparkles.z_index = 5
	add_child(_sparkles)
	_sparkles.position = Vector2.ZERO
	_sparkles.emitting = true

	# One bright puff of light out of the doorway as it finishes opening.
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = 18
	puff.lifetime = 0.6
	puff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	puff.emission_rect_extents = Vector2(6, 12)
	puff.direction = Vector2(0, -1)
	puff.spread = 180.0
	puff.initial_velocity_min = 15.0
	puff.initial_velocity_max = 35.0
	puff.damping_min = 30.0
	puff.damping_max = 40.0
	puff.gravity = Vector2.ZERO
	puff.color_ramp = _gradient([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_spawn(puff, global_position)


# Big flash of white when the player walks through.
func _burst_light() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 30
	p.lifetime = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(6, 14)
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.damping_min = 50.0
	p.damping_max = 70.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = _gradient([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_spawn(p, global_position)


func _gradient(colors: Array[Color]) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	return g


func _spawn(p: CPUParticles2D, at: Vector2) -> void:
	p.z_index = 20
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
