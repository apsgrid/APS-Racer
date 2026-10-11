extends Node2D

const SIM_DT: float = 1.0 / 120.0
const MAX_SKID_POINTS: int = 1200
const MAX_SMOKE_PUFFS: int = 90

var sim: VehicleSim = VehicleSim.new()
var track: TrackModel = TrackModel.new()
var accumulator: float = 0.0
var camera_world: Vector2 = Vector2.ZERO
var pixels_per_meter: float = 25.0
var touches: Dictionary = {}

var skid_points: Array[Vector2] = []
var previous_rear: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var has_previous_rear: bool = false
var smoke_positions: Array[Vector2] = []
var smoke_life: Array[float] = []
var smoke_spawn_cooldown: float = 0.0
var tuning_panel: TuningPanel

func _ready() -> void:
	sim.set_preset(0)
	camera_world = sim.position
	tuning_panel = TuningPanel.new()
	add_child(tuning_panel)
	tuning_panel.setup(sim)
	tuning_panel.car_selected.connect(_on_tuning_car_selected)
	set_process_input(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var controls: Dictionary = _read_controls()
	accumulator = min(accumulator + delta, 0.25)
	while accumulator >= SIM_DT:
		sim.step(
			SIM_DT,
			float(controls["throttle"]),
			float(controls["brake"]),
			float(controls["steer"]),
			bool(controls["handbrake"]),
			track.surface_mu
		)
		track.resolve_barriers(sim)
		_record_tyre_effects(SIM_DT)
		sim.last_impact_kph = move_toward(sim.last_impact_kph, 0.0, SIM_DT * 28.0)
		accumulator -= SIM_DT

	_update_smoke(delta)
	var speed: float = sim.velocity.length()
	var look_ahead: Vector2 = sim.velocity * 0.16
	var camera_target: Vector2 = sim.position + look_ahead
	camera_world = camera_world.lerp(camera_target, 1.0 - exp(-6.0 * delta))
	var zoom_target: float = lerp(29.0, 17.5, clamp(speed / 48.0, 0.0, 1.0))
	pixels_per_meter = lerp(pixels_per_meter, zoom_target, 1.0 - exp(-4.0 * delta))
	queue_redraw()

func _record_tyre_effects(dt: float) -> void:
	var wheels: Array[Vector2] = sim.get_wheel_world_positions()
	var rear_left: Vector2 = wheels[2]
	var rear_right: Vector2 = wheels[3]
	var slipping_left: bool = sim.wheel_grip_usage[2] > 0.93 and abs(sim.wheel_slip_angles[2]) > 5.0
	var slipping_right: bool = sim.wheel_grip_usage[3] > 0.93 and abs(sim.wheel_slip_angles[3]) > 5.0
	var moving: bool = sim.speed_kph() > 18.0

	if has_previous_rear and moving:
		if slipping_left:
			_add_skid_segment(previous_rear[0], rear_left)
		if slipping_right:
			_add_skid_segment(previous_rear[1], rear_right)

	smoke_spawn_cooldown = max(smoke_spawn_cooldown - dt, 0.0)
	if moving and smoke_spawn_cooldown <= 0.0 and (slipping_left or slipping_right):
		smoke_positions.append((rear_left + rear_right) * 0.5)
		smoke_life.append(0.72)
		smoke_spawn_cooldown = 0.055
		while smoke_positions.size() > MAX_SMOKE_PUFFS:
			smoke_positions.remove_at(0)
			smoke_life.remove_at(0)

	previous_rear[0] = rear_left
	previous_rear[1] = rear_right
	has_previous_rear = true

func _add_skid_segment(a: Vector2, b: Vector2) -> void:
	skid_points.append(a)
	skid_points.append(b)
	while skid_points.size() > MAX_SKID_POINTS:
		skid_points.remove_at(0)
		skid_points.remove_at(0)

func _update_smoke(delta: float) -> void:
	for i: int in range(smoke_life.size() - 1, -1, -1):
		smoke_life[i] -= delta
		if smoke_life[i] <= 0.0:
			smoke_life.remove_at(i)
			smoke_positions.remove_at(i)

func _read_controls() -> Dictionary:
	if tuning_panel != null and tuning_panel.is_open():
		return {"steer": 0.0, "throttle": 0.0, "brake": 0.0, "handbrake": false}

	var steer: float = 0.0
	var throttle: float = 0.0
	var brake: float = 0.0
	var handbrake: bool = false

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

	var joypads: Array[int] = Input.get_connected_joypads()
	if not joypads.is_empty():
		var joy: int = joypads[0]
		var stick_x: float = Input.get_joy_axis(joy, JOY_AXIS_LEFT_X)
		if abs(stick_x) > 0.12:
			steer = stick_x

		var rt_raw: float = Input.get_joy_axis(joy, JOY_AXIS_TRIGGER_RIGHT)
		var lt_raw: float = Input.get_joy_axis(joy, JOY_AXIS_TRIGGER_LEFT)
		var signed_triggers: bool = rt_raw < -0.25 or lt_raw < -0.25
		var rt: float = clamp((rt_raw + 1.0) * 0.5, 0.0, 1.0) if signed_triggers else max(rt_raw, 0.0)
		var lt: float = clamp((lt_raw + 1.0) * 0.5, 0.0, 1.0) if signed_triggers else max(lt_raw, 0.0)
		throttle = max(throttle, rt)
		brake = max(brake, lt)
		if Input.is_joy_button_pressed(joy, JOY_BUTTON_A):
			throttle = 1.0
		if Input.is_joy_button_pressed(joy, JOY_BUTTON_B):
			brake = 1.0
		if Input.is_joy_button_pressed(joy, JOY_BUTTON_X):
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
		"throttle": clamp(throttle, 0.0, 1.0),
		"brake": clamp(brake, 0.0, 1.0),
		"handbrake": handbrake
	}

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T or event.keycode == KEY_F1:
			tuning_panel.toggle()
			return
		elif event.keycode == KEY_ESCAPE and tuning_panel.is_open():
			tuning_panel.set_open(false)
			return

	if tuning_panel != null and tuning_panel.is_open():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reset_car()
		elif event.keycode == KEY_1:
			_select_preset(0)
		elif event.keycode == KEY_2:
			_select_preset(1)
		elif event.keycode == KEY_3:
			_select_preset(2)

	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			_select_preset(sim.preset_index - 1)
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			_select_preset(sim.preset_index + 1)

	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			var rects: Dictionary = _control_rects()
			if Rect2(rects["reset"]).has_point(event.position):
				_reset_car()
			elif Rect2(rects["preset"]).has_point(event.position):
				_select_preset(sim.preset_index + 1)
			elif Rect2(rects["tune"]).has_point(event.position):
				tuning_panel.set_open(true)
		else:
			touches.erase(event.index)

	if event is InputEventScreenDrag:
		touches[event.index] = event.position

