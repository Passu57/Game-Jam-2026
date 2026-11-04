extends StaticBody2D
## Spikes that pop up and down (see the "Spikes" animation).
## Touching them while they're up kills the player. The Hazard area moves
## with the sprite, so retracted spikes are safe to walk over.

## Untick to make the spikes harmless (e.g. switched off by a button).
@export var deadly: bool = true
@export var moving: bool = true

@onready var hazard: Area2D = $Sprite2D/Hazard
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	hazard.body_entered.connect(_on_hazard_body_entered)
	if moving == false:
		animation_player.play("RESET")


func _physics_process(_delta: float) -> void:
	# Also catch a player who stands still while the spikes rise into them.
	if not deadly:
		return
	for body in hazard.get_overlapping_bodies():
		_hurt(body)


func _on_hazard_body_entered(body: Node2D) -> void:
	if deadly:
		_hurt(body)


func _hurt(body: Node) -> void:
	if body.has_method("die") and not body.get("is_dead"):
		body.die()
