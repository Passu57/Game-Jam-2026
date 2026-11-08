extends Node2D
## The ending. A solar panel the robot can charge from (press E).
##   1. The robot locks in place and charges: energy flows from the panel,
##      the robot glows brighter, a charge bar fills up.
##   2. Fully charged: a flash, and ALL the colors flood back into the world.
##   3. The camera slowly rises up while quotes and the credits drift past,
##      ending on "THANK YOU FOR PLAYING", then back to the main menu.
##
## Put the node on the floor (its origin = the bottom of the post).
## Quotes and credits are editable in the Inspector.

const FONT := preload("res://UI/MainMenu/fonts/spark_font.fnt")
const FONT_SMALL := preload("res://UI/MainMenu/fonts/spark_font_small.fnt")
const TITLE_TOP := preload("res://UI/MainMenu/art/title_the_last.png")
const TITLE_BOTTOM := preload("res://UI/MainMenu/art/title_spark.png")
const CHARGE_SOUND := preload("res://Sounds/color_machine_activate.wav")
const DONE_SOUND_PATH := "res://Sounds/Weird sounds/free_game_ui_sounds/wav/ui/ui_achievement.wav"
const MAIN_MENU := "res://UI/MainMenu/MainMenu.tscn"

@export_group("Charging")
## How long charging takes (seconds).
@export var charge_time: float = 4.0
## Pause after the colors come back, before the camera starts rising (seconds).
@export var color_reveal_time: float = 3.0

@export_group("Camera")
## How far the camera rises (pixels). Level05's shaft is ~1150 px tall.
@export var rise_distance: float = 1000.0
## How long the rise takes (seconds). Bigger = slower.
@export var rise_time: float = 75.0
## The camera drifts to this X while rising (the middle of the shaft).
## Leave at -1 to stay above the robot.
@export var camera_center_x: float = 328.0

@export_group("Text")
## Quotes that drift past first, one at a time.
@export var quotes: Array[String] = [
	"THE WORLD WAS NEVER GREY.\nWE JUST STOPPED LOOKING.",
	"EVEN THE SMALLEST SPARK\nCAN LIGHT UP EVERYTHING AROUND IT.",
	"YOU DIDN'T FIGHT THE DARK.\nYOU FIXED IT.",
	"EVERY COLOR WAS WAITING\nFOR SOMEONE TO NOTICE IT.",
]
## Credits under the game title. One line per line.
@export_multiline var credits_text: String = """MADE FOR A GAME JAM - THEME: PACIFIST

GAME BY
KARL-MARKOS KADAPIK
KARL-SANDER MAEOTS

ART
ROBOT PLATFORM PACK - Edu
PARALLAX CAVE - Exice
MK 16X16 NATURE TILESET - Ipixl
2D PUZZLE ELEMENTS - Jan Schneider
CAVES AND MINES PROPS - STATIONSUPPLY
CRATES, SHELVES AND SPIKES - Krackselbubbel
JUNGLE ASSETS - GREEN TILE - Graph Script Dev
SHROOM CAVE ASSETS - Auru
FACTORY MACHINE - Claude helped converting
LAMONA BACKGROUND - Pixel_1992

SOUND
FREE GAME & UI SOUND PACK - WILLOSUNA
FILMCOW SOUNDS - Filmcow

ENGINE
GODOT 4"""
## The last quote, right before the thank-you.
@export_multiline var final_quote: String = "IF YOU OPEN YOUR EYES,\nYOU CAN SEE ALL THE COLORS\nTHE WORLD HAS TO OFFER."
## Space between the quotes (screen pixels).
@export var quote_gap: float = 150.0
## Extra space around the game title and before the final quote (screen pixels).
@export var section_gap: float = 170.0
## How long "THANK YOU FOR PLAYING" stays before fading out (seconds).
@export var end_hold_time: float = 5.0

## True once used (also stops the interact outline).
var is_fixed: bool = false

const PANEL_W := 48
const PANEL_H := 39
const GLINT_FRAMES := 9   # frame 0 = no glint, 1..8 = glint sweeping across

var _sprite: Sprite2D
var _led: ColorRect
var _charging: bool = false
var _glint_wait: float = 1.5
var _glint_frame: float = 0.0
var _player: CharacterBody2D
var _camera: Camera2D
var _cam_start: Vector2
var _cam_end: Vector2
var _credits_layer: CanvasLayer
var _credits: Control
var _text_start_y: float
var _text_end_y: float
var _progress: float = 0.0
var _rising: bool = false
var _time: float = 0.0
var _sfx: AudioStreamPlayer
var _rise_tween: Tween
var _skip_button: Button
var _skipping: bool = false

