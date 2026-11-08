extends Control
## Main menu for "The Last Spark" (the first scene of the game).
## The cave drifts by in grey - the only color left is one small spark.
##
## Works with mouse, keyboard (arrows + Enter, Esc to go back) and gamepad.

## The level "Start Game" loads.
@export_file("*.tscn") var first_level: String = "res://Levels/level1.tscn"

const SETTINGS_PATH := "user://settings.cfg"
const SPARK_ICON := preload("res://UI/MainMenu/art/spark_icon.png")
const ROBOT_IDLE_FRAMES := 5      # frames 0..4 of the robot sheet
const VOLUME_STEPS := 10

@onready var start_button: Button = $Buttons/StartButton
@onready var tutorial_button: Button = $Buttons/TutorialButton
@onready var settings_button: Button = $Buttons/SettingsButton
@onready var credits_button: Button = $Buttons/CreditsButton

@onready var robot: Sprite2D = $Scene/Robot
@onready var spark: Sprite2D = $Scene/Spark
@onready var glow: Sprite2D = $Scene/Glow
@onready var title: Control = $Title
@onready var title_spark: TextureRect = $Title/Spark
@onready var dim: ColorRect = $Dim
@onready var fade: ColorRect = $Fade

@onready var tutorial_panel: PanelContainer = $TutorialPanel
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var credits_panel: PanelContainer = $CreditsPanel
@onready var volume_meter: Label = $SettingsPanel/VBox/VolumeRow/Meter
@onready var volume_down: Button = $SettingsPanel/VBox/VolumeRow/Down
@onready var volume_up: Button = $SettingsPanel/VBox/VolumeRow/Up
@onready var fullscreen_button: Button = $SettingsPanel/VBox/FullscreenButton

var volume: int = 8            # 0..10
var music_volume: int = 6      # 0..10, 60% by default
var fullscreen: bool = false
var _music_meter: Label
var _music_down: Button
var _music_up: Button

var _time: float = 0.0
var _spark_home: Vector2
var _open_panel: Control = null
var _opened_from: Button = null
var _starting: bool = false
var _embers: CPUParticles2D
var _flicker: float = 0.0


func _ready() -> void:
	# The menu shows its own grey world; hide the in-game color filter here.
	if has_node("/root/ColorManager"):
		get_node("/root/ColorManager").visible = false

	_load_settings()
	_apply_settings()

	var main_buttons: Array[Button] = [start_button, tutorial_button, settings_button, credits_button]
	for b in main_buttons:
		_setup_button(b)
	start_button.pressed.connect(_on_start)
	tutorial_button.pressed.connect(_open.bind(tutorial_panel, tutorial_button))
	settings_button.pressed.connect(_open.bind(settings_panel, settings_button))
	credits_button.pressed.connect(_open.bind(credits_panel, credits_button))

	for panel in [tutorial_panel, settings_panel, credits_panel]:
		panel.visible = false
		var back: Button = panel.get_node("VBox/BackButton")
		_setup_button(back)
		back.pressed.connect(_close)
	_build_music_row()
	for b in [volume_down, volume_up, fullscreen_button, _music_down, _music_up]:
		_setup_button(b)
	volume_down.pressed.connect(_change_volume.bind(-1))
	volume_up.pressed.connect(_change_volume.bind(1))
	_music_down.pressed.connect(_change_music.bind(-1))
	_music_up.pressed.connect(_change_music.bind(1))
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	_refresh_settings_ui()

	dim.visible = false
	_spark_home = spark.position
	_make_dust()
	_embers = _make_embers()
	_intro()
	start_button.grab_focus()


