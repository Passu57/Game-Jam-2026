@tool
extends Node2D
## Laser obstacle. The beam fires to the RIGHT of the node (rotate the node
## to aim it: 90 = down, 180 = left, -90 = up). Touching the beam kills the robot.
##
## LEVER: drag this laser into a lever's "Target". Flipping the lever turns
## the laser off (or on, if "Lever Turns Off" is unticked).
## TIMING: tick "Use Timer" to make it blink on/off by itself. Give several
## lasers different "Time Offset"s to make them take turns.

## Beam length in pixels (from the emitter to the far end).
@export_range(16, 1000, 1) var length: float = 96.0:
	set(value):
		length = value
		queue_redraw()
## Stop the beam at walls (and boxes) instead of always using "Length".
## Pushing a box into the beam can then block it!
@export var stop_at_walls: bool = false
## Draw a receiver at the far end of the beam.
@export var show_receiver: bool = true:
	set(value):
		show_receiver = value
		queue_redraw()

@export_group("Unlock")
## The laser only works once this color is unlocked (Red by default).
## Before that it's dark and harmless. Untick everything to have it on
## from the start.
@export_flags("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta") var required_color: int = 1
## When the color unlocks, it flickers this long before the beam fires (seconds).
@export var power_up_time: float = 0.7
## Testing only: power up as if the color just unlocked when the level starts.
## Untick before shipping!
@export var test_power_up_on_start: bool = false

@export_group("Lever")
## Is the laser switched on at the start?
@export var starts_on: bool = true
## A lever flipped ON turns the laser OFF (and back on when flipped off).
@export var lever_turns_off: bool = true

@export_group("Timing")
## Blink on and off by itself.
@export var use_timer: bool = false
## How long the beam stays on (seconds).
@export var on_time: float = 2.0
## How long the beam stays off (seconds).
@export var off_time: float = 1.5
## Shifts the timing, so lasers next to each other can take turns (seconds).
@export var time_offset: float = 0.0
## A thin flickering line warns the player this long before it turns on.
@export var warning_time: float = 0.45

@export_group("Look")
@export var beam_color: Color = Color(1.0, 0.18, 0.18):
	set(value):
		beam_color = value
		queue_redraw()
## Beam thickness in pixels.
@export_range(1, 8, 1) var beam_width: int = 2:
	set(value):
		beam_width = value
		queue_redraw()

## Emitted when the beam turns on / off.
signal switched(active: bool)

const EMITTER := preload("res://Interactables/Laser/laser_emitter.png")
const BEAM_START := 7.0   # where the beam leaves the emitter's lens
const FRAME := 16.0

## Switched on (by default / by the lever). The timer can still blink it.
var powered: bool = true
## Is the beam actually deadly right now?
var active: bool = true

var _time: float = 0.0
var _warning: bool = false
## False until the required color is unlocked.
var _color_ok: bool = true
var _power_up_left: float = 0.0
var _beam_end: float = 96.0   # where the beam actually ends (walls)
var _hit_wall: bool = false
var _area: Area2D
var _shape: RectangleShape2D
var _shape_node: CollisionShape2D
var _sparks: CPUParticles2D


func _ready() -> void:
	powered = starts_on
	_beam_end = length
	if Engine.is_editor_hint():
		return
	# Dead until its color comes back.
	if required_color != 0 and not ColorManager.is_unlocked(required_color):
		_color_ok = false
		ColorManager.colors_unlocked.connect(_on_colors_unlocked)
		if test_power_up_on_start:
			_on_colors_unlocked(required_color)
	_area = Area2D.new()
	_area.monitorable = false
	_area.collision_layer = 0
	_area.collision_mask = 1
	_shape = RectangleShape2D.new()
	_shape_node = CollisionShape2D.new()
	_shape_node.shape = _shape
	_area.add_child(_shape_node)
	add_child(_area, false, Node.INTERNAL_MODE_FRONT)

	_sparks = CPUParticles2D.new()
	_sparks.amount = 8
	_sparks.lifetime = 0.3
	_sparks.direction = Vector2(-1, 0)
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 25.0
	_sparks.initial_velocity_max = 60.0
	_sparks.gravity = Vector2(0, 150)
	_sparks.scale_amount_min = 1.0
	_sparks.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(beam_color.r, beam_color.g, beam_color.b, 0.0))
	_sparks.color_ramp = g
	_sparks.emitting = false
	add_child(_sparks, false, Node.INTERNAL_MODE_FRONT)
	_update_state()


func _on_colors_unlocked(mask: int) -> void:
	if mask & required_color and not _color_ok:
		_color_ok = true
		_power_up_left = power_up_time  # flicker a moment, then fire


# --- Lever / script controls ----------------------------------------------

