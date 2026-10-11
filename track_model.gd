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

const CAR_COLLISION_RADIUS: float = 1.15
const ASPHALT_MU: float = 1.0
const GRASS_MU: float = 0.43

func rounded_box_sdf(point: Vector2, half_size: Vector2, radius: float) -> float:
	var q: Vector2 = point.abs() - half_size + Vector2(radius, radius)
	var outside: Vector2 = Vector2(max(q.x, 0.0), max(q.y, 0.0))
	return min(max(q.x, q.y), 0.0) + outside.length() - radius

func is_on_road(point: Vector2) -> bool:
	var outer_d: float = rounded_box_sdf(point, ROAD_OUTER_HALF, ROAD_OUTER_RADIUS)
	var inner_d: float = rounded_box_sdf(point, ROAD_INNER_HALF, ROAD_INNER_RADIUS)
	return outer_d <= 0.0 and inner_d >= 0.0

func surface_mu(point: Vector2) -> float:
	return ASPHALT_MU if is_on_road(point) else GRASS_MU

func _sdf_normal(point: Vector2, half_size: Vector2, radius: float) -> Vector2:
	const EPS: float = 0.02
	var dx: float = rounded_box_sdf(point + Vector2(EPS, 0.0), half_size, radius) - rounded_box_sdf(point - Vector2(EPS, 0.0), half_size, radius)
	var dy: float = rounded_box_sdf(point + Vector2(0.0, EPS), half_size, radius) - rounded_box_sdf(point - Vector2(0.0, EPS), half_size, radius)
	var n: Vector2 = Vector2(dx, dy)
	return n.normalized() if n.length_squared() > 0.000001 else Vector2.UP

func resolve_barriers(sim: VehicleSim) -> bool:
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
	return rounded_rect_points(ROAD_OUTER_HALF, ROAD_OUTER_RADIUS, 12)

func road_inner_points() -> PackedVector2Array:
	return rounded_rect_points(ROAD_INNER_HALF, ROAD_INNER_RADIUS, 12)

func barrier_outer_points() -> PackedVector2Array:
	return rounded_rect_points(BARRIER_OUTER_HALF, BARRIER_OUTER_RADIUS, 12)

func barrier_inner_points() -> PackedVector2Array:
	return rounded_rect_points(BARRIER_INNER_HALF, BARRIER_INNER_RADIUS, 12)
