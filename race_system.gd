class_name RaceSystem
extends RefCounted

const SAVE_PATH: String = "user://aps_racer_race_records.json"
const GHOST_SAMPLE_INTERVAL: float = 1.0 / 30.0
const MAX_GHOST_SECONDS: float = 180.0
const MAX_GHOST_SAMPLES: int = 5400

var total_laps: int = 3
var state: String = "countdown"
var countdown: float = 3.25
var current_lap: int = 1
var race_elapsed: float = 0.0
var lap_elapsed: float = 0.0
var last_lap_time: float = 0.0
var best_lap_time: float = 0.0
var next_checkpoint: int = 1
var completed_checkpoints: int = 0
var last_sector_time: float = 0.0
var best_sector_times: Array[float] = [0.0, 0.0, 0.0, 0.0]
var sector_start_time: float = 0.0
var event_message: String = ""
var event_message_time: float = 0.0
var finish_time: float = 0.0
var paused: bool = false

var race_key: String = "default"
var persistence_enabled: bool = true
var ghost_recording_enabled: bool = true
var ghost_overflowed: bool = false
var current_ghost: Array = []
var best_ghost: Array = []
var ghost_sample_accumulator: float = 0.0

func _init(enable_persistence: bool = true, enable_ghost_recording: bool = true) -> void:
	persistence_enabled = enable_persistence
	ghost_recording_enabled = enable_ghost_recording

func configure(key: String, laps: int = 3) -> void:
	race_key = key
	total_laps = max(laps, 1)
	_load_record()

func restart() -> void:
	state = "countdown"
	countdown = 3.25
	current_lap = 1
	race_elapsed = 0.0
	lap_elapsed = 0.0
	last_lap_time = 0.0
	next_checkpoint = 1
	completed_checkpoints = 0
	last_sector_time = 0.0
	sector_start_time = 0.0
	event_message = "GET READY"
	event_message_time = 1.0
	finish_time = 0.0
	current_ghost.clear()
	ghost_sample_accumulator = 0.0
	ghost_overflowed = false
	paused = false

func set_paused(value: bool) -> void:
	paused = value

func is_racing() -> bool:
	return state == "racing"

func is_finished() -> bool:
	return state == "finished"

func controls_locked() -> bool:
	return state == "countdown" or state == "finished"

func step(dt: float, position: Vector2, angle: float, track: TrackModel) -> void:
	if paused:
		return

	if event_message_time > 0.0:
		event_message_time = max(event_message_time - dt, 0.0)

	if state == "countdown":
		var before: int = int(ceil(countdown))
		countdown -= dt
		var after: int = int(ceil(max(countdown, 0.0)))
		if after != before and after > 0:
			event_message = str(after)
			event_message_time = 0.85
		if countdown <= 0.0:
			countdown = 0.0
			state = "racing"
			event_message = "GO"
			event_message_time = 0.85
			_start_lap(position, angle)
		return

	if state != "racing":
		return

	race_elapsed += dt
	lap_elapsed += dt
	_record_ghost(dt, position, angle)

	var gates: Array[Dictionary] = track.race_gates()
	if gates.is_empty():
		return
	var gate_index: int = next_checkpoint
	var gate: Dictionary = gates[gate_index]
	var gate_position: Vector2 = Vector2(gate["position"])
	var radius: float = float(gate.get("radius", 4.0))
	var expected_direction: Vector2 = Vector2(gate.get("direction", Vector2.RIGHT)).normalized()
	var forward: Vector2 = Vector2(cos(angle), sin(angle))
	var correct_direction: bool = forward.dot(expected_direction) > 0.25
	if position.distance_to(gate_position) <= radius and correct_direction:
		_cross_gate(gate_index, position, angle)

func _cross_gate(gate_index: int, position: Vector2, angle: float) -> void:
	var sector_index: int
	if gate_index == 0:
		sector_index = 3
	else:
		sector_index = gate_index - 1

	var sector_time: float = max(lap_elapsed - sector_start_time, 0.0)
	last_sector_time = sector_time
	if best_sector_times[sector_index] <= 0.0 or sector_time < best_sector_times[sector_index]:
		best_sector_times[sector_index] = sector_time
	sector_start_time = lap_elapsed

	if gate_index == 0:
		_complete_lap(position, angle)
		return

	completed_checkpoints += 1
	next_checkpoint = gate_index + 1
	if next_checkpoint >= 4:
		next_checkpoint = 0
	event_message = "SECTOR %d  %s" % [gate_index, format_time(sector_time)]
	event_message_time = 1.15

func _complete_lap(position: Vector2, angle: float) -> void:
	last_lap_time = lap_elapsed
	var new_best: bool = best_lap_time <= 0.0 or last_lap_time < best_lap_time
	if new_best:
		best_lap_time = last_lap_time
		if ghost_recording_enabled and not ghost_overflowed:
			best_ghost = current_ghost.duplicate(true)
			if best_ghost.is_empty() or float(best_ghost[-1].get("t", 0.0)) < lap_elapsed:
				best_ghost.append({"t": lap_elapsed, "x": position.x, "y": position.y, "a": angle})
		else:
			best_ghost.clear()
		_save_record()

	event_message = ("NEW BEST  " if new_best else "LAP  ") + format_time(last_lap_time)
	event_message_time = 2.0
	completed_checkpoints += 1

	if current_lap >= total_laps:
		state = "finished"
		finish_time = race_elapsed
		event_message = "FINISH  " + format_time(finish_time)
		event_message_time = 999.0
		return

	current_lap += 1
	_start_lap(position, angle)

