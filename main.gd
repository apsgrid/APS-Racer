extends Node2D

const SIM_DT := 1.0 / 120.0
const OUTER := Rect2(-25.0, -15.0, 50.0, 30.0)
const INNER := Rect2(-14.0, -6.0, 28.0, 12.0)

var sim := VehicleSim.new()
var accumulator := 0.0
var camera_world := Vector2.ZERO
var pixels_per_meter := 25.0
var touches: Dictionary = {}

func _ready() -> void:
	camera_world = sim.position
	set_process_input(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var controls: Dictionary = _read_controls()
	accumulator = min(accumulator + delta, 0.25)
	while accumulator >= SIM_DT:
		sim.step(
			SIM_DT,
			controls.throttle,
			controls.brake,
			controls.steer,
			controls.handbrake,
			_surface_mu
		)
		accumulator -= SIM_DT

	var speed := sim.velocity.length()
	var look_ahead := sim.velocity * 0.16
	var camera_target := sim.position + look_ahead
	camera_world = camera_world.lerp(camera_target, 1.0 - exp(-6.0 * delta))
	var zoom_target: float = lerp(29.0, 18.0, clamp(speed / 48.0, 0.0, 1.0))
	pixels_per_meter = lerp(pixels_per_meter, zoom_target, 1.0 - exp(-4.0 * delta))
	queue_redraw()

func _read_controls() -> Dictionary:
	var steer := 0.0
	var throttle := 0.0
	var brake := 0.0
	var handbrake := false

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle = 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		brake = 1.0
	if Input.is_key_pressed(KEY_SPACE):
		handbrake = true

	if _touch_active("left"):
		steer -= 1.0
	if _touch_active("right"):
		steer += 1.0
	if _touch_active("throttle"):
		throttle = 1.0
	if _touch_active("brake"):
		brake = 1.0
	if _touch_active("handbrake"):
		handbrake = true

	return {
		"steer": clamp(steer, -1.0, 1.0),
		"throttle": throttle,
		"brake": brake,
		"handbrake": handbrake
	}

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		sim.reset()
		camera_world = sim.position

	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if _control_rects()["reset"].has_point(event.position):
				sim.reset()
				camera_world = sim.position
		else:
			touches.erase(event.index)

	if event is InputEventScreenDrag:
		touches[event.index] = event.position

func _touch_active(control_name: String) -> bool:
	var rects := _control_rects()
	var rect: Rect2 = rects[control_name]
	for pos in touches.values():
		if rect.has_point(pos):
			return true
	return false

func _control_rects() -> Dictionary:
	var view := get_viewport_rect().size
	var button := Vector2(116.0, 116.0)
	return {
		"left": Rect2(Vector2(24.0, view.y - 146.0), button),
		"right": Rect2(Vector2(152.0, view.y - 146.0), button),
		"brake": Rect2(Vector2(view.x - 280.0, view.y - 146.0), button),
		"throttle": Rect2(Vector2(view.x - 152.0, view.y - 146.0), button),
		"handbrake": Rect2(Vector2(view.x - 216.0, view.y - 274.0), Vector2(150.0, 92.0)),
		"reset": Rect2(Vector2(view.x - 116.0, 20.0), Vector2(92.0, 54.0))
	}

func _is_on_road(world_pos: Vector2) -> bool:
	return OUTER.has_point(world_pos) and not INNER.has_point(world_pos)

func _surface_mu(world_pos: Vector2) -> float:
	return 1.0 if _is_on_road(world_pos) else 0.42

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var centre := get_viewport_rect().size * 0.5
	return centre + (world_pos - camera_world) * pixels_per_meter

func _rect_to_screen(world_rect: Rect2) -> Rect2:
	return Rect2(
		_world_to_screen(world_rect.position),
		world_rect.size * pixels_per_meter
	)

func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#2f6f3a"))
	draw_rect(_rect_to_screen(OUTER), Color("#3c4046"))
	draw_rect(_rect_to_screen(INNER), Color("#2f6f3a"))
	draw_rect(_rect_to_screen(OUTER), Color("#e5e5e5"), false, 2.0)
	draw_rect(_rect_to_screen(INNER), Color("#e5e5e5"), false, 2.0)
	_draw_start_line()
	_draw_car()
	_draw_telemetry()
	_draw_touch_controls()

func _draw_start_line() -> void:
	for i in range(8):
		var y0 := 6.1 + float(i) * 1.1
		var colour := Color.WHITE if i % 2 == 0 else Color.BLACK
		draw_rect(_rect_to_screen(Rect2(-0.22, y0, 0.44, 1.1)), colour)

func _draw_car() -> void:
	var body_local := [
		Vector2(2.2, -0.9),
		Vector2(2.2, 0.9),
		Vector2(-2.2, 0.9),
		Vector2(-2.2, -0.9)
	]
	var body_screen := PackedVector2Array()
	for point in body_local:
		body_screen.append(_world_to_screen(sim.position + point.rotated(sim.angle)))
	draw_colored_polygon(body_screen, Color("#e34f4f"))

	var nose_a := _world_to_screen(sim.position + Vector2(2.22, -0.62).rotated(sim.angle))
	var nose_b := _world_to_screen(sim.position + Vector2(2.22, 0.62).rotated(sim.angle))
	draw_line(nose_a, nose_b, Color("#fff2a8"), 4.0)

	var front_x := sim.wheelbase * (1.0 - sim.front_weight_fraction)
	var rear_x := -sim.wheelbase * sim.front_weight_fraction
	var half_track := sim.track_width * 0.5
	var wheel_data := [
		[Vector2(front_x, -half_track), sim.steering_angle],
		[Vector2(front_x, half_track), sim.steering_angle],
		[Vector2(rear_x, -half_track), 0.0],
		[Vector2(rear_x, half_track), 0.0]
	]
	for wheel in wheel_data:
		_draw_wheel(wheel[0], wheel[1])

func _draw_wheel(local_pos: Vector2, steer: float) -> void:
	var centre_world := sim.position + local_pos.rotated(sim.angle)
	var wheel_angle := sim.angle + steer
	var half := Vector2(0.34, 0.13)
	var local_points := [
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
		Vector2(-half.x, -half.y)
	]
	var screen_points := PackedVector2Array()
	for point in local_points:
		screen_points.append(_world_to_screen(centre_world + point.rotated(wheel_angle)))
	draw_colored_polygon(screen_points, Color("#111111"))

func _draw_telemetry() -> void:
	var surface_name := "ASPHALT" if sim.last_surface_mu > 0.8 else "GRASS"
	var lines := [
		"APS RACER // PHYSICS PROTOTYPE",
		"Speed: %6.1f km/h" % sim.speed_kph(),
		"Steer: %6.1f deg" % rad_to_deg(sim.steering_angle),
		"Yaw:   %6.1f deg/s" % rad_to_deg(sim.angular_velocity),
		"Long G: %5.2f" % (sim.last_long_accel / 9.81),
		"Lat G:  %5.2f" % (sim.last_lat_accel / 9.81),
		"FL slip: %5.1f deg" % sim.wheel_slip_angles[0],
		"FR slip: %5.1f deg" % sim.wheel_slip_angles[1],
		"RL slip: %5.1f deg" % sim.wheel_slip_angles[2],
		"RR slip: %5.1f deg" % sim.wheel_slip_angles[3],
		"Surface: " + surface_name,
		"WASD/arrows drive | Space handbrake | R reset"
	]
	var font := ThemeDB.fallback_font
	for i in range(lines.size()):
		var pos := Vector2(18.0, 30.0 + float(i) * 22.0)
		draw_string(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color.WHITE)

func _draw_touch_controls() -> void:
	var rects := _control_rects()
	_draw_touch_button(rects["left"], "<", _touch_active("left"))
	_draw_touch_button(rects["right"], ">", _touch_active("right"))
	_draw_touch_button(rects["brake"], "BRAKE", _touch_active("brake"))
	_draw_touch_button(rects["throttle"], "GO", _touch_active("throttle"))
	_draw_touch_button(rects["handbrake"], "HANDBRAKE", _touch_active("handbrake"))
	_draw_touch_button(rects["reset"], "RESET", false)

func _draw_touch_button(rect: Rect2, label: String, active: bool) -> void:
	var fill := Color(1.0, 1.0, 1.0, 0.28 if active else 0.14)
	draw_rect(rect, fill, true)
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.55), false, 2.0)
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18)
	var text_pos := rect.position + (rect.size - text_size) * 0.5 + Vector2(0.0, text_size.y * 0.78)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)
