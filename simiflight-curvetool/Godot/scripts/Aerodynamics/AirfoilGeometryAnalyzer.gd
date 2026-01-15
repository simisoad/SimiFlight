class_name AirfoilGeometryAnalyzer
extends RefCounted

# --- TUNING PARAMETERS (Changed from CONST to STATIC VAR) ---
static var base_stall_deg: float = 8.0
static var stall_radius_factor: float = 7.0
static var stall_thickness_factor: float = 5.0
static var stall_shape_factor: float = 8.0
static var stall_fwd_camber_penalty: float = 15.0
static var stall_bwd_camber_penalty: float = 35.0
static var stall_peak_pos_penalty: float = 8.0

# Limits
static var min_stall_angle: float = 2.0
static var max_stall_angle: float = 25.0
# 0.0025 = 0.25% thickness.
static var MIN_PHYSICAL_THICKNESS = 0.0025

static var MAX_STEPS_AREA_CALC_WEB: float = 150
static var MAX_STEPS_AREA_CALC: float = 500


static func analyze(profile: AirfoilProfile) -> Dictionary:
	# 1. Sanitize Data (Sort by X)
	var upper = _prepare_surface(profile.upper_surface)
	var lower = _prepare_surface(profile.lower_surface)

	if upper.is_empty() or lower.is_empty(): return {}

	# 2. Analyze Geometry (Robust)
	var geo = _analyze_geometry_robust(upper, lower)

	#print("Airfoil: %s result from _analyze_geometry_robust:" % profile.name)
	#for entry in geo:
		#print(entry, ": ", geo[entry])
	# 3. Integrals
	var alpha_0 = calculate_alpha_0(upper, lower)
	var cm_0 = _calculate_cm0_integrated(upper, lower)

	# --- STALL PREDICTION (DYNAMIC) ---

	# 1. Calculate Nose Ratio (Bluntness vs Thickness)
	# Airfoils are usually around 0.25 - 0.35.
	# Bricks/Tubes are 0.9 - 1.0.
	var safe_thick = max(geo.max_thick, 0.001)
	var nose_ratio = geo.le_bluntness / safe_thick
	var tail_ratio = geo.te_bluntness / safe_thick

	# 2. Dynamic Bluntness Penalty
	# We start penalizing if the nose is wider than 50% of the max thickness.
	# smoothstep(0.4, 0.9, ratio) -> transitions from Airfoil to Brick.
	var blunt_factor_fwd = smoothstep(0.4, 0.9, nose_ratio)
	var le_sharpness_penalty = blunt_factor_fwd * 20.0 # Max 20 deg penalty for bricks

	var stall_fwd = _calculate_stall_angle(
		geo.le_radius_norm,
		geo.max_thick,
		geo.fullness_factor,
		geo.pos_max_thick_x,
		geo.max_camber,
		true
	) - le_sharpness_penalty

	# 3. Dynamic Backward Penalty (Symmetrical logic)
	var blunt_factor_bwd = smoothstep(0.4, 0.9, tail_ratio)
	var te_sharpness_penalty = blunt_factor_bwd * 20.0

	var stall_back = _calculate_stall_angle(
		geo.te_radius_norm,
		geo.max_thick,
		geo.fullness_factor,
		geo.pos_max_thick_x,
		geo.max_camber,
		false
	) - te_sharpness_penalty

	return {
		"fore_aft_symmetry": geo.fore_aft_symmetry,
		"thickness": geo.max_thick,
		"pos_max_thick_x": geo.pos_max_thick_x,
		"camber": geo.max_camber,
		"centroid_x": geo.centroid_x,
		"le_radius": geo.le_radius,
		"le_tip_thickness": geo.le_tip_thickness,
		"le_bluntness": geo.le_bluntness,
		"te_radius": geo.te_radius_norm,
		"te_openness": geo.te_openness,
		"te_bluntness": geo.te_bluntness,
		"rectangularity": geo.rectangularity,
		"alpha_0": alpha_0,
		"cm_0": cm_0,
		"stall_angle_fwd": stall_fwd,
		"stall_angle_back": stall_back
	}

