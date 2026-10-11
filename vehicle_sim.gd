class_name VehicleSim
extends RefCounted

const G: float = 9.81

var position: Vector2 = Vector2(0.0, 12.0)
var velocity: Vector2 = Vector2.ZERO
var angle: float = 0.0
var angular_velocity: float = 0.0
var steering_angle: float = 0.0

var preset_index: int = 0
var preset_name: String = "RWD SPORT"
var mass: float = 1240.0
var inertia: float = 1850.0
var wheelbase: float = 2.55
var track_width: float = 1.58
var cg_height: float = 0.52
var front_weight_fraction: float = 0.55
var drive_front_fraction: float = 0.0

var max_engine_force: float = 7200.0
var reverse_force: float = 4200.0
var max_brake_force: float = 15500.0
var front_brake_bias: float = 0.62
var base_tyre_mu: float = 1.12
var corner_stiffness: float = 3400.0
var yaw_damping: float = 850.0
var aero_drag: float = 0.43
var rolling_resistance: float = 145.0

var last_long_accel: float = 0.0
var last_lat_accel: float = 0.0
var wheel_slip_angles: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_loads: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_grip_usage: Array[float] = [0.0, 0.0, 0.0, 0.0]
var last_surface_mu: float = 1.0
var last_impact_kph: float = 0.0

func reset() -> void:
	position = Vector2(0.0, 12.0)
	velocity = Vector2.ZERO
	angle = 0.0
	angular_velocity = 0.0
	steering_angle = 0.0
	last_long_accel = 0.0
	last_lat_accel = 0.0
	last_impact_kph = 0.0

func set_preset(index: int) -> void:
	preset_index = posmod(index, 3)
	match preset_index:
		0:
			preset_name = "RWD SPORT"
			mass = 1240.0
			inertia = 1850.0
			wheelbase = 2.55
			track_width = 1.58
			cg_height = 0.52
			front_weight_fraction = 0.55
			drive_front_fraction = 0.0
			max_engine_force = 7200.0
			max_brake_force = 15500.0
			front_brake_bias = 0.62
			base_tyre_mu = 1.12
			corner_stiffness = 3400.0
			yaw_damping = 850.0
		1:
			preset_name = "FWD HATCH"
			mass = 1120.0
			inertia = 1580.0
			wheelbase = 2.45
			track_width = 1.54
			cg_height = 0.56
			front_weight_fraction = 0.62
			drive_front_fraction = 1.0
			max_engine_force = 6100.0
			max_brake_force = 14800.0
			front_brake_bias = 0.67
			base_tyre_mu = 1.05
			corner_stiffness = 3250.0
			yaw_damping = 980.0
		2:
			preset_name = "AWD RALLY"
			mass = 1320.0
			inertia = 1980.0
			wheelbase = 2.58
			track_width = 1.61
			cg_height = 0.58
			front_weight_fraction = 0.54
			drive_front_fraction = 0.48
			max_engine_force = 7800.0
			max_brake_force = 15800.0
			front_brake_bias = 0.60
			base_tyre_mu = 1.08
			corner_stiffness = 3350.0
			yaw_damping = 790.0
	reset()

func cycle_preset(direction: int = 1) -> void:
	set_preset(preset_index + direction)

func get_forward() -> Vector2:
	return Vector2(cos(angle), sin(angle))

func get_right() -> Vector2:
	return Vector2(-sin(angle), cos(angle))

func speed_kph() -> float:
	return velocity.length() * 3.6

func get_wheel_offsets() -> Array[Vector2]:
	var front_x: float = wheelbase * (1.0 - front_weight_fraction)
	var rear_x: float = -wheelbase * front_weight_fraction
	var half_track: float = track_width * 0.5
	return [
		Vector2(front_x, -half_track),
		Vector2(front_x, half_track),
		Vector2(rear_x, -half_track),
		Vector2(rear_x, half_track)
	]

func get_wheel_world_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for local_offset: Vector2 in get_wheel_offsets():
		result.append(position + local_offset.rotated(angle))
	return result

