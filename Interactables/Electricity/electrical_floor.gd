extends StaticBody2D
## Electrified puddle. While powered, touching the water shocks the player:
## they flash, freeze for a moment and respawn at the level's SpawnPoint.
## Jump over it! Can be switched off (e.g. by a button or a fixed machine)
## with turn_off(), which shows calm water and makes it safe.

## Emitted when the player touches the powered water.
signal player_shocked(player: Node2D)

## Is the electricity on? Untick to make the puddle safe.
@export var powered: bool = true:
	set(value):
		powered = value
		if is_node_ready():
			_update_visual()

## How long the player is frozen (flashing) before respawning, in seconds.
@export var shock_time: float = 0.4

## Frame of the sprite sheet that shows calm water (power off).
const OFF_FRAME := 8

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var hazard: Area2D = $Hazard

var _shocking := false


func _ready() -> void:
	hazard.body_entered.connect(_on_hazard_body_entered)
	_update_visual()
	# Start each puddle at a random point so several side by side don't sync up.
	if powered:
		anim.seek(randf() * anim.current_animation_length, true)


func turn_on() -> void:
	powered = true


func turn_off() -> void:
	powered = false


func _update_visual() -> void:
	if powered:
		anim.play("Zap")
	else:
		anim.stop()
		sprite.frame = OFF_FRAME


func _on_hazard_body_entered(body: Node2D) -> void:
	if powered and not _shocking and body is CharacterBody2D:
		_shock(body)


func _shock(player: CharacterBody2D) -> void:
	_shocking = true
	player_shocked.emit(player)

	# If the player has its own reaction (e.g. losing a life), let it handle it.
	if player.has_method("on_shocked"):
		player.on_shocked(self)
		_shocking = false
		return

	# Default: freeze + electric flash, then respawn.
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var tween := create_tween()
	for i in 3:
		tween.tween_property(player, "modulate", Color(0.6, 1.6, 2.0), shock_time / 6.0)
		tween.tween_property(player, "modulate", Color(1, 1, 1), shock_time / 6.0)
	await tween.finished

	if is_instance_valid(player):
		player.global_position = _get_respawn_position(player)
		player.velocity = Vector2.ZERO
		player.set_physics_process(true)
	_shocking = false


func _get_respawn_position(player: Node2D) -> Vector2:
	var level := get_tree().current_scene
	var spawn := level.get_node_or_null("SpawnPoint") if level else null
	if spawn is Node2D:
		return spawn.global_position
	return player.global_position + Vector2(-48, -32)  # fallback: step back
