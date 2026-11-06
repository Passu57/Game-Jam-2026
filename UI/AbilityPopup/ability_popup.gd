extends CanvasLayer
## Autoload: AbilityPopup
## Shows a small "module installed" popup whenever GameProgress unlocks an
## ability: a little light burst around the robot, then a compact panel that
## slides in at the top with the ability name and how to use it.
## When the player actually uses the ability, it says "NICE!" and closes.
##
## Add new abilities to ABILITIES below. {jump} / {throw} / {interact} etc.
## are replaced with the key the player has bound to that action.

const FONT := preload("res://UI/MainMenu/fonts/spark_font.fnt")
const FONT_SMALL := preload("res://UI/MainMenu/fonts/spark_font_small.fnt")
const ICONS := preload("res://UI/AbilityPopup/ability_icons.png")
const ICON_SIZE := 16

const ABILITIES := {
	&"double_jump": {
		"title": "DOUBLE JUMP",
		"text": "PRESS {jump} IN THE AIR",
		"icon": 0,
	},
	&"wrench_throw": {
		"title": "WRENCH THROW",
		"text": "HOLD {throw} TO AIM, LET GO TO THROW",
		"icon": 1,
	},
	&"dash": {
		"title": "DASH",
		"text": "PRESS {dash} TO DASH, EVEN IN THE AIR",
		"icon": 2,
	},
	&"wall_jump": {
		"title": "WALL JUMP",
		"text": "PRESS {jump} ON A WALL TO KICK OFF",
		"icon": 3,
	},
}

## Main color of the popup (border, header).
@export var accent: Color = Color(0.45, 0.93, 1.0)
## Color used for key names in the instruction.
@export var key_color: Color = Color(1.0, 0.84, 0.25)
## How long the popup stays if the player doesn't try the ability (seconds).
@export var show_time: float = 8.0
## Distance from the top of the screen (pixels).
@export var top_margin: float = 40.0
## Short slow-motion moment when picking it up (0 = off).
@export var slowmo_time: float = 0.2
@export var slowmo_scale: float = 0.4

var _queue: Array[StringName] = []
var _busy: bool = false
var _current: StringName = &""
var _waiting_for_use: bool = false
var _close_timer: float = 0.0
var _last_air_jumps: int = -1

var _root: Control
var _holder: CenterContainer
var _panel: PanelContainer
var _header: Label
var _title: Label
var _text: RichTextLabel
var _icon: TextureRect
var _bar: ColorRect


func _ready() -> void:
	layer = 110  # above ColorManager (100), so the popup is always in color
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameProgress.ability_unlocked.connect(_on_ability_unlocked)


