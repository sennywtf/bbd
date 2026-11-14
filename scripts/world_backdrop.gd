extends Node2D

const CLOUD_A := preload("res://assets/background/cloud4.png")
const CLOUD_B := preload("res://assets/background/cloud6.png")
const SKY_TILE := preload("res://assets/sprites/sky-tile.png")

var world_end := 4700.0

func _draw() -> void:
	draw_texture_rect(SKY_TILE, Rect2(-500, -1000, world_end + 1000.0, 2400), true)
	for i in range(ceili((world_end + 700.0) / 720.0)):
		var cloud := CLOUD_A if i % 2 == 0 else CLOUD_B
		var cloud_x := float(i) * 720.0 - 330.0
		var cloud_y := 27.0 + float((i * 3) % 4) * 29.0
		draw_texture_rect(cloud, Rect2(cloud_x, cloud_y, 178, 97), false, Color(1, 1, 1, 0.75))
