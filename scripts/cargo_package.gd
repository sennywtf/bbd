extends RigidBody2D
class_name CargoPackage

const BOX_SPRITE := preload("res://assets/sprites/box.png")
const DAMAGED_SPRITE := preload("res://assets/sprites/box-damaged.png")

var package_id := 1
var health := 100.0
var fragility := 1.0
var van: VanController
var impact_cooldown := 0.0
var settling_time_left := 0.0
var delivered := false

func setup(id: int, weight: float, fragility_value: float, size: Vector2) -> void:
	package_id = id
	mass = weight
	fragility = fragility_value
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	add_child(shape_node)
	set_meta("size", size)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 | 4
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.35
	angular_damp = 2.0
	freeze = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(_on_body_entered)
	queue_redraw()

func start() -> void:
	settling_time_left = 0.35
	freeze = false
	sleeping = false

func _physics_process(delta: float) -> void:
	if freeze or delivered:
		return
	impact_cooldown = maxf(0.0, impact_cooldown - delta)
	settling_time_left = maxf(0.0, settling_time_left - delta)
	if not is_instance_valid(van):
		return
	var relative_velocity := van.linear_velocity - linear_velocity
	apply_central_force(relative_velocity * mass * 8.0)

func _on_body_entered(body: Node) -> void:
	if freeze or delivered or impact_cooldown > 0.0 or settling_time_left > 0.0:
		return
	var other_velocity := van.linear_velocity
	if body is CargoPackage:
		other_velocity = body.linear_velocity
	var speed := (linear_velocity - other_velocity).length()
	var impact := maxf(0.0, speed - 85.0) * fragility * 0.075
	var actual_damage := minf(health, impact)
	if actual_damage > 0.0:
		health -= actual_damage
		GameManager.record_cargo_damage(actual_damage, package_id)
		queue_redraw()
		impact_cooldown = 0.25

func _draw() -> void:
	var size: Vector2 = get_meta("size", Vector2(27, 27))
	var sprite := BOX_SPRITE if health > 35.0 else DAMAGED_SPRITE
	draw_texture_rect(sprite, Rect2(-size * 0.5, size), false)
