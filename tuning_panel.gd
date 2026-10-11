class_name TuningPanel
extends CanvasLayer

signal car_selected(index: int)

const USER_PRESETS_PATH: String = "user://aps_racer_handling_presets.json"

var sim: VehicleSim
var panel: PanelContainer
var car_selector: OptionButton
var preset_name: LineEdit
var saved_selector: OptionButton
var status_label: Label
var controls: Dictionary = {}
var _syncing: bool = false

func setup(target_sim: VehicleSim) -> void:
	sim = target_sim
	layer = 50
	_build_ui()
	_refresh_saved_list()
	sync_from_sim()
	set_open(false)

func is_open() -> bool:
	return panel != null and panel.visible

func toggle() -> void:
	set_open(not is_open())

func set_open(value: bool) -> void:
	if panel == null:
		return
	panel.visible = value
	if value:
		sync_from_sim()

func sync_from_sim() -> void:
	if sim == null or panel == null:
		return
	_syncing = true
	car_selector.select(sim.preset_index)
	preset_name.text = sim.preset_name
	var values: Dictionary = sim.get_tunable_values()
	for schema: Dictionary in sim.tuning_schema():
		var key: String = String(schema["key"])
		if not controls.has(key):
			continue
		var display_value: float = _to_display(float(values[key]), schema)
		var pair: Dictionary = controls[key]
		(pair["slider"] as HSlider).value = display_value
		(pair["spin"] as SpinBox).value = display_value
	_syncing = false

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "HandlingLab"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -610.0
	panel.offset_right = -14.0
	panel.offset_top = 14.0
	panel.offset_bottom = -14.0
	add_child(panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.055, 0.96)
	style.border_color = Color(0.55, 0.72, 0.84, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var header: HBoxContainer = HBoxContainer.new()
	outer.add_child(header)
	var title: Label = Label.new()
	title.text = "HANDLING LAB"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button: Button = Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(func() -> void: set_open(false))
	header.add_child(close_button)

	var help: Label = Label.new()
	help.text = "Live tuning. Driving input is disabled while this panel is open."
	help.modulate = Color(0.78, 0.84, 0.9)
	outer.add_child(help)

	var car_row: HBoxContainer = HBoxContainer.new()
	outer.add_child(car_row)
	var car_label: Label = Label.new()
	car_label.text = "Base car"
	car_label.custom_minimum_size.x = 110.0
	car_row.add_child(car_label)
	car_selector = OptionButton.new()
	car_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(sim.get_preset_count()):
		car_selector.add_item(String(VehicleSim.FALLBACK_PRESETS[i]["name"]), i)
	car_selector.item_selected.connect(_on_car_selected)
	car_row.add_child(car_selector)

	var name_row: HBoxContainer = HBoxContainer.new()
	outer.add_child(name_row)
	var name_label: Label = Label.new()
	name_label.text = "Preset name"
	name_label.custom_minimum_size.x = 110.0
	name_row.add_child(name_label)
	preset_name = LineEdit.new()
	preset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_name.placeholder_text = "e.g. RWD Neutral v3"
	name_row.add_child(preset_name)

	var save_row: HBoxContainer = HBoxContainer.new()
	outer.add_child(save_row)
	saved_selector = OptionButton.new()
	saved_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(saved_selector)
	var save_button: Button = Button.new()
	save_button.text = "SAVE"
	save_button.pressed.connect(_save_named_preset)
	save_row.add_child(save_button)
	var load_button: Button = Button.new()
	load_button.text = "LOAD"
	load_button.pressed.connect(_load_selected_preset)
	save_row.add_child(load_button)
	var delete_button: Button = Button.new()
	delete_button.text = "DELETE"
	delete_button.pressed.connect(_delete_selected_preset)
	save_row.add_child(delete_button)

	var action_row: HBoxContainer = HBoxContainer.new()
	outer.add_child(action_row)
	var reset_button: Button = Button.new()
	reset_button.text = "RESET TO BAKED"
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_reset_to_baked)
	action_row.add_child(reset_button)
	var copy_button: Button = Button.new()
	copy_button.text = "COPY VALUES"
	copy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_button.pressed.connect(_copy_values)
	action_row.add_child(copy_button)
	var bake_button: Button = Button.new()
	bake_button.text = "BAKE CURRENT"
	bake_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bake_button.pressed.connect(_bake_current)
	action_row.add_child(bake_button)

	var separator: HSeparator = HSeparator.new()
	outer.add_child(separator)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(grid)

	for schema: Dictionary in sim.tuning_schema():
		_add_tuning_row(grid, schema)

	status_label = Label.new()
	status_label.text = "LIVE — baked baseline loaded"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.modulate = Color(0.65, 0.9, 0.7)
	outer.add_child(status_label)

