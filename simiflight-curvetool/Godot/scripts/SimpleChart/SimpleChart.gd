@tool
class_name SimpleChart
extends Control

# --- Visual Settings ---
@export_group("Colors")
@export var background_color: Color = Color(0.12, 0.12, 0.14, 1.0)
@export var grid_color: Color = Color(1, 1, 1, 0.15)
@export var axis_text_color: Color = Color(0.8, 0.8, 0.8, 1.0)
@export var zero_line_color_x: Color = Color(0.301, 0.0, 0.0, 0.5)
@export var zero_line_color_y: Color = Color(0.0, 0.166, 0.0, 0.5)
@export var plot_area_color: Color = Color(0.145, 0.145, 0.168, 1.0)

# NEW: Highlight Color
@export var highlight_range_color: Color = Color(1, 1, 1, 0.05)

@export_group("Layout")
@export var margin_left: float = 60.0
@export var margin_bottom: float = 40.0
@export var margin_top: float = 40.0
@export var margin_right: float = 20.0
@export var font_size: int = 14
@export var line_width: float = 1.0
@export var zero_line_width: float = 2.0
# --- Data State ---
@export_category("Domain")
@export var set_domain_from_inspector: bool = false
@export var min_x: float = -180.0
@export var max_x: float = 180.0
@export var min_y: float = -2.5
@export var max_y: float = 2.5

@export_group("Interaction")
@export var enable_zoom: bool = true
@export var zoom_sensitivity: float = 0.1
@export var auto_zoom_limit: bool = false
@export var max_zoom_factor: float = 100.0
@export var max_zoom_out: float = 1.0

# Manual Limits (used if auto_zoom_limit is false)
@export var min_range_x: float = 3.6
@export var max_range_x: float = 360.0
@export var min_range_y: float = 0.05
@export var max_range_y: float = 5.0

# NEW: Highlight Configuration
@export_group("Features")
@export var show_range_highlight: bool = false
@export var highlight_min_x: float = -180.0
@export var highlight_max_x: float = 180.0
@export var add_reset_button: bool = true
@export var reset_button_name: String = "R"
@export var reset_button_tooltip: String = "Reset View (Double Click Right Mouse Button)"


var initial_min_x: float = -180.0
var initial_max_x: float = 180.0
var initial_min_y: float = -2.5
var initial_max_y: float = 2.5

var _series: Array[Dictionary] = []

# --- Internal Nodes ---
var _plot_area: Control
var _default_font: Font

# --- Input State ---
var _dragging: bool = false
var _last_mouse_pos: Vector2

@export_tool_button("Add Reset Btn") var add_reset_btn = _set_chart_buttons

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_default_font = ThemeDB.get_fallback_font()

	_plot_area = Control.new()
	_plot_area.name = "PlotArea"
	_plot_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plot_area.clip_contents = true
	add_child(_plot_area)

	_plot_area.draw.connect(_on_plot_area_draw)
	if set_domain_from_inspector:
		set_domain(min_x, max_x, min_y, max_y)
		_update_layout()
	if add_reset_button:
		_set_chart_buttons()
	queue_redraw()

func _set_chart_buttons()-> void:
	var btn_hbox: = HBoxContainer.new()
	self.add_child(btn_hbox)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset_view_button: SquareButton = SquareButton.new()
	reset_view_button.text = reset_button_name
	reset_view_button.tooltip_text = reset_button_tooltip
	#reset_view_button.theme = self.theme
	reset_view_button.focus_mode = Control.FOCUS_NONE
	btn_hbox.add_child(reset_view_button)
	await self.get_tree().process_frame
	btn_hbox.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	btn_hbox.position.x = (self.size.x -(btn_hbox.size.x + margin_right+2.0))
	btn_hbox.position.y+= margin_top + 2.0
	reset_view_button.pressed.connect(func(): reset_zoom())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _update_layout() -> void:
	if not _plot_area: return
	_plot_area.position = Vector2(margin_left, margin_top)
	_plot_area.size = Vector2(size.x - margin_left - margin_right, size.y - margin_top - margin_bottom)
	queue_redraw()

