class_name AirfoilGenerators
extends RefCounted

enum Family {
	NACA_4_DIGIT,
	JOUKOWSKI,
	SUPER_SHAPE,
	FLAT_PLATE
}

enum CamberType {
	STANDARD,       # NACA 2-Parabola (Sharpest at P)
	SMOOTH_SINE,    # Smooth Arc (Ignores P, peak is at 50%)
	REFLEX          # S-Shape (Curve up at tail)
}

# --- UI Configuration Helper ---
# Returns which controls should be enabled for the selected family
static func get_ui_config(family: Family) -> Dictionary:
	match family:
		Family.NACA_4_DIGIT:
			# NACA supports everything except Shape Exponent
			return {"m": true, "p": true, "t": true, "le": true, "te": true, "exp": false, "camber_mode": true}
		Family.JOUKOWSKI:
			# Joukowski handles its own camber/thickness via transform.
			# Position (p) and Camber Mode are fixed by the math.
			return {"m": true, "p": false, "t": true, "le": false, "te": false, "exp": false, "camber_mode": false}
		Family.SUPER_SHAPE:
			# Fully flexible
			return {"m": true, "p": true, "t": true, "le": false, "te": true, "exp": true, "camber_mode": true}
		Family.FLAT_PLATE:
			# Fully flexible
			return {"m": true, "p": true, "t": true, "le": false, "te": false, "exp": false, "camber_mode": true}
	return {}

static func generate(family: Family, params: Dictionary) -> Dictionary:
	match family:
		Family.NACA_4_DIGIT:
			return _gen_naca4(params)
		Family.JOUKOWSKI:
			return _gen_joukowski(params)
		Family.SUPER_SHAPE:
			return _gen_supershape(params)
		Family.FLAT_PLATE:
			return _gen_flat_plate(params)
	return {}

# ==============================================================================
# 1. SHARED CAMBER MATH
# ==============================================================================
static func _get_camber_geometry(type: CamberType, m: float, p: float, x: float) -> Dictionary:
	var yc = 0.0
	var dyc_dx = 0.0

	if m == 0.0:
		return {"y": 0.0, "dy": 0.0}

	match type:
		CamberType.STANDARD:
			# Standard NACA 2-Parabola
			# If p is effectively 0 or 1, fallback to 0 camber to prevent div/0
			if p <= 0.05 or p >= 0.95: p = 0.5

			if x < p:
				yc = (m / pow(p, 2)) * (2.0 * p * x - pow(x, 2))
				dyc_dx = (2.0 * m / pow(p, 2)) * (p - x)
			else:
				yc = (m / pow(1.0 - p, 2)) * ((1.0 - 2.0 * p) + 2.0 * p * x - pow(x, 2))
				dyc_dx = (2.0 * m / pow(1.0 - p, 2)) * (p - x)

		CamberType.SMOOTH_SINE:
			# Simple half-sine wave
			yc = m * sin(PI * x)
			dyc_dx = m * PI * cos(PI * x)

		CamberType.REFLEX:
			# S-Curve for Flying Wings
			var crossing = 1.0 + (1.0 - p)
			var k = 5.0 * m # Scaler

			yc = k * x * (x - 1.0) * (x - crossing)
			dyc_dx = k * (3.0*pow(x,2) - 2.0*x*(1.0 + crossing) + crossing)

	return {"y": yc, "dy": dyc_dx}

# ==============================================================================
# 2. GENERATORS
# ==============================================================================

static func _gen_naca4(params: Dictionary) -> Dictionary:
	var num_points = params.get("num_points", 100)
	var t = params.t
	var le_mult = params.get("le_mult", 1.0)
	var te_thick = params.get("te_thick", 0.0)
	var camber_type = params.get("camber_type", CamberType.STANDARD)

	var a0 = 0.2969 * le_mult
	var a1 = -0.1260
	var a2 = -0.3516
	var a3 = 0.2843
	var a4 = -(a0 + a1 + a2 + a3)

	var upper = []
	var lower = []


	for i in range(num_points + 1):
		var beta = (float(i) / num_points) * PI
		var x = (1.0 - cos(beta)) / 2.0

		# 1. Thickness
		var yt = 5.0 * t * (a0 * sqrt(x) + a1 * x + a2 * pow(x, 2) + a3 * pow(x, 3) + a4 * pow(x, 4))
		yt += (te_thick * 0.5) * x
		if yt < 0.0: yt = 0.0

		# 2. Camber (Using Helper)
		var cam = _get_camber_geometry(camber_type, params.m, params.p, x)
		var theta = atan(cam.dy)

		upper.append(Vector2(x - yt * sin(theta), cam.y + yt * cos(theta)))
		lower.append(Vector2(x + yt * sin(theta), cam.y - yt * cos(theta)))

	if upper[0] != Vector2.ZERO:
		upper[0] = Vector2.ZERO

	if lower[0] != Vector2.ZERO:
		lower[0] = Vector2.ZERO

	if te_thick != 0.0 and t != 0.0:
		upper.append(Vector2(1.0,0.0))
		lower.append(Vector2(1.0,0.0))

	return _finalize_output(upper, lower, params)