static func _calculate_stall_angle(radius_norm: float, thickness: float, fullness: float, peak_x: float, camber: float, is_forward: bool) -> float:
	var base = base_stall_deg

	var val_radius = sqrt(clamp(radius_norm, 0.0, 0.1) / 0.02) * stall_radius_factor
	var val_thick = thickness * stall_thickness_factor
	var val_shape = max(0.0, fullness - 0.5) * stall_shape_factor
	var val_peak_penalty = max(0.0, peak_x - 0.30) * stall_peak_pos_penalty

	# DYNAMIC THICKNESS PENALTY (Corrected for Joukowski)
	# 30% thick wings DO fly (e.g. root sections), they just stall earlier.
	# We push the penalty start to 0.25 and make it less aggressive.

	# Range: 25% to 45% thickness
	var thick_factor = smoothstep(0.25, 0.45, thickness)
	var thick_penalty = thick_factor * 15.0 # Max 15 deg penalty, not 40 or 50.

	var val_camber_penalty = 0.0
	if is_forward:
		val_camber_penalty = abs(camber) * stall_fwd_camber_penalty
	else:
		val_camber_penalty = abs(camber) * stall_bwd_camber_penalty

	var total = base + val_radius + val_thick + val_shape - val_peak_penalty - val_camber_penalty - thick_penalty

	# Ensure we never return a negative stall angle for the base geometry
	return clamp(total, min_stall_angle, max_stall_angle)

static func _analyze_geometry_robust(upper: Array[Vector2], lower: Array[Vector2]) -> Dictionary:
	# 1. DETERMINE ACTUAL CHORD LENGTH
	var min_x = 1000.0
	var max_x = -1000.0

	# Combine arrays to find bounds
	var all_points = upper + lower
	for p in all_points:
		if p.x < min_x: min_x = p.x
		if p.x > max_x: max_x = p.x

	var chord_length = max_x - min_x
	if chord_length <= 0.0001: chord_length = 1.0 # Prevent div/0

	var scale_factor = 1.0 / chord_length

	# 2. MAX THICKNESS SCAN (Normalized)
	var max_thick = 0.0
	var pos_max_thick_x = 0.3
	var max_camber = 0.0

	# We iterate all X coords available in the data
	var x_coords = []
	for p in upper: x_coords.append(p.x)

	for x in x_coords:
		var y_u = _get_y_at_x_sorted(upper, x)
		var y_l = _get_y_at_x_sorted(lower, x)
		var t = abs(y_u - y_l) * scale_factor # Normalize!

		if t > max_thick:
			max_thick = t
			# Store position as normalized percentage (0.0 to 1.0)
			pos_max_thick_x = (x - min_x) * scale_factor

		var c = (y_u + y_l) * 0.5 * scale_factor
		if abs(c) > abs(max_camber): max_camber = c

	# Area Calc (Approximation)
	var total_area = 0.0
	# INFO: this will fix the performance issue for WEB!
	var steps = MAX_STEPS_AREA_CALC
	if OS.has_feature("web"): steps = MAX_STEPS_AREA_CALC_WEB

	for i in range(steps):
		var t = float(i)/float(steps-1)
		# Map t (0..1) to actual x coordinates (min_x..max_x)
		var x = lerp(min_x, max_x, t)
		var local_h = (_get_y_at_x_sorted(upper, x) - _get_y_at_x_sorted(lower, x)) * scale_factor
		total_area += local_h * (1.0/steps)
	print("tot area: ", total_area)
	# --- LE GEOMETRY (Normalized) ---
	# We check at the actual Tip (min_x) and 1% chord (min_x + 0.01 * chord)
	var le_tip_thickness = abs(_get_y_at_x_sorted(upper, min_x) - _get_y_at_x_sorted(lower, min_x)) * scale_factor

	var x_1pct = min_x + (0.01 * chord_length)
	var le_bluntness = abs(_get_y_at_x_sorted(upper, x_1pct) - _get_y_at_x_sorted(lower, x_1pct)) * scale_factor

	# LE Radius (Geometric fit at 0.5%)
	var x_sample = min_x + (0.005 * chord_length)
	var t_nose = abs(_get_y_at_x_sorted(upper, x_sample) - _get_y_at_x_sorted(lower, x_sample)) * scale_factor
	var le_radius_approx = 0.0
	if t_nose > 0.0:
		# Formula expects normalized inputs, which we now have
		le_radius_approx = (t_nose * 0.5) ** 2 / (2.0 * 0.005)

	# --- TE GEOMETRY (Normalized) ---
	# Check at actual Tail (max_x) and 99% chord
	var raw_te_openness = abs(_get_y_at_x_sorted(upper, max_x) - _get_y_at_x_sorted(lower, max_x)) * scale_factor

	# NEW: Apply Virtual Minimum Thickness (Boundary Layer / Manufacturing limit)

	var te_openness = max(raw_te_openness, MIN_PHYSICAL_THICKNESS)

	var x_99pct = max_x - (0.01 * chord_length)
	var te_bluntness = abs(_get_y_at_x_sorted(upper, x_99pct) - _get_y_at_x_sorted(lower, x_99pct)) * scale_factor

	# TE Radius (Geometric fit at 99.5%)
	var x_sample_te = max_x - (0.005 * chord_length)
	var t_tail = abs(_get_y_at_x_sorted(upper, x_sample_te) - _get_y_at_x_sorted(lower, x_sample_te)) * scale_factor

	# Enforce minimums on the tail thickness calculation too
	t_tail = max(t_tail, MIN_PHYSICAL_THICKNESS)

	var te_radius_approx = 0.0
	if t_tail > 0.0:
		te_radius_approx = (t_tail * 0.5) ** 2 / (2.0 * 0.005)

	# --- RECTANGULARITY ---
	var bounding_box_area = max(max_thick, 0.001) * 1.0
	var rectangularity = clamp(total_area / bounding_box_area, 0.0, 1.0)
	var fullness = 0.5
	if max_thick > 0.0: fullness = total_area / max_thick

	# --- NEW SYMMETRY DETECTION ---

	# 1. Position Symmetry (Is the thickest point near 0.5?)
	# If peak is at 0.3 (normal wing), score is 0.0. If at 0.5 (oval), score is 1.0.
	var dist_from_center = abs(pos_max_thick_x - 0.5)
	var sym_pos = 1.0 - smoothstep(0.0, 0.15, dist_from_center)

	# 2. Radius Symmetry (Is the Nose similar to the Tail?)
	var rad_diff = abs(le_radius_approx - te_radius_approx)
	var sym_rad = 1.0 - smoothstep(0.0, 0.02, rad_diff)

	# 3. Bluntness Symmetry (Is the tip thickness similar?)
	var blunt_diff = abs(le_bluntness - te_bluntness)
	var sym_blunt = 1.0 - smoothstep(0.0, 0.02, blunt_diff)

	# Combine them. We use min() because if ANY of these fail, it's not symmetric.
	# We allow a small blend, but essentially we want high certainty.
	var fore_aft_symmetry = min(sym_pos, min(sym_rad, sym_blunt))

	return {
		"fore_aft_symmetry": fore_aft_symmetry,
		"max_thick": max_thick,
		"pos_max_thick_x": pos_max_thick_x,
		"max_camber": max_camber,
		"le_radius": le_radius_approx,
		"le_radius_norm": le_radius_approx,
		"le_tip_thickness": le_tip_thickness,
		"le_bluntness": le_bluntness,

		"te_openness": te_openness,
		"te_bluntness": te_bluntness,
		"te_radius_norm": te_radius_approx,

		"fullness_factor": fullness,
		"rectangularity": rectangularity,
		"centroid_x": 0.25
	}

