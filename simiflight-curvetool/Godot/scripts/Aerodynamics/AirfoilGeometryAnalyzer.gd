class_name AirfoilGeometryAnalyzer
extends RefCounted

# --- TUNING PARAMETERS ---
static var base_stall_deg: float = 8.0
static var stall_radius_factor: float = 7.0
static var stall_thickness_factor: float = 5.0
static var stall_shape_factor: float = 8.0
static var stall_fwd_camber_penalty: float = 15.0
static var stall_bwd_camber_penalty: float = 35.0
static var stall_peak_pos_penalty: float = 8.0

# Limits
static var min_stall_angle: float = 2.0
static var max_stall_angle: float = 100.0
static var MIN_PHYSICAL_THICKNESS = 0.0025

static var MAX_STEPS_AREA_CALC_WEB: float = 150
static var MAX_STEPS_AREA_CALC: float = 500

# ==============================================================================
#  MAIN ANALYSIS PIPELINE
# ==============================================================================

static func analyze(profile: AirfoilProfile) -> AirfoilGeometryResult:
	var res = AirfoilGeometryResult.new()

	# 1. Prepare surfaces
	var upper = _prepare_surface(profile.upper_surface)
	var lower = _prepare_surface(profile.lower_surface)
	if upper.is_empty() or lower.is_empty(): return res

	# 2. Robust Geometric Scan
	_analyze_geometry_robust(upper, lower, res)

	# 3. Physics Integrals
	res.alpha_0 = calculate_alpha_0(upper, lower)
	res.cm_0 = _calculate_cm0_integrated(upper, lower)

	# 4. Metadata Refinement (Professional Override)
	if not profile.metadata.is_empty():
		_apply_metadata_refinement(res, profile.metadata)

	# 5. Vortex Potential Calculation
	# Sharp noses (radius < 1.5% chord) and boxy shapes favor vortices
	var nose_sharpness = clamp(1.0 - (res.le_radius_norm / 0.015), 0.0, 1.0)
	var shape_trigger = smoothstep(0.4, 0.9, res.rectangularity)
	res.vortex_potential = max(nose_sharpness, shape_trigger)

	# 6. Final Stall Prediction
	_predict_stalls(res)

	return res

# ==============================================================================
#  INTERNAL STAGES
# ==============================================================================

static func _apply_metadata_refinement(res: AirfoilGeometryResult, meta: Dictionary) -> void:
	var family = meta.get("family", -1)

	# 1. Design Intent Fixes
	if family == AirfoilGenerators.Family.FLAT_PLATE:
		res.le_radius = 0.0001
		res.le_radius_norm = 0.0001
		res.rectangularity = 0.95
		res.le_bluntness = res.thickness

	if family == AirfoilGenerators.Family.SUPER_SHAPE:
		var e = meta.get("shape_exp", 2.0)
		if e < 1.5: # Angular/Diamond
			res.le_radius = 0.0001
			res.le_radius_norm = 0.0001
			res.camber_efficiency *= 0.75 # Corner-drag penalty

		if e > 5.0: # Brick
			res.rectangularity = 1.0
			res.le_bluntness = res.thickness

	# Use designer's precise values if available
	if meta.has("design_t"): res.thickness = meta.design_t
	if meta.has("design_m"): res.camber = meta.design_m

	if meta.get("te_thick", 0.0) > 0.01:
		res.te_openness = meta.te_thick
		res.te_bluntness = max(res.te_bluntness, meta.te_thick)

	# Exotic Penalty: Banana-Diamond shapes (Angular + High Camber)
	if family == AirfoilGenerators.Family.SUPER_SHAPE:
		var banana_penalty = abs(res.camber) * 2.0
		res.rectangularity = clamp(res.rectangularity + banana_penalty, 0.0, 1.0)

