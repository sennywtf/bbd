extends CanvasLayer
class_name ShiftHud

signal start_requested
signal next_level_requested
signal retry_requested
signal home_requested

const INK := Color("30263d")
const CREAM := Color("fff1d1")
const TERRACOTTA := Color("9e4b32")
const SKY := Color("8ce0f3")
const USE_FRAME_TEXTURE := true

var packages: Array[CargoPackage] = []
var zones: Array[DeliveryZone] = []
var van: VanController
var font: FontFile
var root: Control
var game_ui: Control
var home_panel: PanelContainer
var name_panel: PanelContainer
var name_edit: LineEdit
var name_error: Label
var leaderboard_panel: PanelContainer
var leaderboard_list: VBoxContainer
var checklist_panel: PanelContainer
var checklist_list: VBoxContainer
var checklist_rows: Array[Dictionary] = []
var checklist_button: Button
var receipt_panel: PanelContainer
var receipt_box: VBoxContainer
var modal_dim: ColorRect
var fade: ColorRect
var confetti
var level_label: Label
var stops_label: Label
var timer_label: Label
var action_label: Label
var route_label: Label
var delivery_hold_progress := 0.0
var delivery_hold_bar: ProgressBar
var notice_panel: PanelContainer
var notice_label: Label
var notice_time := 0.0
var damage_notice_cooldown := 0.0

func _ready() -> void:
	font = load("res://assets/fonts/DaydreamDemo.otf")
	var fallback_font := SystemFont.new()
	fallback_font.font_names = PackedStringArray(["Courier New", "Menlo", "DejaVu Sans Mono"])
	fallback_font.font_weight = 800
	font.fallbacks = [fallback_font]
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_game_ui()
	_build_home()
	_build_modal_dim()
	_build_name_prompt()
	_build_leaderboard()
	_build_checklist()
	game_ui.remove_child(notice_panel)
	root.add_child(notice_panel)
	_build_receipt()
	_build_fade()
	_build_confetti()
	GameManager.cargo_damaged.connect(_on_cargo_damaged)
	game_ui.hide()
	name_panel.hide()
	leaderboard_panel.hide()
	checklist_panel.hide()
	receipt_panel.hide()
	modal_dim.hide()
	fade.hide()

func setup(boxes: Array[CargoPackage], stops: Array[DeliveryZone], vehicle: VanController) -> void:
	packages = boxes
	zones = stops
	van = vehicle
	level_label.text = "LEVEL %d / %d" % [GameManager.current_level, GameManager.MAX_LEVEL]
	stops_label.text = "0 / %d" % GameManager.total_stops()
	var duration := ceili(GameManager.shift_duration())
	timer_label.text = "%02d:%02d" % [duration / 60, duration % 60]
	checklist_button.text = "CHECKLIST  0/%d" % GameManager.total_stops()
	_build_checklist_rows()

func set_delivery_hold_progress(value: float) -> void:
	delivery_hold_progress = clampf(value, 0.0, 1.0)

func _process(delta: float) -> void:
	if not GameManager.running:
		return
	damage_notice_cooldown = maxf(0.0, damage_notice_cooldown - delta)
	var seconds := ceili(GameManager.time_left)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	stops_label.text = "%d / %d" % [GameManager.delivered.size(), GameManager.total_stops()]
	checklist_button.text = "CHECKLIST  %d/%d" % [GameManager.delivered.size(), GameManager.total_stops()]
	delivery_hold_bar.hide()
	_update_checklist_rows()
	var next_stop := 0
	for zone in zones:
		if not zone.completed:
			next_stop = zone.package_id
			if zone.van_inside:
				action_label.text = "DELIVERING" if delivery_hold_progress > 0.0 else "DELIVER"
				if absf(van.linear_velocity.x) > 70.0:
					route_label.text = "SLOW DOWN FOR STOP %d" % next_stop
				elif delivery_hold_progress > 0.0:
					route_label.text = "HOLD E  %d%%" % roundi(delivery_hold_progress * 100.0)
					delivery_hold_bar.value = delivery_hold_progress * 100.0
					delivery_hold_bar.show()
				else:
					route_label.text = "HOLD E AT STOP %d" % next_stop
			else:
				action_label.text = "ACTION"
				route_label.text = "DRIVE TO STOP %d" % next_stop
			break
	if notice_time > 0.0:
		notice_time -= delta
		if notice_time <= 0.0:
			notice_panel.hide()

func begin_game_transition() -> void:
	if fade.visible:
		return
	confetti.stop()
	modal_dim.hide()
	name_panel.hide()
	leaderboard_panel.hide()
	fade.show()
	fade.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.35)
	tween.tween_callback(_reveal_game)
	tween.tween_interval(0.10)
	tween.tween_property(fade, "modulate:a", 0.0, 0.45)
	tween.tween_callback(_hide_fade)

