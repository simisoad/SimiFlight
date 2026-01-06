class_name AirfoilGeometryAnalyzer
extends RefCounted

# --- VIRTUAL WIND TUNNEL CALIBRATION ---

# The floor for any lifting surface
const BASE_STALL_DEG = 8.0

# Radius Factor: How much the round nose helps flow attachment.
const STALL_RADIUS_FACTOR = 7.0

# Thickness Factor: Thicker wings sustain higher angles.
const STALL_THICKNESS_FACTOR = 5.0

# Shape Bonus: Fullness of the airfoil (Biconvex vs Wedge).
const STALL_SHAPE_FACTOR = 8.0

# --- NEW PENALTIES ---

# 1. Forward Camber Penalty
# Camber shifts the curve Left. It increases CL_max, but DECREASES the geometric stall angle.
# Example: NACA 0012 stalls at 16deg. NACA 4412 stalls at ~14deg (but has higher lift at 14).
const STALL_FWD_CAMBER_PENALTY = 15.0

# 2. Backward Camber Penalty
# Flying against camber is disastrous for attachment.
const STALL_BWD_CAMBER_PENALTY = 35.0

# 3. Laminar Flow Penalty (Peak thickness far back)
# NACA 6-series have sharp noses and stall slightly earlier/sharper.
const STALL_PEAK_POS_PENALTY = 8.0

# Hard Limits
const MIN_STALL_ANGLE = 5.0
const MAX_STALL_ANGLE = 20.0

static func analyze(profile: AirfoilProfile) -> Dictionary:
	# 1. Analyze Geometry
	var geo = _analyze_geometry_integrated(profile)

	# 2. Calculate Aerodynamic Centers
	var alpha_0 = calculate_alpha_0(profile)
	var cm_0 = _calculate_cm0_integrated(profile)

	# 3. Predict Stall Angles

	# Forward: affected by Nose Radius, Thickness, Fullness, Peak Position, and Camber
	var stall_fwd = _calculate_stall_angle(
		geo.le_radius_norm,
		geo.max_thick,
		geo.fullness_factor,
		geo.pos_max_thick_x,
		geo.max_camber,
		true # is_forward
	)

	# Backward: affected by TE "Radius" (thickness), Thickness, Fullness, and INVERTED Camber
	var stall_back = _calculate_stall_angle(
		geo.te_radius_norm,
		geo.max_thick,
		geo.fullness_factor,
		geo.pos_max_thick_x,
		geo.max_camber,
		false # is_backward
	)

	return {
		"thickness": geo.max_thick,
		"pos_max_thick_x": geo.pos_max_thick_x,
		"camber": geo.max_camber,
		"centroid_x": geo.centroid_x,
		"le_radius": geo.le_radius, # Real physical radius for physics model
		"te_thickness": geo.te_thickness,
		"alpha_0": alpha_0,
		"cm_0": cm_0,
		"stall_angle_fwd": stall_fwd,
		"stall_angle_back": stall_back
	}

# --------------------------------------------------------------------------
# STALL PREDICTION LOGIC
# --------------------------------------------------------------------------

static func _calculate_stall_angle(
	radius_norm: float,
	thickness: float,
	fullness: float,
	peak_x: float,
	camber: float,
	is_forward: bool
) -> float:

	var base = BASE_STALL_DEG

	# 1. Radius Bonus (Square root scaling for diminishing returns)
	# radius_norm is approx 0.015 for standard wings
	var val_radius = sqrt(clamp(radius_norm, 0.0, 0.1) / 0.02) * STALL_RADIUS_FACTOR

	# 2. Thickness Bonus
	var val_thick = thickness * STALL_THICKNESS_FACTOR

	# 3. Shape/Fullness Bonus
	var val_shape = max(0.0, fullness - 0.5) * STALL_SHAPE_FACTOR

	# 4. Laminar Flow / Peak Position Penalty
	# Standard airfoils peak at 0.30. Laminar (NACA 6) peak at 0.40+.
	# If peak is far back, the nose is usually sharper/elliptical -> earlier stall.
	var val_peak_penalty = max(0.0, peak_x - 0.30) * STALL_PEAK_POS_PENALTY

	# 5. Camber Penalty
	var val_camber_penalty = 0.0

	if is_forward:
		# Forward: Camber reduces geometric stall angle slightly.
		val_camber_penalty = abs(camber) * STALL_FWD_CAMBER_PENALTY
	else:
		# Backward: Flying against camber destroys lift.
		val_camber_penalty = abs(camber) * STALL_BWD_CAMBER_PENALTY

	# Summation
	var total = base + val_radius + val_thick + val_shape - val_peak_penalty - val_camber_penalty

	return clamp(total, MIN_STALL_ANGLE, MAX_STALL_ANGLE)

