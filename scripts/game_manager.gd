extends Node

signal shift_ended
signal shift_started
signal cargo_damaged(package_id: int, amount: float)

const MAX_LEVEL := 10
const BASE_SHIFT_SECONDS := 30.0
const SECONDS_PER_LEVEL := 5.0
const BASE_PAY := 60.0
const DAMAGE_RATE := 0.45
const REPAIR_RATE := 0.60
const PROFILE_PATH := "user://bounce_back_profile.json"
const LEADERBOARD_PATH := "user://bounce_back_leaderboard.json"
const BACKGROUND_MUSIC_PATH := "res://assets/audio/monkeys_spinning_monkeys.mp3"
const MUSIC_VOLUME_DB := -20.0

var player_name := ""
var current_level := 1
var campaign_score := 0.0
var campaign_complete := false
var auto_start_after_reload := false
var time_left := BASE_SHIFT_SECONDS
var running := false
var finished := false
var shift_clear := false
var delivered: Array[Dictionary] = []
var cargo_damage := 0.0
var van_damage := 0.0
var leaderboard: Array[Dictionary] = []
var music_player: AudioStreamPlayer

func _ready() -> void:
	_load_profile()
	_load_leaderboard()
	music_player = AudioStreamPlayer.new()
	var music_stream := load(BACKGROUND_MUSIC_PATH) as AudioStreamMP3
	music_stream.loop = true
	music_player.stream = music_stream
	music_player.volume_db = MUSIC_VOLUME_DB
	add_child(music_player)

func start_music() -> void:
	if not music_player.playing:
		music_player.play()

func stop_music() -> void:
	music_player.stop()

func total_stops() -> int:
	return current_level + 2

func shift_duration() -> float:
	return BASE_SHIFT_SECONDS + float(current_level - 1) * SECONDS_PER_LEVEL

func difficulty() -> float:
	return 1.0 + float(current_level - 1) * 0.08

func reset_campaign() -> void:
	current_level = 1
	campaign_score = 0.0
	campaign_complete = false
	auto_start_after_reload = false
	running = false
	finished = false
	shift_clear = false
	time_left = shift_duration()
	delivered.clear()
	cargo_damage = 0.0
	van_damage = 0.0

func advance_level() -> void:
	if shift_clear and current_level < MAX_LEVEL:
		current_level += 1
		shift_clear = false
		auto_start_after_reload = true

func start_shift() -> void:
	time_left = shift_duration()
	delivered.clear()
	cargo_damage = 0.0
	van_damage = 0.0
	finished = false
	shift_clear = false
	running = true
	shift_started.emit()

func _process(delta: float) -> void:
	if not running:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		finish_shift()

func record_cargo_damage(amount: float, package_id: int = 0) -> void:
	var actual := maxf(0.0, amount)
	cargo_damage += actual
	if actual > 0.0:
		cargo_damaged.emit(package_id, actual)

func record_van_damage(amount: float) -> void:
	van_damage += maxf(0.0, amount)

func deliver_package(package_id: int, health: float) -> void:
	if not running:
		return
	delivered.append({"id": package_id, "health": health})
	if delivered.size() >= total_stops():
		finish_shift()

func finish_shift() -> void:
	if finished:
		return
	running = false
	finished = true
	shift_clear = delivered.size() >= total_stops()
	if shift_clear:
		campaign_score += receipt()["net"]
		campaign_complete = current_level >= MAX_LEVEL
		_update_leaderboard()
	shift_ended.emit()

func receipt() -> Dictionary:
	var gross: float = delivered.size() * BASE_PAY
	var damage_penalty: float = cargo_damage * DAMAGE_RATE
	var repair_cost: float = van_damage * REPAIR_RATE
	return {
		"delivered": delivered.size(),
		"gross": gross,
		"damage_penalty": damage_penalty,
		"repair_cost": repair_cost,
		"net": gross - damage_penalty - repair_cost
	}

func set_player_name(value: String) -> bool:
	var cleaned := value.strip_edges().substr(0, 16)
	if cleaned.is_empty():
		return false
	player_name = cleaned
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"name": player_name}))
	return true

func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if parsed is Dictionary:
		player_name = str(parsed.get("name", "")).substr(0, 16)

func _load_leaderboard() -> void:
	leaderboard.clear()
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LEADERBOARD_PATH))
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary and entry.has("name") and entry.has("level") and entry.has("score"):
				leaderboard.append(entry)
	leaderboard.sort_custom(_score_before)

func _update_leaderboard() -> void:
	if player_name.is_empty():
		return
	var new_entry := {"name": player_name, "level": current_level, "score": roundf(campaign_score * 100.0) / 100.0}
	var replaced := false
	for index in range(leaderboard.size()):
		var old := leaderboard[index]
		if str(old["name"]) == player_name:
			if _score_before(new_entry, old):
				leaderboard[index] = new_entry
			replaced = true
			break
	if not replaced:
		leaderboard.append(new_entry)
	leaderboard.sort_custom(_score_before)
	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(leaderboard))

func _score_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["level"]) != int(b["level"]):
		return int(a["level"]) > int(b["level"])
	return float(a["score"]) > float(b["score"])
