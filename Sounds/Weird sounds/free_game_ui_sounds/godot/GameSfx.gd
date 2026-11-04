extends Node
## Plays the Free Game & UI Sound Pack sounds by name.
## Add this script as an Autoload named GameSfx, then call GameSfx.play("jump").

@export var folders: PackedStringArray = ["res://free_game_ui_sounds/ogg", "res://free_game_ui_sounds_bonus/ogg"]
@export var voices: int = 8
@export var bus: StringName = &"Master"

var sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	for f in folders:
		_scan(f)
	for i in voices:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(path.path_join(sub))
	for file in dir.get_files():
		var clean := file.trim_suffix(".import").trim_suffix(".remap")
		if clean.ends_with(".ogg") or clean.ends_with(".wav"):
			var key := clean.get_basename()
			if not sounds.has(key):
				sounds[key] = load(path.path_join(clean))


func play(sound_name: String, pitch_variation: float = 0.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not sounds.has(sound_name):
		push_warning("GameSfx: unknown sound " + sound_name)
		return null
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = sounds[sound_name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()
	return p


func names() -> Array:
	var out := sounds.keys()
	out.sort()
	return out
