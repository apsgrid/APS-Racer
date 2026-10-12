class_name StarterActor
extends RefCounted

const VARIANT_COUNT: int = 4
const HIT_RADIUS: float = 0.70
const RECOVERY_DELAY: float = 1.05
const WALK_SPEED: float = 4.2

var variant: int = 0
var state: String = "line"
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var angle: float = 0.0
var recovery_timer: float = 0.0
var crowd_target: Vector2 = Vector2.ZERO
var hit_speed_kph: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func restart(track: TrackModel) -> void:
	variant = rng.randi_range(0, VARIANT_COUNT - 1)
	state = "line"
	position = track.starter_line_position()
	velocity = Vector2.ZERO
	angle = 0.0
	recovery_timer = 0.0
	crowd_target = track.starter_crowd_position()
	hit_speed_kph = 0.0

func is_at_line() -> bool:
	return state == "line"

func is_with_crowd() -> bool:
	return state == "crowd"

func try_hit(car: VehicleSim) -> bool:
	if state != "line":
		return false
	var delta: Vector2 = position - car.position
	var distance: float = delta.length()
	var collision_distance: float = HIT_RADIUS + 1.15
	if distance >= collision_distance:
		return false
	var speed: float = car.velocity.length()
	if speed < 1.0:
		return false

	var normal: Vector2 = delta.normalized() if distance > 0.001 else -Vector2(cos(car.angle), sin(car.angle))
	var impact_speed: float = max(speed, abs(car.velocity.dot(normal)))
	hit_speed_kph = impact_speed * 3.6
	velocity = car.velocity * 0.62 + normal * min(4.5, impact_speed * 0.18)
	position += normal * max(collision_distance - distance, 0.0)
	angle = velocity.angle()
	state = "hit"
	recovery_timer = RECOVERY_DELAY

	car.velocity *= 0.90
	car.angular_velocity *= 0.90
	car.last_impact_kph = max(car.last_impact_kph, hit_speed_kph)
	return true

func step(dt: float) -> void:
	match state:
		"hit":
			position += velocity * dt
			velocity = velocity.move_toward(Vector2.ZERO, dt * 7.2)
			if velocity.length_squared() > 0.01:
				angle = velocity.angle()
			recovery_timer -= dt
			if recovery_timer <= 0.0:
				state = "joining"
				velocity = Vector2.ZERO
		"joining":
			var delta: Vector2 = crowd_target - position
			var distance: float = delta.length()
			if distance <= 0.12:
				position = crowd_target
				velocity = Vector2.ZERO
				state = "crowd"
			else:
				var direction: Vector2 = delta / max(distance, 0.0001)
				velocity = direction * min(WALK_SPEED, distance / max(dt, 0.001))
				position += velocity * dt
				angle = direction.angle()
		"crowd":
			position = crowd_target
			velocity = Vector2.ZERO

func portrait_path() -> String:
	return "res://art/export/shared/starter/corey_%02d.png" % (variant + 1)
