extends Control
## A soundboard: one button per sound. Open sfx_board.tscn and press Play.

const SFX := preload("res://free_game_ui_sounds/godot/GameSfx.gd")

var sfx: Node


func _ready() -> void:
	sfx = SFX.new()
	add_child(sfx)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	scroll.add_child(grid)
	for n in sfx.names():
		var b := Button.new()
		b.text = n
		b.custom_minimum_size = Vector2(220, 36)
		b.pressed.connect(func() -> void: sfx.play(n))
		grid.add_child(b)
	print("SFX_BOARD sounds=", sfx.names().size())