func _reset_car() -> void:
	sim.reset()
	camera_world = sim.position
	has_previous_rear = false

func _select_preset(index: int) -> void:
	sim.set_preset(index)
	camera_world = sim.position
	has_previous_rear = false
	skid_points.clear()
	smoke_positions.clear()
	smoke_life.clear()
	if tuning_panel != null:
		tuning_panel.sync_from_sim()

func _on_tuning_car_selected(index: int) -> void:
	_select_preset(index)

func _touch_active(control_name: String) -> bool:
	var rects: Dictionary = _control_rects()
	var rect: Rect2 = Rect2(rects[control_name])
	for value: Variant in touches.values():
		var pos: Vector2 = Vector2(value)
		if rect.has_point(pos):
			return true
	return false

func _control_rects() -> Dictionary:
	var view: Vector2 = get_viewport_rect().size
	var button: Vector2 = Vector2(116.0, 116.0)
	return {
		"left": Rect2(Vector2(24.0, view.y - 146.0), button),
		"right": Rect2(Vector2(152.0, view.y - 146.0), button),
		"brake": Rect2(Vector2(view.x - 280.0, view.y - 146.0), button),
		"throttle": Rect2(Vector2(view.x - 152.0, view.y - 146.0), button),
		"handbrake": Rect2(Vector2(view.x - 216.0, view.y - 274.0), Vector2(150.0, 92.0)),
		"tune": Rect2(Vector2(view.x - 356.0, 20.0), Vector2(108.0, 54.0)),
		"preset": Rect2(Vector2(view.x - 236.0, 20.0), Vector2(108.0, 54.0)),
		"reset": Rect2(Vector2(view.x - 116.0, 20.0), Vector2(92.0, 54.0))
	}

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var centre: Vector2 = get_viewport_rect().size * 0.5
	return centre + (world_pos - camera_world) * pixels_per_meter