func _process(delta: float) -> void:
	_time += delta

	# Robot idles, gazing at the spark.
	robot.frame = int(_time * 6.0) % ROBOT_IDLE_FRAMES

	# Spark flickers and floats (moves in whole "big pixels" so it stays crisp).
	spark.frame = int(_time * 10.0) % 4
	var bob := roundf(sin(_time * 1.6) * 2.0) * 3.0
	spark.position = _spark_home + Vector2(0, bob)
	glow.position = spark.position
	_embers.position = spark.position

	# Every now and then the spark sputters, like it's struggling to stay lit.
	_flicker = maxf(_flicker - delta * 4.0, 0.0)
	if randf() < delta * 0.6:
		_flicker = 1.0
	var pulse := 0.85 + 0.15 * sin(_time * 3.1) - _flicker * 0.35
	glow.modulate.a = clampf(pulse, 0.3, 1.0)
	var steps := 3.0
	var s := 8.0 + roundf((0.5 + 0.5 * sin(_time * 2.3)) * steps) * 0.5
	glow.scale = Vector2(s, s)
	var bright := 1.0 + 0.12 * sin(_time * 3.1) - _flicker * 0.25
	title_spark.modulate = Color(bright, bright, bright)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _open_panel != null:
		_close()
		get_viewport().set_input_as_handled()


# --- Buttons --------------------------------------------------------------

func _setup_button(b: Button) -> void:
	b.mouse_entered.connect(func(): if not _starting: b.grab_focus())
	b.focus_entered.connect(_on_button_focus.bind(b, true))
	b.focus_exited.connect(_on_button_focus.bind(b, false))


# The focused button lights up like it's hovered and gets a little spark.
func _on_button_focus(b: Button, focused: bool) -> void:
	if focused:
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover"))
		b.icon = SPARK_ICON
	else:
		b.remove_theme_stylebox_override("normal")
		b.icon = null


# --- Panels ---------------------------------------------------------------

func _open(panel: Control, from: Button) -> void:
	if _starting:
		return
	_open_panel = panel
	_opened_from = from
	dim.visible = true
	dim.modulate.a = 0.0
	panel.visible = true
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.94, 0.94)
	panel.modulate.a = 0.0
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(dim, "modulate:a", 1.0, 0.15)
	t.tween_property(panel, "modulate:a", 1.0, 0.15)
	t.tween_property(panel, "scale", Vector2.ONE, 0.22)
	var back: Button = panel.get_node("VBox/BackButton")
	if panel == settings_panel:
		volume_up.grab_focus()
	else:
		back.grab_focus()


func _close() -> void:
	if _open_panel == null:
		return
	var panel := _open_panel
	_open_panel = null
	var t := create_tween().set_parallel(true)
	t.tween_property(dim, "modulate:a", 0.0, 0.12)
	t.tween_property(panel, "modulate:a", 0.0, 0.12)
	t.chain().tween_callback(func():
		panel.visible = false
		dim.visible = false)
	if _opened_from:
		_opened_from.grab_focus()


# --- Start game -----------------------------------------------------------

func _on_start() -> void:
	if _starting:
		return
	_starting = true
	for b in [start_button, tutorial_button, settings_button, credits_button]:
		b.disabled = true
	# The spark bursts, then everything fades to black.
	_burst(spark.position)
	var t := create_tween()
	t.tween_interval(0.25)
	t.tween_property(fade, "modulate:a", 1.0, 0.7)
	t.tween_callback(_go_to_game)


