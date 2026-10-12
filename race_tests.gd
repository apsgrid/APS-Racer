extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	print("=== APS RACER RACE TESTS ===")
	_test_checkpoint_order_and_laps()
	_test_ghost_playback()
	_test_ghost_memory_cap()
	_test_time_trial_void_lap()
	_test_track_limit_wheel_count()
	_test_dynamic_dry_line()
	_test_ai_driver()

	if failures.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("FAIL: ", failure)
		print("RESULT: FAIL (%d)" % failures.size())
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _test_checkpoint_order_and_laps() -> void:
	var track: TrackModel = TrackModel.new()
	var race: RaceSystem = RaceSystem.new(false)
	race.configure("test", 3)
	race.restart()

	race.step(3.30, Vector2(-3.0, 15.0), 0.0, track)
	_assert(race.state == "racing", "Countdown did not transition to racing.")
	_assert(race.next_checkpoint == 1, "Race did not start expecting checkpoint 1.")

	race.step(0.50, Vector2(0.0, -16.0), PI, track)
	_assert(race.next_checkpoint == 1, "Out-of-order checkpoint was incorrectly accepted.")
	race.step(0.25, Vector2(30.0, 0.0), PI * 0.5, track)
	_assert(race.next_checkpoint == 1, "Checkpoint crossed in the wrong direction was accepted.")

	race.restart()
	race.step(3.30, Vector2(-3.0, 15.0), 0.0, track)
	var lap_durations: Array[float] = [4.0, 4.8, 5.2]
	for lap_index: int in range(3):
		var sector: float = lap_durations[lap_index] / 4.0
		race.step(sector, Vector2(30.0, 0.0), -PI * 0.5, track)
		_assert(race.next_checkpoint == 2, "Lap %d did not accept checkpoint 1." % (lap_index + 1))
		race.step(sector, Vector2(0.0, -16.0), PI, track)
		_assert(race.next_checkpoint == 3, "Lap %d did not accept checkpoint 2." % (lap_index + 1))
		race.step(sector, Vector2(-30.0, 0.0), PI * 0.5, track)
		_assert(race.next_checkpoint == 0, "Lap %d did not accept checkpoint 3." % (lap_index + 1))
		race.step(sector, Vector2(0.0, 16.0), 0.0, track)

		if lap_index < 2:
			_assert(race.current_lap == lap_index + 2, "Lap counter did not advance.")
			_assert(race.next_checkpoint == 1, "Next lap did not reset checkpoint sequence.")

	_assert(race.state == "finished", "Three-lap event did not finish.")
	_assert(abs(race.best_lap_time - 4.0) < 0.02, "Best lap was not retained.")
	_assert(race.best_ghost.size() >= 4, "Best-lap ghost was not captured.")
	_assert(race.best_sector_times[0] > 0.0, "Sector bests were not recorded.")
	print("Race flow | best ", race.format_time(race.best_lap_time), " | ghost frames ", race.best_ghost.size())

func _test_ghost_playback() -> void:
	var track: TrackModel = TrackModel.new()
	var race: RaceSystem = RaceSystem.new(false)
	race.configure("ghost", 1)
	race.restart()
	race.step(3.30, Vector2(-3.0, 15.0), 0.0, track)
	race.step(1.0, Vector2(30.0, 0.0), -PI * 0.5, track)
	race.step(1.0, Vector2(0.0, -16.0), PI, track)
	race.step(1.0, Vector2(-30.0, 0.0), PI * 0.5, track)
	race.step(1.0, Vector2(0.0, 16.0), 0.0, track)

	var saved: Array = race.best_ghost.duplicate(true)
	var best: float = race.best_lap_time
	race.restart()
	race.best_ghost = saved
	race.best_lap_time = best
	race.step(3.30, Vector2(-3.0, 15.0), 0.0, track)
	race.step(1.5, Vector2(15.0, 16.0), 0.0, track)
	var ghost: Dictionary = race.ghost_transform()
	_assert(not ghost.is_empty(), "Ghost transform was empty during a timed lap.")
	_assert(ghost.has("position"), "Ghost transform has no position.")
	print("Ghost playback | transform available=", not ghost.is_empty())

func _test_ghost_memory_cap() -> void:
	var track: TrackModel = TrackModel.new()
	var race: RaceSystem = RaceSystem.new(false, true)
	race.configure("memory-cap", 1)
	race.restart()
	race.step(3.30, Vector2(-3.0, 15.0), 0.0, track)

	var dt: float = 1.0 / 30.0
	for i: int in range(RaceSystem.MAX_GHOST_SAMPLES + 600):
		race.step(dt, Vector2(-3.0, 15.0), 0.0, track)

	_assert(race.current_ghost.size() <= RaceSystem.MAX_GHOST_SAMPLES, "Ghost buffer exceeded its hard cap.")
	_assert(race.ghost_overflowed, "Ghost overflow flag was not set after reaching the cap.")
	print("Ghost memory cap | frames ", race.current_ghost.size(), " / ", RaceSystem.MAX_GHOST_SAMPLES)

