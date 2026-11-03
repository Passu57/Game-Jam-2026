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

## Electricity only exists once Yellow is restored. Until then, even a
## powered floor is just calm, safe water. Untick for a floor that's
## dangerous from the very start.
@export var needs_yellow: bool = true

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
	ColorManager.colors_unlocked.connect(_on_colors_unlocked)
	_update_visual()


func turn_on() -> void:
	powered = true


func turn_off() -> void:
	powered = false


## True when the floor actually zaps: switched on AND the world has power.
func is_live() -> bool:
	if not powered:
		return false
	return not needs_yellow or ColorManager.is_unlocked(ColorManager.YELLOW)


func _on_colors_unlocked(_mask: int) -> void:
	_update_visual()


func _update_visual() -> void:
	var was_playing := anim.is_playing()
	if is_live():
		anim.play("Zap")
		# Start each puddle at a random point so several side by side don't sync up.
		if not was_playing:
			anim.seek(randf() * anim.current_animation_length, true)
		# Power just came on while someone stands in it? Zap them.
		_shock_anyone_inside()
	else:
		anim.stop()
		sprite.frame = OFF_FRAME


func _shock_anyone_inside() -> void:
	if not is_inside_tree():
		return
	for body in hazard.get_overlapping_bodies():
		_on_hazard_body_entered(body)


func _on_hazard_body_entered(body: Node2D) -> void:
	if is_live() and not _shocking and body is CharacterBody2D:
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
