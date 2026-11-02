extends Node
## Autoload: InteractHighlighter
## Puts a glowing outline on whatever the player can interact with right now.
## Works with any InteractionController (anything with get_current_target()).
## Objects that are already done (is_fixed == true) are not highlighted.

const OUTLINE_SHADER := preload("res://Systems/Interaction/interact_outline.gdshader")

## Outline color. White shows up well even while the world is black & white.
@export var outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Outline thickness in pixels.
@export var outline_width: float = 1.0
## How long the outline takes to fade in/out (seconds).
@export var fade_time: float = 0.15

var _controllers: Array[Node] = []
var _current: Node = null
var _tweens := {}  # sprite -> Tween


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


func _physics_process(_delta: float) -> void:
	var target := _find_target()
	if target != _current:
		if is_instance_valid(_current):
			_fade(_current, 0.0)
		_current = target
		if _current != null:
			_fade(_current, 1.0)

	# Keep the outline locked to the sprite's current animation frame.
	for sprite in _tweens.keys():
		if is_instance_valid(sprite):
			_update_frame_rect(sprite)
		else:
			_tweens.erase(sprite)


func _on_node_added(node: Node) -> void:
	if node.has_method("get_current_target") and not _controllers.has(node):
		_controllers.append(node)


func _find_target() -> Node:
	for controller in _controllers.duplicate():
		if not is_instance_valid(controller):
			_controllers.erase(controller)
			continue
		if not controller.is_inside_tree():
			continue
		var target: Node = controller.get_current_target()
		if target != null and target.get("is_fixed") != true:
			return target
	return null


func _fade(target: Node, to: float) -> void:
	var sprite := _get_sprite(target)
	if sprite == null:
		return
	var mat := _get_outline_material(sprite)
	_update_frame_rect(sprite)
	if _tweens.has(sprite) and _tweens[sprite] is Tween and _tweens[sprite].is_valid():
		_tweens[sprite].kill()
	var tween := create_tween()
	tween.tween_property(mat, "shader_parameter/intensity", to, fade_time)
	_tweens[sprite] = tween


func _get_sprite(target: Node) -> CanvasItem:
	var sprite := target.get_node_or_null("Sprite2D")
	if sprite is CanvasItem:
		return sprite
	for child in target.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null


func _get_outline_material(sprite: CanvasItem) -> ShaderMaterial:
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader != OUTLINE_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
		mat.set_shader_parameter("intensity", 0.0)
		sprite.material = mat
	mat.set_shader_parameter("outline_color", outline_color)
	mat.set_shader_parameter("outline_width", outline_width)
	return mat


# Tells the shader which part of the sprite sheet is the current frame.
func _update_frame_rect(sprite: CanvasItem) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null or not (sprite is Sprite2D):
		return
	var s := sprite as Sprite2D
	if s.texture == null:
		return
	var tex_size := s.texture.get_size()
	var area := Rect2(Vector2.ZERO, tex_size)
	if s.region_enabled:
		area = s.region_rect
	var frame_size := area.size / Vector2(s.hframes, s.vframes)
	var frame_pos := area.position + frame_size * Vector2(s.frame_coords)
	mat.set_shader_parameter("frame_min", frame_pos / tex_size)
	mat.set_shader_parameter("frame_max", (frame_pos + frame_size) / tex_size)
