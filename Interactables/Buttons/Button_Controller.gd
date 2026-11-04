extends StaticBody2D
## Pressure button. Pressed while anything (player, box...) stands on it.
## toggle = true: stays pressed forever after the first press.
## toggle = false: releases only when EVERYTHING has left the button.

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D

@export var scene_to_open: StaticBody2D = null
@export var toggle: bool = true
var opened: bool = false
## True while the button is held down.
var is_pressed: bool = false


func on() -> void:
	if opened or is_pressed:
		return
	is_pressed = true
	sprite_2d.frame = 95
	if scene_to_open != null:
		scene_to_open.on()
	if toggle:
		opened = true


func off() -> void:
	if toggle or not is_pressed:
		return
	is_pressed = false
	sprite_2d.frame = 94
	if scene_to_open != null:
		scene_to_open.off()


func _on_area_2d_body_entered(_body: Node2D) -> void:
	on()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if toggle:
		return
	# Something left: only release if nothing else is still on the button.
	for other in area.get_overlapping_bodies():
		if other != body:
			return
	off()
