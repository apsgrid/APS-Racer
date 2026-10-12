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

const CAR_COLLISION_RADIUS: float = 1.15

var road_mu: float = 1.0
var runoff_mu: float = 0.43
var course_index: int = 0

var _road_outer_cache: PackedVector2Array = PackedVector2Array()
var _road_inner_cache: PackedVector2Array = PackedVector2Array()
var _barrier_outer_cache: PackedVector2Array = PackedVector2Array()
var _barrier_inner_cache: PackedVector2Array = PackedVector2Array()
var _round_gates_cache: Array[Dictionary] = []
var _round_line_cache: Array[Vector2] = []
var _figure8_gates_cache: Array[Dictionary] = []
var _figure8_line_cache: PackedVector2Array = PackedVector2Array()
var _figure8_ai_line_cache: Array[Vector2] = []

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
	_round_line_cache = [
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

func set_surface_profile(next_road_mu: float, next_runoff_mu: float) -> void:
	road_mu = next_road_mu
	runoff_mu = next_runoff_mu

func course_id() -> String:
	return "figure_eight" if course_index == 1 else "round"

func course_name() -> String:
	return "FIGURE 8" if course_index == 1 else "ROUND"

func set_course(index: int) -> void:
	course_index = posmod(index, 2)

func cycle_course(direction: int = 1) -> void:
	set_course(course_index + direction)

func rounded_box_sdf(point: Vector2, half_size: Vector2, radius: float) -> float:
	var q: Vector2 = point.abs() - half_size + Vector2(radius, radius)
	var outside: Vector2 = Vector2(max(q.x, 0.0), max(q.y, 0.0))
	return min(max(q.x, q.y), 0.0) + outside.length() - radius

func is_on_road(point: Vector2) -> bool:
	if course_id() == "figure_eight":
		return _distance_to_figure8(point) <= FIG8_ROAD_HALF
	var outer_d: float = rounded_box_sdf(point, ROAD_OUTER_HALF, ROAD_OUTER_RADIUS)
	var inner_d: float = rounded_box_sdf(point, ROAD_INNER_HALF, ROAD_INNER_RADIUS)
	return outer_d <= 0.0 and inner_d >= 0.0

func surface_mu(point: Vector2) -> float:
	return road_mu if is_on_road(point) else runoff_mu

func _sdf_normal(point: Vector2, half_size: Vector2, radius: float) -> Vector2:
	const EPS: float = 0.02
	var dx: float = rounded_box_sdf(point + Vector2(EPS, 0.0), half_size, radius) - rounded_box_sdf(point - Vector2(EPS, 0.0), half_size, radius)
	var dy: float = rounded_box_sdf(point + Vector2(0.0, EPS), half_size, radius) - rounded_box_sdf(point - Vector2(0.0, EPS), half_size, radius)
	var n: Vector2 = Vector2(dx, dy)
	return n.normalized() if n.length_squared() > 0.000001 else Vector2.UP

func resolve_barriers(sim: VehicleSim) -> bool:
	if course_id() == "figure_eight":
		return _resolve_figure8_barrier(sim)

	var collided: bool = false
	var outer_d: float = rounded_box_sdf(sim.position, BARRIER_OUTER_HALF, BARRIER_OUTER_RADIUS)
	if outer_d > -CAR_COLLISION_RADIUS:
		var outer_n: Vector2 = _sdf_normal(sim.position, BARRIER_OUTER_HALF, BARRIER_OUTER_RADIUS)
		var outer_penetration: float = outer_d + CAR_COLLISION_RADIUS
		sim.position -= outer_n * outer_penetration
		_apply_impact(sim, outer_n, true)
		collided = true

	var inner_d: float = rounded_box_sdf(sim.position, BARRIER_INNER_HALF, BARRIER_INNER_RADIUS)
	if inner_d < CAR_COLLISION_RADIUS:
		var inner_n: Vector2 = _sdf_normal(sim.position, BARRIER_INNER_HALF, BARRIER_INNER_RADIUS)
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
	return _road_outer_cache

func road_inner_points() -> PackedVector2Array:
	return _road_inner_cache

func barrier_outer_points() -> PackedVector2Array:
	return _barrier_outer_cache

func barrier_inner_points() -> PackedVector2Array:
	return _barrier_inner_cache

func figure_eight_points() -> PackedVector2Array:
	return _figure8_line_cache

func race_gates() -> Array[Dictionary]:
	return _figure8_gates_cache if course_id() == "figure_eight" else _round_gates_cache

func racing_line_points() -> Array[Vector2]:
	return _figure8_ai_line_cache if course_id() == "figure_eight" else _round_line_cache

func player_grid_pose() -> Dictionary:
	if course_id() == "figure_eight":
		return _figure8_grid_pose(-0.13, -0.80)
	return {"position": Vector2(-3.2, 14.6), "angle": 0.0}

func ai_grid_pose() -> Dictionary:
	if course_id() == "figure_eight":
		return _figure8_grid_pose(-0.22, 0.95)
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
