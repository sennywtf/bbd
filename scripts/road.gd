extends StaticBody2D
class_name Road

const ROAD_TILE := preload("res://assets/sprites/road-tile.png")

const ROAD_START := -500
const STEP := 16
const FIRST_HOUSE_X := 1000.0
const HOUSE_SPACING := 850.0
const HOUSE_FLAT_HALF_WIDTH := 215.0
const HOUSE_BLEND_WIDTH := 75.0
var road_end := 4200
var level := 1

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var top := PackedVector2Array()
	var x := ROAD_START
	while x <= road_end:
		top.append(Vector2(x, height_at(float(x), level)))
		x += STEP
	var polygon := top.duplicate()
	polygon.append(Vector2(road_end, 900))
	polygon.append(Vector2(ROAD_START, 900))
	var solid := CollisionPolygon2D.new()
	solid.polygon = polygon
	add_child(solid)
	var pixel_top := PackedVector2Array()
	x = ROAD_START
	while x <= road_end:
		var step_y := snappedf(height_at(float(x), level), 5.0)
		pixel_top.append(Vector2(x, step_y))
		pixel_top.append(Vector2(mini(x + STEP, road_end), step_y))
		x += STEP
	var pixel_polygon := pixel_top.duplicate()
	pixel_polygon.append(Vector2(road_end, 900))
	pixel_polygon.append(Vector2(ROAD_START, 900))
	var asphalt := Polygon2D.new()
	asphalt.polygon = pixel_polygon
	asphalt.texture = ROAD_TILE
	asphalt.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	asphalt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(asphalt)
	var rim := Line2D.new()
	rim.points = pixel_top
	rim.width = 7.0
	rim.default_color = Color("e5dae0")
	add_child(rim)
	var gutter := Line2D.new()
	var gutter_points := PackedVector2Array()
	for point in pixel_top:
		gutter_points.append(point + Vector2(0, 16))
	gutter.points = gutter_points
	gutter.width = 2.0
	gutter.default_color = Color("536b8d")
	add_child(gutter)

static func height_at(x: float, level_number: int = 1) -> float:
	var road_y := _profile_height_at(x, level_number)
	var house_index := roundi((x - FIRST_HOUSE_X) / HOUSE_SPACING)
	if house_index < 0:
		return road_y
	var house_x := FIRST_HOUSE_X + float(house_index) * HOUSE_SPACING
	var distance := absf(x - house_x)
	if distance >= HOUSE_FLAT_HALF_WIDTH + HOUSE_BLEND_WIDTH:
		return road_y
	var house_y := _profile_height_at(house_x, level_number)
	if distance <= HOUSE_FLAT_HALF_WIDTH:
		return house_y
	var blend := (distance - HOUSE_FLAT_HALF_WIDTH) / HOUSE_BLEND_WIDTH
	blend = blend * blend * (3.0 - 2.0 * blend)
	return lerpf(house_y, road_y, blend)

static func _profile_height_at(x: float, level_number: int) -> float:
	var difficulty := 1.0 + float(level_number - 1) * 0.08
	var roughness := clampf(float(level_number - 1) / 9.0, 0.0, 1.0)
	var y := 535.0 + 5.0 * sin(x / 122.0)
	var segment := int(floor(x / HOUSE_SPACING))
	var phase := fposmod(x, HOUSE_SPACING)
	var feature_count := 2
	if _hash01(segment, 17, level_number) < 0.25 + roughness * 0.55:
		feature_count = 3
	for feature in range(feature_count):
		var channel := feature * 4
		var lane := (float(feature) + 0.5) / float(feature_count)
		var center := 385.0 + 355.0 * lane + (_hash01(segment, channel, level_number) - 0.5) * 40.0
		var width := 55.0 + _hash01(segment, channel + 1, level_number) * 18.0
		var amplitude := (20.0 + _hash01(segment, channel + 2, level_number) * 12.0) * difficulty
		var direction := 1.0 if _hash01(segment, channel + 3, level_number) < 0.5 else -0.9
		y += direction * amplitude * exp(-pow((phase - center) / width, 2.0))
	var ripple_envelope := pow(sin(PI * phase / HOUSE_SPACING), 2.0)
	var ripple_phase := _hash01(segment, 23, level_number) * TAU
	var ripple_scale := roughness * (0.75 + _hash01(segment, 24, level_number) * 0.5) * ripple_envelope
	y += ripple_scale * (5.0 * sin(x / 38.0 + ripple_phase) + 2.5 * sin(x / 23.0 + ripple_phase * 1.7))
	return y

static func _hash01(segment: int, channel: int, level_number: int) -> float:
	var seed := float(segment * 127 + channel * 719 + level_number * 911 + 53)
	return fposmod(sin(seed * 12.9898) * 43758.5453, 1.0)
