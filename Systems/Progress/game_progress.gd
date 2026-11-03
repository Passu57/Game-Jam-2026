extends Node
## Global game progress (autoload: GameProgress).
## Remembers which abilities the player has unlocked so far.
##
## Use from anywhere:
##   GameProgress.unlock(GameProgress.DOUBLE_JUMP)
##   if GameProgress.has(GameProgress.DOUBLE_JUMP): ...

## Emitted the first time an ability gets unlocked.
signal ability_unlocked(ability: StringName)

# Ability names. Add new ones here (dash, wall jump...).
const DOUBLE_JUMP := &"double_jump"
const WRENCH_THROW := &"wrench_throw"

## Abilities the player starts the game with. Normally empty.
## Tip for testing: add &"double_jump" here to have it from the start.
var starting_abilities: Array[StringName] = []

var _unlocked: Dictionary = {}


func _ready() -> void:
	reset()


## Unlocks an ability. Does nothing if it's already unlocked.
func unlock(ability: StringName) -> void:
	if _unlocked.has(ability):
		return
	_unlocked[ability] = true
	print("Unlocked ability: ", ability)
	ability_unlocked.emit(ability)


## True if the ability is unlocked.
func has(ability: StringName) -> bool:
	return _unlocked.has(ability)


## Locks an ability again (handy for testing).
func lock(ability: StringName) -> void:
	_unlocked.erase(ability)


## Back to a fresh game.
func reset() -> void:
	_unlocked.clear()
	for ability in starting_abilities:
		_unlocked[ability] = true
