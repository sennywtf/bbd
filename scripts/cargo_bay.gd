extends AnimatableBody2D
class_name CargoBay

var van: VanController

func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	_add_wall(Vector2(-102, -39), Vector2(8, 102))
	_add_wall(Vector2(40, -39), Vector2(8, 102))
	_add_wall(Vector2(-31, 10), Vector2(145, 8))
	_add_wall(Vector2(-31, -91), Vector2(145, 8))

func _physics_process(_delta: float) -> void:
	if is_instance_valid(van):
		global_transform = van.global_transform

func _add_wall(center: Vector2, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	add_child(collision)
