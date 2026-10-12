class_name VisualRenderer
extends RefCounted


var _vehicle_texture_cache: Dictionary = {}
var _asset_texture_cache: Dictionary = {}

func _asset_texture(path: String) -> Texture2D:
	if _asset_texture_cache.has(path):
		return _asset_texture_cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_asset_texture_cache[path] = texture
	return texture

func _ui_icon_texture(icon_id: String) -> Texture2D:
	return _asset_texture("res://art/export/shared/ui/ui_icon_%s.svg" % icon_id)

func _draw_world_asset(
	canvas: CanvasItem,
	path: String,
	world_pos: Vector2,
	world_to_screen: Callable,
	ppm: float,
	world_size: Vector2,
	rotation: float = 0.0,
	modulate: Color = Color.WHITE
) -> void:
	var texture: Texture2D = _asset_texture(path)
	if texture == null:
		return
	var centre: Vector2 = world_to_screen.call(world_pos)
	var size_px: Vector2 = world_size * ppm
	canvas.draw_set_transform(centre, rotation, Vector2.ONE)
	canvas.draw_texture_rect(texture, Rect2(-size_px * 0.5, size_px), false, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_tiled_world_texture(
	canvas: CanvasItem,
	path: String,
	world_rect: Rect2,
	world_to_screen: Callable,
	modulate: Color
) -> void:
	var texture: Texture2D = _asset_texture(path)
	if texture == null:
		return
	var a: Vector2 = world_to_screen.call(world_rect.position)
	var b: Vector2 = world_to_screen.call(world_rect.position + world_rect.size)
	canvas.draw_texture_rect(texture, Rect2(a, b - a), true, modulate)

func _vehicle_asset_id(theme_id: String, preset_index: int) -> String:
	if theme_id == "red_dirt":
		match preset_index:
			1: return "baja_compact"
			2: return "monster_4x4"
			_: return "desert_prerunner"
	match preset_index:
		1: return "neon_hot_hatch"
		2: return "neon_xc90_p2"
		_: return "neon_gt"

func _vehicle_texture(theme_id: String, preset_index: int) -> Texture2D:
	var asset_id: String = _vehicle_asset_id(theme_id, preset_index)
	var key: String = theme_id + ":" + asset_id
	if _vehicle_texture_cache.has(key):
		return _vehicle_texture_cache[key]
	var path: String = "res://art/export/vehicles/%s/%s/%s_composite.png" % [theme_id, asset_id, asset_id]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_vehicle_texture_cache[key] = texture
	return texture

func _vehicle_sprite_square_m(theme_id: String, preset_index: int) -> float:
	if theme_id == "red_dirt":
		if preset_index == 2:
			return 6.10
		if preset_index == 1:
			return 5.45
		return 5.85
	if preset_index == 2:
		return 5.95
	if preset_index == 1:
		return 5.20
	return 5.55

func _draw_asset_car(
	canvas: CanvasItem,
	theme: ThemeSystem,
	sim: VehicleSim,
	world_to_screen: Callable,
	ppm: float,
	texture: Texture2D
) -> void:
	var screen_pos: Vector2 = world_to_screen.call(sim.position)
	var square_px: float = ppm * _vehicle_sprite_square_m(theme.id(), sim.preset_index)

	var shadow: Color = theme.colour("car_shadow")
	shadow.a = 0.38
	canvas.draw_set_transform(
		screen_pos + Vector2(ppm * 0.14, ppm * 0.17),
		sim.angle,
		Vector2(1.0, 0.46)
	)
	canvas.draw_circle(Vector2.ZERO, square_px * 0.34, shadow)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	canvas.draw_set_transform(screen_pos, sim.angle + PI * 0.5, Vector2.ONE)
	canvas.draw_texture_rect(
		texture,
		Rect2(Vector2(-square_px * 0.5, -square_px * 0.5), Vector2(square_px, square_px)),
		false,
		Color.WHITE
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

const RED_SCRUB: Array[Vector2] = [
	Vector2(-46, -28), Vector2(-40, 27), Vector2(-30, -29), Vector2(-20, 28),
	Vector2(-8, -28), Vector2(8, 29), Vector2(20, -30), Vector2(31, 28),
	Vector2(42, -26), Vector2(46, 24), Vector2(-46, 8), Vector2(46, -7),
	Vector2(-41, -5), Vector2(39, 7), Vector2(-15, 3), Vector2(12, -2)
]

const RED_ROCKS: Array[Vector2] = [
	Vector2(-43, -18), Vector2(-37, 19), Vector2(-27, 25), Vector2(-11, -26),
	Vector2(3, -29), Vector2(18, 27), Vector2(33, -24), Vector2(44, 16),
	Vector2(-45, 15), Vector2(43, -15), Vector2(-7, 1), Vector2(9, 4)
]

const NEON_BUILDINGS: Array[Rect2] = [
	Rect2(-50, -32, 11, 8), Rect2(-37, -33, 9, 9), Rect2(-25, -32, 12, 7),
	Rect2(-11, -34, 10, 9), Rect2(3, -33, 13, 8), Rect2(19, -34, 9, 10),
	Rect2(31, -32, 14, 8), Rect2(-51, 24, 12, 9), Rect2(-36, 25, 9, 8),
	Rect2(-24, 24, 12, 10), Rect2(-9, 25, 11, 8), Rect2(5, 24, 12, 10),
	Rect2(20, 25, 10, 8), Rect2(33, 24, 13, 9),
	Rect2(-52, -20, 9, 10), Rect2(-51, -7, 8, 11), Rect2(-51, 8, 9, 10),
	Rect2(43, -21, 9, 10), Rect2(44, -7, 8, 11), Rect2(43, 8, 9, 10)
]

func draw_world(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	world_to_screen: Callable,
	world_points_to_screen: Callable,
	pixels_per_meter: float,
	visual_time: float
) -> void:
	var viewport_size: Vector2 = canvas.get_viewport_rect().size
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), theme.colour("ground"))
	draw_static_world(canvas, theme, track, world_to_screen, world_points_to_screen, pixels_per_meter)
	draw_weather(canvas, theme, visual_time)

func draw_static_world(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	world_to_screen: Callable,
	world_points_to_screen: Callable,
	pixels_per_meter: float
) -> void:
	if track.course_id() == "airfield":
		_draw_airfield_environment(canvas, theme, world_to_screen, pixels_per_meter)
	elif theme.id() == "red_dirt":
		_draw_red_dirt_environment(canvas, theme, world_to_screen, pixels_per_meter)
	else:
		_draw_neon_environment(canvas, theme, world_to_screen, pixels_per_meter)
	_draw_track(canvas, theme, track, world_to_screen, world_points_to_screen, pixels_per_meter)
	if track.course_id() == "round":
		_draw_course_markers(canvas, theme, world_to_screen, pixels_per_meter)
	elif track.course_id() == "airfield":
		_draw_airfield_plane(canvas, theme, world_to_screen, pixels_per_meter)

func draw_weather(canvas: CanvasItem, theme: ThemeSystem, visual_time: float) -> void:
	_draw_weather(canvas, theme, visual_time)

