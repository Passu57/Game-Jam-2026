extends Node2D
@onready var spawn_point: Marker2D = $SpawnPoint


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var player : CharacterBody2D = get_child(1)
	player.global_position = spawn_point.global_position
	player.velocity = Vector2(0, 0)
	pass # Replace with function body. 


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
