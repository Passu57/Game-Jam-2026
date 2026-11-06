extends Node2D
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var level_music: AudioStreamPlayer = $SoundTrackLevel3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var player : CharacterBody2D = get_child(1)
	player.global_position = spawn_point.global_position
	player.velocity = Vector2(0, 0)
	pass # Replace with function body. 
	if level_music:
		level_music.play()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