func _draw_red_dirt_environment(
	canvas: CanvasItem,
	theme: ThemeSystem,
	world_to_screen: Callable,
	ppm: float
) -> void:
	_draw_tiled_world_texture(
		canvas,
		"res://art/export/skins/red_dirt/environment/rd_surface_loose.png",
		Rect2(-70.0, -50.0, 140.0, 100.0),
		world_to_screen,
		Color(1.0, 1.0, 1.0, 0.48)
	)

	var patch_colour: Color = theme.colour("ground_dark")
	patch_colour.a = 0.20
	for i: int in range(14):
		var wx: float = -52.0 + float((i * 17) % 103)
		var wy: float = -34.0 + float((i * 29) % 67)
		var centre: Vector2 = world_to_screen.call(Vector2(wx, wy))
		canvas.draw_circle(centre, ppm * (1.5 + float(i % 4) * 0.55), patch_colour)

	for p: Vector2 in RED_SCRUB:
		var pos: Vector2 = world_to_screen.call(p)
		var scrub: Color = Color("#7f7541")
		var dark: Color = Color("#4f4b2c")
		canvas.draw_circle(pos, max(3.0, ppm * 0.20), dark)
		canvas.draw_line(pos + Vector2(-ppm * 0.22, 0), pos + Vector2(ppm * 0.22, 0), scrub, max(1.0, ppm * 0.06))
		canvas.draw_line(pos + Vector2(0, -ppm * 0.17), pos + Vector2(0, ppm * 0.17), scrub, max(1.0, ppm * 0.05))

	for p: Vector2 in RED_ROCKS:
		var pos: Vector2 = world_to_screen.call(p)
		var rock: Color = Color("#9a6b51")
		var shadow: Color = Color("#3a231d")
		canvas.draw_circle(pos + Vector2(ppm * 0.08, ppm * 0.08), max(2.5, ppm * 0.18), shadow)
		canvas.draw_circle(pos, max(2.5, ppm * 0.16), rock)

	_draw_red_dirt_props(canvas, theme, world_to_screen, ppm)
	_draw_world_asset(canvas, "res://art/export/skins/red_dirt/environment/rd_shed.png", Vector2(-44.0, 24.0), world_to_screen, ppm, Vector2(6.0, 5.0), -0.08)
	_draw_world_asset(canvas, "res://art/export/skins/red_dirt/environment/rd_barrier_tyre_stack.png", Vector2(43.0, -23.0), world_to_screen, ppm, Vector2(6.5, 3.2), 0.12)
	_draw_world_asset(canvas, "res://art/export/skins/red_dirt/environment/rd_event_sign.png", Vector2(-42.5, -23.0), world_to_screen, ppm, Vector2(4.0, 4.0))
	_draw_world_asset(canvas, "res://art/export/skins/red_dirt/environment/rd_scrub_a.png", Vector2(40.0, 25.0), world_to_screen, ppm, Vector2(4.0, 4.0))
	_draw_world_asset(canvas, "res://art/export/skins/red_dirt/environment/rd_rock_a.png", Vector2(34.0, 26.0), world_to_screen, ppm, Vector2(3.4, 3.4))

