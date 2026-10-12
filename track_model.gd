class_name TrackModel
extends RefCounted

const ROAD_OUTER_HALF: Vector2 = Vector2(34.0, 20.0)
const ROAD_OUTER_RADIUS: float = 9.0
const ROAD_INNER_HALF: Vector2 = Vector2(26.0, 12.0)
const ROAD_INNER_RADIUS: float = 5.0

const BARRIER_OUTER_HALF: Vector2 = Vector2(36.0, 22.0)
const BARRIER_OUTER_RADIUS: float = 10.0
const BARRIER_INNER_HALF: Vector2 = Vector2(24.0, 10.0)
const BARRIER_INNER_RADIUS: float = 4.0

const FIG8_A: float = 30.0
const FIG8_B: float = 17.0
const FIG8_ROAD_HALF: float = 4.4
const FIG8_BARRIER_HALF: float = 5.8
const FIG8_SAMPLES: int = 96

const AIRFIELD_ROAD_OUTER_HALF: Vector2 = Vector2(60.0, 23.0)
const AIRFIELD_ROAD_OUTER_RADIUS: float = 8.0
const AIRFIELD_ROAD_INNER_HALF: Vector2 = Vector2(47.0, 10.5)
const AIRFIELD_ROAD_INNER_RADIUS: float = 4.0
const AIRFIELD_BARRIER_OUTER_HALF: Vector2 = Vector2(62.0, 25.0)
const AIRFIELD_BARRIER_OUTER_RADIUS: float = 9.0
const AIRFIELD_BARRIER_INNER_HALF: Vector2 = Vector2(45.0, 8.5)
const AIRFIELD_BARRIER_INNER_RADIUS: float = 3.0
const AIRFIELD_ROAD_MU: float = 1.10
const AIRFIELD_RUNOFF_MU: float = 0.68

const CAR_COLLISION_RADIUS: float = 1.15

var road_mu: float = 1.0
var runoff_mu: float = 0.43
var course_index: int = 0
var wet_surface: bool = false
var dry_road_mu: float = 1.12
var _dry_line_levels: PackedFloat32Array = PackedFloat32Array()

var _road_outer_cache: PackedVector2Array = PackedVector2Array()
var _road_inner_cache: PackedVector2Array = PackedVector2Array()
var _barrier_outer_cache: PackedVector2Array = PackedVector2Array()
var _barrier_inner_cache: PackedVector2Array = PackedVector2Array()
var _round_gates_cache: Array[Dictionary] = []
var _round_line_cache: Array[Vector2] = []

var _figure8_gates_cache: Array[Dictionary] = []
var _figure8_line_cache: PackedVector2Array = PackedVector2Array()
var _figure8_ai_line_cache: Array[Vector2] = []

var _airfield_road_outer_cache: PackedVector2Array = PackedVector2Array()
var _airfield_road_inner_cache: PackedVector2Array = PackedVector2Array()
var _airfield_barrier_outer_cache: PackedVector2Array = PackedVector2Array()
var _airfield_barrier_inner_cache: PackedVector2Array = PackedVector2Array()
var _airfield_gates_cache: Array[Dictionary] = []
var _airfield_line_cache: Array[Vector2] = []

