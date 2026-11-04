@tool
extends Sprite2D
## Torch with a recolorable, glowing flame.
## Pick "Flame Color" in the Inspector. Every preset's shades can be tweaked
## in its own group below (Green / Yellow / Red / Blue / Custom Colors).
## The glow takes the preset's "Light" shade.

enum FlameColor { GREEN, YELLOW, RED, BLUE, CUSTOM }

const FLAME_SHADER := preload("res://Interactables/decorations/torch_flame.gdshader")
const GLOW_SHADER := preload("res://Interactables/decorations/torch_glow.gdshader")
const GLOW_NAME := "FlameGlow"

## Which flame this torch has.
@export var flame_color: FlameColor = FlameColor.GREEN:
	set(value):
		flame_color = value
		_apply()

@export_group("Look")
## Flame brightness (above 1 = brighter).
@export_range(0.5, 3.0, 0.05) var brightness: float = 1.0:
	set(value):
		brightness = value
		_apply()
## How much the flame and glow flicker (0 = steady).
@export_range(0.0, 0.5, 0.01) var flicker: float = 0.08:
	set(value):
		flicker = value
		_apply()

@export_group("Glow")
## Turn the glow on/off.
@export var glow_enabled: bool = true:
	set(value):
		glow_enabled = value
		_apply()
## How bright the glow is.
@export_range(0.0, 2.0, 0.05) var glow_strength: float = 1.0:
	set(value):
		glow_strength = value
		_apply()
## Glow size (diameter) in pixels.
@export_range(8, 160, 2) var glow_size: int = 48:
	set(value):
		glow_size = value
		_apply()
## Number of light rings (fewer = chunkier pixel look).
@export_range(1, 8) var glow_steps: int = 4:
	set(value):
		glow_steps = value
		_apply()
## Where the glow sits, relative to the torch (the flame).
@export var glow_offset: Vector2 = Vector2(0, -15):
	set(value):
		glow_offset = value
		_apply()

@export_group("Green", "green_")
@export var green_outline: Color = Color8(34, 51, 22):
	set(v): green_outline = v; _apply()
@export var green_mid: Color = Color8(61, 161, 0):
	set(v): green_mid = v; _apply()
@export var green_light: Color = Color8(165, 214, 54):
	set(v): green_light = v; _apply()
@export var green_core: Color = Color8(135, 246, 235):
	set(v): green_core = v; _apply()

@export_group("Yellow", "yellow_")
@export var yellow_outline: Color = Color8(92, 42, 8):
	set(v): yellow_outline = v; _apply()
@export var yellow_mid: Color = Color8(232, 122, 18):
	set(v): yellow_mid = v; _apply()
@export var yellow_light: Color = Color8(255, 196, 56):
	set(v): yellow_light = v; _apply()
@export var yellow_core: Color = Color8(255, 246, 190):
	set(v): yellow_core = v; _apply()

@export_group("Red", "red_")
@export var red_outline: Color = Color8(70, 10, 12):
	set(v): red_outline = v; _apply()
@export var red_mid: Color = Color8(196, 32, 24):
	set(v): red_mid = v; _apply()
@export var red_light: Color = Color8(255, 96, 40):
	set(v): red_light = v; _apply()
@export var red_core: Color = Color8(255, 206, 140):
	set(v): red_core = v; _apply()

@export_group("Blue", "blue_")
@export var blue_outline: Color = Color8(14, 24, 82):
	set(v): blue_outline = v; _apply()
@export var blue_mid: Color = Color8(30, 88, 230):
	set(v): blue_mid = v; _apply()
@export var blue_light: Color = Color8(92, 170, 255):
	set(v): blue_light = v; _apply()
@export var blue_core: Color = Color8(206, 246, 255):
	set(v): blue_core = v; _apply()

@export_group("Custom Colors", "custom_")
@export var custom_outline: Color = Color8(60, 20, 70):
	set(v): custom_outline = v; _apply()
@export var custom_mid: Color = Color8(160, 50, 200):
	set(v): custom_mid = v; _apply()
@export var custom_light: Color = Color8(230, 120, 255):
	set(v): custom_light = v; _apply()
@export var custom_core: Color = Color8(255, 220, 255):
	set(v): custom_core = v; _apply()

var _glow: Sprite2D = null


func _ready() -> void:
	_apply()


## The 4 shades (outline, mid, light, core) of the chosen flame color.
func get_flame_colors() -> Array[Color]:
	match flame_color:
		FlameColor.GREEN:
			return [green_outline, green_mid, green_light, green_core]
		FlameColor.YELLOW:
			return [yellow_outline, yellow_mid, yellow_light, yellow_core]
		FlameColor.RED:
			return [red_outline, red_mid, red_light, red_core]
		FlameColor.BLUE:
			return [blue_outline, blue_mid, blue_light, blue_core]
	return [custom_outline, custom_mid, custom_light, custom_core]


func _apply() -> void:
	if not is_inside_tree():
		return
	var cols := get_flame_colors()
	var offset_t := fmod(global_position.x * 0.37 + global_position.y * 0.11, TAU)

	# Flame recolor.
	var mat := material as ShaderMaterial
	if mat == null or mat.shader != FLAME_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = FLAME_SHADER
		mat.resource_local_to_scene = true
		material = mat
	mat.set_shader_parameter("flame_dark", cols[0])
	mat.set_shader_parameter("flame_mid", cols[1])
	mat.set_shader_parameter("flame_light", cols[2])
	mat.set_shader_parameter("flame_core", cols[3])
	mat.set_shader_parameter("brightness", brightness)
	mat.set_shader_parameter("flicker", flicker)
	mat.set_shader_parameter("flicker_offset", offset_t)

	# Glow.
	var glow := _get_glow()
	glow.visible = glow_enabled
	glow.position = glow_offset
	glow.scale = Vector2(glow_size, glow_size)
	var gmat := glow.material as ShaderMaterial
	gmat.set_shader_parameter("glow_color", cols[2])
	gmat.set_shader_parameter("strength", glow_strength)
	gmat.set_shader_parameter("pixel_size", float(glow_size))
	gmat.set_shader_parameter("steps", glow_steps)
	gmat.set_shader_parameter("flicker", flicker)
	gmat.set_shader_parameter("flicker_offset", offset_t)


# The glow is made by this script (not saved in the scene), so every torch
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
		_glow.show_behind_parent = true  # light behind the torch, not over it
		_glow.material = ShaderMaterial.new()
		(_glow.material as ShaderMaterial).shader = GLOW_SHADER
		add_child(_glow, false, Node.INTERNAL_MODE_FRONT)
	return _glow
