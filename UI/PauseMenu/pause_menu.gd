extends CanvasLayer
## Autoload: PauseMenu
## Press Esc / P / gamepad Start in any level to pause (not on the main menu).
## The world behind slows to a stop, blurs and loses its color, while the
## last spark keeps flickering above the menu.
##
## Pages: RESUME, OPTIONS (volume, fullscreen, controls), MAIN MENU, QUIT GAME.
## Settings are shared with the main menu (user://settings.cfg).
## The game also pauses itself when the window loses focus.

const THEME := preload("res://UI/MainMenu/menu_theme.tres")
const SPARK_ICON := preload("res://UI/MainMenu/art/spark_icon.png")
const SPARK_GLOW := preload("res://UI/MainMenu/art/spark_glow.png")
const BACKDROP_SHADER := preload("res://UI/PauseMenu/pause_backdrop.gdshader")
const SFX_DIR := "res://Sounds/Weird sounds/free_game_ui_sounds/wav/ui/"
const MAIN_MENU := "res://UI/MainMenu/MainMenu.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const VOLUME_STEPS := 10
## Audio bus that all music plays on (created at startup if missing).
const MUSIC_BUS := "Music"
## Music volume for a fresh install (0..10, 6 = 60%).
const DEFAULT_MUSIC_VOLUME := 6

## Colors of the 6 color groups (same order as ColorManager bits).
const BAND_COLORS: Array[Color] = [
	Color(0.95, 0.27, 0.25), Color(1.0, 0.84, 0.25), Color(0.36, 0.9, 0.4),
	Color(0.3, 0.9, 0.95), Color(0.32, 0.48, 1.0), Color(0.88, 0.36, 0.95),
]

## One of these is typed out under the title every time you pause.
const FLAVOR: Array[String] = [
	"THE SPARK FLICKERS, WAITING FOR YOU.",
	"SYSTEMS ON STANDBY.",
	"THE CAVE HOLDS ITS BREATH.",
	"EVEN A SMALL LIGHT CAN WAIT.",
	"POWER SAVING MODE: ON",
	"THE MACHINES ARE STILL WAITING.",
]

## Controls listed in Options. An ability name hides the row until unlocked.
const CONTROLS := [
	["MOVE", ["move_left", "move_right"], &""],
	["JUMP", ["jump"], &""],
	["INTERACT", ["interact"], &""],
	["THROW WRENCH", ["throw"], &"wrench_throw"],
	["DASH", ["dash"], &"dash"],
	["PAUSE", ["pause"], &""],
]

## Pause automatically when the game window loses focus.
@export var pause_on_focus_loss: bool = true

var is_open: bool = false

var volume: int = 8
var music_volume: int = DEFAULT_MUSIC_VOLUME
var fullscreen: bool = false

var _busy: bool = false
var _quiet: bool = false
var _time: float = 0.0
var _flicker: float = 0.0
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _page: Control = null
var _return_focus: Control = null
var _confirm_action: Callable

var _sfx: AudioStreamPlayer
var _sounds: Dictionary = {}

var _root: Control
var _backdrop: ColorRect
var _backdrop_mat: ShaderMaterial
var _dust: CPUParticles2D
var _fade: ColorRect

var _main_page: VBoxContainer
var _spark: TextureRect
var _spark_glow: TextureRect
var _flavor: Label
var _band_boxes: Array[Panel] = []
var _colors_label: Label
var _modules_label: Label
var _resume_button: Button
var _options_button: Button
var _menu_button: Button
var _quit_button: Button

var _options_page: PanelContainer
var _volume_meter: Label
var _volume_down: Button
var _volume_up: Button
var _music_meter: Label
var _music_down: Button
var _music_up: Button
var _fullscreen_button: Button
var _controls_grid: GridContainer

var _confirm_page: PanelContainer
var _confirm_title: Label
var _confirm_text: Label
var _confirm_yes: Button
var _confirm_no: Button


func _ready() -> void:
	layer = 120  # above the color filter (100) and ability popup (110)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_pause_action()
	_ensure_music_bus()
	_load_sounds()
	_build()
	_load_settings()
	_apply_music_volume()
	_hide_now()


# --- Input ----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not is_open:
		if event.is_action_pressed("pause") and _can_pause():
			get_viewport().set_input_as_handled()
			open()
		return

	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _busy:
			return
		if _page == _main_page:
			resume()
		else:
			_back_to_main()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss:
		if not is_open and _can_pause():
			open()


func _can_pause() -> bool:
	if _busy or get_tree().paused:
		return false
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path != MAIN_MENU


# --- Open / close ---------------------------------------------------------