func _test_dynamic_dry_line() -> void:
	var track: TrackModel = TrackModel.new()
	track.set_course(0)
	track.set_surface_profile(0.96, 0.43)
	track.set_wet_surface(true, 1.16)
	var line: Array[Vector2] = track.racing_line_points()
	var sample: Vector2 = line[0]
	var wet_mu: float = track.surface_mu(sample)
	var traffic: Array[Vector2] = [sample]
	for i: int in range(900):
		track.update_dry_line(1.0 / 120.0, traffic)
	var dry_mu: float = track.surface_mu(sample)
	_assert(dry_mu > wet_mu + 0.10, "Dynamic dry line did not gain meaningful grip.")
	_assert(track.dry_line_average() > 0.01, "Dynamic dry line did not retain traffic state.")
	print("Dry line | wet %.3f -> trafficked %.3f | average %.1f%%" % [wet_mu, dry_mu, track.dry_line_average() * 100.0])

func _test_ai_driver() -> void:
	_run_ai_course(0, 60.0, 0.75)
	_run_ai_course(1, 105.0, 0.70)
	_run_ai_course(2, 85.0, 0.76)

func _run_ai_course(course_index: int, max_time: float, minimum_on_road: float) -> void:
	var track: TrackModel = TrackModel.new()
	track.set_course(course_index)
	track.set_surface_profile(0.88, 0.56)
	var ai: AIDriver = AIDriver.new()
	ai.setup(track)
	var ai_race: RaceSystem = RaceSystem.new(false, false)
	ai_race.configure("ai-test-" + track.course_id(), 3)
	ai_race.restart()
	var on_road_samples: int = 0
	var samples: int = 0
	var dt: float = 1.0 / 120.0
	var max_steps: int = int(120.0 * max_time)

	for i: int in range(max_steps):
		ai.step(dt, ai_race.is_racing(), track)
		ai_race.step(dt, ai.sim.position, ai.sim.angle, track)
		if i % 30 == 0:
			samples += 1
			if track.is_on_road(ai.sim.position):
				on_road_samples += 1
		if ai_race.is_finished():
			break

	var ratio: float = float(on_road_samples) / float(max(samples, 1))
	_assert(ai_race.is_finished(), "AI failed to complete %s three-lap event." % track.course_name())
	_assert(ai_race.finish_time < max_time, "AI completed %s too slowly for the baseline." % track.course_name())
	_assert(ratio > minimum_on_road, "AI spent too much of %s off road." % track.course_name())
	print("AI %s | finish %s | on-road %.0f%% | speed %.1f km/h" % [track.course_name(), ai_race.format_time(ai_race.finish_time), ratio * 100.0, ai.sim.speed_kph()])

func _test_time_trial_void_lap() -> void:
	var track: TrackModel = TrackModel.new()
	var race: RaceSystem = RaceSystem.new(false, true)
	race.configure("tt-test", 1, true)
	race.restart()
	race.step(3.30, Vector2(-3.0, 15.0), 0.0, track)

	# First lap is valid and should establish the ghost/best.
	for gate in [
		[1.0, Vector2(30.0, 0.0), -PI * 0.5],
		[1.0, Vector2(0.0, -16.0), PI],
		[1.0, Vector2(-30.0, 0.0), PI * 0.5],
		[1.0, Vector2(0.0, 16.0), 0.0]
	]:
		race.step(float(gate[0]), Vector2(gate[1]), float(gate[2]), track)
	var valid_best: float = race.best_lap_time
	var valid_ghost_size: int = race.best_ghost.size()
	_assert(race.state == "racing", "Time Trial should continue after completing a lap.")
	_assert(race.current_lap == 2, "Time Trial did not advance to lap 2.")
	_assert(valid_best > 0.0, "Time Trial valid lap did not set a best time.")
	_assert(valid_ghost_size > 1, "Time Trial valid lap did not set a ghost.")

	# Second lap is faster but invalid, so it must not replace the record or ghost.
	race.invalidate_current_lap("TRACK LIMITS")
	for gate in [
		[0.7, Vector2(30.0, 0.0), -PI * 0.5],
		[0.7, Vector2(0.0, -16.0), PI],
		[0.7, Vector2(-30.0, 0.0), PI * 0.5],
		[0.7, Vector2(0.0, 16.0), 0.0]
	]:
		race.step(float(gate[0]), Vector2(gate[1]), float(gate[2]), track)
	_assert(race.state == "racing", "Time Trial incorrectly finished after a void lap.")
	_assert(race.current_lap == 3, "Time Trial did not continue after a void lap.")
	_assert(not race.last_lap_valid, "Void lap was not marked invalid.")
	_assert(abs(race.best_lap_time - valid_best) < 0.001, "Void lap overwrote the Time Trial best.")
	_assert(race.best_ghost.size() == valid_ghost_size, "Void lap overwrote the Time Trial ghost.")
	print("Time Trial | valid best %s | void lap %s | ghost retained %d" % [
		race.format_time(valid_best),
		race.format_time(race.last_lap_time),
		race.best_ghost.size()
	])

func _test_track_limit_wheel_count() -> void:
	var track: TrackModel = TrackModel.new()
	var car: VehicleSim = VehicleSim.new()
	car.set_preset(0)
	car.angle = 0.0

	var saw_two: bool = false
	var saw_three_or_more: bool = false
	var trigger_y: float = 0.0
	for step: int in range(0, 100):
		car.position = Vector2(0.0, 15.0 + float(step) * 0.10)
		var off: int = track.off_track_wheel_count(car)
		if off == 2:
			saw_two = true
		if off > 2:
			saw_three_or_more = true
			trigger_y = car.position.y
			break
	_assert(saw_two, "Track-limit scan never observed exactly two wheels off.")
	_assert(saw_three_or_more, "Track-limit scan never observed more than two wheels off.")
	print("Track limits | 2 wheels allowed | void threshold reached near y=%.2f" % trigger_y)