func _world_points_to_screen(world_points: PackedVector2Array) -> PackedVector2Array:
	var screen_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in world_points:
		screen_points.append(_world_to_screen(point))
	return screen_points

func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#285f32"))
	_draw_track()
	_draw_skid_marks()
	_draw_smoke()
	_draw_test_markers()
	_draw_car()
	_draw_telemetry()
	_draw_touch_controls()

func _draw_track() -> void:
	var outer_road: PackedVector2Array = _world_points_to_screen(track.road_outer_points())
	var inner_road: PackedVector2Array = _world_points_to_screen(track.road_inner_points())
	draw_colored_polygon(outer_road, Color("#3d4147"))
	draw_colored_polygon(inner_road, Color("#285f32"))

	var outer_barrier: PackedVector2Array = _world_points_to_screen(track.barrier_outer_points())
	var inner_barrier: PackedVector2Array = _world_points_to_screen(track.barrier_inner_points())
	if outer_barrier.size() > 1:
		outer_barrier.append(outer_barrier[0])
		draw_polyline(outer_barrier, Color("#d8d8d8"), 4.0, true)
	if inner_barrier.size() > 1:
		inner_barrier.append(inner_barrier[0])
		draw_polyline(inner_barrier, Color("#d8d8d8"), 4.0, true)

	_draw_start_line()

func _draw_start_line() -> void:
	for i: int in range(8):
		var y0: float = 12.2 + float(i) * 0.96
		var colour: Color = Color.WHITE if i % 2 == 0 else Color.BLACK
		var a: Vector2 = _world_to_screen(Vector2(-0.25, y0))
		var b: Vector2 = _world_to_screen(Vector2(0.25, y0 + 0.96))
		draw_rect(Rect2(a, b - a), colour)

func _draw_test_markers() -> void:
	var marker_colour: Color = Color(1.0, 0.74, 0.18, 0.9)
	for x: float in [-20.0, -12.0, -4.0, 4.0, 12.0, 20.0]:
		var pos: Vector2 = _world_to_screen(Vector2(x, -16.0))
		draw_circle(pos, max(3.0, pixels_per_meter * 0.12), marker_colour)
	for x: float in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		var offset: float = 1.2 if int(x / 8.0) % 2 == 0 else -1.2
		var pos2: Vector2 = _world_to_screen(Vector2(x, 16.0 + offset))
		draw_circle(pos2, max(3.0, pixels_per_meter * 0.12), Color("#77c9ff"))

func _draw_skid_marks() -> void:
	for i: int in range(0, skid_points.size() - 1, 2):
		var a: Vector2 = _world_to_screen(skid_points[i])
		var b: Vector2 = _world_to_screen(skid_points[i + 1])
		draw_line(a, b, Color(0.05, 0.05, 0.05, 0.58), max(1.0, pixels_per_meter * 0.07), true)

func _draw_smoke() -> void:
	for i: int in range(smoke_positions.size()):
		var life_ratio: float = clamp(smoke_life[i] / 0.72, 0.0, 1.0)
		var radius: float = pixels_per_meter * lerp(0.18, 0.58, 1.0 - life_ratio)
		var alpha: float = 0.32 * life_ratio
		draw_circle(_world_to_screen(smoke_positions[i]), radius, Color(0.9, 0.9, 0.9, alpha))

func _draw_car() -> void:
	var body_local: Array[Vector2] = [
		Vector2(2.2, -0.9),
		Vector2(2.2, 0.9),
		Vector2(-2.2, 0.9),
		Vector2(-2.2, -0.9)
	]
	var body_screen: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in body_local:
		body_screen.append(_world_to_screen(sim.position + point.rotated(sim.angle)))

	var body_colour: Color = Color("#e34f4f")
	if sim.preset_index == 1:
		body_colour = Color("#55a9ff")
	elif sim.preset_index == 2:
		body_colour = Color("#f2c14e")
	draw_colored_polygon(body_screen, body_colour)

	var nose_a: Vector2 = _world_to_screen(sim.position + Vector2(2.22, -0.62).rotated(sim.angle))
	var nose_b: Vector2 = _world_to_screen(sim.position + Vector2(2.22, 0.62).rotated(sim.angle))
	draw_line(nose_a, nose_b, Color("#fff2a8"), 4.0)

	var offsets: Array[Vector2] = sim.get_wheel_offsets()
	for i: int in range(4):
		var steer: float = sim.steering_angle if i < 2 else 0.0
		_draw_wheel(offsets[i], steer)

