extends Node2D

const SIM_DT: float = 1.0 / 120.0
const MAX_SKID_POINTS: int = 1200
const MAX_SMOKE_PUFFS: int = 90
const SETTINGS_PATH: String = "user://aps_racer_settings.json"

var sim: VehicleSim = VehicleSim.new()
var track: TrackModel = TrackModel.new()
var themes: ThemeSystem = ThemeSystem.new()
var visuals: VisualRenderer = VisualRenderer.new()
var static_world: StaticWorldLayer
var weather_layer: WeatherLayer
var race: RaceSystem = RaceSystem.new(true)
var ai_driver: AIDriver = AIDriver.new()
var ai_race: RaceSystem = RaceSystem.new(false, false)
var accumulator: float = 0.0
var camera_world: Vector2 = Vector2.ZERO
var pixels_per_meter: float = 25.0
var touches: Dictionary = {}
var visual_time: float = 0.0
var telemetry_open: bool = false
var weather_effects_enabled: bool = true
var event_mode: String = "race"
var starter: StarterActor = StarterActor.new()
var haptic_cooldown: float = 0.0

var skid_points: Array[Vector2] = []
var previous_rear: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var has_previous_rear: bool = false
var smoke_positions: Array[Vector2] = []
var smoke_life: Array[float] = []
var smoke_spawn_cooldown: float = 0.0
var tuning_panel: TuningPanel

func _ready() -> void:
	sim.set_preset(0)
	_load_preferences()
	ai_driver.setup(track)
	camera_world = sim.position
	static_world = StaticWorldLayer.new()
	add_child(static_world)
	static_world.setup(visuals, themes, track)
	weather_layer = WeatherLayer.new()
	add_child(weather_layer)
	weather_layer.setup(themes)
	weather_layer.set_effects_enabled(weather_effects_enabled)
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
			_update_track_limits()
			track.resolve_barriers(sim)

			if event_mode == "race":
				ai_driver.step(SIM_DT, ai_race.is_racing(), track, sim)
				_resolve_car_collision()

			if race.is_racing():
				starter.try_hit(sim)
				if event_mode == "race":
					starter.try_hit(ai_driver.sim)
			starter.step(SIM_DT)

			if race.is_racing():
				var dry_line_traffic: Array[Vector2] = []
				if sim.speed_kph() > 8.0:
					dry_line_traffic.append(sim.position)
				if event_mode == "race" and ai_driver.sim.speed_kph() > 8.0:
					dry_line_traffic.append(ai_driver.sim.position)
				if not dry_line_traffic.is_empty():
					track.update_dry_line(SIM_DT, dry_line_traffic)

			race.step(SIM_DT, sim.position, sim.angle, track)
			if event_mode == "race":
				ai_race.step(SIM_DT, ai_driver.sim.position, ai_driver.sim.angle, track)

			_record_tyre_effects(SIM_DT)
			sim.last_impact_kph = move_toward(sim.last_impact_kph, 0.0, SIM_DT * 28.0)
			if event_mode == "race":
				ai_driver.sim.last_impact_kph = move_toward(ai_driver.sim.last_impact_kph, 0.0, SIM_DT * 28.0)
		accumulator -= SIM_DT

	if not panel_open:
		_update_smoke(delta)
		_update_haptics(delta)

	var speed: float = sim.velocity.length()
	var look_ahead: Vector2 = sim.velocity * 0.16
	var camera_target: Vector2 = sim.position + look_ahead
	camera_world = camera_world.lerp(camera_target, 1.0 - exp(-6.0 * delta))
	var zoom_target: float = lerp(29.0, 17.5, clamp(speed / 48.0, 0.0, 1.0))
	pixels_per_meter = lerp(pixels_per_meter, zoom_target, 1.0 - exp(-4.0 * delta))
	if static_world != null:
		static_world.update_camera(camera_world, pixels_per_meter, get_viewport_rect().size)
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
	var ambient_trail: bool = weather_effects_enabled and moving and sim.speed_kph() > 28.0
	var should_spawn: bool = weather_effects_enabled and (slipping_left or slipping_right or ambient_trail)
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