func _init() -> void:
	_road_outer_cache = rounded_rect_points(ROAD_OUTER_HALF, ROAD_OUTER_RADIUS, 12)
	_road_inner_cache = rounded_rect_points(ROAD_INNER_HALF, ROAD_INNER_RADIUS, 12)
	_barrier_outer_cache = rounded_rect_points(BARRIER_OUTER_HALF, BARRIER_OUTER_RADIUS, 12)
	_barrier_inner_cache = rounded_rect_points(BARRIER_INNER_HALF, BARRIER_INNER_RADIUS, 12)

	_round_gates_cache = [
		{
			"name":"START / FINISH",
			"position":Vector2(0.0, 16.0),
			"radius":4.5,
			"direction":Vector2(1.0, 0.0),
			"a":Vector2(0.0, 12.2),
			"b":Vector2(0.0, 19.8)
		},
		{
			"name":"EAST",
			"position":Vector2(30.0, 0.0),
			"radius":5.0,
			"direction":Vector2(0.0, -1.0),
			"a":Vector2(26.2, 0.0),
			"b":Vector2(33.8, 0.0)
		},
		{
			"name":"BACK STRAIGHT",
			"position":Vector2(0.0, -16.0),
			"radius":4.5,
			"direction":Vector2(-1.0, 0.0),
			"a":Vector2(0.0, -19.8),
			"b":Vector2(0.0, -12.2)
		},
		{
			"name":"WEST",
			"position":Vector2(-30.0, 0.0),
			"radius":5.0,
			"direction":Vector2(0.0, 1.0),
			"a":Vector2(-33.8, 0.0),
			"b":Vector2(-26.2, 0.0)
		}
	]
	var round_anchors: Array[Vector2] = [
		Vector2(0.0, 16.0),
		Vector2(18.0, 16.0),
		Vector2(26.0, 13.5),
		Vector2(30.5, 7.0),
		Vector2(30.5, -7.0),
		Vector2(26.0, -13.5),
		Vector2(18.0, -16.0),
		Vector2(0.0, -16.0),
		Vector2(-18.0, -16.0),
		Vector2(-26.0, -13.5),
		Vector2(-30.5, -7.0),
		Vector2(-30.5, 7.0),
		Vector2(-26.0, 13.5),
		Vector2(-18.0, 16.0)
	]
	_round_line_cache = _smooth_closed_line(round_anchors, 5)

	for i: int in range(FIG8_SAMPLES + 1):
		var t: float = TAU * float(i) / float(FIG8_SAMPLES)
		var p: Vector2 = _figure8_point(t)
		_figure8_line_cache.append(p)
		if i < FIG8_SAMPLES and i % 4 == 0:
			_figure8_ai_line_cache.append(p)

	_figure8_gates_cache = [
		_make_figure8_gate("START / FINISH", 0.0, 4.3),
		_make_figure8_gate("RIGHT LOOP", PI * 0.5, 4.6),
		_make_figure8_gate("CROSSOVER", PI, 4.3),
		_make_figure8_gate("LEFT LOOP", PI * 1.5, 4.6)
	]

	_airfield_road_outer_cache = rounded_rect_points(AIRFIELD_ROAD_OUTER_HALF, AIRFIELD_ROAD_OUTER_RADIUS, 14)
	_airfield_road_inner_cache = rounded_rect_points(AIRFIELD_ROAD_INNER_HALF, AIRFIELD_ROAD_INNER_RADIUS, 10)
	_airfield_barrier_outer_cache = rounded_rect_points(AIRFIELD_BARRIER_OUTER_HALF, AIRFIELD_BARRIER_OUTER_RADIUS, 14)
	_airfield_barrier_inner_cache = rounded_rect_points(AIRFIELD_BARRIER_INNER_HALF, AIRFIELD_BARRIER_INNER_RADIUS, 10)

	_airfield_gates_cache = [
		{
			"name":"START / FINISH",
			"position":Vector2(0.0, 16.7),
			"radius":5.7,
			"direction":Vector2(1.0, 0.0),
			"a":Vector2(0.0, 11.3),
			"b":Vector2(0.0, 22.1)
		},
		{
			"name":"EAST APRON",
			"position":Vector2(54.5, 0.0),
			"radius":6.2,
			"direction":Vector2(0.0, -1.0),
			"a":Vector2(49.2, 0.0),
			"b":Vector2(59.8, 0.0)
		},
		{
			"name":"BACK RUNWAY",
			"position":Vector2(0.0, -16.7),
			"radius":5.7,
			"direction":Vector2(-1.0, 0.0),
			"a":Vector2(0.0, -22.1),
			"b":Vector2(0.0, -11.3)
		},
		{
			"name":"WEST APRON",
			"position":Vector2(-54.5, 0.0),
			"radius":6.2,
			"direction":Vector2(0.0, 1.0),
			"a":Vector2(-59.8, 0.0),
			"b":Vector2(-49.2, 0.0)
		}
	]
	var airfield_anchors: Array[Vector2] = [
		Vector2(0.0, 16.7),
		Vector2(24.0, 16.7),
		Vector2(43.0, 16.7),
		Vector2(52.0, 13.2),
		Vector2(55.2, 7.0),
		Vector2(55.2, -7.0),
		Vector2(52.0, -13.2),
		Vector2(43.0, -16.7),
		Vector2(24.0, -16.7),
		Vector2(0.0, -16.7),
		Vector2(-24.0, -16.7),
		Vector2(-43.0, -16.7),
		Vector2(-52.0, -13.2),
		Vector2(-55.2, -7.0),
		Vector2(-55.2, 7.0),
		Vector2(-52.0, 13.2),
		Vector2(-43.0, 16.7),
		Vector2(-24.0, 16.7)
	]
	_airfield_line_cache = airfield_anchors
	reset_dry_line()