func _draw_red_dirt_props(
	canvas: CanvasItem,
	theme: ThemeSystem,
	world_to_screen: Callable,
	ppm: float
) -> void:
	var fence_colour: Color = Color("#8e806e")
	var fence_dark: Color = Color("#493f37")
	for y: float in [-18.0, -9.0, 0.0, 9.0, 18.0]:
		for x: float in [-48.0, 48.0]:
			var p: Vector2 = world_to_screen.call(Vector2(x, y))
			canvas.draw_circle(p, max(2.0, ppm * 0.10), fence_dark)
			canvas.draw_line(p + Vector2(0, -ppm * 0.24), p + Vector2(0, ppm * 0.24), fence_colour, max(2.0, ppm * 0.08))

	var sign_pos: Vector2 = world_to_screen.call(Vector2(-42.5, -23.0))
	_draw_panel(canvas, Rect2(sign_pos - Vector2(48, 20), Vector2(96, 40)), Color("#573325"), theme.colour("accent"), 5, 2)
	var font: Font = ThemeDB.fallback_font
	canvas.draw_string(font, sign_pos + Vector2(-34, 6), "RED DIRT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, theme.colour("ui_text"))

func _draw_airfield_environment(
	canvas: CanvasItem,
	theme: ThemeSystem,
	world_to_screen: Callable,
	ppm: float
) -> void:
	var grass_a: Vector2 = world_to_screen.call(Vector2(-78.0, -42.0))
	var grass_b: Vector2 = world_to_screen.call(Vector2(78.0, 42.0))
	canvas.draw_rect(Rect2(grass_a, grass_b - grass_a), Color("#39433b"))

	for y: float in [-31.0, 31.0]:
		var apron_a: Vector2 = world_to_screen.call(Vector2(-60.0, y - 2.0))
		var apron_b: Vector2 = world_to_screen.call(Vector2(60.0, y + 2.0))
		canvas.draw_rect(Rect2(apron_a, apron_b - apron_a), Color("#4b5050"))

	var hangar_a: Vector2 = world_to_screen.call(Vector2(-29.0, -7.0))
	var hangar_b: Vector2 = world_to_screen.call(Vector2(-18.0, 7.0))
	canvas.draw_rect(Rect2(hangar_a, hangar_b - hangar_a), Color("#596167"))
	canvas.draw_rect(Rect2(hangar_a, hangar_b - hangar_a), Color("#9aa2a6"), false, max(2.0, ppm * 0.08))

	var tower: Vector2 = world_to_screen.call(Vector2(28.0, 0.0))
	canvas.draw_circle(tower, max(8.0, ppm * 0.55), Color("#30363a"))
	canvas.draw_circle(tower, max(5.0, ppm * 0.36), Color("#87939a"))
	var glass: Color = theme.colour("accent")
	glass.a = 0.55
	canvas.draw_circle(tower, max(3.0, ppm * 0.22), glass)

func _draw_airfield_plane(
	canvas: CanvasItem,
	theme: ThemeSystem,
	world_to_screen: Callable,
	ppm: float
) -> void:
	var body: Color = Color("#d6dadd")
	var edge: Color = Color("#69747b")
	var shadow: Color = Color(0.05, 0.06, 0.07, 0.32)
	var centre: Vector2 = Vector2(3.0, 0.0)

	var shadow_points: PackedVector2Array = PackedVector2Array([
		world_to_screen.call(centre + Vector2(-11.0, -1.0)) + Vector2(5, 6),
		world_to_screen.call(centre + Vector2(8.5, -1.0)) + Vector2(5, 6),
		world_to_screen.call(centre + Vector2(12.0, 0.0)) + Vector2(5, 6),
		world_to_screen.call(centre + Vector2(8.5, 1.0)) + Vector2(5, 6),
		world_to_screen.call(centre + Vector2(-11.0, 1.0)) + Vector2(5, 6)
	])
	canvas.draw_colored_polygon(shadow_points, shadow)

	var wing: PackedVector2Array = PackedVector2Array([
		world_to_screen.call(centre + Vector2(-1.0, -8.0)),
		world_to_screen.call(centre + Vector2(2.8, -8.0)),
		world_to_screen.call(centre + Vector2(5.0, -1.0)),
		world_to_screen.call(centre + Vector2(5.0, 1.0)),
		world_to_screen.call(centre + Vector2(2.8, 8.0)),
		world_to_screen.call(centre + Vector2(-1.0, 8.0)),
		world_to_screen.call(centre + Vector2(0.8, 1.0)),
		world_to_screen.call(centre + Vector2(0.8, -1.0))
	])
	canvas.draw_colored_polygon(wing, body.darkened(0.04))
	canvas.draw_polyline(_closed(wing), edge, max(1.5, ppm * 0.05), true)

	var fuselage: PackedVector2Array = PackedVector2Array([
		world_to_screen.call(centre + Vector2(-11.0, -1.0)),
		world_to_screen.call(centre + Vector2(8.2, -1.0)),
		world_to_screen.call(centre + Vector2(11.8, 0.0)),
		world_to_screen.call(centre + Vector2(8.2, 1.0)),
		world_to_screen.call(centre + Vector2(-11.0, 1.0))
	])
	canvas.draw_colored_polygon(fuselage, body)
	canvas.draw_polyline(_closed(fuselage), edge, max(1.5, ppm * 0.05), true)

	var tail: PackedVector2Array = PackedVector2Array([
		world_to_screen.call(centre + Vector2(-9.4, -4.0)),
		world_to_screen.call(centre + Vector2(-6.7, -3.2)),
		world_to_screen.call(centre + Vector2(-5.2, -0.7)),
		world_to_screen.call(centre + Vector2(-5.2, 0.7)),
		world_to_screen.call(centre + Vector2(-6.7, 3.2)),
		world_to_screen.call(centre + Vector2(-9.4, 4.0)),
		world_to_screen.call(centre + Vector2(-8.3, 0.8)),
		world_to_screen.call(centre + Vector2(-8.3, -0.8))
	])
	canvas.draw_colored_polygon(tail, body.darkened(0.08))
	canvas.draw_polyline(_closed(tail), edge, max(1.5, ppm * 0.045), true)

	for y: float in [-3.8, 3.8]:
		var engine: Vector2 = world_to_screen.call(centre + Vector2(2.8, y))
		canvas.draw_circle(engine, max(3.0, ppm * 0.25), edge)
		canvas.draw_circle(engine, max(2.0, ppm * 0.16), Color("#1d252b"))

	var stripe: Color = theme.colour("accent")
	stripe.a = 0.72
	canvas.draw_line(
		world_to_screen.call(centre + Vector2(-7.5, 0.0)),
		world_to_screen.call(centre + Vector2(8.5, 0.0)),
		stripe,
		max(1.5, ppm * 0.08),
		true
	)

func _draw_neon_environment(
	canvas: CanvasItem,
	theme: ThemeSystem,
	world_to_screen: Callable,
	ppm: float
) -> void:
	_draw_tiled_world_texture(
		canvas,
		"res://art/export/skins/brisbane_neon_rain/environment/bnr_surface_dark_wet.png",
		Rect2(-70.0, -50.0, 140.0, 100.0),
		world_to_screen,
		Color(1.0, 1.0, 1.0, 0.58)
	)

	var building_fill: Color = Color("#080d17")
	var building_edge: Color = Color("#172537")
	for i: int in range(NEON_BUILDINGS.size()):
		var wr: Rect2 = NEON_BUILDINGS[i]
		var a: Vector2 = world_to_screen.call(wr.position)
		var b: Vector2 = world_to_screen.call(wr.position + wr.size)
		var sr: Rect2 = Rect2(a, b - a)
		canvas.draw_rect(sr, building_fill)
		canvas.draw_rect(sr, building_edge, false, max(1.0, ppm * 0.05))

		if i % 3 == 0:
			var glow: Color = theme.colour("accent")
			glow.a = 0.18
			canvas.draw_rect(Rect2(sr.position + Vector2(4, 4), Vector2(max(4.0, sr.size.x - 8), 5)), glow)
		elif i % 3 == 1:
			var glow2: Color = theme.colour("accent2")
			glow2.a = 0.16
			canvas.draw_rect(Rect2(sr.position + Vector2(4, sr.size.y - 9), Vector2(max(4.0, sr.size.x - 8), 5)), glow2)

	_draw_world_asset(canvas, "res://art/export/skins/brisbane_neon_rain/environment/bnr_billboard.png", Vector2(-43.5, -26.0), world_to_screen, ppm, Vector2(7.0, 3.5))
	_draw_world_asset(canvas, "res://art/export/skins/brisbane_neon_rain/environment/bnr_neon_barrier.png", Vector2(39.5, 25.0), world_to_screen, ppm, Vector2(7.0, 3.4))
	_draw_world_asset(canvas, "res://art/export/skins/brisbane_neon_rain/environment/bnr_light_pole.png", Vector2(45.5, -15.0), world_to_screen, ppm, Vector2(3.0, 6.0))
	_draw_neon_sign(canvas, theme, world_to_screen.call(Vector2(-43.5, -26.0)), "BRISBANE", true)
	_draw_neon_sign(canvas, theme, world_to_screen.call(Vector2(40.0, 25.0)), "02:00", false)
	_draw_neon_sign(canvas, theme, world_to_screen.call(Vector2(45.5, -15.0)), "OPEN", true)

func _draw_neon_sign(
	canvas: CanvasItem,
	theme: ThemeSystem,
	centre: Vector2,
	text: String,
	use_primary: bool
) -> void:
	var accent: Color = theme.colour("accent") if use_primary else theme.colour("accent2")
	var glow: Color = accent
	glow.a = 0.18
	var rect: Rect2 = Rect2(centre - Vector2(48, 18), Vector2(96, 36))
	_draw_panel(canvas, rect.grow(6), Color(0,0,0,0.65), glow, 4, 8)
	_draw_panel(canvas, rect, Color("#080a11"), accent, 4, 2)
	var font: Font = ThemeDB.fallback_font
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	canvas.draw_string(font, centre - Vector2(size.x * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, accent)

func _draw_track(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	world_to_screen: Callable,
	world_points_to_screen: Callable,
	ppm: float
) -> void:
	if track.course_id() == "figure_eight":
		_draw_figure8_track(canvas, theme, track, world_to_screen, world_points_to_screen, ppm)
		return
	if track.course_id() == "airfield":
		_draw_airfield_track(canvas, theme, track, world_to_screen, world_points_to_screen, ppm)
		return

	var outer: PackedVector2Array = world_points_to_screen.call(track.road_outer_points())
	var inner: PackedVector2Array = world_points_to_screen.call(track.road_inner_points())
	canvas.draw_colored_polygon(outer, theme.colour("road"))
	canvas.draw_colored_polygon(inner, theme.colour("ground"))

	if theme.id() == "red_dirt":
		_draw_red_dirt_track_detail(canvas, theme, track, world_to_screen, world_points_to_screen, ppm)
	else:
		_draw_neon_track_detail(canvas, theme, track, world_to_screen, world_points_to_screen, ppm)

	var outer_barrier: PackedVector2Array = world_points_to_screen.call(track.barrier_outer_points())
	var inner_barrier: PackedVector2Array = world_points_to_screen.call(track.barrier_inner_points())
	if outer_barrier.size() > 1:
		outer_barrier.append(outer_barrier[0])
		_draw_barrier_line(canvas, theme, outer_barrier, ppm)
	if inner_barrier.size() > 1:
		inner_barrier.append(inner_barrier[0])
		_draw_barrier_line(canvas, theme, inner_barrier, ppm)

	_draw_start_line(canvas, theme, world_to_screen, ppm)


func _draw_airfield_track(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	world_to_screen: Callable,
	world_points_to_screen: Callable,
	ppm: float
) -> void:
	var outer: PackedVector2Array = world_points_to_screen.call(track.road_outer_points())
	var inner: PackedVector2Array = world_points_to_screen.call(track.road_inner_points())
	var tarmac: Color = Color("#4b4f52")
	var infield: Color = Color("#39433b")
	canvas.draw_colored_polygon(outer, tarmac)
	canvas.draw_colored_polygon(inner, infield)

	var outer_barrier: PackedVector2Array = world_points_to_screen.call(track.barrier_outer_points())
	var inner_barrier: PackedVector2Array = world_points_to_screen.call(track.barrier_inner_points())
	if outer_barrier.size() > 1:
		outer_barrier.append(outer_barrier[0])
		canvas.draw_polyline(outer_barrier, Color("#23282b"), max(4.0, ppm * 0.22), true)
		canvas.draw_polyline(outer_barrier, Color("#aeb6ba"), max(1.5, ppm * 0.07), true)
	if inner_barrier.size() > 1:
		inner_barrier.append(inner_barrier[0])
		canvas.draw_polyline(inner_barrier, Color("#23282b"), max(4.0, ppm * 0.22), true)
		canvas.draw_polyline(inner_barrier, Color("#aeb6ba"), max(1.5, ppm * 0.07), true)

	var white: Color = Color(0.95, 0.95, 0.92, 0.78)
	var yellow: Color = Color("#f0c64a")
	yellow.a = 0.76
	for x: int in range(-48, 49, 12):
		for y: float in [-16.7, 16.7]:
			canvas.draw_line(
				world_to_screen.call(Vector2(float(x) - 3.3, y)),
				world_to_screen.call(Vector2(float(x) + 3.3, y)),
				white,
				max(2.0, ppm * 0.10),
				true
			)
	for y2: int in range(-6, 7, 4):
		for x2: float in [-55.2, 55.2]:
			canvas.draw_line(
				world_to_screen.call(Vector2(x2, float(y2) - 1.2)),
				world_to_screen.call(Vector2(x2, float(y2) + 1.2)),
				yellow,
				max(1.5, ppm * 0.065),
				true
			)

	var runway_edge: Color = Color(0.92, 0.92, 0.88, 0.34)
	for y3: float in [-12.2, 12.2, -21.2, 21.2]:
		canvas.draw_line(
			world_to_screen.call(Vector2(-45.0, y3)),
			world_to_screen.call(Vector2(45.0, y3)),
			runway_edge,
			max(1.0, ppm * 0.045),
			true
		)

	var font: Font = ThemeDB.fallback_font
	for label_pos: Vector2 in [Vector2(-39.0, 16.7), Vector2(39.0, -16.7)]:
		var p: Vector2 = world_to_screen.call(label_pos)
		canvas.draw_string(font, p + Vector2(-10, 5), "27", HORIZONTAL_ALIGNMENT_LEFT, -1, max(11, int(ppm * 0.46)), white)

	var gate: Dictionary = track.race_gates()[0]
	var a: Vector2 = world_to_screen.call(Vector2(gate["a"]))
	var b: Vector2 = world_to_screen.call(Vector2(gate["b"]))
	var delta: Vector2 = (b - a) / 12.0
	for i: int in range(12):
		var p0: Vector2 = a + delta * float(i)
		var p1: Vector2 = a + delta * float(i + 1)
		canvas.draw_line(p0, p1, Color.WHITE if i % 2 == 0 else Color("#151719"), max(5.0, ppm * 0.22), true)

func _draw_figure8_track(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	world_to_screen: Callable,
	world_points_to_screen: Callable,
	ppm: float
) -> void:
	var line: PackedVector2Array = world_points_to_screen.call(track.figure_eight_points())
	if line.size() < 2:
		return

	var barrier_dark: Color = theme.colour("barrier_dark")
	var barrier_light: Color = theme.colour("barrier")
	var road: Color = theme.colour("road")
	var edge: Color = theme.colour("edge")

	if theme.id() == "brisbane_neon_rain":
		var glow: Color = theme.colour("accent2")
		glow.a = 0.10
		canvas.draw_polyline(line, glow, max(12.0, ppm * 12.8), true)

	canvas.draw_polyline(line, barrier_dark, max(10.0, ppm * 11.6), true)
	canvas.draw_polyline(line, barrier_light, max(8.0, ppm * 10.5), true)
	canvas.draw_polyline(line, road, max(7.0, ppm * 8.8), true)

	edge.a = 0.42 if theme.id() == "red_dirt" else 0.62
	canvas.draw_polyline(line, edge, max(1.5, ppm * 0.08), true)

	if theme.id() == "brisbane_neon_rain":
		var wet: Color = theme.colour("road_light")
		wet.a = 0.16
		canvas.draw_polyline(line, wet, max(1.0, ppm * 0.05), true)
	else:
		var rut: Color = theme.colour("road_dark")
		rut.a = 0.30
		canvas.draw_polyline(line, rut, max(1.0, ppm * 0.07), true)

	_draw_figure8_start_line(canvas, theme, track, world_to_screen)

func _draw_figure8_start_line(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	world_to_screen: Callable
) -> void:
	var gates: Array[Dictionary] = track.race_gates()
	if gates.is_empty():
		return
	var gate: Dictionary = gates[0]
	var a: Vector2 = world_to_screen.call(Vector2(gate["a"]))
	var b: Vector2 = world_to_screen.call(Vector2(gate["b"]))
	var delta: Vector2 = (b - a) / 10.0
	for i: int in range(10):
		var p0: Vector2 = a + delta * float(i)
		var p1: Vector2 = a + delta * float(i + 1)
		var colour: Color
		if theme.id() == "red_dirt":
			colour = Color("#f2e0c3") if i % 2 == 0 else Color("#3b2118")
		else:
			colour = theme.colour("accent") if i % 2 == 0 else theme.colour("accent2")
		canvas.draw_line(p0, p1, colour, 7.0, true)

func _draw_red_dirt_track_detail(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	world_to_screen: Callable,
	world_points_to_screen: Callable,
	ppm: float
) -> void:
	var edge: Color = theme.colour("edge")
	edge.a = 0.56
	var outer_line: PackedVector2Array = world_points_to_screen.call(track.road_outer_points())
	var inner_line: PackedVector2Array = world_points_to_screen.call(track.road_inner_points())
	outer_line.append(outer_line[0])
	inner_line.append(inner_line[0])
	canvas.draw_polyline(outer_line, edge, max(2.0, ppm * 0.10), true)
	canvas.draw_polyline(inner_line, edge, max(2.0, ppm * 0.10), true)

	var rut: Color = theme.colour("road_dark")
	rut.a = 0.42
	var rut_w: float = max(1.0, ppm * 0.055)
	for y: float in [-16.3, -15.0, 15.0, 16.3]:
		canvas.draw_line(world_to_screen.call(Vector2(-24.0, y)), world_to_screen.call(Vector2(24.0, y)), rut, rut_w, true)
	for x: float in [-30.5, -29.2, 29.2, 30.5]:
		canvas.draw_line(world_to_screen.call(Vector2(x, -8.0)), world_to_screen.call(Vector2(x, 8.0)), rut, rut_w, true)

	for i: int in range(22):
		var x: float = -25.0 + float((i * 11) % 51)
		var y: float = -16.0 if i % 2 == 0 else 16.0
		var p: Vector2 = world_to_screen.call(Vector2(x, y + sin(float(i)) * 0.55))
		var pebble: Color = theme.colour("road_light")
		pebble.a = 0.30
		canvas.draw_circle(p, max(1.0, ppm * 0.035), pebble)

func _draw_neon_track_detail(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	world_to_screen: Callable,
	world_points_to_screen: Callable,
	ppm: float
) -> void:
	var outer_line: PackedVector2Array = world_points_to_screen.call(track.road_outer_points())
	var inner_line: PackedVector2Array = world_points_to_screen.call(track.road_inner_points())
	outer_line.append(outer_line[0])
	inner_line.append(inner_line[0])

	var glow: Color = theme.colour("accent")
	glow.a = 0.13
	canvas.draw_polyline(outer_line, glow, max(8.0, ppm * 0.38), true)
	canvas.draw_polyline(inner_line, glow, max(8.0, ppm * 0.38), true)

	var edge: Color = theme.colour("edge")
	edge.a = 0.75
	canvas.draw_polyline(outer_line, edge, max(2.0, ppm * 0.065), true)
	canvas.draw_polyline(inner_line, edge, max(2.0, ppm * 0.065), true)

	var wet: Color = theme.colour("road_light")
	wet.a = 0.18
	for y: float in [-15.3, 15.3]:
		canvas.draw_line(world_to_screen.call(Vector2(-23.0, y)), world_to_screen.call(Vector2(23.0, y)), wet, max(2.0, ppm * 0.12), true)
	for x: float in [-29.7, 29.7]:
		canvas.draw_line(world_to_screen.call(Vector2(x, -7.0)), world_to_screen.call(Vector2(x, 7.0)), wet, max(2.0, ppm * 0.12), true)

	var lane: Color = Color(0.85, 0.92, 0.98, 0.42)
	for x: int in range(-21, 22, 6):
		canvas.draw_line(world_to_screen.call(Vector2(float(x), -16.0)), world_to_screen.call(Vector2(float(x + 3), -16.0)), lane, max(1.5, ppm * 0.055), true)
		canvas.draw_line(world_to_screen.call(Vector2(float(x), 16.0)), world_to_screen.call(Vector2(float(x + 3), 16.0)), lane, max(1.5, ppm * 0.055), true)

	for y: int in range(-6, 7, 4):
		canvas.draw_line(world_to_screen.call(Vector2(-30.0, float(y))), world_to_screen.call(Vector2(-30.0, float(y + 2))), lane, max(1.5, ppm * 0.055), true)
		canvas.draw_line(world_to_screen.call(Vector2(30.0, float(y))), world_to_screen.call(Vector2(30.0, float(y + 2))), lane, max(1.5, ppm * 0.055), true)

	var magenta: Color = theme.colour("accent2")
	magenta.a = 0.13
	canvas.draw_rect(_screen_rect_from_world(world_to_screen, Rect2(-18.0, 14.7, 7.5, 0.8)), magenta)
	canvas.draw_rect(_screen_rect_from_world(world_to_screen, Rect2(9.0, -15.5, 9.0, 0.8)), magenta)

func _draw_barrier_line(canvas: CanvasItem, theme: ThemeSystem, points: PackedVector2Array, ppm: float) -> void:
	var dark: Color = theme.colour("barrier_dark")
	var light: Color = theme.colour("barrier")
	if theme.id() == "brisbane_neon_rain":
		var glow: Color = theme.colour("accent2")
		glow.a = 0.09
		canvas.draw_polyline(points, glow, max(7.0, ppm * 0.32), true)
	canvas.draw_polyline(points, dark, max(4.0, ppm * 0.19), true)
	canvas.draw_polyline(points, light, max(1.5, ppm * 0.07), true)

func _draw_start_line(canvas: CanvasItem, theme: ThemeSystem, world_to_screen: Callable, ppm: float) -> void:
	for i: int in range(8):
		var y0: float = 12.25 + float(i) * 0.95
		var a: Vector2 = world_to_screen.call(Vector2(-0.28, y0))
		var b: Vector2 = world_to_screen.call(Vector2(0.28, y0 + 0.95))
		var colour: Color
		if theme.id() == "red_dirt":
			colour = Color("#f2e0c3") if i % 2 == 0 else Color("#3b2118")
		else:
			colour = theme.colour("accent") if i % 2 == 0 else theme.colour("accent2")
		canvas.draw_rect(Rect2(a, b - a), colour)

func _draw_course_markers(canvas: CanvasItem, theme: ThemeSystem, world_to_screen: Callable, ppm: float) -> void:
	for x: float in [-20.0, -12.0, -4.0, 4.0, 12.0, 20.0]:
		var p: Vector2 = world_to_screen.call(Vector2(x, -16.0))
		if theme.id() == "red_dirt":
			_draw_cone(canvas, p, ppm, theme.colour("accent"))
		else:
			_draw_road_stud(canvas, p, ppm, theme.colour("accent2"))

	for x: float in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		var offset: float = 1.2 if int(x / 8.0) % 2 == 0 else -1.2
		var p2: Vector2 = world_to_screen.call(Vector2(x, 16.0 + offset))
		if theme.id() == "red_dirt":
			_draw_cone(canvas, p2, ppm, theme.colour("accent2"))
		else:
			_draw_road_stud(canvas, p2, ppm, theme.colour("accent"))

func _draw_cone(canvas: CanvasItem, pos: Vector2, ppm: float, colour: Color) -> void:
	var h: float = max(7.0, ppm * 0.38)
	var w: float = h * 0.55
	var pts: PackedVector2Array = PackedVector2Array([
		pos + Vector2(0, -h * 0.55),
		pos + Vector2(w * 0.5, h * 0.45),
		pos + Vector2(-w * 0.5, h * 0.45)
	])
	canvas.draw_colored_polygon(pts, colour)
	canvas.draw_line(pos + Vector2(-w * 0.7, h * 0.48), pos + Vector2(w * 0.7, h * 0.48), Color("#3c251d"), max(2.0, ppm * 0.08))

func _draw_road_stud(canvas: CanvasItem, pos: Vector2, ppm: float, colour: Color) -> void:
	var glow: Color = colour
	glow.a = 0.16
	canvas.draw_circle(pos, max(5.0, ppm * 0.22), glow)
	canvas.draw_circle(pos, max(2.0, ppm * 0.08), colour)

func _draw_weather(canvas: CanvasItem, theme: ThemeSystem, visual_time: float) -> void:
	var size: Vector2 = canvas.get_viewport_rect().size
	if theme.id() == "brisbane_neon_rain":
		var rain: Color = Color(0.72, 0.90, 1.0, 0.20)
		for i: int in range(76):
			var x: float = fposmod(float(i * 83) + visual_time * 410.0, size.x + 80.0) - 40.0
			var y: float = fposmod(float(i * 137) + visual_time * 710.0, size.y + 100.0) - 50.0
			canvas.draw_line(Vector2(x, y), Vector2(x - 9.0, y + 22.0), rain, 1.0, true)

		var haze: Color = theme.colour("accent")
		haze.a = 0.035
		canvas.draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), haze)
	else:
		var dust: Color = theme.colour("effect")
		dust.a = 0.07
		for i: int in range(26):
			var x2: float = fposmod(float(i * 113) + visual_time * 25.0, size.x + 80.0) - 40.0
			var y2: float = fposmod(float(i * 59) + visual_time * 11.0, size.y + 60.0) - 30.0
			canvas.draw_circle(Vector2(x2, y2), 1.0 + float(i % 3), dust)