func _reveal_game() -> void:
	home_panel.hide()
	game_ui.show()

func _hide_fade() -> void:
	fade.hide()
	start_requested.emit()

func show_notice(message: String) -> void:
	notice_label.text = message
	notice_panel.show()
	notice_time = 2.2

func _on_cargo_damaged(_package_id: int, _amount: float) -> void:
	if GameManager.running and damage_notice_cooldown <= 0.0:
		show_notice("CARGO DAMAGED! DRIVE CAREFULLY")
		damage_notice_cooldown = 0.65

func show_receipt() -> void:
	game_ui.hide()
	checklist_panel.hide()
	notice_panel.hide()
	modal_dim.hide()
	for child in receipt_box.get_children():
		receipt_box.remove_child(child)
		child.queue_free()
	var result := GameManager.receipt()
	var title := "LEVEL %d COMPLETE" % GameManager.current_level
	if not GameManager.shift_clear:
		title = "SHIFT FAILED"
	elif GameManager.campaign_complete:
		title = "GAME COMPLETE"
	receipt_box.add_child(_label(title, 28, TERRACOTTA, false))
	receipt_box.add_child(_label("%s / LEVEL %d OF %d" % [GameManager.player_name, GameManager.current_level, GameManager.MAX_LEVEL], 13, TERRACOTTA, false))
	_spacer(receipt_box, 8)
	receipt_box.add_child(_label("HOUSES  %d / %d" % [result["delivered"], GameManager.total_stops()], 17, INK, false))
	receipt_box.add_child(_label("BASE PAY  +%s" % _money(result["gross"]), 16, INK, false))
	receipt_box.add_child(_label("PACKAGE DAMAGE  %s" % _money(-result["damage_penalty"]), 16, INK, false))
	receipt_box.add_child(_label("VAN REPAIRS  %s" % _money(-result["repair_cost"]), 16, INK, false))
	_spacer(receipt_box, 4)
	receipt_box.add_child(_label("SHIFT TOTAL  %s" % _money(result["net"]), 20, TERRACOTTA, false))
	receipt_box.add_child(_label("CLEARED SHIFT PAY  %s" % _money(GameManager.campaign_score), 14, TERRACOTTA, false))
	_spacer(receipt_box, 7)
	if GameManager.shift_clear and not GameManager.campaign_complete:
		var next_button := _button("NEXT LEVEL")
		next_button.pressed.connect(func() -> void: next_level_requested.emit())
		receipt_box.add_child(next_button)
	elif not GameManager.shift_clear:
		var retry_button := _button("RETRY LEVEL")
		retry_button.pressed.connect(func() -> void: retry_requested.emit())
		receipt_box.add_child(retry_button)
	var home_button := _button("HOME")
	home_button.pressed.connect(func() -> void: home_requested.emit())
	receipt_box.add_child(home_button)
	receipt_panel.show()
	if GameManager.shift_clear:
		confetti.burst()
	else:
		confetti.stop()

func _build_game_ui() -> void:
	game_ui = Control.new()
	game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(game_ui)
	var status_panel := _panel(Vector2(18, 16), Vector2(455, 112), false)
	game_ui.add_child(status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 2)
	status_panel.add_child(status_box)
	level_label = _label("LEVEL 1 / %d" % GameManager.MAX_LEVEL, 14, SKY)
	status_box.add_child(level_label)
	var main_line := HBoxContainer.new()
	main_line.add_theme_constant_override("separation", 26)
	status_box.add_child(main_line)
	stops_label = _label("0 / 3", 26, CREAM)
	main_line.add_child(stops_label)
	timer_label = _label("00:30", 26, CREAM)
	main_line.add_child(timer_label)
	status_box.add_child(_label("DELIVERIES      SHIFT CLOCK", 11, CREAM))
	checklist_button = _button("CHECKLIST  0/3")
	checklist_button.position = Vector2(1000, 18)
	checklist_button.custom_minimum_size = Vector2(260, 62)
	checklist_button.size = Vector2(260, 62)
	checklist_button.add_theme_font_size_override("font_size", 16)
	checklist_button.pressed.connect(_toggle_checklist)
	game_ui.add_child(checklist_button)
	var keycap := _panel(Vector2(24, 609), Vector2(75, 75), true)
	game_ui.add_child(keycap)
	var key_label := _label("E", 41, TERRACOTTA, false)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keycap.add_child(key_label)
	action_label = _label("ACTION", 26, CREAM)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	action_label.position = Vector2(115, 609)
	action_label.size = Vector2(410, 38)
	game_ui.add_child(action_label)
	route_label = _label("DRIVE TO STOP 1", 16, CREAM)
	route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	route_label.position = Vector2(115, 651)
	route_label.size = Vector2(410, 29)
	game_ui.add_child(route_label)
	delivery_hold_bar = ProgressBar.new()
	delivery_hold_bar.position = Vector2(115, 687)
	delivery_hold_bar.size = Vector2(280, 9)
	delivery_hold_bar.max_value = 100.0
	delivery_hold_bar.show_percentage = false
	delivery_hold_bar.add_theme_stylebox_override("background", _style(INK, CREAM, 1, 0))
	delivery_hold_bar.add_theme_stylebox_override("fill", _style(CREAM, CREAM, 0, 0))
	game_ui.add_child(delivery_hold_bar)
	delivery_hold_bar.hide()
	notice_panel = _panel(Vector2(805, 632), Vector2(455, 62), false)
	game_ui.add_child(notice_panel)
	notice_label = _label("", 14, CREAM)
	notice_panel.add_child(notice_label)
	notice_panel.hide()