func _start_lap(position: Vector2, angle: float) -> void:
	lap_elapsed = 0.0
	sector_start_time = 0.0
	next_checkpoint = 1
	current_ghost.clear()
	ghost_sample_accumulator = 0.0
	ghost_overflowed = false
	if ghost_recording_enabled:
		current_ghost.append({"t": 0.0, "x": position.x, "y": position.y, "a": angle})

func _record_ghost(dt: float, position: Vector2, angle: float) -> void:
	if not ghost_recording_enabled or ghost_overflowed:
		return
	ghost_sample_accumulator += dt
	if ghost_sample_accumulator < GHOST_SAMPLE_INTERVAL:
		return
	ghost_sample_accumulator = fmod(ghost_sample_accumulator, GHOST_SAMPLE_INTERVAL)
	if current_ghost.size() >= MAX_GHOST_SAMPLES or lap_elapsed >= MAX_GHOST_SECONDS:
		ghost_overflowed = true
		return
	current_ghost.append({
		"t": lap_elapsed,
		"x": position.x,
		"y": position.y,
		"a": angle
	})

func ghost_transform() -> Dictionary:
	if best_ghost.size() < 2 or state != "racing":
		return {}
	var t: float = lap_elapsed
	if best_lap_time > 0.0:
		t = min(t, best_lap_time)

	var lo: int = 0
	var hi: int = best_ghost.size() - 1
	while lo + 1 < hi:
		var mid: int = (lo + hi) / 2
		if float(best_ghost[mid]["t"]) < t:
			lo = mid
		else:
			hi = mid

	var a: Dictionary = Dictionary(best_ghost[lo])
	var b: Dictionary = Dictionary(best_ghost[hi])
	var ta: float = float(a["t"])
	var tb: float = float(b["t"])
	var ratio: float = 0.0 if tb <= ta else clamp((t - ta) / (tb - ta), 0.0, 1.0)
	var angle_a: float = float(a["a"])
	var angle_b: float = float(b["a"])
	var delta_angle: float = wrapf(angle_b - angle_a, -PI, PI)
	return {
		"position": Vector2(
			lerp(float(a["x"]), float(b["x"]), ratio),
			lerp(float(a["y"]), float(b["y"]), ratio)
		),
		"angle": angle_a + delta_angle * ratio
	}

func progress_score(position: Vector2, track: TrackModel) -> float:
	var base: int = (current_lap - 1) * 4
	var sector_progress: int
	if next_checkpoint == 0:
		sector_progress = 3
	else:
		sector_progress = next_checkpoint - 1
	base += sector_progress
	if state == "finished":
		return 1000000.0 - finish_time
	var gates: Array[Dictionary] = track.race_gates()
	if gates.is_empty():
		return float(base) * 1000.0
	var gate: Dictionary = gates[next_checkpoint]
	var distance: float = position.distance_to(Vector2(gate["position"]))
	return float(base) * 1000.0 - distance

func countdown_text() -> String:
	if state != "countdown":
		return ""
	var n: int = int(ceil(countdown))
	return str(max(n, 1))

func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--.---"
	var minutes: int = int(seconds) / 60
	var secs: float = fmod(seconds, 60.0)
	return "%02d:%06.3f" % [minutes, secs]

func _load_record() -> void:
	best_lap_time = 0.0
	best_sector_times = [0.0, 0.0, 0.0, 0.0]
	best_ghost.clear()
	if not persistence_enabled or not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var records: Dictionary = Dictionary(parsed.get("records", {}))
	if not records.has(race_key):
		return
	var record: Dictionary = Dictionary(records[race_key])
	best_lap_time = float(record.get("best_lap", 0.0))
	var sectors: Variant = record.get("best_sectors", [])
	if sectors is Array and sectors.size() == 4:
		for i: int in range(4):
			best_sector_times[i] = float(sectors[i])
	var ghost: Variant = record.get("ghost", [])
	if ghost is Array:
		best_ghost = ghost

func _save_record() -> void:
	if not persistence_enabled:
		return
	var database: Dictionary = {"version": 1, "records": {}}
	if FileAccess.file_exists(SAVE_PATH):
		var read_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if read_file != null:
			var parsed: Variant = JSON.parse_string(read_file.get_as_text())
			if parsed is Dictionary:
				database = parsed
	var records: Dictionary = Dictionary(database.get("records", {}))
	records[race_key] = {
		"best_lap": best_lap_time,
		"best_sectors": best_sector_times,
		"ghost": best_ghost,
		"saved_at": Time.get_datetime_string_from_system()
	}
	database["version"] = 1
	database["records"] = records
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(database))