func draw_dynamic_dry_line(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	world_to_screen: Callable,
	ppm: float
) -> void:
	if theme.id() != "brisbane_neon_rain" or not track.wet_surface:
		return
	for segment: Dictionary in track.dry_line_segments():
		var level: float = float(segment.get("level", 0.0))
		if level <= 0.01:
			continue
		var a: Vector2 = world_to_screen.call(Vector2(segment["a"]))
		var b: Vector2 = world_to_screen.call(Vector2(segment["b"]))
		var dry: Color = Color("#263038")
		dry.a = 0.08 + 0.23 * level
		var width: float = max(3.0, ppm * 1.70)
		canvas.draw_line(a, b, dry, width, true)
		canvas.draw_circle(a, width * 0.5, dry)
		var centre: Color = Color("#56616a")
		centre.a = 0.02 + 0.07 * level
		canvas.draw_line(a, b, centre, max(1.0, ppm * 0.18), true)

func draw_skid_marks(
	canvas: CanvasItem,
	theme: ThemeSystem,
	skid_points: Array[Vector2],
	world_to_screen: Callable,
	ppm: float
) -> void:
	var colour: Color = theme.colour("skid")
	colour.a = 0.50 if theme.id() == "red_dirt" else 0.62
	for i: int in range(0, skid_points.size() - 1, 2):
		var a: Vector2 = world_to_screen.call(skid_points[i])
		var b: Vector2 = world_to_screen.call(skid_points[i + 1])
		canvas.draw_line(a, b, colour, max(1.0, ppm * 0.07), true)