## Pauses the game and shows the menu.
func open() -> void:
	if is_open:
		return
	is_open = true
	_busy = true
	get_tree().paused = true
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play("ui_popup_in")

	_refresh_status()
	_root.visible = true
	_options_page.visible = false
	_confirm_page.visible = false
	_page = null
	_return_focus = null

	_set_progress(0.0)
	_dust.modulate.a = 0.0
	var t := _tween().set_parallel(true)
	t.tween_method(_set_progress, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_dust, "modulate:a", 1.0, 0.6)
	t.chain().tween_callback(func(): _busy = false)

	_flavor.text = FLAVOR.pick_random()
	_flavor.visible_ratio = 0.0
	_show_page(_main_page, _resume_button, 0.05)
	var ft := _tween()
	ft.tween_interval(0.3)
	ft.tween_property(_flavor, "visible_ratio", 1.0, 0.7)


## Closes the menu and continues the game.
func resume() -> void:
	if not is_open or _busy:
		return
	_busy = true
	_play("ui_popup_out")
	var t := _tween().set_parallel(true)
	t.tween_method(_set_progress, 1.0, 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_dust, "modulate:a", 0.0, 0.2)
	if _page:
		t.tween_property(_page, "modulate:a", 0.0, 0.15)
		t.tween_property(_page, "scale", Vector2(0.95, 0.95), 0.15)
	t.chain().tween_callback(func():
		_hide_now()
		get_tree().paused = false
		Input.mouse_mode = _prev_mouse_mode
		_busy = false)


func _hide_now() -> void:
	is_open = false
	_root.visible = false
	_main_page.visible = false
	_options_page.visible = false
	_confirm_page.visible = false
	_page = null


func _set_progress(v: float) -> void:
	_backdrop_mat.set_shader_parameter("progress", v)


# --- Pages ----------------------------------------------------------------

func _show_page(page: Control, focus: Control, delay: float = 0.0) -> void:
	var old := _page
	_page = page
	if old != null and old != page:
		var ot := _tween().set_parallel(true)
		ot.tween_property(old, "modulate:a", 0.0, 0.1)
		ot.tween_property(old, "scale", Vector2(0.96, 0.96), 0.1)
		ot.chain().tween_callback(func(): if _page != old: old.visible = false)
		delay = maxf(delay, 0.08)

	page.visible = true
	page.modulate.a = 0.0
	page.pivot_offset = page.get_combined_minimum_size() * 0.5
	page.scale = Vector2(0.92, 0.92)
	var t := _tween().set_parallel(true)
	t.tween_property(page, "modulate:a", 1.0, 0.16).set_delay(delay)
	t.tween_property(page, "scale", Vector2.ONE, 0.26).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if focus:
		_quiet = true
		focus.grab_focus()
		_quiet = false


func _back_to_main() -> void:
	_play("ui_back")
	var focus: Control = _return_focus if _return_focus else _resume_button
	_show_page(_main_page, focus)


func _open_options() -> void:
	_play("ui_accept")
	_return_focus = _options_button
	_load_settings()
	_refresh_settings_ui()
	_refresh_controls()
	_show_page(_options_page, _volume_up)


func _ask(title: String, text: String, from: Button, action: Callable) -> void:
	_play("ui_accept")
	_return_focus = from
	_confirm_title.text = title
	_confirm_text.text = text
	_confirm_action = action
	_show_page(_confirm_page, _confirm_no)


func _on_confirm_yes() -> void:
	_play("ui_accept")
	if _confirm_action.is_valid():
		_confirm_action.call()


# --- Leaving the level ----------------------------------------------------

func _quit_to_menu() -> void:
	_busy = true
	await _fade_to_black()
	get_tree().paused = false
	Engine.time_scale = 1.0
	_hide_now()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU)
	# The main menu fades in from black by itself; wait until it's there.
	await get_tree().process_frame
	await get_tree().process_frame
	_fade.visible = false
	_busy = false


func _quit_game() -> void:
	_busy = true
	await _fade_to_black()
	get_tree().quit()


func _fade_to_black() -> void:
	_fade.visible = true
	_fade.modulate.a = 0.0
	var t := _tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.5)
	await t.finished


# --- Status (colors + modules) -------------------------------------------

