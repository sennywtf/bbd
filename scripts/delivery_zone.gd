extends Area2D
class_name DeliveryZone

# Six pixel houses cut from the player-supplied sprite sheet.
const HOUSE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/houses/sprites/house-1.png"),
	preload("res://assets/houses/sprites/house-2.png"),
	preload("res://assets/houses/sprites/house-3.png"),
	preload("res://assets/houses/sprites/house-4.png"),
	preload("res://assets/houses/sprites/house-5.png"),
	preload("res://assets/houses/sprites/house-6.png"),
]
const DOOR_OFFSETS := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const MAX_HOUSE_SIZE := Vector2(210.0, 225.0)
const SIGN_SPRITE := preload("res://assets/sprites/stop-sign.png")
const SIGN_DONE_SPRITE := preload("res://assets/sprites/stop-sign-done.png")
const YARD_SPRITE := preload("res://assets/sprites/yard.png")
const YARD_DONE_SPRITE := preload("res://assets/sprites/yard-done.png")

var package_id := 1
var van_inside := false
var completed := false

func package_drop_position(box_height: float = 22.0) -> Vector2:
	var variant := (package_id - 1) % HOUSE_TEXTURES.size()
	return Vector2(DOOR_OFFSETS[variant], _visual_ground_offset() - box_height * 0.5)

func _visual_ground_offset() -> float:
	return snappedf(Road.height_at(global_position.x, GameManager.current_level), 5.0) - global_position.y

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 0
	collision_mask = 8
	monitoring = true
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(175, 120)
	collision.shape = rect
	collision.position = Vector2(0, -26)
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is VanController:
		van_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body is VanController:
		van_inside = false

func _draw() -> void:
	var ground_y := _visual_ground_offset()
	_draw_front_yard(ground_y)
	var texture := HOUSE_TEXTURES[(package_id - 1) % HOUSE_TEXTURES.size()]
	var source_size := texture.get_size()
	var scale := minf(MAX_HOUSE_SIZE.x / source_size.x, MAX_HOUSE_SIZE.y / source_size.y)
	var size := source_size * scale
	# The cropped PNG bottom and the zone origin both sit on the flat road pad.
	draw_texture_rect(texture, Rect2(-size.x * 0.5, ground_y - size.y + 2.0, size.x, size.y), false)
	_draw_delivery_sign(ground_y)

func _draw_front_yard(ground_y: float) -> void:
	draw_texture(YARD_DONE_SPRITE if completed else YARD_SPRITE, Vector2(-110, ground_y - 4.0))

func _draw_delivery_sign(ground_y: float) -> void:
	draw_texture(SIGN_DONE_SPRITE if completed else SIGN_SPRITE, Vector2(135, ground_y - 105.0))
	draw_string(ThemeDB.fallback_font, Vector2(139, ground_y - 84.0), "STOP %d" % package_id, HORIZONTAL_ALIGNMENT_CENTER, 68, 13, Color("7c3d32"))