func draw_tyre_effects(
	canvas: CanvasItem,
	theme: ThemeSystem,
	positions: Array[Vector2],
	life: Array[float],
	world_to_screen: Callable,
	ppm: float
) -> void:
	for i: int in range(positions.size()):
		var life_ratio: float = clamp(life[i] / 0.72, 0.0, 1.0)
		var pos: Vector2 = world_to_screen.call(positions[i])
		if theme.effect_mode() == "dust":
			var dust: Color = theme.colour("effect")
			dust.a = 0.28 * life_ratio
			var radius: float = ppm * lerp(0.18, 0.72, 1.0 - life_ratio)
			canvas.draw_circle(pos, radius, dust)
			var inner: Color = theme.colour("road_light")
			inner.a = 0.12 * life_ratio
			canvas.draw_circle(pos + Vector2(radius * 0.22, -radius * 0.1), radius * 0.55, inner)
		else:
			var spray: Color = theme.colour("effect")
			spray.a = 0.22 * life_ratio
			var radius2: float = ppm * lerp(0.12, 0.47, 1.0 - life_ratio)
			canvas.draw_circle(pos, radius2, spray)
			canvas.draw_line(pos, pos + Vector2(0, radius2 * 1.8), Color(0.65, 0.90, 1.0, 0.10 * life_ratio), max(1.0, ppm * 0.04))