# --------------------------------------------------------------------------
# GEOMETRY EXTRACTION
# --------------------------------------------------------------------------

static func _analyze_geometry_integrated(profile: AirfoilProfile) -> Dictionary:
	if profile.upper_surface.is_empty(): return {}

	var max_thick = 0.0
	var pos_max_thick_x = 0.3
	var max_camber = 0.0
	var total_area = 0.0

	var steps = 200
	for i in range(steps):
		var x = float(i) / float(steps - 1)
		var y_up = _get_y_at_x(profile.upper_surface, x)
		var y_lo = _get_y_at_x(profile.lower_surface, x)

		var t = y_up - y_lo
		if t > max_thick:
			max_thick = t
			pos_max_thick_x = x

		var cam = (y_up + y_lo) * 0.5
		if abs(cam) > abs(max_camber):
			max_camber = cam

		if i > 0:
			total_area += t * (1.0/steps)

	# --- LE RADIUS (Improved) ---
	# We use Thickness at 0.5% chord to estimate the nose circle.
	# This ignores "Droop" (Camber) which confused the old algorithm.
	var x_sample = 0.005
	var t_nose = _get_y_at_x(profile.upper_surface, x_sample) - _get_y_at_x(profile.lower_surface, x_sample)
	var le_radius_approx = (t_nose * 0.5) ** 2 / (2.0 * x_sample)

	# --- TE THICKNESS ---
	var te_thick = abs(_get_y_at_x(profile.upper_surface, 1.0) - _get_y_at_x(profile.lower_surface, 1.0))


	# --- TE RADIUS (For backward flight) ---
	# Estimate effective radius of the back. If sharp, 0. If oval, t/2.
	var te_radius_approx = 0.0
	if te_thick > 0.002:
		te_radius_approx = te_thick * 0.5
	# The mathematical shape of the profile creates a completely sharp edge,
	# which is not realistic in the real world.
	if te_thick == 0.0: te_thick = 0.005

	# Fullness
	var fullness = 0.5
	if max_thick > 0.0:
		fullness = total_area / max_thick

	return {
		"max_thick": max_thick,
		"pos_max_thick_x": pos_max_thick_x,
		"max_camber": max_camber,
		"le_radius": le_radius_approx,
		"le_radius_norm": le_radius_approx, # Can be normalized if needed
		"te_thickness": te_thick,
		"te_radius_norm": te_radius_approx,
		"fullness_factor": fullness,
		"centroid_x": 0.25 # Placeholder, not strictly used for stall
	}

# --------------------------------------------------------------------------
# AERODYNAMICS (Thin Airfoil Theory)
# --------------------------------------------------------------------------

static func calculate_alpha_0(profile: AirfoilProfile) -> float:
	var integral_sum = 0.0
	var N = 40
	for i in range(1, N):
		var theta = PI * float(i) / float(N)
		var x = 0.5 * (1.0 - cos(theta))
		var dz_dx = _get_camber_slope_at_x(profile, x)
		integral_sum += dz_dx * (cos(theta) - 1.0)
	return -(1.0 / PI) * integral_sum * (PI / float(N))

static func _calculate_cm0_integrated(profile: AirfoilProfile) -> float:
	var integral_sum = 0.0
	var N = 40
	for i in range(1, N):
		var theta = PI * float(i) / float(N)
		var x = 0.5 * (1.0 - cos(theta))
		var dz_dx = _get_camber_slope_at_x(profile, x)
		integral_sum += dz_dx * (cos(theta) - cos(2.0 * theta))
	return -0.25 * integral_sum * (PI / float(N))

# --------------------------------------------------------------------------
# UTILS
# --------------------------------------------------------------------------

static func _get_camber_slope_at_x(profile: AirfoilProfile, x: float) -> float:
	var eps = 0.001
	var y_up_p = _get_y_at_x(profile.upper_surface, x + eps)
	var y_lo_p = _get_y_at_x(profile.lower_surface, x + eps)
	var y_up_m = _get_y_at_x(profile.upper_surface, x - eps)
	var y_lo_m = _get_y_at_x(profile.lower_surface, x - eps)
	var cam_p = (y_up_p + y_lo_p) * 0.5
	var cam_m = (y_up_m + y_lo_m) * 0.5
	return (cam_p - cam_m) / (2.0 * eps)

static func _get_y_at_x(points: Array[Vector2], target_x: float) -> float:
	if points.is_empty(): return 0.0
	if target_x <= points[0].x: return points[0].y
	if target_x >= points[-1].x: return points[-1].y

	# Simple optimized search assuming sorted X
	for i in range(points.size() - 1):
		if points[i+1].x >= target_x:
			var t = (target_x - points[i].x) / (points[i+1].x - points[i].x)
			return lerp(points[i].y, points[i+1].y, t)
	return 0.0