func _build_home() -> void:
	home_panel = _panel(Vector2(330, 92), Vector2(620, 540), true)
	root.add_child(home_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	home_panel.add_child(box)
	box.add_child(_label("BAD DAY DELIVERY", 36, TERRACOTTA, false))
	box.add_child(_label("BOUNCE BACK", 22, TERRACOTTA, false))
	_spacer(box, 29)
	box.add_child(_label("DELIVER FAST. PROTECT THE CARGO.", 16, TERRACOTTA, false))
	_spacer(box, 29)
	var play_button := _button("PLAY")
	play_button.pressed.connect(_on_play_pressed)
	box.add_child(play_button)
	var leaderboard_button := _button("LEADERBOARD")
	leaderboard_button.pressed.connect(_show_leaderboard)
	box.add_child(leaderboard_button)

func _build_modal_dim() -> void:
	modal_dim = ColorRect.new()
	modal_dim.color = Color(0.08, 0.04, 0.10, 0.62)
	modal_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_dim)

func _build_name_prompt() -> void:
	name_panel = _panel(Vector2(365, 177), Vector2(550, 355), true)
	root.add_child(name_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	name_panel.add_child(box)
	box.add_child(_label("WHO IS DRIVING?", 27, TERRACOTTA, false))
	box.add_child(_label("ENTER YOUR NAME FOR THE LEADERBOARD", 12, INK, false))
	_spacer(box, 8)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "YOUR NAME"
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 55)
	name_edit.add_theme_font_override("font", font)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.add_theme_color_override("font_color", TERRACOTTA)
	name_edit.add_theme_color_override("font_placeholder_color", Color("b58771"))
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_stylebox_override("normal", _style(Color("fff9e8"), TERRACOTTA, 3, 9))
	name_edit.text_submitted.connect(_on_name_submitted)
	box.add_child(name_edit)
	name_error = _label("", 12, TERRACOTTA, false)
	box.add_child(name_error)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var confirm := _button("START DRIVING")
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_submit_name)
	buttons.add_child(confirm)
	var back := _button("BACK")
	back.add_theme_font_size_override("font_size", 16)
	back.custom_minimum_size = Vector2(105, 60)
	back.pressed.connect(_close_modal)
	buttons.add_child(back)

