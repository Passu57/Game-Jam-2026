extends Node
## Turns on a glow shader once a color is unlocked.
## Add this as a child of something whose material uses glow_grass.gdshader
## (e.g. a TileMapLayer). The glow stays off until the chosen color comes back,
## then fades in together with the color.

## Which color group switches the glow on. Default: Blue.
@export_flags("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta") var color: int = 16
## How long the glow takes to fade in (seconds). Matches the color fade.
@export var fade_time: float = 1.5

var _material: ShaderMaterial


func _ready() -> void:
	var host := get_parent() as CanvasItem
	if host == null or not (host.material is ShaderMaterial):
		push_warning("color_glow: parent needs a ShaderMaterial with glow_grass.gdshader")
		return
	_material = host.material
	_set_glow(1.0 if ColorManager.is_unlocked(color) else 0.0)
	ColorManager.colors_unlocked.connect(_on_colors_unlocked)


func _on_colors_unlocked(mask: int) -> void:
	if mask & color:
		var tween := create_tween()
		tween.tween_method(_set_glow, 0.0, 1.0, fade_time)


func _set_glow(value: float) -> void:
	if _material:
		_material.set_shader_parameter("glow_strength", value)
