@tool
extends Sprite2D
## A lantern (or any lamp sprite) with a flickering flame and a soft
## pixel-art glow, like the torches.
## Only the lantern's light colors flicker; set "Glow Offset" so the glow sits
## on the glass.

const FLICKER_SHADER := preload("res://Interactables/decorations/lantern_flicker.gdshader")
const GLOW_SHADER := preload("res://Interactables/decorations/torch_glow.gdshader")
const GLOW_NAME := "LanternGlow"

@export_group("Flame")
## How much the light flickers (0 = steady).
@export_range(0.0, 0.6, 0.01) var flicker: float = 0.18:
	set(value):
		flicker = value
		_apply()
## How fast it flickers.
@export_range(1.0, 20.0, 0.5) var flicker_speed: float = 9.0:
	set(value):
		flicker_speed = value
		_apply()
## Brightness of the lit glass.
@export_range(0.5, 2.5, 0.05) var brightness: float = 1.1:
	set(value):
		brightness = value
		_apply()

@export_group("Glow")
@export var glow_enabled: bool = true:
	set(value):
		glow_enabled = value
		_apply()
## Glow color (warm lantern light by default).
@export var glow_color: Color = Color(1.0, 0.72, 0.25):
	set(value):
		glow_color = value
		_apply()
@export_range(0.0, 2.0, 0.05) var glow_strength: float = 0.9:
	set(value):
		glow_strength = value
		_apply()
## Glow size (diameter) in pixels.
@export_range(8, 200, 2) var glow_size: int = 64:
	set(value):
		glow_size = value
		_apply()
## Number of light rings (fewer = chunkier pixel look).
@export_range(1, 8) var glow_steps: int = 4:
	set(value):
		glow_steps = value
		_apply()
## Where the glow sits, relative to the sprite's center (the lantern glass).
@export var glow_offset: Vector2 = Vector2(6, 3):
	set(value):
		glow_offset = value
		_apply()

var _glow: Sprite2D = null


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	var offset_t := fmod(global_position.x * 0.37 + global_position.y * 0.11, TAU)

	var mat := material as ShaderMaterial
	if mat == null or mat.shader != FLICKER_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = FLICKER_SHADER
		mat.resource_local_to_scene = true
		material = mat
	mat.set_shader_parameter("flicker", flicker)
	mat.set_shader_parameter("flicker_speed", flicker_speed)
	mat.set_shader_parameter("flicker_offset", offset_t)
	mat.set_shader_parameter("brightness", brightness)

	var glow := _get_glow()
	glow.visible = glow_enabled
	glow.position = Vector2(-glow_offset.x if flip_h else glow_offset.x, glow_offset.y)
	glow.scale = Vector2(glow_size, glow_size)
	var gmat := glow.material as ShaderMaterial
	gmat.set_shader_parameter("glow_color", glow_color)
	gmat.set_shader_parameter("strength", glow_strength)
	gmat.set_shader_parameter("pixel_size", float(glow_size))
	gmat.set_shader_parameter("steps", glow_steps)
	gmat.set_shader_parameter("flicker", flicker * 0.6)
	gmat.set_shader_parameter("flicker_speed", flicker_speed)
	gmat.set_shader_parameter("flicker_offset", offset_t)


# The glow is made by this script (not saved in the scene), so every lantern
# gets one automatically and it never doubles up.
func _get_glow() -> Sprite2D:
	if is_instance_valid(_glow):
		return _glow
	_glow = get_node_or_null(GLOW_NAME) as Sprite2D
	if _glow == null:
		_glow = Sprite2D.new()
		_glow.name = GLOW_NAME
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_glow.texture = ImageTexture.create_from_image(img)
		_glow.show_behind_parent = true  # light behind the lantern, not over it
		var gmat := ShaderMaterial.new()
		gmat.shader = GLOW_SHADER
		_glow.material = gmat
		add_child(_glow, false, Node.INTERNAL_MODE_FRONT)
	return _glow