func _add_tuning_row(grid: GridContainer, schema: Dictionary) -> void:
	var key: String = String(schema["key"])
	var label: Label = Label.new()
	label.text = String(schema["label"])
	label.tooltip_text = key
	label.custom_minimum_size.x = 145.0
	grid.add_child(label)

	var value_row: HBoxContainer = HBoxContainer.new()
	value_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value_row)

	var slider: HSlider = HSlider.new()
	slider.min_value = float(schema["min"])
	slider.max_value = float(schema["max"])
	slider.step = float(schema["step"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 220.0
	value_row.add_child(slider)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = float(schema["min"])
	spin.max_value = float(schema["max"])
	spin.step = float(schema["step"])
	spin.custom_minimum_size.x = 112.0
	spin.allow_greater = false
	spin.allow_lesser = false
	value_row.add_child(spin)

	var unit: String = String(schema.get("unit", ""))
	if not unit.is_empty():
		var unit_label: Label = Label.new()
		unit_label.text = unit
		unit_label.custom_minimum_size.x = 58.0
		value_row.add_child(unit_label)

	controls[key] = {"slider": slider, "spin": spin, "schema": schema}
	slider.value_changed.connect(func(value: float) -> void: _on_slider_changed(key, value))
	spin.value_changed.connect(func(value: float) -> void: _on_spin_changed(key, value))

func _on_slider_changed(key: String, value: float) -> void:
	if _syncing:
		return
	var pair: Dictionary = controls[key]
	_syncing = true
	(pair["spin"] as SpinBox).value = value
	_syncing = false
	_apply_display_value(key, value, pair["schema"])

func _on_spin_changed(key: String, value: float) -> void:
	if _syncing:
		return
	var pair: Dictionary = controls[key]
	_syncing = true
	(pair["slider"] as HSlider).value = value
	_syncing = false
	_apply_display_value(key, value, pair["schema"])

func _apply_display_value(key: String, display_value: float, schema: Dictionary) -> void:
	sim.set(key, _from_display(display_value, schema))
	_set_status("LIVE — unsaved changes", Color(1.0, 0.8, 0.42))

func _to_display(value: float, schema: Dictionary) -> float:
	if bool(schema.get("degrees", false)):
		return rad_to_deg(value)
	return value * float(schema.get("scale", 1.0))

func _from_display(value: float, schema: Dictionary) -> float:
	if bool(schema.get("degrees", false)):
		return deg_to_rad(value)
	return value / float(schema.get("scale", 1.0))

func _on_car_selected(index: int) -> void:
	if _syncing:
		return
	car_selected.emit(index)

func _save_named_preset() -> void:
	var clean_name: String = preset_name.text.strip_edges()
	if clean_name.is_empty():
		_set_status("Give the preset a name first.", Color(1.0, 0.45, 0.4))
		return

	var database: Dictionary = _load_database()
	var presets: Dictionary = Dictionary(database.get("presets", {}))
	presets[clean_name] = {
		"base_index": sim.preset_index,
		"base_name": sim.preset_name,
		"values": sim.get_tunable_values(),
		"saved_at": Time.get_datetime_string_from_system()
	}
	database["version"] = 1
	database["presets"] = presets
	if _write_database(database):
		_refresh_saved_list(clean_name)
		_set_status("Saved preset: " + clean_name, Color(0.55, 1.0, 0.65))
	else:
		_set_status("Could not save preset file.", Color(1.0, 0.45, 0.4))

func _load_selected_preset() -> void:
	if saved_selector.item_count == 0:
		_set_status("No saved presets yet.", Color(1.0, 0.75, 0.4))
		return
	var name: String = saved_selector.get_item_text(saved_selector.selected)
	var database: Dictionary = _load_database()
	var presets: Dictionary = Dictionary(database.get("presets", {}))
	if not presets.has(name):
		_refresh_saved_list()
		return
	var record: Dictionary = Dictionary(presets[name])
	var base_index: int = int(record.get("base_index", sim.preset_index))
	car_selected.emit(base_index)
	sim.preset_name = name
	sim.apply_tunable_values(Dictionary(record.get("values", {})))
	preset_name.text = name
	sync_from_sim()
	preset_name.text = name
	_set_status("Loaded preset: " + name, Color(0.55, 0.86, 1.0))

func _delete_selected_preset() -> void:
	if saved_selector.item_count == 0:
		return
	var name: String = saved_selector.get_item_text(saved_selector.selected)
	var database: Dictionary = _load_database()
	var presets: Dictionary = Dictionary(database.get("presets", {}))
	if presets.erase(name):
		database["presets"] = presets
		_write_database(database)
		_refresh_saved_list()
		_set_status("Deleted preset: " + name, Color(1.0, 0.72, 0.45))

func _reset_to_baked() -> void:
	sim.reset_to_baked()
	preset_name.text = sim.preset_name
	sync_from_sim()
	_set_status("Reset to baked baseline.", Color(0.65, 0.9, 0.7))

func _copy_values() -> void:
	var clean_name: String = preset_name.text.strip_edges()
	if clean_name.is_empty():
		clean_name = sim.preset_name
	var payload: Dictionary = {
		"slot": sim.preset_index,
		"name": clean_name,
		"values": sim.get_tunable_values()
	}
	DisplayServer.clipboard_set(JSON.stringify(payload, "\t"))
	_set_status("Current values copied to clipboard.", Color(0.55, 0.86, 1.0))

func _bake_current() -> void:
	var clean_name: String = preset_name.text.strip_edges()
	if not clean_name.is_empty():
		sim.preset_name = clean_name
	var result: Dictionary = sim.bake_current_to_project()
	if bool(result.get("ok", false)):
		_set_status("BAKED: " + String(result.get("path", "")), Color(0.5, 1.0, 0.58))
	else:
		_copy_values()
		_set_status(String(result.get("message", "Bake failed")) + " Values copied.", Color(1.0, 0.72, 0.35))

func _refresh_saved_list(select_name: String = "") -> void:
	if saved_selector == null:
		return
	saved_selector.clear()
	var database: Dictionary = _load_database()
	var presets: Dictionary = Dictionary(database.get("presets", {}))
	var names: Array = presets.keys()
	names.sort()
	for name: Variant in names:
		saved_selector.add_item(String(name))
	if not select_name.is_empty():
		for i: int in range(saved_selector.item_count):
			if saved_selector.get_item_text(i) == select_name:
				saved_selector.select(i)
				break

func _load_database() -> Dictionary:
	if not FileAccess.file_exists(USER_PRESETS_PATH):
		return {"version": 1, "presets": {}}
	var file: FileAccess = FileAccess.open(USER_PRESETS_PATH, FileAccess.READ)
	if file == null:
		return {"version": 1, "presets": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {"version": 1, "presets": {}}

func _write_database(database: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(USER_PRESETS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(database, "\t"))
	return true

func _set_status(text: String, colour: Color) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.modulate = colour