## Emitted when the camera has finished rising (normally or after a skip).
signal _rise_finished

const THEME := preload("res://UI/MainMenu/menu_theme.tres")


func _ready() -> void:
	_build_panel_v2()
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)


# --- Interaction -----------------------------------------------------------

## Called by the player's InteractionController when E is pressed.
func interact(player: Node) -> void:
	if is_fixed or not (player is CharacterBody2D):
		return
	is_fixed = true
	_player = player
	_run_ending()


func _run_ending() -> void:
	_lock_player()
	await _charge()
	await _reveal_colors()
	_start_rise()


# --- 1. Charging -------------------------------------------------------------

func _lock_player() -> void:
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	var anim := _player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim:
		anim.play("Idle")
	var s := _player.get_node_or_null("Sprite2D") as Sprite2D
	if s:
		s.flip_h = global_position.x < _player.global_position.x  # face the panel
	var dust := _player.get_node_or_null("RunDustParticles") as CPUParticles2D
	if dust:
		dust.emitting = false


func _charge() -> void:
	_play(CHARGE_SOUND)
	_charging = true
	var panel_top := global_position + Vector2(2, -PANEL_H + 10)
	var target := _player.global_position + Vector2(0, -2)

	# Energy flowing from the panel into the robot.
	var flow := CPUParticles2D.new()
	flow.amount = 40
	flow.lifetime = 0.7
	flow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flow.emission_rect_extents = Vector2(14, 3)
	var to_robot := target - panel_top
	flow.direction = to_robot.normalized()
	flow.spread = 12.0
	flow.gravity = Vector2.ZERO
	flow.initial_velocity_min = to_robot.length() / 0.75
	flow.initial_velocity_max = to_robot.length() / 0.65
	flow.scale_amount_min = 1.0
	flow.scale_amount_max = 2.0
	flow.color_ramp = _energy_ramp()
	flow.z_index = 20
	get_parent().add_child(flow)
	flow.global_position = panel_top
	flow.emitting = true

	# Charge bar above the robot.
	var bar_root := Node2D.new()
	bar_root.z_index = 30
	get_parent().add_child(bar_root)
	bar_root.global_position = _player.global_position + Vector2(-11, -26)
	var back := ColorRect.new()
	back.size = Vector2(22, 4)
	back.color = Color(0.05, 0.05, 0.07, 0.9)
	bar_root.add_child(back)
	var fill := ColorRect.new()
	fill.position = Vector2(1, 1)
	fill.size = Vector2(0, 2)
	fill.color = Color(1.0, 0.85, 0.3)
	bar_root.add_child(fill)

	var t := create_tween().set_parallel(true)
	t.tween_property(fill, "size:x", 20.0, charge_time).set_trans(Tween.TRANS_SINE)
	t.tween_property(_player, "modulate", Color(1.7, 1.6, 1.3), charge_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_sprite, "modulate", Color(1.25, 1.25, 1.2), charge_time * 0.6)
	await t.finished

	_charging = false
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.8)
	flow.emitting = false
	get_tree().create_timer(1.0).timeout.connect(flow.queue_free)
	var bt := create_tween()
	bt.tween_property(bar_root, "modulate:a", 0.0, 0.4)
	bt.tween_callback(bar_root.queue_free)


# --- 2. The colors come back -----------------------------------------------

func _reveal_colors() -> void:
	if ResourceLoader.exists(DONE_SOUND_PATH):
		_play(load(DONE_SOUND_PATH))
	_burst(_player.global_position)

	# White flash over everything, then fade it away as the colors flood in.
	var layer := CanvasLayer.new()
	layer.layer = 105
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.85, 0.12)
	t.tween_callback(func():
		var cm := get_node_or_null("/root/ColorManager")
		if cm:
			cm.unlock(cm.ALL))
	t.tween_property(flash, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_player, "modulate", Color(1.15, 1.12, 1.05), 1.4)
	t.tween_callback(layer.queue_free)
	await get_tree().create_timer(color_reveal_time).timeout


# --- 3. The camera rises with quotes and credits ---------------------------