func _build_leaderboard() -> void:
	leaderboard_panel = _panel(Vector2(350, 104), Vector2(580, 510), true)
	root.add_child(leaderboard_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	leaderboard_panel.add_child(box)
	box.add_child(_label("LEADERBOARD", 30, TERRACOTTA, false))
	box.add_child(_label("BEST LOCAL CAMPAIGN RESULTS", 12, TERRACOTTA, false))
	leaderboard_list = VBoxContainer.new()
	leaderboard_list.custom_minimum_size = Vector2(0, 325)
	leaderboard_list.add_theme_constant_override("separation", 8)
	box.add_child(leaderboard_list)
	var back := _button("BACK")
	back.pressed.connect(_close_modal)
	box.add_child(back)

func _build_checklist() -> void:
	checklist_panel = _panel(Vector2(835, 94), Vector2(425, 515), true)
	root.add_child(checklist_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	checklist_panel.add_child(box)
	box.add_child(_label("PACKAGE CHECKLIST", 22, TERRACOTTA, false))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 403)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	checklist_list = VBoxContainer.new()
	checklist_list.add_theme_constant_override("separation", 10)
	scroll.add_child(checklist_list)
	var close := _button("CLOSE")
	close.custom_minimum_size = Vector2(0, 50)
	close.pressed.connect(_toggle_checklist)
	box.add_child(close)

func _build_checklist_rows() -> void:
	checklist_rows.clear()
	for child in checklist_list.get_children():
		child.queue_free()
	for i in range(GameManager.total_stops()):
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		checklist_list.add_child(row)
		var status := _label("BOX %02d / NOT DELIVERED" % (i + 1), 13, INK, false)
		row.add_child(status)
		var health := _label("HEALTH 100%", 11, TERRACOTTA, false)
		row.add_child(health)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(340, 13)
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = 100.0
		bar.add_theme_stylebox_override("background", _style(Color("cbaaaa"), INK, 1, 0))
		bar.add_theme_stylebox_override("fill", _style(Color("86cfae"), Color("86cfae"), 0, 0))
		row.add_child(bar)
		checklist_rows.append({"status": status, "health": health, "bar": bar})

func _update_checklist_rows() -> void:
	for i in range(checklist_rows.size()):
		var row := checklist_rows[i]
		var hp := 100.0
		var delivered_now := false
		for entry in GameManager.delivered:
			if int(entry["id"]) == i + 1:
				hp = float(entry["health"])
				delivered_now = true
				break
		if not delivered_now and is_instance_valid(packages[i]):
			hp = packages[i].health
		row["status"].text = "BOX %02d / %s" % [i + 1, "DELIVERED" if delivered_now else "NOT DELIVERED"]
		row["health"].text = "HEALTH %d%%" % roundi(hp)
		row["bar"].value = hp

func _build_receipt() -> void:
	receipt_panel = _panel(Vector2(332, 74), Vector2(616, 574), true)
	root.add_child(receipt_panel)
	receipt_box = VBoxContainer.new()
	receipt_box.add_theme_constant_override("separation", 9)
	receipt_panel.add_child(receipt_box)

func _build_fade() -> void:
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(fade)

func _build_confetti() -> void:
	confetti = preload("res://scripts/pixel_confetti.gd").new()
	confetti.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(confetti)

func _on_play_pressed() -> void:
	if GameManager.player_name.is_empty():
		modal_dim.show()
		name_panel.show()
		name_edit.grab_focus()
	else:
		begin_game_transition()

func _on_name_submitted(_value: String) -> void:
	_submit_name()

func _submit_name() -> void:
	if not GameManager.set_player_name(name_edit.text):
		name_error.text = "PLEASE ENTER A NAME"
		return
	name_error.text = ""
	begin_game_transition()

func _show_leaderboard() -> void:
	for child in leaderboard_list.get_children():
		leaderboard_list.remove_child(child)
		child.queue_free()
	if GameManager.leaderboard.is_empty():
		leaderboard_list.add_child(_label("NO SCORES YET. FINISH A LEVEL!", 13, INK, false))
	else:
		for i in range(mini(10, GameManager.leaderboard.size())):
			var entry := GameManager.leaderboard[i]
			var value := "%02d  %s  LV %d  %s" % [i + 1, str(entry["name"]), int(entry["level"]), _money(float(entry["score"]))]
			leaderboard_list.add_child(_label(value, 12, INK, false))
	modal_dim.show()
	leaderboard_panel.show()

func _close_modal() -> void:
	leaderboard_panel.hide()
	name_panel.hide()
	modal_dim.hide()

func _toggle_checklist() -> void:
	checklist_panel.visible = not checklist_panel.visible
	if checklist_panel.visible:
		_update_checklist_rows()

func _panel(at: Vector2, dimensions: Vector2, paper: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.custom_minimum_size = dimensions
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _style(CREAM if paper else INK, TERRACOTTA if paper else Color("fff3dc"), 5 if paper else 3, 17))
	if USE_FRAME_TEXTURE:
		var grain := UiFrameTexture.new()
		grain.paper = paper
		panel.add_child(grain)
	return panel

func _style(fill: Color, border: Color, border_size: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_size)
	style.set_content_margin_all(margin)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _label(value: String, size: int, color: Color, outlined: bool = true) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outlined:
		label.add_theme_color_override("font_outline_color", Color("160f21"))
		label.add_theme_constant_override("outline_size", 3)
	return label

func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", TERRACOTTA)
	button.add_theme_color_override("font_hover_color", TERRACOTTA)
	button.add_theme_stylebox_override("normal", _style(Color("ffe9be"), TERRACOTTA, 5, 10))
	button.add_theme_stylebox_override("hover", _style(Color("fff8e5"), TERRACOTTA, 5, 10))
	button.add_theme_stylebox_override("pressed", _style(Color("efca9b"), TERRACOTTA, 5, 10))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, SKY, 3, 10))
	return button

func _money(amount: float) -> String:
	var value := absf(amount)
	return "-$%.2f" % value if amount < -0.005 else "$%.2f" % value

func _spacer(box: BoxContainer, height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size = Vector2(1, height)
	box.add_child(space)
