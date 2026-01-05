class_name WindTunnelView extends Control

# Data for drawing
var profile_points: Array[Vector2] = []
var alpha_deg: float = 0.0
var lift_force: float = 0.0
var drag_force: float = 0.0
var moment: float = 0.0
var cl_val: float = 0.0 # We need raw values for CoP calculation
var cm_val: float = 0.0
var cd_val: float = 0.0
# Settings
const ZOOM = 400.0 # Pixels per meter (Profile is usually normalized to 1m)
const CENTER_OFFSET = Vector2(0.5, 0.5) # Center of the control relative to size
var auto_scale_vectors: bool = true
# Colors
const COL_AIRFOIL = Color.GRAY
const COL_LIFT = Color.ROYAL_BLUE
const COL_DRAG = Color.FIREBRICK
const COL_RES = Color.GREEN_YELLOW
const COL_MOMENT = Color.ORANGE
const COL_WIND = Color(0.5, 0.8, 1.0, 0.3)

func update_state(alpha: float, l: float, d: float, m: float, raw_cl: float, raw_cm: float, raw_cd: float):
	alpha_deg = alpha
	lift_force = l
	drag_force = d
	moment = m
	# Store raw values for CoP calculation
	cl_val = raw_cl
	cm_val = raw_cm
	cd_val = raw_cd
	queue_redraw() # Triggers _draw() in the next frame

func _draw():
	var center_screen = size * CENTER_OFFSET
	var rot_rad = deg_to_rad(alpha_deg)

	# --- 1. Draw Profile (remains largely same) ---
	if profile_points.size() > 1:
			var draw_pts = PackedVector2Array()
			for p in profile_points:
				# FIX: Invert Y-axis!
				# Aerodynamic Y+ is Up, Godot Y+ is Down.
				# So we mirror p.y with -p.y
				var fixed_p = Vector2(p.x, -p.y)

				# Profile is usually 0..1 on X. We center it around (0.25, 0).
				var local_p = fixed_p - Vector2(0.25, 0.0)

				var rotated_p = local_p.rotated(rot_rad)
				var screen_p = center_screen + (rotated_p * ZOOM)
				draw_pts.append(screen_p)

			# Draw Profile Body
			var color_fill = Color(0.7, 0.7, 0.7, 0.5) # Semi-transparent gray
			draw_colored_polygon(draw_pts, color_fill)

			# Draw Outline (to keep it sharp)
			# draw_polyline needs points, doesn't need to be closed,
			# but since Start=End, it looks fine.
			draw_polyline(draw_pts, COL_AIRFOIL, 2.0, true)
			# Mark Aerodynamic Center (Pivot)
			draw_circle(center_screen, 4.0, Color.WHITE)

	# --- 2. Vectors (ALWAYS drawn at AC / Center) ---
	# We skip the yellow point (CoP).

	var force_origin = center_screen

	# Mark Aerodynamic Center
	draw_circle(center_screen, 4.0, Color.WHITE)

	# Lift (Blue)
	var vec_lift = Vector2(0, -lift_force * _get_scale_factor())
	var lift_string: String = str("Lift Force: %.2f, Cl: %.2f" % [lift_force, cl_val])
	_draw_arrow(force_origin, vec_lift, COL_LIFT, lift_string)

	# Drag (Red)
	var vec_drag = Vector2(drag_force * _get_scale_factor(), 0)
	var drag_string: String = str("Drag Force: %.2f, Cd: %.2f" % [drag_force, cd_val])
	_draw_arrow(force_origin, vec_drag, COL_DRAG, drag_string)

	# --- 3. Moment Visualization (Torque) ---
	# This is now the most important part for stability!

	if abs(moment) > 0.01:
		# We scale the radius or length of the arc with strength
		# A moment of e.g., 100 Nm should be clearly visible.

		# Direction: Positive Moment = Nose Up (Right rotation in Graph?)
		# In Godot Simulation: Z-Axis Rotation.
		# Here in 2D View:
		# Cm > 0 -> Pitch Up -> Nose moves "Up" (in local profile)

		var arc_color = COL_MOMENT
		var arc_radius = 50.0
		var arc_width = 3.0

		# Length of arc based on strength (visual feedback)
		# We cap it at a half-circle so it doesn't look wild
		var arc_angle = clamp(abs(moment) * 0.005, 0.2, PI)
		var start_angle = -PI/2 - (arc_angle / 2.0)
		var end_angle = -PI/2 + (arc_angle / 2.0)

		# Draw the Arc
		draw_arc(center_screen, arc_radius, start_angle, end_angle, 16, arc_color, arc_width)

		# Draw Arrow Tip at correct end
		# If Moment positive (Nose Up) -> Arrow points clockwise (or counter?)
		# Convention: Positive Cm = Pitch Up = Nose goes up.

		var tip_pos = Vector2.ZERO
		var tip_rot = 0.0

		if moment > 0:
			# Arrow tip at "right" end of arc (Nose Up)
			tip_pos = center_screen + Vector2(cos(end_angle), sin(end_angle)) * arc_radius
			tip_rot = end_angle + PI/2
		else:
			# Arrow tip at "left" end (Nose Down)
			tip_pos = center_screen + Vector2(cos(start_angle), sin(start_angle)) * arc_radius
			tip_rot = start_angle - PI/2

		_draw_triangle_tip(tip_pos, tip_rot, arc_color)

		# Label with Value
		draw_string(get_theme_default_font(), center_screen + Vector2(60, -60), "M: %.1f" % moment, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, arc_color)
		_draw_wind_lines()