func _go_to_game() -> void:
	if has_node("/root/ColorManager"):
		var cm := get_node("/root/ColorManager")
		cm.visible = true
		cm.reset()          # new game: back to black & white
	if has_node("/root/GameProgress"):
		get_node("/root/GameProgress").reset()

	# Keep the screen black across the scene change, then fade level 1 in.
	# (Same trick as the level exit doors: the overlay lives on the root, so it
	# survives the menu being freed and fades the new level in by itself.)
	var layer := CanvasLayer.new()
	layer.layer = 126  # above everything, incl. the color filter and pause menu
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	get_tree().root.add_child(layer)
	var t := layer.create_tween()
	t.tween_interval(0.35)
	t.tween_property(black, "color:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(layer.queue_free)

	get_tree().change_scene_to_file(first_level)


# --- Settings -------------------------------------------------------------

func _change_volume(step: int) -> void:
	volume = clampi(volume + step, 0, VOLUME_STEPS)
	_apply_settings()
	_save_settings()
	_refresh_settings_ui()


func _change_music(step: int) -> void:
	music_volume = clampi(music_volume + step, 0, VOLUME_STEPS)
	_apply_settings()
	_save_settings()
	_refresh_settings_ui()


# A copy of the VOLUME row, placed right under it, for the music volume.
func _build_music_row() -> void:
	var volume_row := $SettingsPanel/VBox/VolumeRow
	var row := volume_row.duplicate() as HBoxContainer
	row.name = "MusicRow"
	volume_row.add_sibling(row)
	(row.get_node("Label") as Label).text = "MUSIC"
	_music_meter = row.get_node("Meter")
	_music_down = row.get_node("Down")
	_music_up = row.get_node("Up")


func _toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_apply_settings()
	_save_settings()
	_refresh_settings_ui()


func _refresh_settings_ui() -> void:
	volume_meter.text = "|".repeat(volume) + "#".repeat(VOLUME_STEPS - volume) + "  %3d%%" % (volume * 10)
	if _music_meter:
		_music_meter.text = "|".repeat(music_volume) + "#".repeat(VOLUME_STEPS - music_volume) + "  %3d%%" % (music_volume * 10)
	fullscreen_button.text = "FULLSCREEN:  " + ("ON" if fullscreen else "OFF")


func _apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume == 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume / float(VOLUME_STEPS), 0.001)))
	# Music volume lives on the "Music" bus (created by the PauseMenu autoload).
	var pause_menu := get_node_or_null("/root/PauseMenu")
	if pause_menu and pause_menu.has_method("set_music_volume"):
		pause_menu.set_music_volume(music_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode and not Engine.is_embedded_in_editor():
		DisplayServer.window_set_mode(mode)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		volume = int(cfg.get_value("audio", "volume", volume))
		music_volume = int(cfg.get_value("audio", "music_volume", music_volume))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep any other saved values
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


# --- Effects --------------------------------------------------------------

func _intro() -> void:
	fade.modulate.a = 1.0
	fade.visible = true
	title.modulate.a = 0.0
	var title_end := title.position
	title.position = title_end + Vector2(0, -24)
	var buttons := $Buttons as Control
	buttons.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(fade, "modulate:a", 0.0, 1.0)
	t.tween_property(title, "modulate:a", 1.0, 0.8).set_delay(0.3)
	t.tween_property(title, "position", title_end, 0.8).set_delay(0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(buttons, "modulate:a", 1.0, 0.6).set_delay(0.7)


# Grey dust floating slowly through the whole screen.
func _make_dust() -> void:
	var p := CPUParticles2D.new()
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1000, 560)
	p.position = Vector2(960, 540)
	p.direction = Vector2(1, -0.35)
	p.spread = 25.0
	p.gravity = Vector2(4, -3)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.75, 0.78, 0.86, 0.0))
	ramp.add_point(0.3, Color(0.75, 0.78, 0.86, 0.35))
	ramp.add_point(0.7, Color(0.75, 0.78, 0.86, 0.35))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.75, 0.78, 0.86, 0.0))
	p.color_ramp = ramp
	$Background.add_child(p)


# Warm embers rising off the spark - the only color in the world.
func _make_embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 16
	p.lifetime = 1.8
	p.preprocess = 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.gravity = Vector2(0, -18)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 38.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color_ramp = _ember_ramp()
	$Scene.add_child(p)
	return p


func _burst(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 60
	p.lifetime = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 120)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 420.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color_ramp = _ember_ramp()
	p.position = at
	$Scene.add_child(p)
	p.emitting = true


func _ember_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.98, 0.85, 1.0))
	g.add_point(0.35, Color(1.0, 0.78, 0.3, 1.0))
	g.set_color(g.get_point_count() - 1, Color(0.9, 0.38, 0.1, 0.0))
	return g
