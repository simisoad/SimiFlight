@tool
class_name SimpleChart extends Control

# --- Visual Settings ---
@export_group("Colors")
@export var background_color: Color = Color(0.12, 0.12, 0.14, 1.0)
@export var grid_color: Color = Color(1, 1, 1, 0.15)
@export var axis_text_color: Color = Color(0.8, 0.8, 0.8, 1.0)
@export var zero_line_color_x: Color = Color(0.301, 0.0, 0.0, 0.5)
@export var zero_line_color_y: Color = Color(0.0, 0.166, 0.0, 0.5)
@export var plot_area_color: Color = Color(0.145, 0.145, 0.168, 1.0)
@export var highlight_range_color: Color = Color(1, 1, 1, 0.05)

@export_group("Layout")
@export var x_label: String = ""
@export var y_label: String = ""
@export var lock_aspect_ratio: bool = false
@export var margin_left: float = 60.0
@export var margin_bottom: float = 60.0
@export var margin_top: float = 40.0
@export var margin_right: float = 60.0
@export var font_size: int = 14
@export var line_width: float = 1.0
@export var zero_line_width: float = 2.0

# --- Data State ---
@export_category("Domain")
@export var set_domain_from_inspector: bool = true
@export var min_x: float = -180.0
@export var max_x: float = 180.0
@export var min_y: float = -2.5
@export var max_y: float = 2.5

@export_group("Interaction")
@export var enable_zoom: bool = true
@export var zoom_sensitivity: float = 0.1
@export var auto_zoom_limit: bool = true
@export var max_zoom_factor: float = 50.0
@export var max_zoom_out: float = 4.0

# Manual Limits
@export var min_range_x: float = 3.6
@export var max_range_x: float = 360.0
@export var min_range_y: float = 0.05
@export var max_range_y: float = 5.0

@export_group("Features")
@export var show_range_highlight: bool = false
@export var highlight_min_x: float = -180.0
@export var highlight_max_x: float = 180.0
@export var add_reset_button: bool = true
@export var reset_button_name: String = "R"
@export var reset_button_tooltip: String = "Reset View (Double Click Right Mouse Button)"

# Internal Render State (The domain actually used for drawing)
var _draw_min_x: float
var _draw_max_x: float
var _draw_min_y: float
var _draw_max_y: float

var initial_min_x: float = -180.0
var initial_max_x: float = 180.0
var initial_min_y: float = -2.5
var initial_max_y: float = 2.5

var _series: Array[Dictionary] = []
var _markers: Array[Dictionary] = []
var _plot_area: Control
var _default_font: Font
var _dragging: bool = false
var _last_mouse_pos: Vector2

var DOWN_SAMPLING_THRESHOLD_WEB: int = 500

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
	else:
		initial_min_x = min_x; initial_max_x = max_x
		initial_min_y = min_y; initial_max_y = max_y

	if add_reset_button: _setup_reset_button()

	_update_layout()
	queue_redraw()

func _setup_reset_button()-> void:
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
	if what == NOTIFICATION_RESIZED: _update_layout()

func _update_layout() -> void:
	if not _plot_area: return
	_plot_area.position = Vector2(margin_left, margin_top)
	_plot_area.size = Vector2(size.x - margin_left - margin_right, size.y - margin_top - margin_bottom)
	queue_redraw()

func _recalc_render_domain() -> void:
	if not _plot_area: return

	# Default: Render exactly what the data says
	_draw_min_x = min_x
	_draw_max_x = max_x
	_draw_min_y = min_y
	_draw_max_y = max_y

	if lock_aspect_ratio and _plot_area.size.x > 1 and _plot_area.size.y > 1:
		var data_w = max_x - min_x
		var data_h = max_y - min_y
		if data_w <= 0 or data_h <= 0: return

		# Calculate Pixels Per Unit (PPU)
		var ppu_x = _plot_area.size.x / data_w
		var ppu_y = _plot_area.size.y / data_h

		# We must use the smaller PPU to fit the data without cropping
		var target_ppu = min(ppu_x, ppu_y)

		# Calculate the required visual range to fill the screen at this PPU
		var vis_w = _plot_area.size.x / target_ppu
		var vis_h = _plot_area.size.y / target_ppu

		var center_x = (min_x + max_x) * 0.5
		var center_y = (min_y + max_y) * 0.5

		_draw_min_x = center_x - vis_w * 0.5
		_draw_max_x = center_x + vis_w * 0.5
		_draw_min_y = center_y - vis_h * 0.5
		_draw_max_y = center_y + vis_h * 0.5

