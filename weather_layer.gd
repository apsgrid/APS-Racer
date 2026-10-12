class_name WeatherLayer
extends Node2D

const TILE: float = 256.0

var themes: ThemeSystem
var phase: Vector2 = Vector2.ZERO
var effects_enabled: bool = true

func setup(next_themes: ThemeSystem) -> void:
	themes = next_themes
	z_as_relative = false
	z_index = -10
	set_process(true)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	queue_redraw()

func refresh_theme() -> void:
	phase = Vector2.ZERO
	position = Vector2.ZERO
	queue_redraw()

func set_effects_enabled(enabled: bool) -> void:
	effects_enabled = enabled
	visible = enabled
	set_process(enabled)
	if not enabled:
		phase = Vector2.ZERO
		position = Vector2.ZERO
	queue_redraw()

func _on_viewport_size_changed() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if themes == null or not effects_enabled:
		return
	if themes.id() == "brisbane_neon_rain":
		phase += Vector2(34.0, 185.0) * delta
	else:
		phase += Vector2(14.0, 5.0) * delta
	position = Vector2(fposmod(phase.x, TILE) - TILE, fposmod(phase.y, TILE) - TILE)

func _draw() -> void:
	if themes == null or not effects_enabled:
		return
	var view: Vector2 = get_viewport_rect().size
	var cols: int = int(ceil(view.x / TILE)) + 3
	var rows: int = int(ceil(view.y / TILE)) + 3

	if themes.id() == "brisbane_neon_rain":
		_draw_rain(cols, rows)
	else:
		_draw_dust(cols, rows)

func _draw_rain(cols: int, rows: int) -> void:
	var rain: Color = Color(0.72, 0.90, 1.0, 0.20)
	for tx: int in range(cols):
		for ty: int in range(rows):
			var origin: Vector2 = Vector2(float(tx - 1) * TILE, float(ty - 1) * TILE)
			for i: int in range(9):
				var x: float = fmod(float(i * 83 + tx * 41 + ty * 17), TILE)
				var y: float = fmod(float(i * 137 + tx * 23 + ty * 59), TILE)
				var p: Vector2 = origin + Vector2(x, y)
				draw_line(p, p + Vector2(-9.0, 22.0), rain, 1.0, true)

func _draw_dust(cols: int, rows: int) -> void:
	var dust: Color = themes.colour("effect")
	dust.a = 0.07
	for tx: int in range(cols):
		for ty: int in range(rows):
			var origin: Vector2 = Vector2(float(tx - 1) * TILE, float(ty - 1) * TILE)
			for i: int in range(4):
				var x: float = fmod(float(i * 113 + tx * 37 + ty * 19), TILE)
				var y: float = fmod(float(i * 59 + tx * 29 + ty * 47), TILE)
				var p: Vector2 = origin + Vector2(x, y)
				draw_circle(p, 1.0 + float(i % 3), dust)