static func _prepare_surface(points: Array[Vector2]) -> Array[Vector2]:
	if points.is_empty(): return []
	var p_copy = points.duplicate()
	p_copy.sort_custom(func(a, b): return a.x < b.x)
	return p_copy

static func _get_y_at_x_sorted(points: Array[Vector2], target_x: float) -> float:
	if points.is_empty(): return 0.0
	if target_x <= points[0].x: return points[0].y
	if target_x >= points[-1].x: return points[-1].y
	for i in range(points.size() - 1):
		if points[i+1].x >= target_x:
			var t = (target_x - points[i].x) / (points[i+1].x - points[i].x)
			return lerp(points[i].y, points[i+1].y, t)
	return 0.0

static func calculate_alpha_0(upper: Array[Vector2], lower: Array[Vector2]) -> float:
	var integral_sum = 0.0
	var N = 40
	for i in range(1, N):
		var theta = PI * float(i) / float(N)
		var x = 0.5 * (1.0 - cos(theta))
		var dz_dx = _get_camber_slope_from_arrays(upper, lower, x)
		integral_sum += dz_dx * (cos(theta) - 1.0)
	return -(1.0 / PI) * integral_sum * (PI / float(N))

static func _calculate_cm0_integrated(upper: Array[Vector2], lower: Array[Vector2]) -> float:
	var integral_sum = 0.0
	var N = 40
	for i in range(1, N):
		var theta = PI * float(i) / float(N)
		var x = 0.5 * (1.0 - cos(theta))
		var dz_dx = _get_camber_slope_from_arrays(upper, lower, x)
		integral_sum += dz_dx * (cos(theta) - cos(2.0 * theta))
	return -0.25 * integral_sum * (PI / float(N))

static func _get_camber_slope_from_arrays(upper: Array[Vector2], lower: Array[Vector2], x: float) -> float:
	var eps = 0.001
	var y_up_p = _get_y_at_x_sorted(upper, x + eps)
	var y_lo_p = _get_y_at_x_sorted(lower, x + eps)
	var y_up_m = _get_y_at_x_sorted(upper, x - eps)
	var y_lo_m = _get_y_at_x_sorted(lower, x - eps)
	var cam_p = (y_up_p + y_lo_p) * 0.5
	var cam_m = (y_up_m + y_lo_m) * 0.5
	return (cam_p - cam_m) / (2.0 * eps)