# Helper for Moment Arrow Tip
func _draw_triangle_tip(pos: Vector2, rot: float, color: Color):
	var size_tri = 8.0
	var pts = PackedVector2Array()
	# A triangle pointing in direction 'rot'
	pts.append(pos + Vector2(size_tri, 0).rotated(rot))
	pts.append(pos + Vector2(-size_tri, size_tri*0.6).rotated(rot))
	pts.append(pos + Vector2(-size_tri, -size_tri*0.6).rotated(rot))
	draw_colored_polygon(pts, color)

# Helper to avoid doubling Scale Factor Code
func _get_scale_factor() -> float:
	if !auto_scale_vectors:
		return 1.0
	var max_force = max(abs(lift_force), abs(drag_force))
	if max_force > 0.001:
		return (size.y * 0.35) / max_force
	return 0.1



# --- Helper Drawing Functions ---

func _draw_arrow(start: Vector2, vec: Vector2, color: Color, label: String, width: float = 3.0, dashed: bool = false):
	if vec.length() < 1.0: return
	var end = start + vec

	if dashed:
		# Simple dashed line (optional)
		draw_line(start, end, color, width)
	else:
		draw_line(start, end, color, width)

	# Arrowhead
	var dir = vec.normalized()
	var arrow_size = 10.0
	var perp = Vector2(-dir.y, dir.x) * (arrow_size * 0.5)
	var tip_base = end - (dir * arrow_size)

	var pts = PackedVector2Array([tip_base + perp, end, tip_base - perp])
	draw_colored_polygon(pts, color)

	# Label
	if label != "":
		draw_string(get_theme_default_font(), end + vec.normalized() * 15, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)

func _draw_moment_arc(center: Vector2, mom_val: float, color: Color):
	var radius = 60.0
	var angle_start = -PI/2
	var angle_end = angle_start + (sign(mom_val) * PI * 0.5) # Quarter Circle
	var points = 16

	var pts = PackedVector2Array()
	for i in range(points + 1):
		var t = float(i) / points
		var ang = lerp(angle_start, angle_end, t)
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)

	draw_polyline(pts, color, 2.0)
	draw_string(get_theme_default_font(), center + Vector2(65, -65), "Moment", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _draw_wind_lines():
	var wind_color = COL_WIND
	var spacing = 40.0
	var offset_y = int(Time.get_ticks_msec() / 10.0) % int(spacing) # Animation!

	for i in range(-10, 10):
		var y = (size.y / 2) + (i * spacing) + offset_y
		# Draw short lines for wind from left
		if y > 0 and y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), wind_color, 1.0)
