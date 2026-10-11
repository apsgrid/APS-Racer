extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	print("=== APS RACER RACE TESTS ===")
	_test_checkpoint_order_and_laps()
	_test_ghost_playback()
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

func _test_ai_driver() -> void:
	var track: TrackModel = TrackModel.new()
	track.set_surface_profile(0.88, 0.56)
	var ai: AIDriver = AIDriver.new()
	ai.setup()
	var ai_race: RaceSystem = RaceSystem.new(false)
	ai_race.configure("ai-test", 3)
	ai_race.restart()
	var on_road_samples: int = 0
	var samples: int = 0
	var dt: float = 1.0 / 120.0

	for i: int in range(120 * 60):
		ai.step(dt, ai_race.is_racing(), track)
		ai_race.step(dt, ai.sim.position, ai.sim.angle, track)
		if i % 30 == 0:
			samples += 1
			if track.is_on_road(ai.sim.position):
				on_road_samples += 1
		if ai_race.is_finished():
			break

	var ratio: float = float(on_road_samples) / float(max(samples, 1))
	_assert(ai_race.is_finished(), "AI failed to complete the three-lap event.")
	_assert(ai_race.finish_time < 55.0, "AI completed the event too slowly for the baseline.")
	_assert(ratio > 0.75, "AI spent too much of the test off road.")
	print("AI race | finish %s | on-road %.0f%% | speed %.1f km/h" % [ai_race.format_time(ai_race.finish_time), ratio * 100.0, ai.sim.speed_kph()])
