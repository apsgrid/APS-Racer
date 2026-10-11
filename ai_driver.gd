class_name AIDriver
extends RefCounted

var sim: VehicleSim = VehicleSim.new()
var target_index: int = 1
var enabled: bool = true
var last_controls: Dictionary = {"steer":0.0, "throttle":0.0, "brake":0.0, "handbrake":false}

func setup() -> void:
	sim.set_preset(1)
	sim.max_engine_force *= 0.97
	sim.base_tyre_mu *= 0.98
	restart()

func restart() -> void:
	sim.reset()
	sim.position = Vector2(-6.5, 17.4)
	sim.angle = 0.0
	sim.velocity = Vector2.ZERO
	sim.angular_velocity = 0.0
	target_index = 1
	last_controls = {"steer":0.0, "throttle":0.0, "brake":0.0, "handbrake":false}

func step(dt: float, allow_drive: bool, track: TrackModel) -> void:
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

	var next_index: int = (target_index + 1) % line.size()
	var next_target: Vector2 = line[next_index]
	var blended_target: Vector2 = target.lerp(next_target, clamp(sim.speed_kph() / 180.0, 0.08, 0.34))

	var desired_angle: float = (blended_target - sim.position).angle()
	var angle_error: float = wrapf(desired_angle - sim.angle, -PI, PI)
	var steer: float = clamp(angle_error / 0.62, -1.0, 1.0)

	var turn_demand: float = abs(angle_error)
	var speed_ms: float = sim.velocity.length()
	var target_speed: float = lerp(38.0, 20.0, clamp(turn_demand / 1.15, 0.0, 1.0))
	var throttle: float = 1.0
	var brake: float = 0.0
	if speed_ms > target_speed:
		throttle = 0.10
		brake = clamp((speed_ms - target_speed) / 8.0, 0.0, 0.80)
	elif turn_demand > 0.95:
		throttle = 0.45
	elif turn_demand > 0.62:
		throttle = 0.72

	last_controls = {
		"steer": steer,
		"throttle": throttle,
		"brake": brake,
		"handbrake": false
	}
	sim.step(dt, throttle, brake, steer, false, track.surface_mu)
	track.resolve_barriers(sim)
