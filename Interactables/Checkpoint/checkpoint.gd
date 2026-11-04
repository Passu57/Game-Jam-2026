extends Area2D
## Checkpoint: a recharge station for the robot.
## Walk past it to switch it on. From then on you respawn here, and the
## station rebuilds the robot with a swirl of sparks.
##
## HOW TO USE: drop Checkpoint.tscn into a level with its bottom on the floor.
## The level needs a node called "SpawnPoint" (it already has one); the
## checkpoint moves it to itself when activated.

## Emitted when this checkpoint switches on.
signal activated

## Where the robot reappears, relative to the station's feet.
## Default: standing right next to the station.
@export var respawn_offset: Vector2 = Vector2(14, -16)
## Color of the sparks (keep it a color the level has unlocked, or it shows grey).
@export var spark_color: Color = Color(0.55, 1.0, 0.7)

# Only one checkpoint is active at a time (the most recent one).
static var _active_checkpoint: Node = null

var is_active: bool = false
var _player: Node2D = null
var _player_was_dead: bool = false
var _anim_time: float = 0.0
var _flash_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var checkpoint_sound: AudioStreamPlayer2D = $Checkpoint

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.frame = 0


func _on_body_entered(body: Node) -> void:
	if is_active or not body.has_method("die"):
		return  # only the player switches it on
	activate(body)


## Switch this checkpoint on and make it the respawn point.
func activate(player: Node2D) -> void:
	if is_instance_valid(_active_checkpoint) and _active_checkpoint != self:
		_active_checkpoint.deactivate()
	_active_checkpoint = self
	is_active = true
	_player = player
	_player_was_dead = false

	var spawn := get_tree().current_scene.get_node_or_null("SpawnPoint")
	if spawn is Node2D:
		spawn.global_position = global_position + respawn_offset

	# Boot-up: screen flash + sparks out of the antenna.
	_flash_time = 0.15
	_burst(global_position + Vector2(4, -32), 14, Vector2(0, -1), 70.0, 60.0, 120.0)
	checkpoint_sound.play()
	activated.emit()


## Called when another checkpoint takes over.
func deactivate() -> void:
	is_active = false
	sprite.frame = 0


func _process(delta: float) -> void:
	if not is_active:
		return
	_anim_time += delta

	# Screen: flash on boot/respawn, otherwise the battery blinks between frames 1 and 2.
	if _flash_time > 0.0:
		_flash_time -= delta
		sprite.frame = 3
	else:
		sprite.frame = 1 + int(_anim_time * 2.5) % 2

	# The player just came back to life here: play the rebuild effect.
	if is_instance_valid(_player) and "is_dead" in _player:
		var dead: bool = _player.is_dead
		if _player_was_dead and not dead:
			_rebuild_effect()
		_player_was_dead = dead


# Sparks swirl in from around the robot, then a bright flash: rebuilt!
func _rebuild_effect() -> void:
	var at := _player.global_position
	_flash_time = 0.25

	var gather := CPUParticles2D.new()
	gather.one_shot = true
	gather.explosiveness = 0.6
	gather.amount = 24
	gather.lifetime = 0.45
	gather.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	gather.emission_sphere_radius = 22.0
	gather.gravity = Vector2.ZERO
	gather.radial_accel_min = -260.0  # pulled towards the center
	gather.radial_accel_max = -200.0
	gather.tangential_accel_min = 60.0  # and spun around a little
	gather.tangential_accel_max = 90.0
	gather.scale_amount_min = 1.0
	gather.scale_amount_max = 2.0
	gather.color_ramp = _ramp(0.0, 1.0)
	_spawn(gather, at)

	# After they gather: a small outward flash.
	get_tree().create_timer(0.35).timeout.connect(func():
		_burst(at, 16, Vector2(0, -1), 180.0, 40.0, 90.0))

	# Robot glows brightly and fades back to normal.
	_player.modulate = Color(2.2, 2.2, 2.2)
	var tween := create_tween()
	tween.tween_property(_player, "modulate", Color(1, 1, 1), 0.45)


func _burst(at: Vector2, amount: int, dir: Vector2, spread: float,
		vmin: float, vmax: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.5
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = _ramp(1.0, 0.0)
	_spawn(p, at)


# Fades the sparks from white to the spark color and out.
func _ramp(start_alpha: float, end_alpha: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, maxf(start_alpha, 0.6)))
	g.add_point(0.4, spark_color)
	g.set_color(g.get_point_count() - 1, Color(spark_color.r, spark_color.g, spark_color.b, end_alpha))
	return g


func _spawn(p: CPUParticles2D, at: Vector2) -> void:
	p.z_index = 20
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
