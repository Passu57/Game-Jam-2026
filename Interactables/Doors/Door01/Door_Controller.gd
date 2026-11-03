extends StaticBody2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export_flags("Open Automatically", "Open via key", "Open via button", "Locked") var unlocks_condition: int = 2
@export var button_scene : StaticBody2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func on() -> void:
	animation_player.play("open")

func off() -> void:
	animation_player.play_backwards("open")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
