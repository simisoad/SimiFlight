class_name WindTunnelView extends Control

# --- Configuration ---
@export var background_color: Color = Color(0.12, 0.12, 0.14, 1.0)
@export var airfoil_color: Color = Color.GRAY
@export var lift_color: Color = Color.CYAN
@export var drag_color: Color = Color.ORANGE
@export var moment_color: Color = Color.GREEN
@export var wind_color: Color = Color(1, 1, 1, 0.15)
@onready var reset_view: SquareButton = %ResetView

# --- State ---
var profile_points: Array[Vector2] = []
var profile_center: Vector2 = Vector2(0.5, 0.0)

var alpha_deg: float = 0.0
var lift_force: float = 0.0
var drag_force: float = 0.0
var moment: float = 0.0

var cl: float = 0.0
var cd: float = 0.0
var cm: float = 0.0

# Viewport Transform
var view_zoom: float = 300.0
var default_zoom: float = 0.0
# CHANGE: This is now relative to the screen center (0,0 = Centered)
var pan_offset: Vector2 = Vector2.ZERO

var _is_dragging: bool = false
var _last_mouse_pos: Vector2

# Wind Animation
var _wind_offset: float = 0.0
var _wind_speed_px: float = 50.0
var auto_scale_vectors: bool = true

func _ready() -> void:
	default_zoom = view_zoom
	clip_contents = true
	reset_view.pressed.connect(func(): view_zoom = default_zoom; pan_offset = Vector2.ZERO)
	# We DO NOT set view_offset here anymore.
	# The center is calculated dynamically in _draw().

func _process(delta: float) -> void:
	_wind_offset += delta * -_wind_speed_px
	if _wind_offset < -10000.0: _wind_offset += 10000.0
	queue_redraw()

# --- Public API ---
func update_state(alpha: float, l: float, d: float, m: float, raw_cl: float, raw_cd: float, raw_cm: float, airspeed: float = 50.0):
	alpha_deg = alpha
	lift_force = l
	drag_force = d
	moment = m
	cl = raw_cl
	cd = raw_cd
	cm = raw_cm
	_wind_speed_px = 20.0 + (airspeed * 2.5)
	queue_redraw()

func set_profile(points: Array[Vector2]):
	profile_points = points
	if points.is_empty():
		profile_center = Vector2(0.5, 0.0)
	else:
		var min_p = points[0]
		var max_p = points[0]
		for p in points:
			min_p.x = min(min_p.x, p.x)
			min_p.y = min(min_p.y, p.y)
			max_p.x = max(max_p.x, p.x)
			max_p.y = max(max_p.y, p.y)
		profile_center = (min_p + max_p) / 2.0
	queue_redraw()

# --- Drawing ---
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	# DYNAMIC CENTER CALCULATION
	# This ensures it is always centered, even if the container resizes 1 frame later.
	var screen_center = (size / 2.0) + pan_offset

	_draw_grid(screen_center)
	_draw_wind()

	# 1. Draw Airfoil
	var rot_rad = deg_to_rad(alpha_deg)

	if not profile_points.is_empty():
		var poly = PackedVector2Array()
		for p in profile_points:
			var local_p = Vector2(p.x - profile_center.x, -(p.y - profile_center.y))
			var rotated_p = local_p.rotated(rot_rad)
			poly.append(screen_center + (rotated_p * view_zoom))

		draw_colored_polygon(poly, Color(0.6, 0.6, 0.6, 0.8))
		poly.append(poly[0])
		draw_polyline(poly, airfoil_color, 2.0, true)

	# 2. Draw Aerodynamic Center
	draw_circle(screen_center, 4.0, Color.WHITE)

	# 3. Draw Vectors
	var scale_factor = 1.0
	if auto_scale_vectors:
		var max_f = max(abs(lift_force), abs(drag_force))
		if max_f > 0.1:
			scale_factor = (size.y * 0.35) / max_f
	else:
		scale_factor = 0.1

	var vec_l = Vector2(0, -lift_force * scale_factor)
	_draw_arrow(screen_center, vec_l, lift_color, "L: %.0f N" % lift_force)

	var vec_d = Vector2(drag_force * scale_factor, 0)
	_draw_arrow(screen_center, vec_d, drag_color, "D: %.0f N" % drag_force)

	_draw_moment(screen_center, moment, cm)