func _update_haptics(delta: float) -> void:
	haptic_cooldown = max(haptic_cooldown - delta, 0.0)
	var joypads: Array[int] = Input.get_connected_joypads()
	if joypads.is_empty():
		return
	var risk: float = sim.grip_risk()
	if risk < 0.52 or haptic_cooldown > 0.0:
		return
	var weak: float = clamp((risk - 0.50) / 0.50, 0.0, 1.0) * 0.55
	var strong: float = clamp((risk - 0.78) / 0.22, 0.0, 1.0) * 0.85
	Input.start_joy_vibration(joypads[0], weak, strong, 0.11)
	haptic_cooldown = 0.075

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
		if event.keycode == KEY_C:
			_cycle_course()
			return
		elif event.keycode == KEY_T or event.keycode == KEY_F1:
			tuning_panel.toggle()
			return
		elif event.keycode == KEY_G:
			_cycle_theme()
			return
		elif event.keycode == KEY_H:
			telemetry_open = not telemetry_open
			queue_redraw()
			return
		elif event.keycode == KEY_V:
			_toggle_weather_effects()
			return
		elif event.keycode == KEY_M:
			_toggle_transmission()
			return
		elif event.keycode == KEY_B:
			_toggle_abs()
			return
		elif event.keycode == KEY_F2:
			_toggle_event_mode()
			return
		elif event.keycode == KEY_F3:
			_cycle_ai_difficulty()
			return
		elif event.keycode == KEY_Q:
			sim.shift_down()
			queue_redraw()
			return
		elif event.keycode == KEY_E:
			sim.shift_up()
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
		elif event.button_index == JOY_BUTTON_Y:
			_toggle_transmission()
		elif event.button_index == JOY_BUTTON_BACK:
			_toggle_weather_effects()
		elif event.button_index == JOY_BUTTON_DPAD_UP:
			_toggle_event_mode()
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			_toggle_abs()
		elif event.button_index == JOY_BUTTON_RIGHT_STICK:
			_cycle_ai_difficulty()
		elif event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			sim.shift_down()
			queue_redraw()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			sim.shift_up()
			queue_redraw()

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
			elif Rect2(rects["course"]).has_point(event.position):
				_cycle_course()
			elif Rect2(rects["data"]).has_point(event.position):
				telemetry_open = not telemetry_open
				queue_redraw()
			elif Rect2(rects["weather"]).has_point(event.position):
				_toggle_weather_effects()
			elif Rect2(rects["mode"]).has_point(event.position):
				_toggle_event_mode()
			elif Rect2(rects["difficulty"]).has_point(event.position):
				_cycle_ai_difficulty()
			elif Rect2(rects["abs"]).has_point(event.position):
				_toggle_abs()
			elif Rect2(rects["transmission"]).has_point(event.position):
				_toggle_transmission()
			elif Rect2(rects["shift_down"]).has_point(event.position):
				sim.shift_down()
				queue_redraw()
			elif Rect2(rects["shift_up"]).has_point(event.position):
				sim.shift_up()
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

func _toggle_weather_effects() -> void:
	weather_effects_enabled = not weather_effects_enabled
	smoke_positions.clear()
	smoke_life.clear()
	if weather_layer != null:
		weather_layer.set_effects_enabled(weather_effects_enabled)
	_save_preferences()
	queue_redraw()

func _toggle_transmission() -> void:
	sim.toggle_manual_transmission()
	_save_preferences()
	queue_redraw()

func _toggle_abs() -> void:
	sim.toggle_abs()
	_save_preferences()
	queue_redraw()

func _toggle_event_mode() -> void:
	event_mode = "time_trial" if event_mode == "race" else "race"
	_save_preferences()
	_start_event()
	queue_redraw()

func _cycle_ai_difficulty() -> void:
	ai_driver.cycle_difficulty(1)
	_save_preferences()
	_start_event()
	queue_redraw()

func _load_preferences() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		weather_effects_enabled = bool(parsed.get("weather_effects", true))
		sim.set_manual_transmission(bool(parsed.get("manual_transmission", false)))
		sim.set_abs_enabled(bool(parsed.get("abs_enabled", true)))
		event_mode = String(parsed.get("event_mode", "race"))
		if event_mode != "time_trial":
			event_mode = "race"
		ai_driver.set_difficulty(int(parsed.get("ai_difficulty", 1)))

func _save_preferences() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"weather_effects": weather_effects_enabled,
		"manual_transmission": sim.transmission_manual,
		"abs_enabled": sim.abs_enabled,
		"event_mode": event_mode,
		"ai_difficulty": ai_driver.difficulty_index
	}, "\t"))

func _cycle_theme() -> void:
	themes.cycle(1)
	_apply_theme()
	_start_event()
	queue_redraw()

func _race_key() -> String:
	var base: String = "%s::%s::car_%d" % [track.course_id(), themes.id(), sim.preset_index]
	return base + "::time_trial" if event_mode == "time_trial" else base

func _start_event() -> void:
	sim.reset()
	track.reset_dry_line()
	var player_pose: Dictionary = track.player_grid_pose()
	sim.position = Vector2(player_pose["position"])
	sim.angle = float(player_pose["angle"])
	sim.velocity = Vector2.ZERO
	sim.angular_velocity = 0.0

	ai_driver.restart(track)
	starter.restart(track)

	var time_trial: bool = event_mode == "time_trial"
	race.configure(_race_key(), 1 if time_trial else 3, time_trial)
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

