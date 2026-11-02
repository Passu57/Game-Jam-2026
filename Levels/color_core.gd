extends Area2D

var _restored := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _restored or not body.is_in_group("player"):
		return

	_restored = true
	var tint := get_node_or_null("../WorldTint") as CanvasModulate
	if tint:
		tint.color = Color.WHITE

	var status := get_node_or_null("../HUD/StatusLabel") as Label
	if status:
		status.text = "COLOR RESTORED!  Level 1 complete."

	set_deferred("monitoring", false)
