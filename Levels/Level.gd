extends Node2D
@onready var spawn_point: Marker2D = $SpawnPoint
## The level's music player (a child called "SoundTrackLevel3"). Optional.
@onready var level_music: AudioStreamPlayer2D = get_node_or_null("SoundTrackLevel3")

@export_group("Music")
## How long the music takes to fade in when it starts (seconds).
@export var music_fade_in: float = 2.5
## How long the music takes to fade out before the track ends (seconds).
@export var music_fade_out: float = 2.5
## Short silence between the fade-out and the next start (seconds).
@export var music_gap: float = 0.5
@export_group("")

const SILENT_DB := -60.0

var _music_db: float = 0.0       # the volume set on the player in the editor
var _music_tween: Tween
var _fading_out: bool = false


func _ready() -> void:
	var player : CharacterBody2D = get_child(1)
	player.global_position = spawn_point.global_position
	player.velocity = Vector2(0, 0)
	if level_music:
		# Play on the Music bus so the MUSIC volume setting controls it.
		if AudioServer.get_bus_index("Music") != -1:
			level_music.bus = &"Music"
		_music_db = level_music.volume_db
		_start_music()


func _process(_delta: float) -> void:
	if level_music == null or _fading_out or not level_music.playing:
		return
	var length := level_music.stream.get_length() if level_music.stream else 0.0
	if length <= 0.0:
		return
	# Close to the end: fade out, then start again from the top.
	if level_music.get_playback_position() >= length - music_fade_out - 0.05:
		_fade_out_and_restart()


# Starts the track from the beginning, fading the volume in.
func _start_music() -> void:
	_fading_out = false
	level_music.volume_db = SILENT_DB
	level_music.play()
	_music_tween = _new_music_tween()
	_music_tween.tween_property(level_music, "volume_db", _music_db, music_fade_in) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _fade_out_and_restart() -> void:
	_fading_out = true
	_music_tween = _new_music_tween()
	_music_tween.tween_property(level_music, "volume_db", SILENT_DB, music_fade_out) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_music_tween.tween_callback(level_music.stop)
	_music_tween.tween_interval(music_gap)
	_music_tween.tween_callback(_start_music)


func _new_music_tween() -> Tween:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	return create_tween()