func _refresh_status() -> void:
	var mask := 0
	var cm := get_node_or_null("/root/ColorManager")
	if cm != null and "unlocked_mask" in cm:
		mask = cm.unlocked_mask
	var count := 0
	for i in _band_boxes.size():
		var on := (mask & (1 << i)) != 0
		if on:
			count += 1
		var box := _band_boxes[i]
		var style := box.get_theme_stylebox("panel") as StyleBoxFlat
		if on:
			style.bg_color = BAND_COLORS[i]
			style.border_color = BAND_COLORS[i].lightened(0.4)
		else:
			style.bg_color = Color(0.12, 0.12, 0.15)
			style.border_color = Color(0.3, 0.31, 0.36)
		box.set_meta("on", on)
	_colors_label.text = "COLORS RESTORED  %d/6" % count

	var names: Array[String] = []
	var gp := get_node_or_null("/root/GameProgress")
	var popup := get_node_or_null("/root/AbilityPopup")
	var abilities: Dictionary = {}
	if popup != null and popup.get_script() != null:
		abilities = popup.get_script().get_script_constant_map().get("ABILITIES", {})
	if gp != null:
		for key in abilities:
			if gp.has(key):
				names.append(String(abilities[key].get("title", String(key).to_upper())))
	_modules_label.text = "MODULES:  " + (" + ".join(names) if not names.is_empty() else "NONE YET")


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_time += delta

	# The spark sputters now and then, like on the main menu.
	_flicker = maxf(_flicker - delta * 4.0, 0.0)
	if randf() < delta * 0.7:
		_flicker = 1.0
	var bright := 1.0 + 0.15 * sin(_time * 3.1) - _flicker * 0.3
	_spark.modulate = Color(bright, bright, bright)
	_spark.position.y = roundf(sin(_time * 1.6) * 2.0) * 2.0
	_spark_glow.modulate.a = clampf(0.75 + 0.2 * sin(_time * 3.1) - _flicker * 0.35, 0.25, 1.0)
	var gs := 1.0 + 0.06 * sin(_time * 2.3)
	_spark_glow.scale = Vector2(gs, gs)

	# Restored colors glow softly.
	for i in _band_boxes.size():
		var box := _band_boxes[i]
		if box.get_meta("on", false):
			var a := 0.85 + 0.15 * sin(_time * 2.5 + i * 0.9)
			box.modulate = Color(a, a, a)
		else:
			box.modulate = Color.WHITE


# --- Settings (shared with the main menu) ---------------------------------

func _change_volume(step: int) -> void:
	var before := volume
	volume = clampi(volume + step, 0, VOLUME_STEPS)
	if volume == before:
		_play("ui_invalid")
		return
	_apply_settings()
	_save_settings()
	_refresh_settings_ui()
	_play("ui_slider_tick")


func _change_music(step: int) -> void:
	var before := music_volume
	music_volume = clampi(music_volume + step, 0, VOLUME_STEPS)
	if music_volume == before:
		_play("ui_invalid")
		return
	_apply_music_volume()
	_save_settings()
	_refresh_settings_ui()
	_play("ui_slider_tick")


## Creates the "Music" bus (sending into Master) if the project doesn't have one.
func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, MUSIC_BUS)
	AudioServer.set_bus_send(idx, "Master")


## Sets the Music bus to the music volume (also callable from the main menu).
func set_music_volume(value: int) -> void:
	music_volume = clampi(value, 0, VOLUME_STEPS)
	_apply_music_volume()


func _apply_music_volume() -> void:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus == -1:
		return
	AudioServer.set_bus_mute(bus, music_volume == 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(music_volume / float(VOLUME_STEPS), 0.001)))


func _toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_apply_settings()
	_save_settings()
	_refresh_settings_ui()
	_play("ui_checkbox_on" if fullscreen else "ui_checkbox_off")


func _refresh_settings_ui() -> void:
	_volume_meter.text = "|".repeat(volume) + "#".repeat(VOLUME_STEPS - volume) + "  %3d%%" % (volume * 10)
	_music_meter.text = "|".repeat(music_volume) + "#".repeat(VOLUME_STEPS - music_volume) + "  %3d%%" % (music_volume * 10)
	_fullscreen_button.text = "FULLSCREEN:  " + ("ON" if fullscreen else "OFF")


