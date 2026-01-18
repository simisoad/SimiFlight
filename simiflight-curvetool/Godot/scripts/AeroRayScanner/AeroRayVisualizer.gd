
@tool
class_name AeroRayVisualizer extends Control

# --- Configuration ---
@export var background_color: Color = Color(0.122, 0.122, 0.141, 1.0)
@export var ray_color_clean: Color = Color(0.004, 0.0, 0.824, 1.0)
@export var ray_color_impact: Color = Color(1.0, 0.3, 0.1, 0.9)
@export var ray_color_trapped: Color = Color(1.0, 0.349, 0.0, 0.702)
@export var normal_color: Color = Color(0.0, 1.0, 0.0, 0.6)
@onready var input_num_rays: SpinBoxExtended = %NumRays
@onready var input_ray_spacing_multiplier: SpinBoxExtended = %RaySpacingMultiplier
@onready var input_alpha: HSlider = %Alpha
# --- State ---
var profile_points: Array[Vector2] = []

@onready var alpha_deg: float = input_alpha.value:
	set(v):
		alpha_deg = v
		queue_redraw()

@onready var num_rays: int = int(input_num_rays.value):
	set(v):
		num_rays = v;
		queue_redraw()

@onready var ray_spacing_multiplier: float = input_ray_spacing_multiplier.value:
	set(v):
		ray_spacing_multiplier = v;
		queue_redraw()

var view_zoom: float = 400.0
var default_zoom: float = 400.0
var pan_offset: Vector2 = Vector2.ZERO
var default_offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

func _ready() -> void:
	clip_contents = true
	input_alpha.value_changed.connect(func(v): alpha_deg = v)
	input_num_rays.value_changed.connect(func(v): num_rays = v)
	input_ray_spacing_multiplier.value_changed.connect(func(v): ray_spacing_multiplier = v)

func set_profile(profile: AirfoilProfile):
	profile_points.clear()
	var up = profile.upper_surface.duplicate()
	up.reverse()
	profile_points.append_array(up)
	profile_points.append_array(profile.lower_surface)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	if profile_points.is_empty(): return

	var center = size / 2.0 + pan_offset
	var alpha_rad = deg_to_rad(alpha_deg)

	# 1. Transform Polygon (FIXED Y-FLIP)
	var poly = PackedVector2Array()
	for p in profile_points:
		# We negate p.y to convert from Aero-Up to Godot-Down
		var p_aero = Vector2(p.x - 0.25, -p.y)
		var p_rot = p_aero.rotated(alpha_rad)
		poly.append(center + p_rot * view_zoom)

	# 2. Draw Airfoil
	draw_colored_polygon(poly, Color(1, 1, 1, 0.03))
	draw_polyline(poly, Color(1, 1, 1, 0.4), 1.5, true)

	# 3. Advanced Ray Analysis
	_analyze_flow(center, poly)

func _analyze_flow(center: Vector2, poly: PackedVector2Array):
	var ray_x_start = center.x - view_zoom * 1.0
	var ray_x_end = center.x + view_zoom * 1.0
	var ray_spread = view_zoom * ray_spacing_multiplier

	var total_impact_pressure = 0.0
	var concavity_count = 0
	var hit_y_min = 9999.0
	var hit_y_max = -9999.0

	for i in range(num_rays):
		var y = center.y + lerp(-ray_spread, ray_spread, float(i) / (num_rays - 1))
		var ray_start = Vector2(ray_x_start, y)
		var ray_end = Vector2(ray_x_end, y)

		var intersections = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([ray_start, ray_end]), poly)

		if intersections.size() > 0:
			# Track projected height
			hit_y_min = min(hit_y_min, y); hit_y_max = max(hit_y_max, y)

			for j in range(intersections.size()):
				var segment = intersections[j]
				var p_impact = segment[0]
				var p_exit = segment[1]

				# A. Draw Incoming Ray
				if j == 0:
					draw_line(ray_start, p_impact, ray_color_clean, 1.0,true)

				# B. Calculate Normal at Impact
				var normal = _get_surface_normal(p_impact, poly)
				_draw_normal_vector(p_impact, normal)

				# C. Newtonian Pressure Calculation
				# Wind direction is Vector2(1, 0). Angle between wind and normal:
				var dot = normal.dot(Vector2(-1, 0)) # Normal points OUT, wind points RIGHT
				var pressure = pow(max(0.0, dot), 2.0)
				total_impact_pressure += pressure

				# D. Visualize Impact Intensity
				var impact_col = ray_color_impact
				impact_col.a = 0.2 + pressure * 0.8
				draw_circle(p_impact, 2.0 + pressure * 3.0, impact_col)

				# E. Concavity (Multiple entries)
				if intersections.size() > 1:
					if j > 0: # This is a re-entry point
						draw_line(intersections[j-1][1], p_impact, ray_color_trapped, 2.0, true)
						concavity_count += 1

	var projected_height = (hit_y_max - hit_y_min) / view_zoom if hit_y_max > -9000 else 0.0
	_draw_debug_ui(projected_height, total_impact_pressure / num_rays, concavity_count)

func _get_surface_normal(point: Vector2, poly: PackedVector2Array) -> Vector2:
	# Find the closest segment in the polygon to get the normal
	var closest_normal = Vector2.UP
	var min_dist = 9999.0

	for i in range(poly.size()):
		var p1 = poly[i]
		var p2 = poly[(i + 1) % poly.size()]
		var closest = Geometry2D.get_closest_point_to_segment(point, p1, p2)
		var d = point.distance_to(closest)
		if d < min_dist:
			min_dist = d
			var tangent = (p2 - p1).normalized()
			closest_normal = Vector2(-tangent.y, tangent.x) # Rotate 90 deg
	return closest_normal

func _draw_normal_vector(pos: Vector2, normal: Vector2):
	var normal_vec_scale: float = 100.0
	draw_line(pos, pos + normal * normal_vec_scale, normal_color, 2.0, true)

func _draw_debug_ui(height: float, press: float, conc: int):
	var font = get_theme_default_font()
	var text = "DIAGNOSTICS:\n"
	text += "Projected Height: %.3f c\n" % height
	text += "Newtonian Impact: %.3f\n" % press
	text += "Concave Zones: %d" % conc
	draw_multiline_string(font, Vector2(20, 40), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, -1, Color.CYAN)

# --- Input (Middle Mouse Pan, Wheel Zoom) ---
func _gui_input(event: InputEvent):
	if event.is_action_pressed(&"reset_zoom_chart") and event.double_click:
		view_zoom = default_zoom
		pan_offset = default_offset
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: view_zoom *= 1.1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: view_zoom *= 0.9
		queue_redraw()

	if event is InputEventMouseButton:
		if event.is_action_pressed(&"pan_chart"):
			_is_dragging = true
		elif event.is_action_released(&"pan_chart"):
			_is_dragging = false
	if _is_dragging:
		if event is InputEventMouseMotion:
			pan_offset += event.relative
			queue_redraw()