func _draw_wheel(local_pos: Vector2, steer: float) -> void:
	var centre_world: Vector2 = sim.position + local_pos.rotated(sim.angle)
	var wheel_angle: float = sim.angle + steer
	var half: Vector2 = Vector2(0.34, 0.13)
	var local_points: Array[Vector2] = [
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
		Vector2(-half.x, -half.y)
	]
	var screen_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in local_points:
		screen_points.append(_world_to_screen(centre_world + point.rotated(wheel_angle)))
	draw_colored_polygon(screen_points, Color("#111111"))

func _draw_telemetry() -> void:
	var surface_name: String = "ASPHALT" if sim.last_surface_mu > 0.8 else "GRASS"
	var joy_name: String = "NONE"
	var joypads: Array[int] = Input.get_connected_joypads()
	if not joypads.is_empty():
		joy_name = Input.get_joy_name(joypads[0])

	var lines: Array[String] = [
		"APS RACER // HANDLING BUILD",
		"Car: " + sim.preset_name,
		"Speed: %6.1f km/h" % sim.speed_kph(),
		"Steer: %6.1f deg" % rad_to_deg(sim.steering_angle),
		"Yaw:   %6.1f deg/s" % rad_to_deg(sim.angular_velocity),
		"Long G: %5.2f" % (sim.last_long_accel / 9.81),
		"Lat G:  %5.2f" % (sim.last_lat_accel / 9.81),
		"FL slip: %5.1f deg  grip %3.0f%%" % [sim.wheel_slip_angles[0], sim.wheel_grip_usage[0] * 100.0],
		"FR slip: %5.1f deg  grip %3.0f%%" % [sim.wheel_slip_angles[1], sim.wheel_grip_usage[1] * 100.0],
		"RL slip: %5.1f deg  grip %3.0f%%" % [sim.wheel_slip_angles[2], sim.wheel_grip_usage[2] * 100.0],
		"RR slip: %5.1f deg  grip %3.0f%%" % [sim.wheel_slip_angles[3], sim.wheel_grip_usage[3] * 100.0],
		"Surface: " + surface_name,
		"Impact: %4.0f km/h" % sim.last_impact_kph,
		"Gamepad: " + joy_name,
		"1/2/3 cars | WASD/arrows | Space handbrake | R reset | T tune"
	]
	var font: Font = ThemeDB.fallback_font
	for i: int in range(lines.size()):
		var pos: Vector2 = Vector2(18.0, 30.0 + float(i) * 21.0)
		draw_string(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)

func _draw_touch_controls() -> void:
	var rects: Dictionary = _control_rects()
	_draw_touch_button(Rect2(rects["left"]), "<", _touch_active("left"))
	_draw_touch_button(Rect2(rects["right"]), ">", _touch_active("right"))
	_draw_touch_button(Rect2(rects["brake"]), "BRAKE", _touch_active("brake"))
	_draw_touch_button(Rect2(rects["throttle"]), "GO", _touch_active("throttle"))
	_draw_touch_button(Rect2(rects["handbrake"]), "HANDBRAKE", _touch_active("handbrake"))
	_draw_touch_button(Rect2(rects["tune"]), "TUNE", tuning_panel != null and tuning_panel.is_open())
	_draw_touch_button(Rect2(rects["preset"]), "CAR", false)
	_draw_touch_button(Rect2(rects["reset"]), "RESET", false)

func _draw_touch_button(rect: Rect2, label: String, active: bool) -> void:
	var fill: Color = Color(1.0, 1.0, 1.0, 0.28 if active else 0.14)
	draw_rect(rect, fill, true)
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.55), false, 2.0)
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18)
	var text_pos: Vector2 = rect.position + (rect.size - text_size) * 0.5 + Vector2(0.0, text_size.y * 0.78)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)
