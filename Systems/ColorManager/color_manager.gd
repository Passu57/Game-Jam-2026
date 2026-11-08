extends CanvasLayer
## Global color system (autoload: ColorManager).
## The game starts in black & white. Fixing machines unlocks color groups,
## which fade in smoothly.
##
## Use from anywhere:  ColorManager.unlock(ColorManager.ALL)

signal colors_unlocked(mask: int)

# One bit per color group. Combine them with |, e.g. RED | YELLOW.
# Only 4 colors can be unlocked: Red, Yellow, Green and Blue.
const RED := 1
const YELLOW := 2
const GREEN := 4
const BLUE := 16
## Not unlockable any more. Cyan fills in once Green AND Blue are unlocked,
## Magenta once Blue AND Red are, so the world still ends up in full color.
const CYAN := 8
const MAGENTA := 32
const ALL := RED | YELLOW | GREEN | BLUE
## The colors the player can unlock, in order (for UI like the pause menu).
const UNLOCKABLE: Array[int] = [RED, YELLOW, GREEN, BLUE]

const SHADER := preload("res://Systems/ColorManager/color_world.gdshader")

## How long (seconds) a color takes to fade in.
@export var fade_time: float = 1.5

## Which color groups are unlocked so far (bit mask).
var unlocked_mask: int = 0

var _strength := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _material: ShaderMaterial


func _ready() -> void:
	layer = 100  # draw on top of the game world
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	rect.material = _material
	add_child(rect)
	_apply()


## Unlocks the given color groups (bit mask) with a fade-in.
func unlock(mask: int) -> void:
	mask &= ALL  # Cyan/Magenta can't be unlocked directly
	var newly_unlocked := mask & ~unlocked_mask
	if newly_unlocked == 0:
		return
	unlocked_mask |= newly_unlocked
	for i in 6:
		if newly_unlocked & (1 << i):
			var band := i
			var tween := create_tween()
			tween.tween_method(func(v: float): _set_band(band, v), 0.0, 1.0, fade_time)
	colors_unlocked.emit(newly_unlocked)


## True if every color group in mask is unlocked.
func is_unlocked(mask: int) -> bool:
	return unlocked_mask & mask == mask


## Back to black & white (e.g. when starting a new game).
func reset() -> void:
	unlocked_mask = 0
	for i in 6:
		_strength[i] = 0.0
	_apply()


func _set_band(band: int, value: float) -> void:
	_strength[band] = value
	_apply()


func _apply() -> void:
	# Bands: 0 Red, 1 Yellow, 2 Green, 3 Cyan, 4 Blue, 5 Magenta.
	# Cyan and Magenta follow their two neighbours, fading in with them.
	_strength[3] = minf(_strength[2], _strength[4])
	_strength[5] = minf(_strength[4], _strength[0])
	_material.set_shader_parameter("band_strength", _strength)