func _update_track_limits() -> void:
	if race.is_racing() and track.off_track_wheel_count(sim) > 2:
		race.invalidate_current_lap("TRACK LIMITS")

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

func _cycle_course() -> void:
	track.cycle_course(1)
	_apply_theme()
	_start_event()
	queue_redraw()

func _apply_theme() -> void:
	track.set_surface_profile(
		float(themes.value("road_mu", 1.0)),
		float(themes.value("runoff_mu", 0.43))
	)
	track.set_wet_surface(
		themes.id() == "brisbane_neon_rain" and track.course_id() != "airfield",
		float(themes.value("dry_road_mu", 1.12))
	)
	if tuning_panel != null:
		tuning_panel.apply_skin(themes.current())
	if static_world != null:
		static_world.refresh_theme()
	if weather_layer != null:
		weather_layer.refresh_theme()
		weather_layer.set_effects_enabled(weather_effects_enabled)

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
		"theme": Rect2(Vector2(view.x - 562.0, 20.0), top_button),
		"course": Rect2(Vector2(view.x - 470.0, 20.0), top_button),
		"data": Rect2(Vector2(view.x - 378.0, 20.0), top_button),
		"tune": Rect2(Vector2(view.x - 286.0, 20.0), top_button),
		"preset": Rect2(Vector2(view.x - 194.0, 20.0), top_button),
		"reset": Rect2(Vector2(view.x - 102.0, 20.0), top_button),
		"difficulty": Rect2(Vector2(view.x - 654.0, 72.0), top_button),
		"mode": Rect2(Vector2(view.x - 562.0, 72.0), top_button),
		"abs": Rect2(Vector2(view.x - 470.0, 72.0), top_button),
		"shift_down": Rect2(Vector2(view.x - 378.0, 72.0), top_button),
		"shift_up": Rect2(Vector2(view.x - 286.0, 72.0), top_button),
		"transmission": Rect2(Vector2(view.x - 194.0, 72.0), top_button),
		"weather": Rect2(Vector2(view.x - 102.0, 72.0), top_button)
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
	visuals.draw_race_guidance(
		self,
		themes,
		track,
		race,
		Callable(self, "_world_to_screen"),
		pixels_per_meter,
		visual_time
	)
	visuals.draw_dynamic_dry_line(
		self,
		themes,
		track,
		Callable(self, "_world_to_screen"),
		pixels_per_meter
	)
	visuals.draw_skid_marks(
		self,
		themes,
		skid_points,
		Callable(self, "_world_to_screen"),
		pixels_per_meter
	)
	if weather_effects_enabled:
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
	if starter.state == "line":
		visuals.draw_starter_actor(
			self,
			themes,
			starter,
			Callable(self, "_world_to_screen"),
			pixels_per_meter
		)
	if event_mode == "race":
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
	if starter.state != "line":
		visuals.draw_starter_actor(
			self,
			themes,
			starter,
			Callable(self, "_world_to_screen"),
			pixels_per_meter
		)

	var surface_name: String
	if track.course_id() == "airfield":
		surface_name = "TARMAC" if track.is_on_road(sim.position) else "GRASS"
	else:
		surface_name = String(themes.value("surface_name", "ROAD"))
		if not track.is_on_road(sim.position):
			surface_name = String(themes.value("runoff_name", "RUNOFF"))
		elif track.wet_surface and sim.last_surface_mu > float(themes.value("road_mu", 1.0)) + 0.025:
			surface_name = "DRYING LINE"

	var joy_name: String = "NONE"
	var joypads: Array[int] = Input.get_connected_joypads()
	if not joypads.is_empty():
		joy_name = Input.get_joy_name(joypads[0])

	visuals.draw_hud(self, themes, sim, surface_name, telemetry_open, joy_name)
	visuals.draw_race_hud(
		self,
		themes,
		race,
		_player_position_rank() if event_mode == "race" else 1,
		ai_race,
		event_mode == "time_trial",
		ai_driver.difficulty_name(),
		ai_driver.racecraft_state
	)

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
	visuals.draw_touch_controls(
		self,
		themes,
		rects,
		active,
		show_touch,
		track.course_name(),
		weather_effects_enabled,
		sim.transmission_manual,
		sim.gear_label(),
		event_mode == "time_trial",
		sim.abs_enabled,
		ai_driver.difficulty_name()
	)
	visuals.draw_starter_intro(self, themes, starter, race, get_viewport_rect().size)
