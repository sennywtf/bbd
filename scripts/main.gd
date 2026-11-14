extends Node2D

const DELIVERY_HOLD_SECONDS := 0.8

var van: VanController
var bay: CargoBay
var hud: ShiftHud
var packages: Array[CargoPackage] = []
var zones: Array[DeliveryZone] = []
var delivery_hold_time := 0.0
var delivery_hold_zone: DeliveryZone

func _ready() -> void:
	GameManager.running = false
	GameManager.finished = false
	var stop_count := GameManager.total_stops()
	var route_end := int(Road.FIRST_HOUSE_X + float(stop_count - 1) * Road.HOUSE_SPACING + 850.0)
	var backdrop := preload("res://scripts/world_backdrop.gd").new()
	backdrop.world_end = float(route_end + 500)
	add_child(backdrop)
	var road := Road.new()
	road.level = GameManager.current_level
	road.road_end = route_end
	add_child(road)
	for id in range(1, stop_count + 1):
		var house_x := Road.FIRST_HOUSE_X + Road.HOUSE_SPACING * float(id - 1)
		var zone := DeliveryZone.new()
		zone.package_id = id
		zone.position = Vector2(house_x, Road.height_at(house_x, GameManager.current_level))
		add_child(zone)
		zones.append(zone)
	van = VanController.new()
	van.z_index = 2
	van.position = Vector2(150, Road.height_at(150, GameManager.current_level) - 52.0)
	add_child(van)
	var camera := Camera2D.new()
	camera.offset = Vector2(210, -82)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = -250
	camera.limit_right = route_end + 100
	van.add_child(camera)
	camera.make_current()
	bay = CargoBay.new()
	bay.van = van
	add_child(bay)
	bay.global_transform = van.global_transform
	var cargo_positions := [
		Vector2(-78, -7), Vector2(-35, -7), Vector2(-78, -32),
		Vector2(8, -7), Vector2(-35, -32), Vector2(8, -32),
		Vector2(-78, -57), Vector2(-35, -57), Vector2(8, -57),
		Vector2(-78, -77), Vector2(-35, -77), Vector2(8, -77)
	]
	for i in range(stop_count):
		var package := CargoPackage.new()
		var row := i / 3
		var edge := 22.0 - float(row) * 2.0
		var size := Vector2(edge, edge)
		var weight := 0.9 + float(i % 4) * 0.25
		var fragility := (0.85 + float(i % 3) * 0.25) * GameManager.difficulty()
		package.setup(i + 1, weight, fragility, size)
		package.z_index = 3
		package.van = van
		package.global_position = van.to_global(cargo_positions[i])
		add_child(package)
		packages.append(package)
	hud = ShiftHud.new()
	add_child(hud)
	hud.setup(packages, zones, van)
	hud.start_requested.connect(_start_shift)
	hud.next_level_requested.connect(_next_level)
	hud.retry_requested.connect(_retry_level)
	hud.home_requested.connect(_home)
	GameManager.shift_ended.connect(_end_shift)
	if GameManager.auto_start_after_reload:
		GameManager.auto_start_after_reload = false
		call_deferred("_auto_start")

func _auto_start() -> void:
	hud.begin_game_transition()

func _start_shift() -> void:
	GameManager.start_shift()
	van.start()
	for package in packages:
		package.start()

func _end_shift() -> void:
	van.stop()
	for package in packages:
		if is_instance_valid(package):
			package.freeze = true
	hud.show_receipt()

func _next_level() -> void:
	GameManager.advance_level()
	get_tree().reload_current_scene()

func _retry_level() -> void:
	GameManager.auto_start_after_reload = true
	get_tree().reload_current_scene()

func _home() -> void:
	GameManager.stop_music()
	if GameManager.campaign_complete:
		GameManager.reset_campaign()
	elif hud.receipt_panel.visible and GameManager.shift_clear:
		GameManager.advance_level()
		GameManager.auto_start_after_reload = false
	else:
		GameManager.auto_start_after_reload = false
	get_tree().reload_current_scene()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("bounce_stop") and GameManager.running:
		get_viewport().set_input_as_handled()
		if van.trigger_bounce_stop():
			for package in packages:
				if not is_instance_valid(package) or package.delivered:
					continue
				var relative_velocity := package.linear_velocity - van.linear_velocity
				package.linear_velocity = van.linear_velocity + Vector2(relative_velocity.x * 0.4, relative_velocity.y * 0.15)
				package.angular_velocity *= 0.25
			hud.show_notice("BOUNCE STOP!")
		return
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if hud.home_panel.visible and not hud.name_panel.visible and not hud.leaderboard_panel.visible and not hud.receipt_panel.visible and not hud.checklist_panel.visible and not hud.fade.visible and not GameManager.running:
		return
	GameManager.running = false
	_home()

func _physics_process(_delta: float) -> void:
	if not GameManager.running or not is_instance_valid(van) or van.bounce_stop_time_left <= 0.0:
		return
	for package in packages:
		if not is_instance_valid(package) or package.delivered:
			continue
		var relative_velocity := package.linear_velocity - van.linear_velocity
		package.linear_velocity = van.linear_velocity + Vector2(relative_velocity.x * 0.75, relative_velocity.y * 0.25)
		package.angular_velocity *= 0.25

func _process(delta: float) -> void:
	if not GameManager.running or not Input.is_action_pressed("deliver") or absf(van.linear_velocity.x) > 70.0:
		_reset_delivery_hold()
		return
	var active_zone: DeliveryZone
	for zone in zones:
		if zone.van_inside and not zone.completed:
			active_zone = zone
			break
	if active_zone == null:
		_reset_delivery_hold()
		return
	if delivery_hold_zone != active_zone:
		delivery_hold_zone = active_zone
		delivery_hold_time = 0.0
	delivery_hold_time += delta
	hud.set_delivery_hold_progress(delivery_hold_time / DELIVERY_HOLD_SECONDS)
	if delivery_hold_time >= DELIVERY_HOLD_SECONDS:
		_complete_delivery(active_zone)
		_reset_delivery_hold()

func _reset_delivery_hold() -> void:
	delivery_hold_time = 0.0
	delivery_hold_zone = null
	if is_instance_valid(hud):
		hud.set_delivery_hold_progress(0.0)

func _complete_delivery(zone: DeliveryZone) -> void:
	for package in packages:
		if not is_instance_valid(package) or package.package_id != zone.package_id:
			continue
		var package_health := package.health
		package.delivered = true
		package.freeze = true
		package.linear_velocity = Vector2.ZERO
		package.angular_velocity = 0.0
		package.collision_layer = 0
		package.collision_mask = 0
		package.contact_monitor = false
		package.reparent(zone)
		var box_size: Vector2 = package.get_meta("size")
		package.position = zone.package_drop_position(box_size.y)
		package.rotation = 0.0
		package.z_index = 1
		zone.completed = true
		zone.queue_redraw()
		GameManager.deliver_package(zone.package_id, package_health)
		if GameManager.running:
			hud.show_notice("PACKAGE %d DELIVERED" % zone.package_id)
		return