func _apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume == 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume / float(VOLUME_STEPS), 0.001)))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode and not Engine.is_embedded_in_editor():
		DisplayServer.window_set_mode(mode)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		volume = int(cfg.get_value("audio", "volume", volume))
		music_volume = int(cfg.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep any other saved values
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


func _refresh_controls() -> void:
	for c in _controls_grid.get_children():
		c.queue_free()
	var gp := get_node_or_null("/root/GameProgress")
	for row in CONTROLS:
		var ability: StringName = row[2]
		if ability != &"" and (gp == null or not gp.has(ability)):
			continue
		var keys: Array[String] = []
		for action in row[1]:
			keys.append(_key_name(action))
		var name_label := _small(row[0])
		_controls_grid.add_child(name_label)
		var key_label := _small(" / ".join(keys))
		key_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_controls_grid.add_child(key_label)


func _key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "-"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			return OS.get_keycode_string(code).to_upper()
		if ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT:
					return "LEFT MOUSE"
				MOUSE_BUTTON_RIGHT:
					return "RIGHT MOUSE"
				MOUSE_BUTTON_MIDDLE:
					return "MIDDLE MOUSE"
	return "-"


# --- Sound ----------------------------------------------------------------

func _load_sounds() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -6.0
	_sfx.max_polyphony = 4
	add_child(_sfx)
	for n in ["ui_popup_in", "ui_popup_out", "ui_accept", "ui_back", "ui_blip_up",
			"ui_slider_tick", "ui_checkbox_on", "ui_checkbox_off", "ui_invalid"]:
		var path: String = SFX_DIR + n + ".wav"
		if ResourceLoader.exists(path):
			_sounds[n] = load(path)


func _play(sound: String) -> void:
	if _sounds.has(sound):
		_sfx.stream = _sounds[sound]
		_sfx.play()


func _tween() -> Tween:
	# Runs while the game is paused and ignores slow-motion moments.
	return create_tween().set_ignore_time_scale(true)


func _ensure_pause_action() -> void:
	if InputMap.has_action("pause"):
		return
	InputMap.add_action("pause")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", esc)
	var p := InputEventKey.new()
	p.keycode = KEY_P
	InputMap.action_add_event("pause", p)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	InputMap.action_add_event("pause", start)


# --- Building the UI ------------------------------------------------------

func _build() -> void:
	# Copy the screen after the color filter so the backdrop sees the real image.
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)

	_root = Control.new()
	_root.theme = THEME
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks into the game
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = BACKDROP_SHADER
	_backdrop.material = _backdrop_mat
	_root.add_child(_backdrop)

	var dust_holder := Node2D.new()
	_root.add_child(dust_holder)
	_dust = _make_dust()
	dust_holder.add_child(_dust)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_build_main_page(center)
	_build_options_page(center)
	_build_confirm_page(center)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.visible = false
	add_child(_fade)


func _build_main_page(parent: Control) -> void:
	_main_page = VBoxContainer.new()
	_main_page.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_page.add_theme_constant_override("separation", 6)
	parent.add_child(_main_page)

	# The spark, hovering above the panel.
	var spark_box := Control.new()
	spark_box.custom_minimum_size = Vector2(0, 110)
	spark_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_page.add_child(spark_box)
	var spark_center := Control.new()
	spark_center.set_anchors_preset(Control.PRESET_CENTER)
	spark_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark_box.add_child(spark_center)

	_spark_glow = TextureRect.new()
	_spark_glow.texture = SPARK_GLOW
	_spark_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spark_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spark_glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spark_glow.size = Vector2(170, 170)
	_spark_glow.position = Vector2(-85, -85)
	_spark_glow.pivot_offset = Vector2(85, 85)
	_spark_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark_center.add_child(_spark_glow)

	var spark_holder := Control.new()
	spark_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark_holder.position = Vector2(-28, -28)
	spark_center.add_child(spark_holder)
	_spark = TextureRect.new()
	_spark.texture = SPARK_ICON
	_spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spark.size = Vector2(56, 56)
	_spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark_holder.add_child(_spark)
	var embers := _make_embers()
	embers.position = Vector2(0, -4)
	spark_center.add_child(embers)

	var panel := PanelContainer.new()
	_main_page.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "-  P A U S E D  -"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_flavor = _small("")
	_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor.add_theme_color_override("font_color", Color(0.62, 0.65, 0.72))
	vbox.add_child(_flavor)

	vbox.add_child(_divider())

	# Color progress: one little block per color group.
	var colors_row := HBoxContainer.new()
	colors_row.alignment = BoxContainer.ALIGNMENT_CENTER
	colors_row.add_theme_constant_override("separation", 10)
	vbox.add_child(colors_row)
	_colors_label = _small("COLORS RESTORED  0/6")
	colors_row.add_child(_colors_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	colors_row.add_child(spacer)
	for i in 6:
		var box := Panel.new()
		box.custom_minimum_size = Vector2(22, 22)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.set_border_width_all(3)
		style.anti_aliasing = false
		box.add_theme_stylebox_override("panel", style)
		colors_row.add_child(box)
		_band_boxes.append(box)

	_modules_label = _small("MODULES:  NONE YET")
	_modules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_modules_label)

	vbox.add_child(_divider())

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)
	_resume_button = _button("RESUME", buttons, resume)
	_options_button = _button("OPTIONS", buttons, _open_options)
	_menu_button = _button("MAIN MENU", buttons, func():
		_ask("BACK TO THE MAIN MENU?", "PROGRESS IN THIS LEVEL WILL BE LOST.", _menu_button, _quit_to_menu))
	_quit_button = _button("QUIT GAME", buttons, func():
		_ask("QUIT THE GAME?", "THE LAST SPARK WILL GO DARK... FOR NOW.", _quit_button, _quit_game))
	# Browsers can't close the game, so hide QUIT GAME on web builds.
	if OS.has_feature("web"):
		_quit_button.visible = false