func _start_rise() -> void:
	var old_cam := get_viewport().get_camera_2d()
	_camera = Camera2D.new()
	_camera.zoom = old_cam.zoom if old_cam else Vector2(3, 3)
	get_parent().add_child(_camera)
	_cam_start = old_cam.get_screen_center_position() if old_cam else _player.global_position
	_camera.global_position = _cam_start
	_camera.make_current()
	var end_x := camera_center_x if camera_center_x >= 0.0 else _cam_start.x
	_cam_end = Vector2(end_x, _cam_start.y - rise_distance)

	_build_credits()
	# Wait one frame so the text block knows its size, then plan its path:
	# it starts just below the screen and ends with the thank-you centered.
	await get_tree().process_frame
	var screen_h := get_viewport().get_visible_rect().size.y
	_text_start_y = screen_h + 40.0
	var thanks: Control = _credits.get_meta("thanks")
	var thanks_center := thanks.position.y + thanks.size.y * 0.5
	_text_end_y = screen_h * 0.5 - thanks_center
	_credits.position.y = _text_start_y

	_rising = true
	_rise_tween = create_tween()
	_rise_tween.tween_property(self, "_progress", 1.0, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_rise_tween.finished.connect(func(): _rise_finished.emit())
	_build_skip_button()
	await _rise_finished
	_hide_skip_button()
	await get_tree().create_timer(end_hold_time).timeout
	_finish()


## Skips ahead: the credits scroll quickly up to "THANK YOU FOR PLAYING!".
func skip_credits() -> void:
	if not _rising or _skipping or _progress >= 1.0:
		return
	_skipping = true
	_hide_skip_button()
	if _rise_tween and _rise_tween.is_valid():
		_rise_tween.kill()
	_rise_tween = create_tween()
	_rise_tween.tween_property(self, "_progress", 1.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_rise_tween.finished.connect(func(): _rise_finished.emit())


# A small SKIP >> button in the bottom-right corner, faded in after a moment.
func _build_skip_button() -> void:
	_skip_button = Button.new()
	_skip_button.text = "SKIP  >>"
	_skip_button.theme = THEME
	_skip_button.add_theme_font_override("font", FONT_SMALL)
	_skip_button.anchor_left = 1.0
	_skip_button.anchor_top = 1.0
	_skip_button.anchor_right = 1.0
	_skip_button.anchor_bottom = 1.0
	_skip_button.offset_left = -230
	_skip_button.offset_top = -100
	_skip_button.offset_right = -40
	_skip_button.offset_bottom = -40
	_skip_button.modulate.a = 0.0
	_skip_button.pressed.connect(skip_credits)
	_credits_layer.add_child(_skip_button)
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_property(_skip_button, "modulate:a", 0.85, 0.6)
	_skip_button.grab_focus()  # so Enter / Space / controller A press it


func _hide_skip_button() -> void:
	if _skip_button == null or not is_instance_valid(_skip_button):
		return
	var b := _skip_button
	_skip_button = null
	b.disabled = true
	var t := create_tween()
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)


func _process(delta: float) -> void:
	_time += delta
	_animate_panel(delta)
	if not _rising:
		return
	# Keep the skip button selected (e.g. after closing the pause menu).
	if _skip_button and is_instance_valid(_skip_button) and not get_tree().paused:
		if get_viewport().gui_get_focus_owner() == null:
			_skip_button.grab_focus()
	# Camera and text move together, so the text feels part of the world.
	# The camera drifts sideways to the shaft's middle during the first part.
	var side := clampf(_progress * 6.0, 0.0, 1.0)
	_camera.global_position = Vector2(
		lerpf(_cam_start.x, _cam_end.x, side * side * (3.0 - 2.0 * side)),
		lerpf(_cam_start.y, _cam_end.y, _progress))
	_credits.position.y = lerpf(_text_start_y, _text_end_y, _progress)


func _finish() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 125
	add_child(fade_layer)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(black)
	var t := create_tween().set_parallel(true)
	t.tween_property(black, "color:a", 1.0, 2.5)
	var music := get_tree().current_scene.get_node_or_null("SoundTrackLevel3")
	if music:
		t.tween_property(music, "volume_db", -60.0, 2.5)
	await t.finished
	get_tree().change_scene_to_file(MAIN_MENU)


func _build_credits() -> void:
	_credits_layer = CanvasLayer.new()
	_credits_layer.layer = 112  # above the color filter, below the pause menu
	add_child(_credits_layer)
	var screen_w := get_viewport().get_visible_rect().size.x

	_credits = VBoxContainer.new()
	_credits.position = Vector2(0, 0)
	_credits.custom_minimum_size = Vector2(screen_w, 0)
	_credits.size = Vector2(screen_w, 0)
	_credits.add_theme_constant_override("separation", int(quote_gap))
	_credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_layer.add_child(_credits)

	for q in quotes:
		_credits.add_child(_quote_label(q))
	_credits.add_child(_spacer(section_gap))

	# Game title (same art as the main menu) + credits.
	var title := VBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tex in [TITLE_TOP, TITLE_BOTTOM]:
		var r := TextureRect.new()
		r.texture = tex
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		r.custom_minimum_size = tex.get_size()
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		title.add_child(r)
	var lines := _label(credits_text, FONT_SMALL, Color(0.88, 0.9, 0.95))
	lines.add_theme_constant_override("line_spacing", 10)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	title.add_child(gap)
	title.add_child(lines)
	_credits.add_child(title)

	_credits.add_child(_spacer(section_gap))
	_credits.add_child(_quote_label(final_quote))

	# How many times the robot died on the way here.
	var dc := get_node_or_null("/root/DeathCounter")
	if dc != null:
		var n := int(dc.deaths)
		var line := "NOT A SINGLE DEATH. AMAZING!" if n == 0 else \
			("YOU MADE IT WITH 1 DEATH" if n == 1 else "YOU MADE IT WITH %d DEATHS" % n)
		_credits.add_child(_label(line, FONT_SMALL, Color(0.88, 0.9, 0.95)))

	var thanks := _label("THANK YOU FOR PLAYING!", FONT, Color(1.0, 0.86, 0.42))
	thanks.add_theme_font_size_override("font_size", 28)
	_credits.add_child(thanks)
	_credits.set_meta("thanks", thanks)


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _quote_label(text: String) -> Label:
	var l := _label(text, FONT, Color(1.0, 0.86, 0.42))
	l.add_theme_constant_override("line_spacing", 12)
	return l


func _label(text: String, font: Font, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Effects -----------------------------------------------------------------

func _burst(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 60
	p.lifetime = 1.4
	p.spread = 180.0
	p.gravity = Vector2(0, 40)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 140.0
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.3, Color(1.0, 0.85, 0.3, 1))
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.9, 1.0, 0.0))
	p.color_ramp = g
	p.z_index = 40
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