static func _predict_stalls(res: AirfoilGeometryResult) -> void:
	var safe_thick = max(res.thickness, 0.001)

	# Nose and Tail bluntness ratios
	var nose_ratio = res.le_bluntness / safe_thick
	var tail_ratio = res.te_bluntness / safe_thick

	# Bluntness penalties (The 'Brick' penalty)
	var blunt_penalty_fwd = smoothstep(0.4, 0.9, nose_ratio) * 20.0
	var blunt_penalty_bwd = smoothstep(0.4, 0.9, tail_ratio) * 20.0

	res.stall_angle_fwd = _calculate_stall_angle(
		res.le_radius_norm, res.thickness, res.fullness_factor,
		res.pos_max_thick_x, res.camber, true
	) - blunt_penalty_fwd

	res.stall_angle_back = _calculate_stall_angle(
		res.te_radius_norm, res.thickness, res.fullness_factor,
		res.pos_max_thick_x, res.camber, false
	) - blunt_penalty_bwd

static func _calculate_stall_angle(radius_norm: float, t: float, fullness: float, peak_x: float, camber: float, is_fwd: bool) -> float:
	var base = base_stall_deg

	# --- PROFESSIONAL DYNAMIC SHARPNESS PENALTY ---
	# Instead of 'if radius < 0.001', we use a smooth transition.
	# Suction capacity drops rapidly as the radius approaches zero.
	# This factor is 1.0 at radius=0 and 0.0 at radius=0.002.
	var sharpness_factor = 1.0 - smoothstep(0.0, 0.002, radius_norm)
	base -= (sharpness_factor * 4.0)

	var val_radius = sqrt(clamp(radius_norm, 0.0, 0.1) / 0.02) * stall_radius_factor
	var val_thick = t * stall_thickness_factor
	var val_shape = max(0.0, fullness - 0.5) * stall_shape_factor
	var val_peak_penalty = max(0.0, peak_x - 0.30) * stall_peak_pos_penalty

	var thick_penalty = smoothstep(0.25, 0.45, t) * 15.0
	var camber_penalty = abs(camber) * (stall_fwd_camber_penalty if is_fwd else stall_bwd_camber_penalty)

	var total = base + val_radius + val_thick + val_shape - val_peak_penalty - camber_penalty - thick_penalty
	return clamp(total, min_stall_angle, max_stall_angle)

static func _analyze_geometry_robust(upper: Array[Vector2], lower: Array[Vector2], res: AirfoilGeometryResult) -> void:
	var min_x = 1000.0; var max_x = -1000.0
	for p in upper + lower:
		min_x = min(min_x, p.x); max_x = max(max_x, p.x)

	var chord = max_x - min_x
	if chord <= 0.0001: chord = 1.0
	var scale = 1.0 / chord

	# Scan for max thickness and camber
	var total_area = 0.0
	for p in upper:
		var y_u = _get_y_at_x_sorted(upper, p.x)
		var y_l = _get_y_at_x_sorted(lower, p.x)
		var t_local = abs(y_u - y_l) * scale

		if t_local > res.thickness:
			res.thickness = t_local
			res.pos_max_thick_x = (p.x - min_x) * scale

		var c_local = (y_u + y_l) * 0.5 * scale
		if abs(c_local) > abs(res.camber): res.camber = c_local

	# Area Calculation
	var steps = MAX_STEPS_AREA_CALC_WEB if OS.has_feature("web") else MAX_STEPS_AREA_CALC
	for i in range(steps):
		var x = lerp(min_x, max_x, float(i)/float(steps-1))
		total_area += (_get_y_at_x_sorted(upper, x) - _get_y_at_x_sorted(lower, x)) * scale * (1.0/steps)

	# LE Geometry
	res.le_tip_thickness = abs(_get_y_at_x_sorted(upper, min_x) - _get_y_at_x_sorted(lower, min_x)) * scale
	res.le_bluntness = abs(_get_y_at_x_sorted(upper, min_x + 0.01 * chord) - _get_y_at_x_sorted(lower, min_x + 0.01 * chord)) * scale
	var t_nose_sample = abs(_get_y_at_x_sorted(upper, min_x + 0.005 * chord) - _get_y_at_x_sorted(lower, min_x + 0.005 * chord)) * scale
	res.le_radius_norm = (t_nose_sample * 0.5) ** 2 / (2.0 * 0.005)
	res.le_radius = res.le_radius_norm # Legacy support

	# TE Geometry
	res.te_openness = max(abs(_get_y_at_x_sorted(upper, max_x) - _get_y_at_x_sorted(lower, max_x)) * scale, MIN_PHYSICAL_THICKNESS)
	res.te_bluntness = abs(_get_y_at_x_sorted(upper, max_x - 0.01 * chord) - _get_y_at_x_sorted(lower, max_x - 0.01 * chord)) * scale
	var t_tail_sample = max(abs(_get_y_at_x_sorted(upper, max_x - 0.005 * chord) - _get_y_at_x_sorted(lower, max_x - 0.005 * chord)) * scale, MIN_PHYSICAL_THICKNESS)
	res.te_radius_norm = (t_tail_sample * 0.5) ** 2 / (2.0 * 0.005)

	# Rectangularity & Fullness
	res.rectangularity = clamp(total_area / (max(res.thickness, 0.001) * 1.0), 0.0, 1.0)
	res.fullness_factor = total_area / max(res.thickness, 0.001)

	# Symmetry Detection
	var sym_pos = 1.0 - smoothstep(0.0, 0.15, abs(res.pos_max_thick_x - 0.5))
	var sym_rad = 1.0 - smoothstep(0.0, 0.02, abs(res.le_radius_norm - res.te_radius_norm))
	var sym_blunt = 1.0 - smoothstep(0.0, 0.02, abs(res.le_bluntness - res.te_bluntness))
	res.fore_aft_symmetry = min(sym_pos, min(sym_rad, sym_blunt))

