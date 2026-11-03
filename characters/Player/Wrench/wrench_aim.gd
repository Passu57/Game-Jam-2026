extends Node2D
## Draws the dotted aiming arc while the throw button is held.
## The player fills in `points` (world positions) and `hit` each frame.

## Color of the dots.
@export var dot_color: Color = Color(1, 1, 1, 0.9)
## Draw a dot every N simulated steps (bigger = more space between dots).
@export var dot_every: int = 3
## Size of the dots.
@export var dot_radius: float = 1.2

var points: PackedVector2Array = PackedVector2Array()
## True if the arc ends on something solid (draws a ring there).
var hit: bool = false


func _ready() -> void:
	top_level = true  # draw in world space, not following the player's flip
	global_position = Vector2.ZERO
	z_index = 20


func show_arc(new_points: PackedVector2Array, ends_on_hit: bool) -> void:
	points = new_points
	hit = ends_on_hit
	visible = true
	queue_redraw()


func hide_arc() -> void:
	visible = false
	points.clear()


func _draw() -> void:
	var count := points.size()
	if count == 0:
		return
	for i in range(0, count, dot_every):
		# Dots fade out the further along the arc they are.
		var c := dot_color
		c.a *= lerpf(1.0, 0.35, float(i) / count)
		draw_circle(points[i], dot_radius, c)
	if hit:
		var end := points[count - 1]
		draw_arc(end, 3.5, 0.0, TAU, 16, dot_color, 1.0)