# ------------------------------------------------------------------------------
# DRAWING: MAIN NODE (Grid, Text, Legend)
# ------------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	if not _plot_area: return
	var plot_rect = _plot_area.get_rect()

	# --- NEW: Draw Range Highlight (Behind Grid) ---
	if show_range_highlight:
		# Calculate screen positions for highlight bounds
		# We must check if they are visible
		var x_start = max(min_x, highlight_min_x)
		var x_end = min(max_x, highlight_max_x)

		# Only draw if there is an overlap
		if x_end > x_start:
			var screen_x_start = _map_x(x_start) + margin_left
			var screen_x_end = _map_x(x_end) + margin_left
			var rect_w = screen_x_end - screen_x_start

			# Draw the highlight inside the plot area vertical bounds
			draw_rect(Rect2(screen_x_start, margin_top, rect_w, plot_rect.size.y), highlight_range_color)


	# 1. Grid Steps
	var x_step = _calc_step_size(min_x, max_x, plot_rect.size.x / 80.0)
	var y_step = _calc_step_size(min_y, max_y, plot_rect.size.y / 50.0)

	# 2. X Grid & Labels
	var x_start_grid = floor(min_x / x_step) * x_step
	var curr_x = x_start_grid

	while curr_x <= max_x + 0.001:
		var screen_x = _map_x(curr_x) + margin_left
		if screen_x >= margin_left - 1.0 and screen_x <= size.x - margin_right + 1.0:
			var color = grid_color
			var width = line_width
			if is_equal_approx(curr_x, 0.0): color = zero_line_color_x
			if is_equal_approx(curr_x, 0.0): width = zero_line_width
			draw_line(Vector2(screen_x, margin_top), Vector2(screen_x, size.y - margin_bottom), color, width)

			var text = String.num(curr_x, 1)
			if abs(curr_x) < 0.001: text = "0"
			var text_size = _default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(_default_font, Vector2(screen_x - text_size.x/2, size.y - margin_bottom + text_size.y + 5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, axis_text_color)
		curr_x += x_step

	# 3. Y Grid & Labels
	var y_start_grid = floor(min_y / y_step) * y_step
	var curr_y = y_start_grid

	while curr_y <= max_y + 0.001:
		var screen_y = _map_y(curr_y) + margin_top
		if screen_y >= margin_top - 1.0 and screen_y <= size.y - margin_bottom + 1.0:
			var color = grid_color
			var width = line_width
			if is_equal_approx(curr_y, 0.0): color = zero_line_color_y
			if is_equal_approx(curr_y, 0.0): width = zero_line_width
			draw_line(Vector2(margin_left, screen_y), Vector2(size.x - margin_right, screen_y), color, width)

			var text = String.num(curr_y, 1)
			var text_size = _default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(_default_font, Vector2(margin_left - text_size.x - 10, screen_y + text_size.y/4), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, axis_text_color)
		curr_y += y_step

	# 4. Legend
	var legend_x = margin_left
	for s in _series:
		if not s.visible: continue
		var name_text: String = s.name
		var color = s.color
		draw_rect(Rect2(legend_x, 10, 10, 10), color)
		draw_string(_default_font, Vector2(legend_x + 15, 20), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, axis_text_color)
		var text_len: int = int(name_text.length() * (font_size * 0.7) + 30)
		legend_x += text_len
	draw_rect(plot_rect, plot_area_color, false, 2.0)
	_plot_area.queue_redraw()

# ------------------------------------------------------------------------------
# DRAWING: PLOT AREA
# ------------------------------------------------------------------------------
func _on_plot_area_draw() -> void:
	var plot_size = _plot_area.size

	for s in _series:
		if not s.visible or s.points.is_empty(): continue

		var polyline = PackedVector2Array()

		# --- EXTENSION LOGIC ---
		# To visually extend the curve "outside the domain", we simply need to rely on
		# the physics engine providing data outside -180..180.
		# If your data array already contains points like -200 or +200,
		# this loop handles them automatically and they will be drawn correctly
		# (just clipped by the view rectangle).

		for p in s.points:
			var px = _map_x_local(p.x, plot_size.x)
			var py = _map_y_local(p.y, plot_size.y)
			polyline.append(Vector2(px, py))

		if polyline.size() > 1:
			_plot_area.draw_polyline(polyline, s.color, s.width, true)

# ------------------------------------------------------------------------------
# MATH
# ------------------------------------------------------------------------------
func _map_x(val: float) -> float:
	var range_val = max_x - min_x
	if range_val == 0: range_val = 0.0001
	var t = (val - min_x) / range_val
	return t * _plot_area.size.x

func _map_y(val: float) -> float:
	var range_val = max_y - min_y
	if range_val == 0: range_val = 0.0001
	var t = (val - min_y) / range_val
	return _plot_area.size.y - (t * _plot_area.size.y)

func _map_x_local(val: float, width: float) -> float:
	var range_val = max_x - min_x
	if range_val == 0: range_val = 0.0001
	return ((val - min_x) / range_val) * width

func _map_y_local(val: float, height: float) -> float:
	var range_val = max_y - min_y
	if range_val == 0: range_val = 0.0001
	return height - (((val - min_y) / range_val) * height)

func _calc_step_size(range_min: float, range_max: float, desired_count: float) -> float:
	var rng = range_max - range_min
	if rng <= 0: return 1.0
	var raw_step = rng / max(desired_count, 1.0)
	var magnitude = pow(10, floor(log(raw_step) / log(10)))
	var residual = raw_step / magnitude
	if residual > 5.0: return 10.0 * magnitude
	if residual > 2.0: return 5.0 * magnitude
	if residual > 1.0: return 2.0 * magnitude
	return magnitude

# ------------------------------------------------------------------------------
# API
# ------------------------------------------------------------------------------
func add_series(series_name: String, points: Array, color: Color, width: float = 2.0) -> void:
	_series.append({ "name": series_name, "points": points, "color": color, "width": width, "visible": true })
	queue_redraw()

func clear_series() -> void:
	_series.clear()
	queue_redraw()

func set_domain(p_min_x: float, p_max_x: float, p_min_y: float, p_max_y: float) -> void:
	min_x = p_min_x
	max_x = p_max_x
	min_y = p_min_y
	max_y = p_max_y
	initial_min_x = p_min_x
	initial_max_x = p_max_x
	initial_min_y = p_min_y
	initial_max_y = p_max_y

	if auto_zoom_limit:
		_set_auto_zoom_limit()

	queue_redraw()

func set_series_visible(series_name: String, visibility: bool) -> void:
	for s in _series:
		if s.name == series_name:
			s.visible = visibility
			break
	queue_redraw()

func reset_zoom() -> void:
	set_domain(initial_min_x, initial_max_x, initial_min_y, initial_max_y)

func _set_auto_zoom_limit() -> void:
	max_range_x = (abs(initial_min_x) + initial_max_x) * max_zoom_out
	min_range_x = max_range_x / max_zoom_factor
	max_range_y = (abs(initial_min_y) + initial_max_y) * max_zoom_out
	min_range_y = max_range_y / max_zoom_factor

# ------------------------------------------------------------------------------
# INPUT
# ------------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if not enable_zoom: return

	# Pan (Middle/Right Mouse)
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT):
		if event.pressed:
			_dragging = true
			_last_mouse_pos = event.position
		else:
			_dragging = false

	# Reset (Double Right Click)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.double_click:
		reset_zoom()

	# Pan Logic
	if event is InputEventMouseMotion and _dragging:
		var delta = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		var px_x = (max_x - min_x) / _plot_area.size.x
		var px_y = (max_y - min_y) / _plot_area.size.y
		min_x -= delta.x * px_x
		max_x -= delta.x * px_x
		min_y += delta.y * px_y
		max_y += delta.y * px_y
		queue_redraw()

	# Zoom Logic
	if event is InputEventMouseButton and event.pressed:
		var factor = 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: factor = -zoom_sensitivity
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: factor = zoom_sensitivity

		if factor != 0.0:
			var current_range_x = max_x - min_x
			var current_range_y = max_y - min_y

			var new_range_x = current_range_x * (1.0 + factor)
			var new_range_y = current_range_y * (1.0 + factor)

			# Apply Zoom Limits
			if new_range_x < min_range_x: new_range_x = min_range_x
			if new_range_x > max_range_x: new_range_x = max_range_x
			if new_range_y < min_range_y: new_range_y = min_range_y
			if new_range_y > max_range_y: new_range_y = max_range_y

			var center_x = (min_x + max_x) * 0.5
			var center_y = (min_y + max_y) * 0.5

			min_x = center_x - (new_range_x * 0.5)
			max_x = center_x + (new_range_x * 0.5)
			min_y = center_y - (new_range_y * 0.5)
			max_y = center_y + (new_range_y * 0.5)

			queue_redraw()
