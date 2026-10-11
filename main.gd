extends Node2D

const SIM_DT: float = 1.0 / 120.0
const MAX_SKID_POINTS: int = 1200
const MAX_SMOKE_PUFFS: int = 90

var sim: VehicleSim = VehicleSim.new()
var track: TrackModel = TrackModel.new()
var themes: ThemeSystem = ThemeSystem.new()
var visuals: VisualRenderer = VisualRenderer.new()
var race: RaceSystem = RaceSystem.new(true)
var ai_driver: AIDriver = AIDriver.new()
var ai_race: RaceSystem = RaceSystem.new(false)
var accumulator: float = 0.0
var camera_world: Vector2 = Vector2.ZERO
var pixels_per_meter: float = 25.0
var touches: Dictionary = {}
var visual_time: float = 0.0
var telemetry_open: bool = false

var skid_points: Array[Vector2] = []
var previous_rear: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var has_previous_rear: bool = false
var smoke_positions: Array[Vector2] = []
var smoke_life: Array[float] = []
var smoke_spawn_cooldown: float = 0.0
var tuning_panel: TuningPanel

func _ready() -> void:
	sim.set_preset(0)
	ai_driver.setup()
	camera_world = sim.position
	tuning_panel = TuningPanel.new()
	add_child(tuning_panel)
	tuning_panel.setup(sim)
	tuning_panel.car_selected.connect(_on_tuning_car_selected)
	_apply_theme()
	_start_event()
	set_process_input(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	visual_time += delta
	var panel_open: bool = tuning_panel != null and tuning_panel.is_open()
	race.set_paused(panel_open)
	ai_race.set_paused(panel_open)
	var controls: Dictionary = _read_controls()
	accumulator = min(accumulator + delta, 0.25)

	while accumulator >= SIM_DT:
		if not panel_open:
			sim.step(
				SIM_DT,
				float(controls["throttle"]),
				float(controls["brake"]),
				float(controls["steer"]),
				bool(controls["handbrake"]),
				track.surface_mu
			)
			track.resolve_barriers(sim)

			ai_driver.step(SIM_DT, ai_race.is_racing(), track)
			_resolve_car_collision()

			race.step(SIM_DT, sim.position, sim.angle, track)
			ai_race.step(SIM_DT, ai_driver.sim.position, ai_driver.sim.angle, track)

			_record_tyre_effects(SIM_DT)
			sim.last_impact_kph = move_toward(sim.last_impact_kph, 0.0, SIM_DT * 28.0)
			ai_driver.sim.last_impact_kph = move_toward(ai_driver.sim.last_impact_kph, 0.0, SIM_DT * 28.0)
		accumulator -= SIM_DT

	if not panel_open:
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
	var ambient_trail: bool = moving and sim.speed_kph() > 28.0
	var should_spawn: bool = slipping_left or slipping_right or ambient_trail
	if moving and smoke_spawn_cooldown <= 0.0 and should_spawn:
		smoke_positions.append((rear_left + rear_right) * 0.5)
		smoke_life.append(0.72)
		var base_interval: float = 0.10 if themes.effect_mode() == "dust" else 0.075
		smoke_spawn_cooldown = 0.045 if (slipping_left or slipping_right) else base_interval
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
	if race.controls_locked():
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
		elif event.keycode == KEY_G:
			_cycle_theme()
			return
		elif event.keycode == KEY_H:
			telemetry_open = not telemetry_open
			queue_redraw()
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
			elif Rect2(rects["theme"]).has_point(event.position):
				_cycle_theme()
			elif Rect2(rects["data"]).has_point(event.position):
				telemetry_open = not telemetry_open
				queue_redraw()
		else:
			touches.erase(event.index)

	if event is InputEventScreenDrag:
		touches[event.index] = event.position

func _reset_car() -> void:
	_start_event()

func _select_preset(index: int) -> void:
	sim.set_preset(index)
	if tuning_panel != null:
		tuning_panel.sync_from_sim()
	_start_event()

func _on_tuning_car_selected(index: int) -> void:
	_select_preset(index)

func _cycle_theme() -> void:
	themes.cycle(1)
	_apply_theme()
	_start_event()
	queue_redraw()

func _race_key() -> String:
	return "%s::car_%d" % [themes.id(), sim.preset_index]

func _start_event() -> void:
	sim.reset()
	sim.position = Vector2(-3.2, 14.6)
	sim.angle = 0.0
	sim.velocity = Vector2.ZERO
	sim.angular_velocity = 0.0

	ai_driver.restart()

	race.configure(_race_key(), 3)
	race.restart()
	ai_race.configure("ai", 3)
	ai_race.restart()

	camera_world = sim.position
	accumulator = 0.0
	has_previous_rear = false
	skid_points.clear()
	smoke_positions.clear()
	smoke_life.clear()
	smoke_spawn_cooldown = 0.0

func _resolve_car_collision() -> void:
	var other: VehicleSim = ai_driver.sim
	var delta: Vector2 = other.position - sim.position
	var distance: float = delta.length()
	var min_distance: float = 2.35
	if distance <= 0.001 or distance >= min_distance:
		return

	var normal: Vector2 = delta / distance
	var penetration: float = min_distance - distance
	sim.position -= normal * penetration * 0.5
	other.position += normal * penetration * 0.5

	var relative_velocity: Vector2 = other.velocity - sim.velocity
	var separating_speed: float = relative_velocity.dot(normal)
	if separating_speed >= 0.0:
		return

	var impulse: float = -separating_speed * 0.42
	sim.velocity -= normal * impulse
	other.velocity += normal * impulse
	sim.angular_velocity *= 0.82
	other.angular_velocity *= 0.82
	var impact_kph: float = abs(separating_speed) * 3.6
	sim.last_impact_kph = max(sim.last_impact_kph, impact_kph)
	other.last_impact_kph = max(other.last_impact_kph, impact_kph)

func _player_position_rank() -> int:
	var player_score: float = race.progress_score(sim.position, track)
	var ai_score: float = ai_race.progress_score(ai_driver.sim.position, track)
	return 1 if player_score >= ai_score else 2

func _apply_theme() -> void:
	track.set_surface_profile(
		float(themes.value("road_mu", 1.0)),
		float(themes.value("runoff_mu", 0.43))
	)
	if tuning_panel != null:
		tuning_panel.apply_skin(themes.current())

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
	var drive_button: Vector2 = Vector2(104.0, 104.0)
	var top_button: Vector2 = Vector2(84.0, 44.0)
	return {
		"left": Rect2(Vector2(28.0, view.y - 132.0), drive_button),
		"right": Rect2(Vector2(146.0, view.y - 132.0), drive_button),
		"brake": Rect2(Vector2(view.x - 258.0, view.y - 132.0), Vector2(104.0, 104.0)),
		"throttle": Rect2(Vector2(view.x - 140.0, view.y - 132.0), Vector2(104.0, 104.0)),
		"handbrake": Rect2(Vector2(view.x - 230.0, view.y - 214.0), Vector2(194.0, 58.0)),
		"theme": Rect2(Vector2(view.x - 470.0, 20.0), top_button),
		"data": Rect2(Vector2(view.x - 378.0, 20.0), top_button),
		"tune": Rect2(Vector2(view.x - 286.0, 20.0), top_button),
		"preset": Rect2(Vector2(view.x - 194.0, 20.0), top_button),
		"reset": Rect2(Vector2(view.x - 102.0, 20.0), top_button)
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
	visuals.draw_world(
		self,
		themes,
		track,
		Callable(self, "_world_to_screen"),
		Callable(self, "_world_points_to_screen"),
		pixels_per_meter,
		visual_time
	)
	visuals.draw_race_guidance(
		self,
		themes,
		track,
		race,
		Callable(self, "_world_to_screen"),
		pixels_per_meter,
		visual_time
	)
	visuals.draw_skid_marks(
		self,
		themes,
		skid_points,
		Callable(self, "_world_to_screen"),
		pixels_per_meter
	)
	visuals.draw_tyre_effects(
		self,
		themes,
		smoke_positions,
		smoke_life,
		Callable(self, "_world_to_screen"),
		pixels_per_meter
	)
	visuals.draw_ghost_car(
		self,
		themes,
		race.ghost_transform(),
		Callable(self, "_world_to_screen"),
		pixels_per_meter
	)
	visuals.draw_car(
		self,
		themes,
		ai_driver.sim,
		Callable(self, "_world_to_screen"),
		pixels_per_meter
	)
	visuals.draw_rival_marker(
		self,
		themes,
		ai_driver.sim.position,
		Callable(self, "_world_to_screen"),
		pixels_per_meter
	)
	visuals.draw_car(
		self,
		themes,
		sim,
		Callable(self, "_world_to_screen"),
		pixels_per_meter
	)

	var surface_name: String = String(themes.value("surface_name", "ROAD"))
	if not track.is_on_road(sim.position):
		surface_name = String(themes.value("runoff_name", "RUNOFF"))

	var joy_name: String = "NONE"
	var joypads: Array[int] = Input.get_connected_joypads()
	if not joypads.is_empty():
		joy_name = Input.get_joy_name(joypads[0])

	visuals.draw_hud(self, themes, sim, surface_name, telemetry_open, joy_name)
	visuals.draw_race_hud(self, themes, race, _player_position_rank(), ai_race)

	var rects: Dictionary = _control_rects()
	var active: Dictionary = {
		"left": _touch_active("left"),
		"right": _touch_active("right"),
		"brake": _touch_active("brake"),
		"throttle": _touch_active("throttle"),
		"handbrake": _touch_active("handbrake"),
		"data": telemetry_open,
		"tune": tuning_panel != null and tuning_panel.is_open()
	}
	var show_touch: bool = OS.has_feature("web") or OS.has_feature("android") or DisplayServer.is_touchscreen_available()
	visuals.draw_touch_controls(self, themes, rects, active, show_touch)