# ==============================================================================
#  MATH HELPERS (Keep these existing methods)
# ==============================================================================

static func _prepare_surface(pts: Array[Vector2]) -> Array[Vector2]:
	if pts.is_empty(): return []
	var p_copy = pts.duplicate()
	p_copy.sort_custom(func(a, b): return a.x < b.x)
	return p_copy

static func _get_y_at_x_sorted(pts: Array[Vector2], target_x: float) -> float:
	if pts.is_empty(): return 0.0
	if target_x <= pts[0].x: return pts[0].y
	if target_x >= pts[-1].x: return pts[-1].y
	for i in range(pts.size() - 1):
		if pts[i+1].x >= target_x:
			var t = (target_x - pts[i].x) / (pts[i+1].x - pts[i].x)
			return lerp(pts[i].y, pts[i+1].y, t)
	return 0.0

static func calculate_alpha_0(upper: Array[Vector2], lower: Array[Vector2]) -> float:
	var sum = 0.0; var N = 40
	for i in range(1, N):
		var theta = PI * float(i) / float(N); var x = 0.5 * (1.0 - cos(theta))
		sum += _get_camber_slope_from_arrays(upper, lower, x) * (cos(theta) - 1.0)
	return -(1.0 / PI) * sum * (PI / float(N))

static func _calculate_cm0_integrated(upper: Array[Vector2], lower: Array[Vector2]) -> float:
	var sum = 0.0; var N = 40
	for i in range(1, N):
		var theta = PI * float(i) / float(N); var x = 0.5 * (1.0 - cos(theta))
		sum += _get_camber_slope_from_arrays(upper, lower, x) * (cos(theta) - cos(2.0 * theta))
	return -0.25 * sum * (PI / float(N))

static func _get_camber_slope_from_arrays(upper: Array[Vector2], lower: Array[Vector2], x: float) -> float:
	var eps = 0.001
	var cam_p = (_get_y_at_x_sorted(upper, x+eps) + _get_y_at_x_sorted(lower, x+eps)) * 0.5
	var cam_m = (_get_y_at_x_sorted(upper, x-eps) + _get_y_at_x_sorted(lower, x-eps)) * 0.5
	return (cam_p - cam_m) / (2.0 * eps)