func _smooth_closed_line(anchors: Array[Vector2], steps_per_segment: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if anchors.size() < 4:
		return anchors.duplicate()
	var count: int = anchors.size()
	for i: int in range(count):
		var p0: Vector2 = anchors[posmod(i - 1, count)]
		var p1: Vector2 = anchors[i]
		var p2: Vector2 = anchors[(i + 1) % count]
		var p3: Vector2 = anchors[(i + 2) % count]
		for step: int in range(steps_per_segment):
			var t: float = float(step) / float(steps_per_segment)
			var t2: float = t * t
			var t3: float = t2 * t
			var point: Vector2 = 0.5 * (
				2.0 * p1
				+ (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			result.append(point)
	return result

func set_surface_profile(next_road_mu: float, next_runoff_mu: float) -> void:
	road_mu = next_road_mu
	runoff_mu = next_runoff_mu

func set_wet_surface(active: bool, next_dry_road_mu: float = 1.12) -> void:
	wet_surface = active and course_id() != "airfield"
	dry_road_mu = next_dry_road_mu
	reset_dry_line()

func course_id() -> String:
	match course_index:
		1:
			return "figure_eight"
		2:
			return "airfield"
		_:
			return "round"

func course_name() -> String:
	match course_index:
		1:
			return "FIGURE 8"
		2:
			return "AIRFIELD"
		_:
			return "ROUND"

func set_course(index: int) -> void:
	course_index = posmod(index, 3)
	if course_id() == "airfield":
		wet_surface = false
	reset_dry_line()

func cycle_course(direction: int = 1) -> void:
	set_course(course_index + direction)

func rounded_box_sdf(point: Vector2, half_size: Vector2, radius: float) -> float:
	var q: Vector2 = point.abs() - half_size + Vector2(radius, radius)
	var outside: Vector2 = Vector2(max(q.x, 0.0), max(q.y, 0.0))
	return min(max(q.x, q.y), 0.0) + outside.length() - radius

func is_on_road(point: Vector2) -> bool:
	if course_id() == "figure_eight":
		return _distance_to_figure8(point) <= FIG8_ROAD_HALF
	if course_id() == "airfield":
		var air_outer_d: float = rounded_box_sdf(point, AIRFIELD_ROAD_OUTER_HALF, AIRFIELD_ROAD_OUTER_RADIUS)
		var air_inner_d: float = rounded_box_sdf(point, AIRFIELD_ROAD_INNER_HALF, AIRFIELD_ROAD_INNER_RADIUS)
		return air_outer_d <= 0.0 and air_inner_d >= 0.0
	var outer_d: float = rounded_box_sdf(point, ROAD_OUTER_HALF, ROAD_OUTER_RADIUS)
	var inner_d: float = rounded_box_sdf(point, ROAD_INNER_HALF, ROAD_INNER_RADIUS)
	return outer_d <= 0.0 and inner_d >= 0.0


func off_track_wheel_count(sim: VehicleSim) -> int:
	var count: int = 0
	for wheel_position: Vector2 in sim.get_wheel_world_positions():
		if not is_on_road(wheel_position):
			count += 1
	return count

func surface_mu(point: Vector2) -> float:
	var on_road: bool = is_on_road(point)
	if course_id() == "airfield":
		return AIRFIELD_ROAD_MU if on_road else AIRFIELD_RUNOFF_MU
	if not on_road:
		return runoff_mu
	if not wet_surface:
		return road_mu

	var nearest: Dictionary = _nearest_racing_line(point)
	if nearest.is_empty():
		return road_mu
	var distance: float = float(nearest["distance"])
	var segment: int = int(nearest["segment"])
	if _dry_line_levels.is_empty() or segment >= _dry_line_levels.size():
		return road_mu
	var next_segment: int = (segment + 1) % _dry_line_levels.size()
	var dryness: float = (_dry_line_levels[segment] + _dry_line_levels[next_segment]) * 0.5
	var proximity: float = clamp(1.0 - distance / 3.2, 0.0, 1.0)
	return lerp(road_mu, dry_road_mu, dryness * proximity)

func reset_dry_line() -> void:
	var line: Array[Vector2] = racing_line_points()
	_dry_line_levels = PackedFloat32Array()
	_dry_line_levels.resize(line.size())
	for i: int in range(_dry_line_levels.size()):
		_dry_line_levels[i] = 0.0

func update_dry_line(dt: float, vehicle_positions: Array[Vector2]) -> void:
	if not wet_surface:
		return
	var line: Array[Vector2] = racing_line_points()
	if line.is_empty():
		return
	if _dry_line_levels.size() != line.size():
		reset_dry_line()

	for i: int in range(_dry_line_levels.size()):
		_dry_line_levels[i] = move_toward(_dry_line_levels[i], 0.0, dt * 0.0025)

	for vehicle_pos: Vector2 in vehicle_positions:
		var nearest: Dictionary = _nearest_racing_line(vehicle_pos)
		if nearest.is_empty() or float(nearest["distance"]) > 3.8:
			continue
		var segment: int = int(nearest["segment"])
		var next_segment: int = (segment + 1) % _dry_line_levels.size()
		var prev_segment: int = posmod(segment - 1, _dry_line_levels.size())
		_dry_line_levels[segment] = min(1.0, _dry_line_levels[segment] + dt * 0.42)
		_dry_line_levels[next_segment] = min(1.0, _dry_line_levels[next_segment] + dt * 0.28)
		_dry_line_levels[prev_segment] = min(1.0, _dry_line_levels[prev_segment] + dt * 0.14)

func dry_line_segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not wet_surface:
		return result
	var line: Array[Vector2] = racing_line_points()
	if line.size() < 2 or _dry_line_levels.size() != line.size():
		return result
	for i: int in range(line.size()):
		var j: int = (i + 1) % line.size()
		var level: float = (_dry_line_levels[i] + _dry_line_levels[j]) * 0.5
		if level > 0.01:
			result.append({
				"a": line[i],
				"b": line[j],
				"level": level
			})
	return result

func dry_line_average() -> float:
	if _dry_line_levels.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in _dry_line_levels:
		total += value
	return total / float(_dry_line_levels.size())

func _nearest_racing_line(point: Vector2) -> Dictionary:
	var line: Array[Vector2] = racing_line_points()
	if line.size() < 2:
		return {}
	var best_d2: float = INF
	var best_index: int = 0
	for i: int in range(line.size()):
		var a: Vector2 = line[i]
		var b: Vector2 = line[(i + 1) % line.size()]
		var ab: Vector2 = b - a
		var denom: float = max(ab.length_squared(), 0.000001)
		var u: float = clamp((point - a).dot(ab) / denom, 0.0, 1.0)
		var closest: Vector2 = a + ab * u
		var d2: float = point.distance_squared_to(closest)
		if d2 < best_d2:
			best_d2 = d2
			best_index = i
	return {"segment":best_index, "distance":sqrt(best_d2)}

func _sdf_normal(point: Vector2, half_size: Vector2, radius: float) -> Vector2:
	const EPS: float = 0.02
	var dx: float = rounded_box_sdf(point + Vector2(EPS, 0.0), half_size, radius) - rounded_box_sdf(point - Vector2(EPS, 0.0), half_size, radius)
	var dy: float = rounded_box_sdf(point + Vector2(0.0, EPS), half_size, radius) - rounded_box_sdf(point - Vector2(0.0, EPS), half_size, radius)
	var n: Vector2 = Vector2(dx, dy)
	return n.normalized() if n.length_squared() > 0.000001 else Vector2.UP

func resolve_barriers(sim: VehicleSim) -> bool:
	if course_id() == "figure_eight":
		return _resolve_figure8_barrier(sim)
	if course_id() == "airfield":
		return _resolve_rounded_barriers(
			sim,
			AIRFIELD_BARRIER_OUTER_HALF,
			AIRFIELD_BARRIER_OUTER_RADIUS,
			AIRFIELD_BARRIER_INNER_HALF,
			AIRFIELD_BARRIER_INNER_RADIUS
		)
	return _resolve_rounded_barriers(
		sim,
		BARRIER_OUTER_HALF,
		BARRIER_OUTER_RADIUS,
		BARRIER_INNER_HALF,
		BARRIER_INNER_RADIUS
	)

func _resolve_rounded_barriers(
	sim: VehicleSim,
	outer_half: Vector2,
	outer_radius: float,
	inner_half: Vector2,
	inner_radius: float
) -> bool:
	var collided: bool = false
	var outer_d: float = rounded_box_sdf(sim.position, outer_half, outer_radius)
	if outer_d > -CAR_COLLISION_RADIUS:
		var outer_n: Vector2 = _sdf_normal(sim.position, outer_half, outer_radius)
		var outer_penetration: float = outer_d + CAR_COLLISION_RADIUS
		sim.position -= outer_n * outer_penetration
		_apply_impact(sim, outer_n, true)
		collided = true

	var inner_d: float = rounded_box_sdf(sim.position, inner_half, inner_radius)
	if inner_d < CAR_COLLISION_RADIUS:
		var inner_n: Vector2 = _sdf_normal(sim.position, inner_half, inner_radius)
		var inner_penetration: float = CAR_COLLISION_RADIUS - inner_d
		sim.position += inner_n * inner_penetration
		_apply_impact(sim, inner_n, false)
		collided = true
	return collided

func _resolve_figure8_barrier(sim: VehicleSim) -> bool:
	var best_d2: float = INF
	var best_point: Vector2 = Vector2.ZERO
	for i: int in range(_figure8_line_cache.size() - 1):
		var a: Vector2 = _figure8_line_cache[i]
		var b: Vector2 = _figure8_line_cache[i + 1]
		var ab: Vector2 = b - a
		var denom: float = max(ab.length_squared(), 0.000001)
		var u: float = clamp((sim.position - a).dot(ab) / denom, 0.0, 1.0)
		var closest: Vector2 = a + ab * u
		var d2: float = sim.position.distance_squared_to(closest)
		if d2 < best_d2:
			best_d2 = d2
			best_point = closest

	var distance: float = sqrt(best_d2)
	var allowed: float = FIG8_BARRIER_HALF - CAR_COLLISION_RADIUS
	if distance <= allowed:
		return false

	var normal: Vector2 = sim.position - best_point
	if normal.length_squared() < 0.000001:
		normal = Vector2.UP
	else:
		normal = normal.normalized()
	sim.position = best_point + normal * allowed
	_apply_impact(sim, normal, true)
	return true

func _apply_impact(sim: VehicleSim, normal: Vector2, outer: bool) -> void:
	var normal_speed: float = sim.velocity.dot(normal)
	var approaching: bool = normal_speed > 0.0 if outer else normal_speed < 0.0
	if not approaching:
		return
	sim.last_impact_kph = max(sim.last_impact_kph, abs(normal_speed) * 3.6)
	var tangent_velocity: Vector2 = sim.velocity - normal * normal_speed
	var rebound_velocity: Vector2 = -normal * normal_speed * 0.20
	sim.velocity = tangent_velocity * 0.78 + rebound_velocity
	sim.angular_velocity *= 0.58

func rounded_rect_points(half_size: Vector2, radius: float, corner_segments: int = 10) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var centres: Array[Vector2] = [
		Vector2(half_size.x - radius, half_size.y - radius),
		Vector2(-half_size.x + radius, half_size.y - radius),
		Vector2(-half_size.x + radius, -half_size.y + radius),
		Vector2(half_size.x - radius, -half_size.y + radius)
	]
	var starts: Array[float] = [0.0, 90.0, 180.0, 270.0]
	for corner: int in range(4):
		for step: int in range(corner_segments + 1):
			var degrees: float = starts[corner] + 90.0 * float(step) / float(corner_segments)
			var rad: float = deg_to_rad(degrees)
			points.append(centres[corner] + Vector2(cos(rad), sin(rad)) * radius)
	return points

func road_outer_points() -> PackedVector2Array:
	return _airfield_road_outer_cache if course_id() == "airfield" else _road_outer_cache

func road_inner_points() -> PackedVector2Array:
	return _airfield_road_inner_cache if course_id() == "airfield" else _road_inner_cache

func barrier_outer_points() -> PackedVector2Array:
	return _airfield_barrier_outer_cache if course_id() == "airfield" else _barrier_outer_cache

func barrier_inner_points() -> PackedVector2Array:
	return _airfield_barrier_inner_cache if course_id() == "airfield" else _barrier_inner_cache

func figure_eight_points() -> PackedVector2Array:
	return _figure8_line_cache

func race_gates() -> Array[Dictionary]:
	match course_id():
		"figure_eight":
			return _figure8_gates_cache
		"airfield":
			return _airfield_gates_cache
		_:
			return _round_gates_cache

func racing_line_points() -> Array[Vector2]:
	match course_id():
		"figure_eight":
			return _figure8_ai_line_cache
		"airfield":
			return _airfield_line_cache
		_:
			return _round_line_cache

func player_grid_pose() -> Dictionary:
	if course_id() == "figure_eight":
		return _figure8_grid_pose(-0.13, -0.80)
	if course_id() == "airfield":
		return {"position": Vector2(-5.0, 15.1), "angle": 0.0}
	return {"position": Vector2(-3.2, 14.6), "angle": 0.0}

func ai_grid_pose() -> Dictionary:
	if course_id() == "figure_eight":
		return _figure8_grid_pose(-0.22, 0.95)
	if course_id() == "airfield":
		return {"position": Vector2(-9.0, 18.7), "angle": 0.0}
	return {"position": Vector2(-6.5, 17.4), "angle": 0.0}

func _figure8_point(t: float) -> Vector2:
	return Vector2(FIG8_A * sin(t), FIG8_B * sin(2.0 * t))

func _figure8_tangent(t: float) -> Vector2:
	var tangent: Vector2 = Vector2(FIG8_A * cos(t), 2.0 * FIG8_B * cos(2.0 * t))
	return tangent.normalized()

func _make_figure8_gate(label: String, t: float, radius: float) -> Dictionary:
	var p: Vector2 = _figure8_point(t)
	var direction: Vector2 = _figure8_tangent(t)
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var half_width: float = 4.9
	return {
		"name": label,
		"position": p,
		"radius": radius,
		"direction": direction,
		"a": p - normal * half_width,
		"b": p + normal * half_width
	}

func _figure8_grid_pose(t: float, lateral: float) -> Dictionary:
	var p: Vector2 = _figure8_point(t)
	var tangent: Vector2 = _figure8_tangent(t)
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	return {"position": p + normal * lateral, "angle": tangent.angle()}

func _distance_to_figure8(point: Vector2) -> float:
	var best_d2: float = INF
	for i: int in range(_figure8_line_cache.size() - 1):
		var a: Vector2 = _figure8_line_cache[i]
		var b: Vector2 = _figure8_line_cache[i + 1]
		var ab: Vector2 = b - a
		var denom: float = max(ab.length_squared(), 0.000001)
		var u: float = clamp((point - a).dot(ab) / denom, 0.0, 1.0)
		var closest: Vector2 = a + ab * u
		best_d2 = min(best_d2, point.distance_squared_to(closest))
	return sqrt(best_d2)
