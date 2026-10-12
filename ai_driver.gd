class_name AIDriver
extends RefCounted

const DIFFICULTIES: Array[Dictionary] = [
	{
		"name": "EASY",
		"speed_scale": 0.86,
		"power_scale": 0.91,
		"grip_scale": 0.95,
		"aggression": 0.42
	},
	{
		"name": "NORMAL",
		"speed_scale": 1.0,
		"power_scale": 0.97,
		"grip_scale": 0.98,
		"aggression": 0.68
	},
	{
		"name": "HARD",
		"speed_scale": 1.10,
		"power_scale": 1.03,
		"grip_scale": 1.01,
		"aggression": 0.90
	}
]

var sim: VehicleSim = VehicleSim.new()
var target_index: int = 1
var enabled: bool = true
var difficulty_index: int = 1
var racecraft_state: String = "RACING"
var lane_offset: float = 0.0
var lane_offset_target: float = 0.0
var last_controls: Dictionary = {"steer":0.0, "throttle":0.0, "brake":0.0, "handbrake":false}

func setup(track: TrackModel) -> void:
	set_difficulty(difficulty_index)
	restart(track)

func set_difficulty(index: int) -> void:
	difficulty_index = posmod(index, DIFFICULTIES.size())
	var profile: Dictionary = DIFFICULTIES[difficulty_index]
	sim.set_preset(1)
	sim.max_engine_force *= float(profile["power_scale"])
	sim.base_tyre_mu *= float(profile["grip_scale"])

func cycle_difficulty(direction: int = 1) -> void:
	set_difficulty(difficulty_index + direction)

func difficulty_name() -> String:
	return String(DIFFICULTIES[difficulty_index]["name"])

func aggression() -> float:
	return float(DIFFICULTIES[difficulty_index]["aggression"])

func restart(track: TrackModel) -> void:
	sim.reset()
	var pose: Dictionary = track.ai_grid_pose()
	sim.position = Vector2(pose["position"])
	sim.angle = float(pose["angle"])
	sim.velocity = Vector2.ZERO
	sim.angular_velocity = 0.0
	target_index = 1
	racecraft_state = "RACING"
	lane_offset = 0.0
	lane_offset_target = 0.0
	last_controls = {"steer":0.0, "throttle":0.0, "brake":0.0, "handbrake":false}

func step(dt: float, allow_drive: bool, track: TrackModel, opponent: VehicleSim = null) -> void:
	if not enabled or not allow_drive:
		last_controls = {"steer":0.0, "throttle":0.0, "brake":0.0, "handbrake":false}
		sim.step(dt, 0.0, 0.0, 0.0, false, track.surface_mu)
		track.resolve_barriers(sim)
		return

	var line: Array[Vector2] = track.racing_line_points()
	if line.is_empty():
		return

	var target: Vector2 = line[target_index]
	var distance: float = sim.position.distance_to(target)
	if distance < 5.0:
		target_index = (target_index + 1) % line.size()
		target = line[target_index]

	var prev_index: int = posmod(target_index - 1, line.size())
	var next_index: int = (target_index + 1) % line.size()
	var after_next_index: int = (target_index + 2) % line.size()
	var next_target: Vector2 = line[next_index]
	var tangent: Vector2 = (next_target - line[prev_index]).normalized()
	if tangent.length_squared() < 0.01:
		tangent = Vector2(cos(sim.angle), sin(sim.angle))
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)

	_update_racecraft(dt, target, tangent, normal, opponent)

	var blended_target: Vector2 = target.lerp(next_target, clamp(sim.speed_kph() / 180.0, 0.08, 0.34))
	blended_target += normal * lane_offset

	var desired_angle: float = (blended_target - sim.position).angle()
	var angle_error: float = wrapf(desired_angle - sim.angle, -PI, PI)
	var steer: float = clamp(angle_error / 0.62, -1.0, 1.0)

	var incoming: Vector2 = (target - line[prev_index]).normalized()
	var outgoing: Vector2 = (line[after_next_index] - next_target).normalized()
	var path_turn: float = abs(incoming.angle_to(outgoing))
	var turn_demand: float = max(abs(angle_error), path_turn * 1.35)

	var speed_ms: float = sim.velocity.length()
	var target_speed: float
	if track.course_id() == "figure_eight":
		target_speed = lerp(25.0, 12.5, clamp(turn_demand / 0.90, 0.0, 1.0))
	elif track.course_id() == "airfield":
		target_speed = lerp(46.0, 21.0, clamp(turn_demand / 1.10, 0.0, 1.0))
	else:
		target_speed = lerp(38.0, 20.0, clamp(turn_demand / 1.15, 0.0, 1.0))
	target_speed *= float(DIFFICULTIES[difficulty_index]["speed_scale"])

	var throttle: float = 1.0
	var brake: float = 0.0
	if speed_ms > target_speed:
		throttle = 0.05
		var brake_scale: float = 5.0 if track.course_id() == "figure_eight" else (10.0 if track.course_id() == "airfield" else 8.0)
		brake = clamp((speed_ms - target_speed) / brake_scale, 0.0, 1.0)
	elif turn_demand > 0.95:
		throttle = 0.35 if track.course_id() == "figure_eight" else (0.52 if track.course_id() == "airfield" else 0.45)
	elif turn_demand > 0.62:
		throttle = 0.58 if track.course_id() == "figure_eight" else (0.80 if track.course_id() == "airfield" else 0.72)

	if opponent != null:
		var relative: Vector2 = opponent.position - sim.position
		var forward_gap: float = relative.dot(tangent)
		var lateral_gap: float = abs(relative.dot(normal))
		if forward_gap > 0.0 and forward_gap < 4.0 and lateral_gap < 1.65:
			throttle = min(throttle, 0.20)
			brake = max(brake, clamp((4.0 - forward_gap) / 4.0, 0.15, 0.72))

	last_controls = {
		"steer": steer,
		"throttle": throttle,
		"brake": brake,
		"handbrake": false
	}
	sim.step(dt, throttle, brake, steer, false, track.surface_mu)
	track.resolve_barriers(sim)

func _update_racecraft(
	dt: float,
	target: Vector2,
	tangent: Vector2,
	normal: Vector2,
	opponent: VehicleSim
) -> void:
	lane_offset_target = 0.0
	racecraft_state = "RACING"
	if opponent != null:
		var relative: Vector2 = opponent.position - sim.position
		var forward_gap: float = relative.dot(tangent)
		var lateral_gap: float = relative.dot(normal)
		var distance: float = relative.length()
		var max_offset: float = lerp(0.85, 1.85, aggression())

		if distance < 13.0 and forward_gap > 0.5:
			racecraft_state = "ATTACK"
			var pass_side: float = -1.0 if lateral_gap >= 0.0 else 1.0
			if abs(lateral_gap) < 0.30:
				pass_side = -1.0 if fposmod(float(target_index), 2.0) < 1.0 else 1.0
			lane_offset_target = pass_side * max_offset
		elif distance < 10.0 and forward_gap < -0.5:
			racecraft_state = "DEFEND"
			var cover_side: float = 1.0 if lateral_gap >= 0.0 else -1.0
			lane_offset_target = cover_side * max_offset * 0.62

	var response: float = 1.0 - exp(-3.8 * dt)
	lane_offset = lerp(lane_offset, lane_offset_target, response)