func draw_car(
	canvas: CanvasItem,
	theme: ThemeSystem,
	sim: VehicleSim,
	world_to_screen: Callable,
	ppm: float
) -> void:
	var asset_texture: Texture2D = _vehicle_texture(theme.id(), sim.preset_index)
	if asset_texture != null:
		_draw_asset_car(canvas, theme, sim, world_to_screen, ppm, asset_texture)
		return

	var body: Array[Vector2] = _car_shape(sim.preset_index)
	var shadow_points: PackedVector2Array = PackedVector2Array()
	var body_points: PackedVector2Array = PackedVector2Array()
	var shadow_offset: Vector2 = Vector2(ppm * 0.16, ppm * 0.18)
	for point: Vector2 in body:
		var screen: Vector2 = world_to_screen.call(sim.position + point.rotated(sim.angle))
		shadow_points.append(screen + shadow_offset)
		body_points.append(screen)

	var shadow: Color = theme.colour("car_shadow")
	shadow.a = 0.55
	canvas.draw_colored_polygon(shadow_points, shadow)

	var body_colour: Color = Color("#e45548")
	if sim.preset_index == 1:
		body_colour = Color("#3d9be8")
	elif sim.preset_index == 2:
		body_colour = Color("#efb83f")

	canvas.draw_colored_polygon(body_points, body_colour)
	canvas.draw_polyline(_closed(body_points), body_colour.lightened(0.18), max(1.0, ppm * 0.055), true)

	_draw_wheels(canvas, sim, world_to_screen, ppm)
	_draw_car_glass(canvas, sim, world_to_screen, ppm)
	_draw_car_detail(canvas, theme, sim, world_to_screen, ppm)

func _car_shape(index: int) -> Array[Vector2]:
	if index == 1:
		return [
			Vector2(1.95, -0.85), Vector2(2.18, -0.55), Vector2(2.22, 0.55),
			Vector2(1.95, 0.85), Vector2(-1.62, 0.88), Vector2(-2.05, 0.62),
			Vector2(-2.12, -0.62), Vector2(-1.62, -0.88)
		]
	if index == 2:
		return [
			Vector2(2.10, -0.92), Vector2(2.30, -0.66), Vector2(2.30, 0.66),
			Vector2(2.10, 0.92), Vector2(-2.10, 0.92), Vector2(-2.30, 0.68),
			Vector2(-2.30, -0.68), Vector2(-2.10, -0.92)
		]
	return [
		Vector2(2.35, -0.65), Vector2(2.08, -0.92), Vector2(-1.80, -0.94),
		Vector2(-2.22, -0.68), Vector2(-2.22, 0.68), Vector2(-1.80, 0.94),
		Vector2(2.08, 0.92), Vector2(2.35, 0.65)
	]

func _draw_wheels(canvas: CanvasItem, sim: VehicleSim, world_to_screen: Callable, ppm: float) -> void:
	var offsets: Array[Vector2] = sim.get_wheel_offsets()
	for i: int in range(offsets.size()):
		var steer: float = sim.steering_angle if i < 2 else 0.0
		var centre_world: Vector2 = sim.position + offsets[i].rotated(sim.angle)
		var wheel_angle: float = sim.angle + steer
		var hx: float = 0.36
		var hy: float = 0.13
		var local: Array[Vector2] = [
			Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy), Vector2(-hx, -hy)
		]
		var pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in local:
			pts.append(world_to_screen.call(centre_world + p.rotated(wheel_angle)))
		canvas.draw_colored_polygon(pts, Color("#090a0c"))

func _draw_car_glass(canvas: CanvasItem, sim: VehicleSim, world_to_screen: Callable, ppm: float) -> void:
	var glass: Color = Color("#182431")
	if sim.preset_index == 2:
		glass = Color("#26303a")
	var front: Array[Vector2] = [
		Vector2(0.95, -0.62), Vector2(1.22, -0.47), Vector2(1.22, 0.47), Vector2(0.95, 0.62)
	]
	var roof: Array[Vector2] = [
		Vector2(0.78, -0.61), Vector2(0.78, 0.61), Vector2(-0.88, 0.61), Vector2(-0.88, -0.61)
	]
	canvas.draw_colored_polygon(_car_local_to_screen(front, sim, world_to_screen), glass.lightened(0.12))
	canvas.draw_colored_polygon(_car_local_to_screen(roof, sim, world_to_screen), glass)

func _draw_car_detail(canvas: CanvasItem, theme: ThemeSystem, sim: VehicleSim, world_to_screen: Callable, ppm: float) -> void:
	var forward_a: Vector2 = world_to_screen.call(sim.position + Vector2(2.22, -0.54).rotated(sim.angle))
	var forward_b: Vector2 = world_to_screen.call(sim.position + Vector2(2.22, 0.54).rotated(sim.angle))
	var headlight: Color = Color("#f8f2d0")
	canvas.draw_line(forward_a, forward_b, headlight, max(2.0, ppm * 0.07), true)

	var tail_a: Vector2 = world_to_screen.call(sim.position + Vector2(-2.18, -0.52).rotated(sim.angle))
	var tail_b: Vector2 = world_to_screen.call(sim.position + Vector2(-2.18, 0.52).rotated(sim.angle))
	canvas.draw_line(tail_a, tail_b, Color("#ff4c4c"), max(2.0, ppm * 0.07), true)

	var centre_a: Vector2 = world_to_screen.call(sim.position + Vector2(-1.1, 0).rotated(sim.angle))
	var centre_b: Vector2 = world_to_screen.call(sim.position + Vector2(1.0, 0).rotated(sim.angle))
	canvas.draw_line(centre_a, centre_b, Color(1,1,1,0.15), max(1.0, ppm * 0.035), true)

	if sim.preset_index == 2:
		for y: float in [-0.38, 0.0, 0.38]:
			var lamp: Vector2 = world_to_screen.call(sim.position + Vector2(2.30, y).rotated(sim.angle))
			canvas.draw_circle(lamp, max(1.5, ppm * 0.07), Color("#fff3b0"))

	if theme.id() == "brisbane_neon_rain":
		var reflection: Color = theme.colour("accent")
		reflection.a = 0.10
		canvas.draw_line(forward_a + Vector2(0, 4), forward_a + Vector2(0, 19), reflection, max(2.0, ppm * 0.10), true)
		canvas.draw_line(forward_b + Vector2(0, 4), forward_b + Vector2(0, 19), reflection, max(2.0, ppm * 0.10), true)

func _car_local_to_screen(local_points: Array[Vector2], sim: VehicleSim, world_to_screen: Callable) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in local_points:
		result.append(world_to_screen.call(sim.position + p.rotated(sim.angle)))
	return result