func step(dt: float, throttle: float, brake: float, steer_input: float, handbrake: bool, surface_query: Callable) -> void:
	var forward: Vector2 = get_forward()
	var right: Vector2 = get_right()
	var speed: float = velocity.length()
	var speed_factor: float = clamp(speed / 50.0, 0.0, 1.0)
	var max_steer: float = lerp(0.58, 0.18, speed_factor)
	var target_steer: float = steer_input * max_steer
	steering_angle = move_toward(steering_angle, target_steer, 2.8 * dt)

	var total_weight: float = mass * G
	var transfer: float = mass * last_long_accel * cg_height / wheelbase
	var front_total: float = clamp(
		total_weight * front_weight_fraction - transfer,
		total_weight * 0.22,
		total_weight * 0.78
	)
	var rear_total: float = total_weight - front_total
	var wheel_offsets: Array[Vector2] = get_wheel_offsets()

	var net_force: Vector2 = Vector2.ZERO
	var net_torque: float = 0.0
	var body_forward_speed: float = velocity.dot(forward)
	var reversing: bool = brake > 0.05 and abs(body_forward_speed) < 0.8 and throttle < 0.05

	for i: int in range(4):
		var local_offset: Vector2 = wheel_offsets[i]
		var r: Vector2 = forward * local_offset.x + right * local_offset.y
		var point_velocity: Vector2 = velocity + angular_velocity * Vector2(-r.y, r.x)
		var is_front: bool = i < 2
		var wheel_steer: float = steering_angle if is_front else 0.0
		var wheel_forward: Vector2 = forward.rotated(wheel_steer)
		var wheel_right: Vector2 = right.rotated(wheel_steer)
		var long_speed: float = point_velocity.dot(wheel_forward)
		var lat_speed: float = point_velocity.dot(wheel_right)

		var normal_load: float = (front_total if is_front else rear_total) * 0.5
		wheel_loads[i] = normal_load
		var surface_mu: float = float(surface_query.call(position + r))
		last_surface_mu = surface_mu
		var mu: float = base_tyre_mu * surface_mu
		if handbrake and not is_front:
			mu *= 0.54
		var max_grip: float = max(normal_load * mu, 1.0)

		var requested_long: float = 0.0
		var axle_drive_fraction: float = drive_front_fraction if is_front else (1.0 - drive_front_fraction)
		if throttle > 0.0:
			requested_long += throttle * max_engine_force * axle_drive_fraction * 0.5
		if reversing:
			requested_long -= brake * reverse_force * axle_drive_fraction * 0.5

		if brake > 0.0 and not reversing:
			var axle_brake: float = max_brake_force * (front_brake_bias if is_front else (1.0 - front_brake_bias))
			var ref_speed: float = long_speed if abs(long_speed) > 0.15 else body_forward_speed
			requested_long += -sign(ref_speed) * brake * axle_brake * 0.5

		if handbrake and not is_front:
			var hand_ref: float = long_speed if abs(long_speed) > 0.1 else body_forward_speed
			requested_long += -sign(hand_ref) * 5600.0

		var long_force: float = clamp(requested_long, -max_grip, max_grip)
		var lateral_capacity: float = sqrt(max(max_grip * max_grip - long_force * long_force, 0.0))
		var requested_lat: float = -lat_speed * corner_stiffness
		var lat_force: float = clamp(requested_lat, -lateral_capacity, lateral_capacity)

		wheel_slip_angles[i] = rad_to_deg(atan2(lat_speed, abs(long_speed) + 0.35))
		wheel_grip_usage[i] = Vector2(long_force, lat_force).length() / max_grip
		var force: Vector2 = wheel_forward * long_force + wheel_right * lat_force
		net_force += force
		net_torque += r.cross(force)

	if speed > 0.01:
		net_force += -velocity.normalized() * rolling_resistance
		net_force += -velocity.normalized() * aero_drag * speed * speed

	var acceleration: Vector2 = net_force / mass
	last_long_accel = acceleration.dot(forward)
	last_lat_accel = acceleration.dot(right)
	velocity += acceleration * dt
	var angular_accel: float = (net_torque - angular_velocity * yaw_damping) / inertia
	angular_velocity += angular_accel * dt
	position += velocity * dt
	angle = wrapf(angle + angular_velocity * dt, -PI, PI)

	if position.length() > 300.0:
		reset()