func _build_options_page(parent: Control) -> void:
	_options_page = PanelContainer.new()
	parent.add_child(_options_page)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_options_page.add_child(vbox)

	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "O P T I O N S"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_divider())

	var vol_title := _small("VOLUME")
	vol_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(vol_title)
	var vol_row := HBoxContainer.new()
	vol_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vol_row.add_theme_constant_override("separation", 14)
	vbox.add_child(vol_row)
	_volume_down = _button("-", vol_row, _change_volume.bind(-1), 72)
	_volume_meter = Label.new()
	_volume_meter.custom_minimum_size = Vector2(380, 0)
	_volume_meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_row.add_child(_volume_meter)
	_volume_up = _button("+", vol_row, _change_volume.bind(1), 72)

	var music_title := _small("MUSIC")
	music_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(music_title)
	var music_row := HBoxContainer.new()
	music_row.alignment = BoxContainer.ALIGNMENT_CENTER
	music_row.add_theme_constant_override("separation", 14)
	vbox.add_child(music_row)
	_music_down = _button("-", music_row, _change_music.bind(-1), 72)
	_music_meter = Label.new()
	_music_meter.custom_minimum_size = Vector2(380, 0)
	_music_meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_row.add_child(_music_meter)
	_music_up = _button("+", music_row, _change_music.bind(1), 72)

	_fullscreen_button = _button("FULLSCREEN:  OFF", vbox, _toggle_fullscreen)

	vbox.add_child(_divider())
	var controls_title := _small("CONTROLS")
	controls_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
	vbox.add_child(controls_title)
	_controls_grid = GridContainer.new()
	_controls_grid.columns = 2
	_controls_grid.add_theme_constant_override("h_separation", 40)
	_controls_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_controls_grid)

	vbox.add_child(_divider())
	_button("BACK", vbox, _back_to_main)


func _build_confirm_page(parent: Control) -> void:
	_confirm_page = PanelContainer.new()
	parent.add_child(_confirm_page)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	_confirm_page.add_child(vbox)

	_confirm_title = Label.new()
	_confirm_title.theme_type_variation = &"HeaderLabel"
	_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_confirm_title)
	_confirm_text = _small("")
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_confirm_text)
	vbox.add_child(_divider())

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)
	_confirm_yes = _button("YES", row, _on_confirm_yes, 200)
	_confirm_no = _button("NO", row, _back_to_main, 200)


func _button(text: String, parent: Control, callback: Callable, min_width: float = 440.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 0)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(b)
	b.pressed.connect(func():
		if not _busy:
			callback.call())
	b.mouse_entered.connect(func(): if not _busy: b.grab_focus())
	b.focus_entered.connect(_on_button_focus.bind(b, true))
	b.focus_exited.connect(_on_button_focus.bind(b, false))
	return b


# The focused button lights up and gets the little spark, like the main menu.
func _on_button_focus(b: Button, focused: bool) -> void:
	if focused:
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover"))
		if b.custom_minimum_size.x >= 300:
			b.icon = SPARK_ICON
		if not _quiet:
			_play("ui_blip_up")
	else:
		b.remove_theme_stylebox_override("normal")
		b.icon = null


func _small(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"SmallLabel"
	l.text = text
	return l


func _divider() -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 4)
	line.color = Color(0.36, 0.38, 0.45, 0.6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 60
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
	ramp.add_point(0.3, Color(0.75, 0.78, 0.86, 0.3))
	ramp.add_point(0.7, Color(0.75, 0.78, 0.86, 0.3))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.75, 0.78, 0.86, 0.0))
	p.color_ramp = ramp
	return p


func _make_embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 14
	p.lifetime = 1.6
	p.preprocess = 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.gravity = Vector2(0, -16)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 32.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.98, 0.85, 1.0))
	g.add_point(0.35, Color(1.0, 0.78, 0.3, 1.0))
	g.set_color(g.get_point_count() - 1, Color(0.9, 0.38, 0.1, 0.0))
	p.color_ramp = g
	return p