func _on_ability_unlocked(ability: StringName) -> void:
	_queue.append(ability)
	if not _busy:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	_current = _queue.pop_front()
	var info: Dictionary = ABILITIES.get(_current, {})
	_title.text = info.get("title", String(_current).replace("_", " ").to_upper())
	_text.text = _fill_keys(info.get("text", ""))
	var atlas := AtlasTexture.new()
	atlas.atlas = ICONS
	atlas.region = Rect2(int(info.get("icon", 0)) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	_icon.texture = atlas

	_pickup_moment()
	_open()


# --- The moment of picking it up ------------------------------------------

func _pickup_moment() -> void:
	var player := _find_player()
	if player != null:
		_burst(player.global_position)
	if slowmo_time > 0.0:
		Engine.time_scale = slowmo_scale
		# Real-time timer (ignores the slow motion it causes).
		get_tree().create_timer(slowmo_time, true, false, true).timeout.connect(
			func(): Engine.time_scale = 1.0)


func _burst(at: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 4.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 70.0
	p.damping_min = 80.0
	p.damping_max = 110.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(accent.r, accent.g, accent.b, 0.0))
	p.color_ramp = g
	p.z_index = 50
	scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


func _find_player() -> CharacterBody2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for n in scene.get_children():
		if n is CharacterBody2D and n.has_method("die"):
			return n
	return null


# --- Opening / closing -----------------------------------------------------

func _open() -> void:
	_root.visible = true
	_close_timer = show_time
	_bar.scale.x = 1.0
	_text.visible_ratio = 0.0
	_waiting_for_use = _current in [&"double_jump", &"wrench_throw", &"dash", &"wall_jump"]
	_last_air_jumps = -1

	# Calm slide down + fade in, then the instruction types itself out.
	_holder.modulate.a = 0.0
	_holder.position.y = top_margin - 16.0
	var t := _tween()
	t.set_parallel(true)
	t.tween_property(_holder, "modulate:a", 1.0, 0.25)
	t.tween_property(_holder, "position:y", top_margin, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	t.tween_property(_text, "visible_ratio", 1.0, 0.4)


func _close() -> void:
	_waiting_for_use = false
	_close_timer = 0.0
	var t := _tween()
	t.set_parallel(true)
	t.tween_property(_holder, "modulate:a", 0.0, 0.25)
	t.tween_property(_holder, "position:y", top_margin - 16.0, 0.25)
	await t.finished
	_root.visible = false
	_show_next()


func _process(delta: float) -> void:
	if not _root.visible:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)

	if _close_timer > 0.0:
		_close_timer -= real_delta
		_bar.scale.x = clampf(_close_timer / show_time, 0.0, 1.0)
		if _close_timer <= 0.0:
			_close()
			return

	# Did the player really use it? Then cheer and close.
	if _waiting_for_use and _used_ability():
		_waiting_for_use = false
		_text.text = "[color=#7dff8a]NICE! YOU'VE GOT IT.[/color]"
		_text.visible_ratio = 1.0
		_close_timer = minf(_close_timer, 1.5)


func _used_ability() -> bool:
	match _current:
		&"double_jump":
			# The robot's air-jump counter only goes down on a real double
			# jump (a normal jump from the ground doesn't touch it).
			var player := _find_player()
			if player == null or not ("_air_jumps_left" in player):
				return false
			var now: int = player.get("_air_jumps_left")
			var used := _last_air_jumps >= 0 and now < _last_air_jumps
			_last_air_jumps = now
			return used
		&"wrench_throw":
			return Input.is_action_just_released("throw")
		&"dash":
			var player := _find_player()
			var dash := player.get_node_or_null("DashAbility") if player != null else null
			return dash != null and dash.get("is_dashing") == true
		&"wall_jump":
			var player := _find_player()
			var wj := player.get_node_or_null("WallJumpAbility") if player != null else null
			if wj != null and not wj.wall_jumped.is_connected(_on_wall_jumped):
				wj.wall_jumped.connect(_on_wall_jumped)
			var used := _wall_jump_used
			_wall_jump_used = false
			return used
	return false


var _wall_jump_used: bool = false


func _on_wall_jumped(_dir: float) -> void:
	_wall_jump_used = true


func _tween() -> Tween:
	# UI animations run at normal speed even during the slow-motion moment.
	return create_tween().set_ignore_time_scale(true)


# --- Key names -----------------------------------------------------------

func _fill_keys(text: String) -> String:
	var hex := key_color.to_html(false)
	for action in InputMap.get_actions():
		var tag := "{%s}" % action
		if tag in text:
			text = text.replace(tag, "[color=#%s]%s[/color]" % [hex, _key_name(action)])
	return text


func _key_name(action: StringName) -> String:
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
	return String(action).to_upper()


# --- Building the UI -----------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	# Compact panel, top center.
	_holder = CenterContainer.new()
	_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_holder.offset_top = top_margin
	_holder.offset_bottom = top_margin + 140
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.9)
	style.border_color = accent
	style.set_border_width_all(3)
	style.content_margin_left = 16
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	_holder.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	outer.add_child(row)

	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(64, 64)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)

	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 4)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)

	_header = _label(FONT_SMALL, accent)
	_header.text = "NEW MODULE INSTALLED"
	words.add_child(_header)

	_title = _label(FONT, Color.WHITE)
	words.add_child(_title)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.custom_minimum_size = Vector2(420, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("normal_font", FONT_SMALL)
	_text.add_theme_color_override("default_color", Color(0.85, 0.9, 1.0))
	words.add_child(_text)

	# Thin time-left bar along the bottom.
	var bar_back := ColorRect.new()
	bar_back.custom_minimum_size = Vector2(0, 3)
	bar_back.color = Color(accent.r, accent.g, accent.b, 0.2)
	outer.add_child(bar_back)
	_bar = ColorRect.new()
	_bar.color = accent
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_back.add_child(_bar)


func _label(font: Font, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", color)
	return l
