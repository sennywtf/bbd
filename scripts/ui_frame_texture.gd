extends Control
class_name UiFrameTexture

var paper := true
var texture: ImageTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = _make_grain()
	queue_redraw()

func _draw() -> void:
	if texture == null:
		return
	draw_texture_rect(texture, Rect2(Vector2.ZERO, size), true)
	var accent := Color(0.51, 0.25, 0.20, 0.10) if paper else Color(1.0, 0.93, 0.80, 0.08)
	for x in range(7, int(size.x) - 5, 29):
		draw_rect(Rect2(x, 2, 6, 2), accent)
		draw_rect(Rect2(x + 13, size.y - 4, 4, 2), accent)

func _make_grain() -> ImageTexture:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(24):
		for x in range(24):
			var value := (x * 37 + y * 61 + x * y * 11) % 97
			if value < 12:
				var alpha := 0.05 + float(value % 4) * 0.015
				var ink := Color(0.42, 0.20, 0.15, alpha) if paper else Color(1.0, 0.94, 0.81, alpha)
				image.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(image)