static func _gen_supershape(params: Dictionary) -> Dictionary:
	var num_points = params.get("num_points", 100)
	var t = params.t
	var shape_exp = params.get("shape_exp", 2.0)
	var te_thick = params.get("te_thick", 0.0)
	var camber_type = params.get("camber_type", CamberType.SMOOTH_SINE) # Default to smooth

	var upper = []
	var lower = []

	for i in range(num_points-1):
		var beta = (float(i) / num_points) * PI
		var x = (1.0 - cos(beta)) / 2.0

		# 1. Super-Formula Thickness
		var u = (x * 2.0) - 1.0
		var term = 1.0 - pow(abs(u), shape_exp)
		var base_y = pow(max(0.0, term), 1.0 / shape_exp)

		var yt = (t / 2.0) * base_y
		yt += (te_thick * 0.5) * x

		# 2. Camber (Using Helper)
		var cam = _get_camber_geometry(camber_type, params.m, params.p, x)
		var theta = atan(cam.dy)

		upper.append(Vector2(x - yt * sin(theta), cam.y + yt * cos(theta)))
		lower.append(Vector2(x + yt * sin(theta), cam.y - yt * cos(theta)))
	upper.append(Vector2(1.0,0.0))
	lower.append(Vector2(1.0,0.0))
	return _finalize_output(upper, lower, params)

static func _gen_flat_plate(params: Dictionary) -> Dictionary:
	var num_points = params.get("num_points", 100)
	var t = params.t
	var camber_type = params.get("camber_type", CamberType.STANDARD)

	var upper = []
	var lower = []


	if t != 0.0:
		upper.append(Vector2(0.0,0.0))
		lower.append(Vector2(0.0,0.0))

	for i in range(num_points + 1):
		var x = float(i) / num_points
		var yt = t / 2.0

		# Camber (Using Helper)
		var cam = _get_camber_geometry(camber_type, params.m, params.p, x)
		var theta = atan(cam.dy)

		upper.append(Vector2(x - yt * sin(theta), cam.y + yt * cos(theta)))
		lower.append(Vector2(x + yt * sin(theta), cam.y - yt * cos(theta)))
	if t != 0.0:
		upper.append(Vector2(1.0,0.0))
		lower.append(Vector2(1.0,0.0))
	return _finalize_output(upper, lower, params)

static func _gen_joukowski(params: Dictionary) -> Dictionary:
	var num_points = params.get("num_points", 100)
	# Joukowski input scaling:
	# Thickness: 0.05 - 0.3 typically. We map user t (0.0-0.4) to this.
	var t_param = params.t * 0.8
	# Camber: 0.0 - 0.2 typically.
	var m_param = params.m * 1.0

	# 1. Circle Setup (Zeta Plane)
	# Center is offset (-thickness, +camber)
	var center_x = -t_param
	var center_y = m_param

	# Radius must reach the singularity at (1,0)
	# This ensures the Trailing Edge is sharp (Kutta conditionish)
	var radius = sqrt(pow(1.0 - center_x, 2) + pow(0.0 - center_y, 2))

	# 2. Generate Raw Points (Z Plane)
	# We store them temporarily to calculate bounds before finalizing
	var raw_points: Array[Vector2] = []
	var min_x = 10000.0
	var max_x = -10000.0

	for i in range(num_points + 1):
		var beta = (float(i) / num_points) * PI * 2.0

		# Point on Circle
		var zeta_x = center_x + radius * cos(beta)
		var zeta_y = center_y + radius * sin(beta)

		# Joukowski Transform: z = zeta + 1/zeta
		var denom = (zeta_x * zeta_x) + (zeta_y * zeta_y)
		if denom == 0: denom = 0.00001

		var z_x = zeta_x + (zeta_x / denom)
		var z_y = zeta_y - (zeta_y / denom) # Minus because of complex conjugate logic 1/(x+iy)

		var pt = Vector2(z_x, z_y)
		raw_points.append(pt)

		# Track Bounds
		if pt.x < min_x: min_x = pt.x
		if pt.x > max_x: max_x = pt.x

	# 3. Normalize and Split
	# We want min_x to be 0.0 and max_x to be 1.0
	var chord_length = max_x - min_x
	if chord_length == 0: chord_length = 1.0 # Safety
	var scale_factor = 1.0 / chord_length

	var upper = []
	var lower = []

	for i in range(raw_points.size()):
		var pt = raw_points[i]

		# Normalize: Shift X to 0, Scale X and Y
		pt.x = (pt.x - min_x) * scale_factor
		pt.y = pt.y * scale_factor

		# The loop goes 0 -> 2PI.
		# 0 to PI is usually the "bottom" arc in typical Joukowski winding,
		# PI to 2PI is the "top".
		if i <= num_points / 2:
			upper.append(pt)
		else:
			lower.append(pt)

	# Joukowski lower side usually comes out Tail -> Nose.
	# We want Nose -> Tail for consistency with other generators.
	upper.append(lower.front())
	upper.reverse()

	return _finalize_output(upper, lower, params)

static func _finalize_output(upper: Array, lower: Array, params: Dictionary) -> Dictionary:

	if params.get("mirror_y", false):
		for i in range(upper.size()): upper[i].y = -upper[i].y
		for i in range(lower.size()): lower[i].y = -lower[i].y
	return {"upper": upper, "lower": lower}

#static func _close_airfoil(upper_lower: Array[Vector2], params: Dictionary) -> Array[Vector2]:
	#var closed_upper_lower: Array[Vector2] = []
	#if params.thick_type == Family.FLAT_PLATE:
		#var p_xy_zero: Vector2 = Vector2.ZERO
		#var p_x_one_y_zero: Vector2 = Vector2(1.0,0.0)
		#closed_upper_lower.append(p_xy_zero)
		#closed_upper_lower.append()
#
#
#
	#return closed_upper_lower
