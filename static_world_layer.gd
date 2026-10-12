class_name StaticWorldLayer
extends Node2D

const BASE_PPM: float = 25.0

var visuals: VisualRenderer
var themes: ThemeSystem
var track: TrackModel

func setup(next_visuals: VisualRenderer, next_themes: ThemeSystem, next_track: TrackModel) -> void:
	visuals = next_visuals
	themes = next_themes
	track = next_track
	z_as_relative = false
	z_index = -100
	queue_redraw()

func update_camera(camera_world: Vector2, pixels_per_meter: float, viewport_size: Vector2) -> void:
	var s: float = pixels_per_meter / BASE_PPM
	scale = Vector2(s, s)
	position = viewport_size * 0.5 - camera_world * pixels_per_meter

func refresh_theme() -> void:
	queue_redraw()

func _world_to_local(world_pos: Vector2) -> Vector2:
	return world_pos * BASE_PPM

func _world_points_to_local(world_points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	result.resize(world_points.size())
	for i: int in range(world_points.size()):
		result[i] = world_points[i] * BASE_PPM
	return result

func _draw() -> void:
	if visuals == null or themes == null or track == null:
		return
	draw_rect(Rect2(-10000.0, -10000.0, 20000.0, 20000.0), themes.colour("ground"), true)
	visuals.draw_static_world(
		self,
		themes,
		track,
		Callable(self, "_world_to_local"),
		Callable(self, "_world_points_to_local"),
		BASE_PPM
	)