func _energy_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.6, 0.0))
	g.add_point(0.15, Color(1.0, 0.95, 0.7, 1.0))
	g.add_point(0.7, Color(1.0, 0.8, 0.3, 1.0))
	g.set_color(g.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	return g


func _play(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()


# --- Building the panel ------------------------------------------------------

# Draws the solar panel as pixel art into a little sprite sheet:
# frame 0 = plain panel, frames 1..8 = a light glint sweeping across it.
func _build_panel_v2() -> void:
	var sheet := Image.create_empty(PANEL_W * GLINT_FRAMES, PANEL_H, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for f in GLINT_FRAMES:
		_draw_panel_frame(sheet, f * PANEL_W, f)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.texture = ImageTexture.create_from_image(sheet)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hframes = GLINT_FRAMES
	_sprite.centered = true
	_sprite.offset = Vector2(0, -PANEL_H * 0.5)
	add_child(_sprite)

	# Status light on the junction box (red = waiting, amber = charging, green = done).
	_led = ColorRect.new()
	_led.size = Vector2(1, 1)
	_led.position = Vector2(-PANEL_W * 0.5 + 26, -PANEL_H + 27)
	_led.color = Color(1.0, 0.25, 0.2)
	_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_led)

	# Interaction zone (the player presses E inside it).
	var area := Area2D.new()
	area.name = "InteractionArea"
	area.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(68, 48)
	shape.shape = rect
	shape.position = Vector2(0, -20)
	area.add_child(shape)
	add_child(area)


func _draw_panel_frame(img: Image, ox: int, frame: int) -> void:
	var outline := Color(0.09, 0.1, 0.13)
	var alu := Color(0.55, 0.58, 0.64)
	var alu_hi := Color(0.78, 0.81, 0.86)
	var alu_lo := Color(0.33, 0.35, 0.41)
	var gap := Color(0.12, 0.15, 0.24)
	var metal := Color(0.45, 0.47, 0.53)
	var metal_dk := Color(0.27, 0.28, 0.33)
	var concrete := Color(0.52, 0.51, 0.48)
	var concrete_hi := Color(0.66, 0.65, 0.61)
	var concrete_lo := Color(0.36, 0.35, 0.33)

	# The panel is a parallelogram leaning back toward the sky.
	var top := 2
	var bottom := 22
	var glint_pos := -100
	if frame > 0:
		glint_pos = -8 + (frame - 1) * 8
	for y in range(top, bottom + 1):
		var shift := int(round((bottom - y) * 0.3))
		var x0 := ox + 2 + shift
		var x1 := x0 + 39  # widest point stays inside the 48 px frame
		for x in range(x0, x1 + 1):
			var c: Color
			var lx := x - x0
			var ly := y - top
			if y == top or y == bottom or x == x0 or x == x1:
				c = outline
			elif y == top + 1:
				c = alu_hi
			elif y == bottom - 1:
				c = alu_lo
			elif lx == 1:
				c = alu
			elif lx == 38:
				c = alu_lo
			else:
				# Cells: 6 columns x 3 rows, thin dark gaps between them.
				var cx := lx - 2
				var cy := ly - 2
				if cx % 6 == 5 or cy % 6 == 5:
					c = gap
				else:
					var t := float(ly) / float(bottom - top)
					c = Color(0.27, 0.5, 0.92).lerp(Color(0.09, 0.2, 0.52), t)
					if cy % 6 == 2:
						c = c.lightened(0.12)  # thin busbar line across each cell
					if cx % 6 == 0 and cy % 6 == 0:
						c = c.lightened(0.35)  # corner shine
			# Glint: a diagonal band of light sweeping across the glass.
			if frame > 0 and c != outline:
				var d := lx + ly - glint_pos
				if d >= 0 and d < 3:
					c = c.lerp(Color(1, 1, 1), 0.55 if d == 1 else 0.3)
			img.set_pixel(x, y, c)

	# Mount: a post under the middle of the panel and a diagonal strut.
	var mid := ox + PANEL_W / 2
	for y in range(bottom + 1, 35):
		img.set_pixel(mid - 2, y, outline)
		img.set_pixel(mid - 1, y, metal)
		img.set_pixel(mid, y, metal)
		img.set_pixel(mid + 1, y, metal_dk)
		img.set_pixel(mid + 2, y, outline)
	for i in 8:
		var sx := mid - 3 - i
		var sy := bottom + 1 + i
		img.set_pixel(sx, sy, metal_dk)
		img.set_pixel(sx, sy + 1, outline)
	# Junction box on the post (the status light sits on its front).
	for y in range(25, 31):
		for x in range(mid - 1, mid + 5):
			var edge := y == 25 or y == 30 or x == mid - 1 or x == mid + 4
			img.set_pixel(x, y, outline if edge else Color(0.22, 0.23, 0.28))
	# Concrete base.
	for y in range(35, PANEL_H):
		for x in range(mid - 10, mid + 11):
			var edge := x == mid - 10 or x == mid + 10 or y == PANEL_H - 1
			var c := concrete
			if y == 35:
				c = concrete_hi
			elif y == PANEL_H - 2:
				c = concrete_lo
			img.set_pixel(x, y, outline if edge else c)


# Glint every few seconds (often while charging) + the status light.
func _animate_panel(delta: float) -> void:
	if _sprite == null:
		return
	if _glint_frame > 0.0:
		_glint_frame += delta * 18.0
		if _glint_frame >= GLINT_FRAMES:
			_glint_frame = 0.0
			_glint_wait = 0.5 if _charging else randf_range(2.5, 4.5)
	else:
		_glint_wait -= delta
		if _glint_wait <= 0.0:
			_glint_frame = 1.0
	_sprite.frame = int(_glint_frame)

	if _led:
		if is_fixed and not _charging:
			_led.color = Color(0.3, 1.0, 0.4)  # done
		elif _charging:
			_led.color = Color(1.0, 0.75, 0.2) if fmod(_time, 0.3) < 0.15 else Color(0.4, 0.28, 0.08)
		else:
			_led.color = Color(1.0, 0.25, 0.2) if fmod(_time, 1.6) < 0.25 else Color(0.35, 0.08, 0.06)
