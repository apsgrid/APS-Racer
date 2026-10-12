extends SceneTree

const DT: float = 1.0 / 120.0

func _init() -> void:
	var failures: int = 0
	print("=== APS RACER HANDLING TESTS ===")
	for preset: int in range(3):
		var accel: Dictionary = _test_acceleration(preset)
		var braking: Dictionary = _test_braking(preset)
		var cornering: Dictionary = _test_cornering(preset)
		print("%s | 0-100 %.2fs | 100-0 %.1fm / %.2fs | corner peak %.2fg avg %.2fg" % [
			String(accel["name"]),
			float(accel["time"]),
			float(braking["distance"]),
			float(braking["time"]),
			float(cornering["peak_g"]),
			float(cornering["avg_g"])
		])
		if not bool(accel["pass"]):
			failures += 1
		if not bool(braking["pass"]):
			failures += 1
		if not bool(cornering["pass"]):
			failures += 1

	var drivetrain: Dictionary = _test_reverse_and_manual()
	print("Reverse %.1f km/h | manual G1 %.1f -> G2 %.1f km/h" % [
		float(drivetrain["reverse_kph"]),
		float(drivetrain["gear1_kph"]),
		float(drivetrain["gear2_kph"])
	])
	if not bool(drivetrain["pass"]):
		failures += 1

	if failures == 0:
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL (%d checks)" % failures)
		quit(1)

func _surface(_point: Vector2) -> float:
	return 1.0

func _test_acceleration(preset: int) -> Dictionary:
	var car: VehicleSim = VehicleSim.new()
	car.set_preset(preset)
	car.position = Vector2.ZERO
	var elapsed: float = 0.0
	while car.speed_kph() < 100.0 and elapsed < 15.0:
		car.step(DT, 1.0, 0.0, 0.0, false, _surface)
		elapsed += DT
	var passed: bool = car.speed_kph() >= 100.0 and elapsed > 2.0 and elapsed < 12.0
	return {"name": car.preset_name, "time": elapsed, "pass": passed}

func _test_braking(preset: int) -> Dictionary:
	var car: VehicleSim = VehicleSim.new()
	car.set_preset(preset)
	car.position = Vector2.ZERO
	car.velocity = Vector2(100.0 / 3.6, 0.0)
	var start: Vector2 = car.position
	var elapsed: float = 0.0
	while car.speed_kph() > 1.0 and elapsed < 8.0:
		car.step(DT, 0.0, 1.0, 0.0, false, _surface)
		elapsed += DT
	var distance: float = car.position.distance_to(start)
	var passed: bool = distance > 20.0 and distance < 80.0 and elapsed < 6.0
	return {"distance": distance, "time": elapsed, "pass": passed}

func _test_cornering(preset: int) -> Dictionary:
	var car: VehicleSim = VehicleSim.new()
	car.set_preset(preset)
	car.position = Vector2.ZERO
	car.velocity = Vector2(60.0 / 3.6, 0.0)
	var elapsed: float = 0.0
	var peak_g: float = 0.0
	var sum_g: float = 0.0
	var samples: int = 0
	while elapsed < 5.0:
		car.step(DT, 0.28, 0.0, 0.42, false, _surface)
		elapsed += DT
		if elapsed > 1.0:
			var lateral_g: float = abs(car.last_lat_accel / 9.81)
			peak_g = max(peak_g, lateral_g)
			sum_g += lateral_g
			samples += 1
	var average_g: float = sum_g / float(max(samples, 1))
	var passed: bool = peak_g > 0.25 and peak_g < 1.8 and average_g > 0.12
	return {"peak_g": peak_g, "avg_g": average_g, "pass": passed}

func _test_reverse_and_manual() -> Dictionary:
	var reverse_car: VehicleSim = VehicleSim.new()
	reverse_car.set_preset(0)
	reverse_car.position = Vector2.ZERO
	var reverse_elapsed: float = 0.0
	while reverse_elapsed < 4.0:
		reverse_car.step(DT, 0.0, 1.0, 0.0, false, _surface)
		reverse_elapsed += DT
	var reverse_kph: float = reverse_car.speed_kph()

	var manual_car: VehicleSim = VehicleSim.new()
	manual_car.set_preset(0)
	manual_car.set_manual_transmission(true)
	manual_car.position = Vector2.ZERO
	var elapsed: float = 0.0
	while elapsed < 8.0:
		manual_car.step(DT, 1.0, 0.0, 0.0, false, _surface)
		elapsed += DT
	var gear1_kph: float = manual_car.speed_kph()
	manual_car.shift_up()
	elapsed = 0.0
	while elapsed < 5.0:
		manual_car.step(DT, 1.0, 0.0, 0.0, false, _surface)
		elapsed += DT
	var gear2_kph: float = manual_car.speed_kph()

	var passed: bool = (
		reverse_kph > 25.0 and reverse_kph < 52.0
		and gear1_kph > 45.0 and gear1_kph < 64.0
		and gear2_kph > gear1_kph + 15.0
		and gear2_kph < 100.0
	)
	return {
		"reverse_kph": reverse_kph,
		"gear1_kph": gear1_kph,
		"gear2_kph": gear2_kph,
		"pass": passed
	}
