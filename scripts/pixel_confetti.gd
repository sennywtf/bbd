extends Control

const COLORS := [Color("fff1d1"), Color("9e4b32"), Color("8ce0f3"), Color("86cfae"), Color("f4cc81")]
const INK := Color("30263d")

var particles: Array[Dictionary] = []
var time_left := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	hide()

func burst() -> void:
	particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(90):
		var from_left := i % 2 == 0
		var origin := Vector2(345.0 if from_left else 935.0, 160.0)
		var velocity := Vector2(rng.randf_range(-210.0, 120.0) if from_left else rng.randf_range(-120.0, 210.0), rng.randf_range(-315.0, -115.0))
		particles.append({"position": origin, "velocity": velocity, "size": rng.randi_range(5, 9), "color": COLORS[i % COLORS.size()], "life": rng.randf_range(1.7, 2.4)})
	time_left = 2.4
	show()
	set_process(true)
	queue_redraw()

func stop() -> void:
	set_process(false)
	hide()
	particles.clear()

func _process(delta: float) -> void:
	time_left -= delta
	for i in range(particles.size()):
		var particle := particles[i]
		var velocity: Vector2 = particle["velocity"]
		velocity.y += 380.0 * delta
		particle["position"] = particle["position"] + velocity * delta
		particle["velocity"] = velocity
		particle["life"] = float(particle["life"]) - delta
		particles[i] = particle
	queue_redraw()
	if time_left <= 0.0:
		stop()

func _draw() -> void:
	for particle in particles:
		if float(particle["life"]) <= 0.0:
			continue
		var position: Vector2 = particle["position"]
		var edge: int = particle["size"]
		var point := Vector2(roundf(position.x), roundf(position.y))
		var color: Color = particle["color"]
		color.a = minf(1.0, float(particle["life"]) / 0.35)
		draw_rect(Rect2(point, Vector2(edge, edge)), Color(INK.r, INK.g, INK.b, color.a))
		draw_rect(Rect2(point + Vector2.ONE, Vector2(edge - 2, edge - 2)), color)