func _draw_grid(center_ref: Vector2):
	# Make the grid move with the pan
	var grid_step = 50.0
	var start_x = fmod(center_ref.x, grid_step) - grid_step
	var start_y = fmod(center_ref.y, grid_step) - grid_step
	var col = Color(1, 1, 1, 0.05)

	# Loop covers the whole screen, but offset by start_x/y
	for x in range(start_x, size.x, grid_step):
		draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0)
	for y in range(start_y, size.y, grid_step):
		draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)

func _draw_wind():
	var spacing = 40.0
	var gap = 60.0
	var dash_len = 30.0
	var shift_x = fmod(_wind_offset, gap + dash_len)

	var rng = RandomNumberGenerator.new()
	rng.seed = 1234

	var lines_y = range(0, size.y, spacing)

	for y in lines_y:
		var line_y = y + rng.randf_range(-5.0, 5.0)
		var x = -shift_x - 50.0
		while x < size.x:
			var dynamic_len = dash_len + (_wind_speed_px * 0.02)
			draw_line(Vector2(x, line_y), Vector2(x + dynamic_len, line_y), wind_color, 1.0)
			x += (gap + dynamic_len)

func _draw_arrow(origin: Vector2, vec: Vector2, color: Color, text: String):
	if vec.length() < 5.0: return
	var end = origin + vec
	draw_line(origin, end, color, 3.0)
	var dir = vec.normalized()
	var right = Vector2(-dir.y, dir.x)
	var arrow_sz = 10.0
	var pts = PackedVector2Array([
		end + (dir * 2),
		end - (dir * arrow_sz) + (right * arrow_sz * 0.5),
		end - (dir * arrow_sz) - (right * arrow_sz * 0.5)
	])
	draw_colored_polygon(pts, color)
	draw_string(get_theme_default_font(), end + (dir * 20), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)

func _draw_moment(center: Vector2, m: float, m_coeff: float):
	if abs(m) < 0.5: return
	var radius = 60.0
	var arc_len = clamp(abs(m) * 0.005, 0.4, PI)
	var start = -PI/2 - (arc_len/2)
	var end = -PI/2 + (arc_len/2)
	draw_arc(center, radius, start, end, 32, moment_color, 3.0)
	var tip_pos: Vector2
	var tip_rot: float
	if m > 0:
		tip_pos = center + Vector2(cos(end), sin(end)) * radius
		tip_rot = end + PI/2
	else:
		tip_pos = center + Vector2(cos(start), sin(start)) * radius
		tip_rot = start - PI/2
	var tri = PackedVector2Array([
		tip_pos + Vector2(0, -6).rotated(tip_rot),
		tip_pos + Vector2(-5, 6).rotated(tip_rot),
		tip_pos + Vector2(5, 6).rotated(tip_rot)
	])
	draw_colored_polygon(tri, moment_color)
	draw_string(get_theme_default_font(), center + Vector2(70, -40), "M: %.1f" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, moment_color)

# --- Input (Zoom / Pan) ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_dragging = true
				_last_mouse_pos = event.position
			else:
				_is_dragging = false
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.double_click:
				view_zoom = default_zoom
				pan_offset = Vector2.ZERO
				queue_redraw()

		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				view_zoom *= 1.1
				queue_redraw()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				view_zoom *= 0.9
				if view_zoom < 10.0: view_zoom = 10.0
				queue_redraw()

	if event is InputEventMouseMotion and _is_dragging:
		var delta = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		# Update Pan Offset instead of View Offset
		pan_offset += delta
		queue_redraw()
