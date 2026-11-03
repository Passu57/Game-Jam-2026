extends StaticBody2D
## A lever that flips between on and off.
## Toggle it by standing next to it and pressing E, or by hitting it
## with a thrown wrench. Each toggle runs interact().
##
## Hook it up like the buttons: drag a door (or anything with on()/off())
## into "Target" in the Inspector.

## Emitted every time the lever flips. is_on is the new state.
signal toggled(is_on: bool)

## What this lever controls. Gets on() when flipped on, off() when flipped off.
@export var target: Node = null
## Should the lever start in the "on" position?
@export var start_on: bool = false
## Untick to make it one-way: once on, it stays on.
@export var can_turn_off: bool = true
## Ignore hits for this long after a flip (stops double-toggles).
@export var cooldown: float = 0.3

var is_on: bool = false
var _ready_at_ms: int = 0

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	is_on = start_on
	sprite.frame = 3 if is_on else 0


## Called by the player's InteractionController when E is pressed,
## and by the wrench when it hits the lever.
func interact(_by: Node = null) -> void:
	if Time.get_ticks_msec() < _ready_at_ms:
		return
	if is_on and not can_turn_off:
		return
	_ready_at_ms = Time.get_ticks_msec() + int(cooldown * 1000.0)
	_toggle()


## Called by the thrown wrench.
func on_wrench_hit(wrench: Node) -> void:
	interact(wrench)


func _toggle() -> void:
	is_on = not is_on
	if is_on:
		anim.play("On")
	else:
		anim.play_backwards("On")
	if target != null:
		if is_on and target.has_method("on"):
			target.on()
		elif not is_on and target.has_method("off"):
			target.off()
	toggled.emit(is_on)