func draw_hud(
	canvas: CanvasItem,
	theme: ThemeSystem,
	sim: VehicleSim,
	surface_name: String,
	telemetry_open: bool,
	joy_name: String
) -> void:
	var font: Font = ThemeDB.fallback_font
	var bg: Color = theme.colour("ui_panel")
	bg.a = 0.90
	var border: Color = theme.colour("accent")
	border.a = 0.70
	var text: Color = theme.colour("ui_text")
	var muted: Color = theme.colour("ui_muted")

	var main_rect: Rect2 = Rect2(18, 18, 344, 150)
	_draw_panel(canvas, main_rect, bg, border, 10, 2)

	canvas.draw_string(font, Vector2(34, 44), sim.preset_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, text)
	canvas.draw_string(font, Vector2(34, 63), theme.name().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, muted)
	canvas.draw_string(font, Vector2(34, 78), String(theme.value("tagline", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, theme.colour("accent2"))

	var speed_text: String = "%03d" % int(round(sim.speed_kph()))
	canvas.draw_string(font, Vector2(34, 113), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, text)
	canvas.draw_string(font, Vector2(142, 108), "KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
	canvas.draw_string(font, Vector2(142, 128), sim.gear_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, theme.colour("accent2"))

	var stat_x: float = 222.0
	canvas.draw_string(font, Vector2(stat_x, 86), "LAT  %+.2f G" % (sim.last_lat_accel / 9.81), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, muted)
	canvas.draw_string(font, Vector2(stat_x, 106), "LONG %+.2f G" % (sim.last_long_accel / 9.81), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, muted)
	canvas.draw_string(font, Vector2(stat_x, 126), surface_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, theme.colour("accent2"))

	var risk: float = sim.grip_risk()
	var risk_bg: Rect2 = Rect2(stat_x, 137, 116, 7)
	canvas.draw_rect(risk_bg, Color(0, 0, 0, 0.38), true)
	var risk_colour: Color = theme.colour("success").lerp(theme.colour("danger"), risk)
	canvas.draw_rect(Rect2(risk_bg.position, Vector2(risk_bg.size.x * risk, risk_bg.size.y)), risk_colour, true)
	canvas.draw_string(
		font,
		Vector2(stat_x, 158),
		"GRIP %d%%" % int(round(risk * 100.0)),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		risk_colour if risk > 0.52 else muted
	)

	if sim.last_impact_kph > 1.0:
		var impact: Color = theme.colour("danger")
		canvas.draw_string(font, Vector2(34, 157), "IMPACT %.0f" % sim.last_impact_kph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, impact)

	if telemetry_open:
		_draw_telemetry_panel(canvas, theme, sim, joy_name)

func _draw_telemetry_panel(
	canvas: CanvasItem,
	theme: ThemeSystem,
	sim: VehicleSim,
	joy_name: String
) -> void:
	var font: Font = ThemeDB.fallback_font
	var bg: Color = theme.colour("ui_panel_alt")
	bg.a = 0.94
	var border: Color = theme.colour("accent2")
	border.a = 0.55
	var rect: Rect2 = Rect2(18, 180, 344, 254)
	_draw_panel(canvas, rect, bg, border, 9, 1)

	var title: Color = theme.colour("accent2")
	var text: Color = theme.colour("ui_text")
	var muted: Color = theme.colour("ui_muted")
	canvas.draw_string(font, Vector2(34, 205), "TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, title)

	var lines: Array[String] = [
		"Steer %+.1f deg    Yaw %+.1f deg/s" % [rad_to_deg(sim.steering_angle), rad_to_deg(sim.angular_velocity)],
		"FL %+.1f deg  %3.0f%% grip" % [sim.wheel_slip_angles[0], sim.wheel_grip_usage[0] * 100.0],
		"FR %+.1f deg  %3.0f%% grip" % [sim.wheel_slip_angles[1], sim.wheel_grip_usage[1] * 100.0],
		"RL %+.1f deg  %3.0f%% grip" % [sim.wheel_slip_angles[2], sim.wheel_grip_usage[2] * 100.0],
		"RR %+.1f deg  %3.0f%% grip" % [sim.wheel_slip_angles[3], sim.wheel_grip_usage[3] * 100.0],
		"Mass %.0f kg   Grip %.2f mu" % [sim.mass, sim.base_tyre_mu],
		"Drive %.0f%% front   Brake %.0f%% front" % [sim.drive_front_fraction * 100.0, sim.front_brake_bias * 100.0],
		"Controller: " + joy_name
	]
	for i: int in range(lines.size()):
		canvas.draw_string(font, Vector2(34, 231 + i * 24), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text if i < 5 else muted)

func draw_touch_controls(
	canvas: CanvasItem,
	theme: ThemeSystem,
	rects: Dictionary,
	active: Dictionary,
	show_touch: bool,
	course_name: String,
	weather_enabled: bool,
	manual_mode: bool,
	gear_label: String
) -> void:
	if not show_touch:
		return

	var left_rect: Rect2 = Rect2(rects["left"])
	var right_rect: Rect2 = Rect2(rects["right"])
	_draw_round_button(canvas, theme, left_rect, "<", bool(active.get("left", false)), true)
	_draw_round_button(canvas, theme, right_rect, ">", bool(active.get("right", false)), true)

	_draw_round_button(canvas, theme, Rect2(rects["brake"]), "BRAKE", bool(active.get("brake", false)), false)
	_draw_round_button(canvas, theme, Rect2(rects["throttle"]), "GO", bool(active.get("throttle", false)), false)
	_draw_small_button(canvas, theme, Rect2(rects["handbrake"]), "HANDBRAKE", bool(active.get("handbrake", false)))

	var course_label: String = "FIG 8" if course_name == "FIGURE 8" else ("AIR" if course_name == "AIRFIELD" else "ROUND")
	_draw_small_button(canvas, theme, Rect2(rects["theme"]), "SKIN", false, "skin")
	_draw_small_button(canvas, theme, Rect2(rects["course"]), course_label, false, "course")
	_draw_small_button(canvas, theme, Rect2(rects["data"]), "DATA", bool(active.get("data", false)), "data")
	_draw_small_button(canvas, theme, Rect2(rects["tune"]), "TUNE", bool(active.get("tune", false)), "tune")
	_draw_small_button(canvas, theme, Rect2(rects["preset"]), "CAR", false, "car")
	_draw_small_button(canvas, theme, Rect2(rects["reset"]), "RESET", false, "reset")

	if manual_mode:
		_draw_small_button(canvas, theme, Rect2(rects["shift_down"]), "GEAR -", false)
		_draw_small_button(canvas, theme, Rect2(rects["shift_up"]), "GEAR +", false)
	else:
		_draw_small_button(canvas, theme, Rect2(rects["shift_down"]), "-", false)
		_draw_small_button(canvas, theme, Rect2(rects["shift_up"]), "+", false)
	_draw_small_button(canvas, theme, Rect2(rects["transmission"]), gear_label, manual_mode)
	_draw_small_button(canvas, theme, Rect2(rects["weather"]), "FX ON" if weather_enabled else "FX OFF", weather_enabled)

func _draw_round_button(
	canvas: CanvasItem,
	theme: ThemeSystem,
	rect: Rect2,
	label: String,
	active: bool,
	is_steer: bool
) -> void:
	var centre: Vector2 = rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.5
	var fill: Color = theme.colour("ui_panel")
	fill.a = 0.62 if not active else 0.88
	var border: Color = theme.colour("accent2" if is_steer else "accent")
	border.a = 0.62 if not active else 1.0
	canvas.draw_circle(centre, radius, fill)
	canvas.draw_arc(centre, radius - 1.5, 0, TAU, 48, border, 2.5, true)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 28 if is_steer else 14
	var size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	canvas.draw_string(font, centre + Vector2(-size.x * 0.5, size.y * 0.34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, theme.colour("ui_text"))

func _draw_small_button(
	canvas: CanvasItem,
	theme: ThemeSystem,
	rect: Rect2,
	label: String,
	active: bool,
	icon_id: String = ""
) -> void:
	var fill: Color = theme.colour("ui_panel")
	fill.a = 0.68 if not active else 0.94
	var border: Color = theme.colour("accent")
	border.a = 0.50 if not active else 1.0
	_draw_panel(canvas, rect, fill, border, 8, 2)

	var icon: Texture2D = _ui_icon_texture(icon_id) if not icon_id.is_empty() else null
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10 if icon != null else 12
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	if icon != null:
		var icon_size: float = min(18.0, rect.size.y * 0.42)
		var content_width: float = icon_size + 6.0 + text_size.x
		var start_x: float = rect.get_center().x - content_width * 0.5
		var icon_rect: Rect2 = Rect2(
			Vector2(start_x, rect.get_center().y - icon_size * 0.5),
			Vector2(icon_size, icon_size)
		)
		canvas.draw_texture_rect(icon, icon_rect, false, theme.colour("ui_text"))
		var pos: Vector2 = Vector2(
			start_x + icon_size + 6.0,
			rect.get_center().y + text_size.y * 0.34
		)
		canvas.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, theme.colour("ui_text"))
	else:
		var pos2: Vector2 = rect.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
		canvas.draw_string(font, pos2, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, theme.colour("ui_text"))

func _draw_panel(
	canvas: CanvasItem,
	rect: Rect2,
	fill: Color,
	border: Color,
	_radius: int,
	border_width: int
) -> void:
	canvas.draw_rect(rect, fill, true)
	if border_width > 0:
		canvas.draw_rect(rect, border, false, float(border_width))

func _screen_rect_from_world(world_to_screen: Callable, world_rect: Rect2) -> Rect2:
	var a: Vector2 = world_to_screen.call(world_rect.position)
	var b: Vector2 = world_to_screen.call(world_rect.position + world_rect.size)
	return Rect2(a, b - a)

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
func draw_race_guidance(
	canvas: CanvasItem,
	theme: ThemeSystem,
	track: TrackModel,
	race: RaceSystem,
	world_to_screen: Callable,
	ppm: float,
	visual_time: float
) -> void:
	var gates: Array[Dictionary] = track.race_gates()
	if gates.is_empty():
		return

	for i: int in range(gates.size()):
		var gate: Dictionary = gates[i]
		var a: Vector2 = world_to_screen.call(Vector2(gate["a"]))
		var b: Vector2 = world_to_screen.call(Vector2(gate["b"]))
		var active: bool = i == race.next_checkpoint and race.state == "racing"
		var colour: Color = theme.colour("accent2" if active else "ui_muted")
		colour.a = 0.92 if active else 0.18
		var width: float = max(2.0, ppm * (0.10 if active else 0.045))
		if active:
			var glow: Color = colour
			glow.a = 0.13 + 0.05 * sin(visual_time * 5.0)
			canvas.draw_line(a, b, glow, max(9.0, ppm * 0.42), true)
		canvas.draw_line(a, b, colour, width, true)

	if race.state == "racing":
		var active_gate: Dictionary = gates[race.next_checkpoint]
		var centre: Vector2 = world_to_screen.call(Vector2(active_gate["position"]))
		var pulse: float = 12.0 + sin(visual_time * 4.5) * 3.0
		var ring: Color = theme.colour("accent2")
		ring.a = 0.72
		canvas.draw_arc(centre, max(15.0, ppm * 0.45 + pulse), 0, TAU, 40, ring, 2.0, true)

func draw_ghost_car(
	canvas: CanvasItem,
	theme: ThemeSystem,
	ghost: Dictionary,
	world_to_screen: Callable,
	ppm: float
) -> void:
	if ghost.is_empty():
		return
	var position: Vector2 = Vector2(ghost.get("position", Vector2.ZERO))
	var angle: float = float(ghost.get("angle", 0.0))
	var shape: Array[Vector2] = [
		Vector2(2.25, -0.72), Vector2(2.05, -0.91), Vector2(-1.85, -0.91),
		Vector2(-2.18, -0.66), Vector2(-2.18, 0.66), Vector2(-1.85, 0.91),
		Vector2(2.05, 0.91), Vector2(2.25, 0.72)
	]
	var points: PackedVector2Array = PackedVector2Array()
	for local: Vector2 in shape:
		points.append(world_to_screen.call(position + local.rotated(angle)))
	var fill: Color = theme.colour("accent")
	fill.a = 0.16
	var edge: Color = theme.colour("accent")
	edge.a = 0.52
	canvas.draw_colored_polygon(points, fill)
	canvas.draw_polyline(_closed(points), edge, max(1.5, ppm * 0.055), true)

	var nose: Vector2 = world_to_screen.call(position + Vector2(2.15, 0.0).rotated(angle))
	canvas.draw_circle(nose, max(2.0, ppm * 0.07), edge)

func draw_race_hud(
	canvas: CanvasItem,
	theme: ThemeSystem,
	race: RaceSystem,
	position_rank: int,
	ai_race: RaceSystem
) -> void:
	var font: Font = ThemeDB.fallback_font
	var bg: Color = theme.colour("ui_panel")
	bg.a = 0.90
	var border: Color = theme.colour("accent2")
	border.a = 0.62
	var text: Color = theme.colour("ui_text")
	var muted: Color = theme.colour("ui_muted")
	var accent: Color = theme.colour("accent2")

	var rect: Rect2 = Rect2(430, 18, 332, 142)
	_draw_panel(canvas, rect, bg, border, 10, 2)

	canvas.draw_string(font, Vector2(448, 45), "P%d / 2" % position_rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, accent)
	canvas.draw_string(font, Vector2(544, 45), "LAP %d / %d" % [min(race.current_lap, race.total_laps), race.total_laps], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text)

	var lap_value: String = race.format_time(race.lap_elapsed) if race.state != "countdown" else "--:--.---"
	canvas.draw_string(font, Vector2(448, 78), lap_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, text)

	canvas.draw_string(font, Vector2(448, 102), "BEST  " + race.format_time(race.best_lap_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, muted)
	canvas.draw_string(font, Vector2(448, 122), "LAST  " + race.format_time(race.last_lap_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, muted)

	var ghost_text: String = "GHOST ON" if race.best_ghost.size() > 1 else "NO GHOST YET"
	canvas.draw_string(font, Vector2(638, 102), ghost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, theme.colour("accent"))

	var sector_number: int = 4 if race.next_checkpoint == 0 else race.next_checkpoint
	canvas.draw_string(font, Vector2(638, 122), "S%d  %s" % [sector_number, race.format_time(race.last_sector_time)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, muted)
	var rival_lap: int = min(ai_race.current_lap, ai_race.total_laps)
	canvas.draw_string(font, Vector2(638, 138), "RIVAL L%d" % rival_lap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, muted)

	if race.state == "countdown":
		var label: String = race.countdown_text()
		var size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 88)
		var centre: Vector2 = canvas.get_viewport_rect().size * 0.5
		var shadow: Color = Color(0, 0, 0, 0.55)
		canvas.draw_string(font, centre + Vector2(-size.x * 0.5 + 4, size.y * 0.3 + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 88, shadow)
		canvas.draw_string(font, centre + Vector2(-size.x * 0.5, size.y * 0.3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 88, accent)
	elif race.event_message_time > 0.0 and not race.event_message.is_empty():
		var label2: String = race.event_message
		var size2: Vector2 = font.get_string_size(label2, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var centre2: Vector2 = Vector2(canvas.get_viewport_rect().size.x * 0.5, 180)
		var msg_bg: Color = theme.colour("ui_panel")
		msg_bg.a = 0.88
		var msg_rect: Rect2 = Rect2(centre2 - Vector2(size2.x * 0.5 + 18, 24), Vector2(size2.x + 36, 46))
		_draw_panel(canvas, msg_rect, msg_bg, Color(accent, 0.70), 8, 1)
		canvas.draw_string(font, centre2 + Vector2(-size2.x * 0.5, 8), label2, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, text)

	if race.state == "finished":
		var finish: String = "FINISHED  P%d" % position_rank
		var finish_size: Vector2 = font.get_string_size(finish, HORIZONTAL_ALIGNMENT_LEFT, -1, 42)
		var centre3: Vector2 = canvas.get_viewport_rect().size * 0.5
		var finish_rect: Rect2 = Rect2(centre3.x - finish_size.x * 0.5 - 28, centre3.y - 52, finish_size.x + 56, 88)
		_draw_panel(canvas, finish_rect, Color(theme.colour("ui_bg"), 0.95), Color(accent, 0.95), 12, 2)
		canvas.draw_string(font, Vector2(centre3.x - finish_size.x * 0.5, centre3.y + 8), finish, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, text)
func draw_rival_marker(
	canvas: CanvasItem,
	theme: ThemeSystem,
	position: Vector2,
	world_to_screen: Callable,
	ppm: float
) -> void:
	var centre: Vector2 = world_to_screen.call(position)
	var y_offset: float = max(22.0, ppm * 1.35)
	var tip: Vector2 = centre + Vector2(0, -y_offset + 12)
	var marker: Color = theme.colour("danger")
	var tri: PackedVector2Array = PackedVector2Array([
		tip,
		tip + Vector2(-6, -10),
		tip + Vector2(6, -10)
	])
	canvas.draw_colored_polygon(tri, marker)
	var font: Font = ThemeDB.fallback_font
	var label: String = "RIVAL"
	var size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	canvas.draw_string(font, tip + Vector2(-size.x * 0.5, -14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, marker)
