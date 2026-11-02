extends StaticBody2D
@onready var sprite_2d: Sprite2D = $Sprite2D

@export var scene_to_open: StaticBody2D = null
@export var toggle: bool = true
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func on() -> void:
	sprite_2d.frame = 95
	if scene_to_open != null:
		scene_to_open.on()
	pass

func off() -> void:
	sprite_2d.frame = 94
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_area_2d_body_entered(body: Node2D) -> void:
	on()
	pass # Replace with function body.


func _on_area_2d_body_exited(body: Node2D) -> void:
	if toggle == false:
		off()
	pass # Replace with function body.
