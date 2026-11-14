extends RigidBody2D
class_name VanController

const SPRING_REST := 53.0
const SPRING_RANGE := 72.0
const SPRING_STIFFNESS := 700.0
const SPRING_DAMPING := 100.0
const DRIVE_FORCE := 25500.0
const MAX_SPEED := 285.0
const VAN_SPRITE := preload("res://assets/sprites/van.png")
const WHEEL_SPRITE := preload("res://assets/sprites/wheel.png")
const WHEEL_RADIUS := 18.0

var active := false
var was_grounded := false
var landing_cooldown := 0.0
var wheel_angle := 0.0

func _ready() -> void:
	mass = 16.0
	linear_damp = 0.55
	angular_damp = 1.8
	collision_layer = 8
	collision_mask = 1
	freeze = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var chassis := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(150, 12)
	chassis.shape = shape
	chassis.position = Vector2(0, 0)
	add_child(chassis)
	queue_redraw()

func start() -> void:
	active = true
	freeze = false
	sleeping = false

func stop() -> void:
	active = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true

func _physics_process(delta: float) -> void:
	if not active:
		return
	landing_cooldown = maxf(0.0, landing_cooldown - delta)
	var grounded := false
	var state := get_world_2d().direct_space_state
	for wheel_x in [-72.0, 72.0]:
		var origin := to_global(Vector2(wheel_x, 8))
		var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2.DOWN * SPRING_RANGE, 1, [get_rid()])
		var hit := state.intersect_ray(query)
		if hit.is_empty():
			continue
		grounded = true
		var distance: float = origin.distance_to(hit.position)
		var compression: float = maxf(0.0, SPRING_REST - distance)
		var wheel_offset := Vector2(wheel_x, 8).rotated(rotation)
		var point_velocity: Vector2 = linear_velocity + Vector2(-wheel_offset.y, wheel_offset.x) * angular_velocity
		var force: float = maxf(0.0, compression * SPRING_STIFFNESS + point_velocity.y * SPRING_DAMPING)
		apply_force(Vector2.UP * force, wheel_offset)
		if force > 14000.0 and landing_cooldown <= 0.0:
			GameManager.record_van_damage((force - 14000.0) * 0.004)
			landing_cooldown = 0.65
	if grounded and not was_grounded and linear_velocity.y > 255.0 and landing_cooldown <= 0.0:
		var damage: float = (linear_velocity.y - 255.0) * 0.09
		GameManager.record_van_damage(damage)
		landing_cooldown = 0.65
	was_grounded = grounded
	var throttle := Input.get_axis("drive_left", "drive_right")
	if absf(linear_velocity.x) < MAX_SPEED or signf(throttle) != signf(linear_velocity.x):
		apply_central_force(Vector2(throttle * DRIVE_FORCE, 0))
	if Input.is_action_pressed("brake"):
		apply_central_force(Vector2(-linear_velocity.x * 170.0, 0))
	apply_torque(-rotation * 230000.0 - angular_velocity * 42000.0)
	var forward_speed := linear_velocity.dot(Vector2.RIGHT.rotated(rotation))
	wheel_angle = fposmod(wheel_angle + forward_speed * delta / WHEEL_RADIUS, TAU)
	queue_redraw()

func _draw() -> void:
	draw_texture(VAN_SPRITE, Vector2(-105, -93))
	for wheel_x in [-72.0, 72.0]:
		draw_set_transform(Vector2(wheel_x, 28.0), wheel_angle, Vector2.ONE)
		draw_texture(WHEEL_SPRITE, Vector2(-20, -20))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
