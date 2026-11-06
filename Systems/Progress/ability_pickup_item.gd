extends Area2D
## Drop this in a level. When the player touches it, the ability unlocks
## (through GameProgress), the "module installed" popup shows, and the
## pickup disappears.
## If it has a child "Sprite2D" using ability_icons.png, it shows the right
## icon for its ability automatically and gently bobs up and down.

## Which ability this pickup gives: double_jump, wrench_throw, dash, wall_jump.
@export var ability: StringName = &"double_jump":
	set(value):
		ability = value
		if is_inside_tree():
			_pick_icon()
## How far the icon bobs (pixels) and how fast.
@export var bob_height: float = 2.0
@export var bob_speed: float = 2.5

# Icon position in res://UI/AbilityPopup/ability_icons.png (16 px each).
const ICON_INDEX := {&"double_jump": 0, &"wrench_throw": 1, &"dash": 2, &"wall_jump": 3}

var _sprite: Sprite2D = null
var _base_y: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	# Already have it (e.g. after respawning)? Then don't show the pickup.
	if GameProgress.has(ability):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite != null:
		_base_y = _sprite.position.y
		_pick_icon()


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_t += delta
	# Whole pixels only, so it stays crisp.
	_sprite.position.y = _base_y + roundf(sin(_t * bob_speed) * bob_height)


func _pick_icon() -> void:
	if _sprite == null or not (_sprite.texture is AtlasTexture) or not ICON_INDEX.has(ability):
		return
	var atlas := (_sprite.texture as AtlasTexture).duplicate() as AtlasTexture
	atlas.region = Rect2(int(ICON_INDEX[ability]) * 16, 0, 16, 16)
	_sprite.texture = atlas


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.has_method("die"):  # only the player
		GameProgress.unlock(ability)
		queue_free()