func _draw() -> void:
	# Calculate the render domain before drawing anything
	_recalc_render_domain()

	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	if not _plot_area: return

	# Labels
	if not x_label.is_empty():
		var string_size = _default_font.get_string_size(x_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var center_x = margin_left + (_plot_area.size.x / 2.0) - (string_size.x / 2.0)
		draw_string(_default_font, Vector2(center_x, size.y - 5.0), x_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, axis_text_color)

	if not y_label.is_empty():
		var string_size = _default_font.get_string_size(y_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var center_y = margin_top + (_plot_area.size.y / 2.0)
		draw_set_transform(Vector2(15.0, center_y), -PI/2.0, Vector2.ONE)
		draw_string(_default_font, Vector2(-string_size.x / 2.0, font_size / 3.0), y_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, axis_text_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Highlight
	if show_range_highlight:
		var x_start = max(_draw_min_x, highlight_min_x)
		var x_end = min(_draw_max_x, highlight_max_x)
		if x_end > x_start:
			var s_start = _map_x(x_start) + margin_left
			var s_end = _map_x(x_end) + margin_left
			draw_rect(Rect2(s_start, margin_top, s_end - s_start, _plot_area.size.y), highlight_range_color)

	# Grid
	var plot_rect = _plot_area.get_rect()
	var x_step = _calc_step_size(_draw_min_x, _draw_max_x, plot_rect.size.x / 80.0)
	var y_step = _calc_step_size(_draw_min_y, _draw_max_y, plot_rect.size.y / 50.0)

	var curr_x = floor(_draw_min_x / x_step) * x_step
	while curr_x <= _draw_max_x + 0.001:
		var sx = _map_x(curr_x) + margin_left
		if sx >= margin_left - 1.0 and sx <= size.x - margin_right + 1.0:
			var col = zero_line_color_x if is_equal_approx(curr_x, 0.0) else grid_color
			var w = zero_line_width if is_equal_approx(curr_x, 0.0) else line_width
			draw_line(Vector2(sx, margin_top), Vector2(sx, size.y - margin_bottom), col, w)

			var txt = "%.1f" % curr_x if abs(curr_x) >= 0.1 else "0"
			var ts = _default_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(_default_font, Vector2(sx - ts.x/2, size.y - margin_bottom + ts.y + 5), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, axis_text_color)
		curr_x += x_step

	var curr_y = floor(_draw_min_y / y_step) * y_step
	while curr_y <= _draw_max_y + 0.001:
		var sy = _map_y(curr_y) + margin_top
		if sy >= margin_top - 1.0 and sy <= size.y - margin_bottom + 1.0:
			var col = zero_line_color_y if is_equal_approx(curr_y, 0.0) else grid_color
			var w = zero_line_width if is_equal_approx(curr_y, 0.0) else line_width
			draw_line(Vector2(margin_left, sy), Vector2(size.x - margin_right, sy), col, w)

			var txt = "%.1f" % curr_y
			var ts = _default_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(_default_font, Vector2(margin_left - ts.x - 10, sy + ts.y/4), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, axis_text_color)
		curr_y += y_step

	# Legend (Fixed Spacing)
	var legend_x = margin_left
	for s in _series:
		if not s.series_visible: continue
		draw_rect(Rect2(legend_x, 10, 10, 10), s.color)
		draw_string(_default_font, Vector2(legend_x + 15, 20), s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, axis_text_color)
		var string_size = _default_font.get_string_size(s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		legend_x += 10 + 5 + string_size.x + 20

	draw_rect(_plot_area.get_rect(), plot_area_color, false, 2.0)
	_plot_area.queue_redraw()

func _on_plot_area_draw() -> void:
	var sz = _plot_area.size

	# Draw Series
	for s in _series:
		if not s.series_visible or s.points.is_empty(): continue
		var step = 1

		if s.points.size() > DOWN_SAMPLING_THRESHOLD_WEB and OS.has_feature("web"):
			step = s.points.size() / DOWN_SAMPLING_THRESHOLD_WEB # Downsample for rendering

		var poly = PackedVector2Array()
		for p in range(0, s.points.size(), step):
			var draw_point: Vector2 = s.points[p]
			poly.append(Vector2(_map_x_local(draw_point.x, sz.x), _map_y_local(draw_point.y, sz.y)))
		if poly.size() > 1:
			_plot_area.draw_polyline(poly, s.color, s.width, true)

	# Draw Markers
	for m in _markers:
		if not m.series_visible: continue

		var center = Vector2(_map_x_local(m.pos.x, sz.x), _map_y_local(m.pos.y, sz.y))
		# INFO: Set width to -1.0 if fill is true, to avoid annoying warning of the draw_circle method...
		var width: float = m.width
		if m.fill:
			width = -1.0
		_plot_area.draw_circle(center, m.radius, m.color, m.fill, width)

# --- Math Helpers ---
func _map_x(v: float) -> float:
	return ((v - _draw_min_x) / (_draw_max_x - _draw_min_x)) * _plot_area.size.x

func _map_y(v: float) -> float:
	return _plot_area.size.y - (((v - _draw_min_y) / (_draw_max_y - _draw_min_y)) * _plot_area.size.y)

func _map_x_local(v: float, w: float) -> float:
	return ((v - _draw_min_x) / (_draw_max_x - _draw_min_x)) * w

func _map_y_local(v: float, h: float) -> float:
	return h - (((v - _draw_min_y) / (_draw_max_y - _draw_min_y)) * h)

func _calc_step_size(min_v: float, max_v: float, count: float) -> float:
	var rng = max_v - min_v
	if rng <= 0: return 1.0
	var step = rng / max(count, 1.0)
	var mag = pow(10, floor(log(step) / log(10)))
	var res = step / mag
	if res > 5.0: return 10.0 * mag
	elif res > 2.0: return 5.0 * mag
	elif res > 1.0: return 2.0 * mag
	return mag


# --- Public API ---
func add_series(series_name: String, points: Array, color: Color, width: float = 2.0, series_visible: bool = true):
	_series.append({"name": series_name, "points": points, "color": color, "width": width, "series_visible": series_visible})
	#print(self.name, " , has %s series. " % _series.size())
	queue_redraw()

func add_marker(series_name: String, pos: Vector2, radius: float, color: Color, width: float, fill: bool, series_visible: bool = true):
	_markers.append({"name": series_name, "pos": pos, "radius": radius, "color": color, "width": width, "fill": fill, "series_visible": series_visible})
	#print(self.name, " , has %s markers. " % _markers.size())
	queue_redraw()

func clear_series(): _series.clear(); queue_redraw()
func clear_markers(): _markers.clear(); queue_redraw()

func set_series_visible(series_name: String, v: bool):
	for s in _series: if s.name == series_name: s.series_visible = v
	queue_redraw()

func set_marker_visible(series_name: String, v: bool):
	for m in _markers: if m.name == series_name: m.series_visible = v
	queue_redraw()

func set_domain(nx: float, xx: float, ny: float, xy: float):
	min_x = nx; max_x = xx; min_y = ny; max_y = xy
	initial_min_x = nx; initial_max_x = xx; initial_min_y = ny; initial_max_y = xy
	if auto_zoom_limit: _set_auto_zoom_limit()
	queue_redraw()

func reset_zoom():
	set_domain(initial_min_x, initial_max_x, initial_min_y, initial_max_y)

func _set_auto_zoom_limit():
	max_range_x = (abs(initial_min_x) + initial_max_x) * max_zoom_out
	min_range_x = max_range_x / max_zoom_factor
	max_range_y = (abs(initial_min_y) + initial_max_y) * max_zoom_out
	min_range_y = max_range_y / max_zoom_factor

# --- Input ---
func _gui_input(event: InputEvent) -> void:
	if not enable_zoom: return

	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
			_last_mouse_pos = event.position
			if event.double_click and event.button_index == MOUSE_BUTTON_RIGHT: reset_zoom()

		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor = zoom_sensitivity * (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			_zoom(factor)

	if event is InputEventMouseMotion and _dragging:
		var dx = event.position.x - _last_mouse_pos.x
		var dy = event.position.y - _last_mouse_pos.y
		_last_mouse_pos = event.position

		var x_scale = (max_x - min_x) / _plot_area.size.x
		var y_scale = (max_y - min_y) / _plot_area.size.y

		min_x -= dx * x_scale
		max_x -= dx * x_scale
		min_y += dy * y_scale
		max_y += dy * y_scale
		queue_redraw()

func _zoom(factor: float):
	var rx = max_x - min_x
	var ry = max_y - min_y
	var nx = rx * (1.0 + factor)
	var ny = ry * (1.0 + factor)

	# Clamp zoom
	if nx < min_range_x: nx = min_range_x
	if nx > max_range_x: nx = max_range_x
	if ny < min_range_y: ny = min_range_y
	if ny > max_range_y: ny = max_range_y

	var cx = (min_x + max_x) * 0.5
	var cy = (min_y + max_y) * 0.5

	min_x = cx - nx*0.5
	max_x = cx + nx*0.5
	min_y = cy - ny*0.5
	max_y = cy + ny*0.5
	queue_redraw()