## Called by a lever flipped ON.
func on() -> void:
	set_powered(not lever_turns_off)


## Called by a lever flipped OFF.
func off() -> void:
	set_powered(lever_turns_off)


## Switch the laser on (true) or off (false).
func set_powered(value: bool) -> void:
	powered = value
	_update_state()


func toggle() -> void:
	set_powered(not powered)


# --- Running ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_power_up_left = maxf(_power_up_left - delta, 0.0)
	_update_state()
	_update_beam_end()

	# Hitbox along the beam.
	var beam_len := maxf(_beam_end - BEAM_START, 1.0)
	_shape.size = Vector2(beam_len, float(beam_width) + 2.0)
	_shape_node.position = Vector2(BEAM_START + beam_len * 0.5, 0)
	_area.monitoring = active

	if active:
		for body in _area.get_overlapping_bodies():
			if body.has_method("die") and body.get("is_dead") != true:
				body.die(Color(2.2, 0.4, 0.4))

	_sparks.position = Vector2(_beam_end, 0)
	_sparks.emitting = active and (_hit_wall or not show_receiver)
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_beam_end = length
		queue_redraw()


func _update_state() -> void:
	var was := active
	_warning = false
	if not _color_ok:
		active = false  # its color isn't unlocked yet: dark and harmless
	elif not powered:
		active = false
	elif _power_up_left > 0.0:
		active = false
		_warning = true  # just unlocked: flicker before the beam fires
	elif use_timer and on_time + off_time > 0.0:
		var cycle := on_time + off_time
		var t := fposmod(_time + time_offset, cycle)
		active = t < on_time
		_warning = not active and t >= cycle - warning_time
	else:
		active = true
	if active != was:
		switched.emit(active)


# With "Stop At Walls": the beam ends at the first wall or box in its way.
func _update_beam_end() -> void:
	_hit_wall = false
	_beam_end = length
	if not stop_at_walls:
		return
	var space := get_world_2d().direct_space_state
	var from := to_global(Vector2(BEAM_START, 0))
	var to := to_global(Vector2(length, 0))
	var exclude: Array[RID] = []
	for i in 4:
		var q := PhysicsRayQueryParameters2D.create(from, to, 1, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return
		var col: Object = hit.collider
		if col != null and col.has_method("die"):
			# The robot doesn't block the beam - look past it.
			exclude.append(hit.rid)
			continue
		_beam_end = to_local(hit.position).x
		_hit_wall = true
		return


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	var lit := active or _warning or Engine.is_editor_hint()
	var src := Rect2(FRAME if lit else 0.0, 0, FRAME, FRAME)
	var end_x := _beam_end
	var receiver := show_receiver and not _hit_wall
	var beam_end := end_x - (BEAM_START if receiver else 0.0)

	var shown := active or Engine.is_editor_hint()
	if shown and beam_end > BEAM_START:
		var t := Time.get_ticks_msec() / 1000.0
		var flick := 0.85 + 0.15 * sin(t * 38.0) * sin(t * 13.0)
		var w := float(beam_width)
		var y0 := -floorf(w * 0.5)
		var seg := beam_end - BEAM_START
		# Soft outer glow, the colored beam, then a bright core.
		draw_rect(Rect2(BEAM_START, y0 - 2.0, seg, w + 4.0),
			Color(beam_color.r, beam_color.g, beam_color.b, 0.22 * flick))
		draw_rect(Rect2(BEAM_START, y0 - 1.0, seg, w + 2.0),
			Color(beam_color.r, beam_color.g, beam_color.b, 0.55 * flick))
		draw_rect(Rect2(BEAM_START, y0, seg, w), Color(beam_color.r, beam_color.g, beam_color.b, 1.0))
		if w >= 2.0:
			draw_rect(Rect2(BEAM_START, y0 + floorf(w * 0.5), seg, 1.0),
				Color(1, 0.9, 0.9, 0.9 * flick))
	elif _warning:
		# Warning: a thin dashed line that flickers, no damage yet.
		var t2 := Time.get_ticks_msec() / 1000.0
		if fmod(t2 * 14.0, 1.0) < 0.6:
			var x := BEAM_START
			while x < beam_end:
				draw_rect(Rect2(x, 0, minf(3.0, beam_end - x), 1.0),
					Color(beam_color.r, beam_color.g, beam_color.b, 0.7))
				x += 6.0

	# Emitter at the start.
	draw_texture_rect_region(EMITTER, Rect2(-FRAME * 0.5, -FRAME * 0.5, FRAME, FRAME), src)
	# Receiver at the end (the same device, facing back).
	if receiver:
		draw_set_transform(Vector2(end_x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(EMITTER, Rect2(-FRAME * 0.5, -FRAME * 0.5, FRAME, FRAME), src)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
