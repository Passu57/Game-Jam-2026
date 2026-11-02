extends Area2D

var _opened := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _opened or not body.is_in_group("player"):
		return

	_opened = true
	var bridge := get_node_or_null("../Bridge") as StaticBody2D
	if bridge:
		bridge.visible = true
		var bridge_shape := bridge.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if bridge_shape:
			bridge_shape.set_deferred("disabled", false)

	var plate := get_node_or_null("SwitchPlate") as Polygon2D
	if plate:
		plate.color = Color("#31e6c0")

	var status := get_node_or_null("../HUD/StatusLabel") as Label
	if status:
		status.text = "BRIDGE RESTORED!  Cross safely and reach the color core."
