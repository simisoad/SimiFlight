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

	return _finalize_output(upper, lower, params)

static func _gen_supershape(params: Dictionary) -> Dictionary:
	var num_points = params.get("num_points", 100)
	var t = params.t
	var shape_exp = params.get("shape_exp", 2.0)
	var te_thick = params.get("te_thick", 0.0)
	var camber_type = params.get("camber_type", CamberType.SMOOTH_SINE) # Default to smooth

	var upper = []
	var lower = []

	for i in range(num_points + 1):
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

	return _finalize_output(upper, lower, params)

static func _gen_flat_plate(params: Dictionary) -> Dictionary:
	var num_points = params.get("num_points", 100)
	var t = params.t
	var camber_type = params.get("camber_type", CamberType.STANDARD)

	var upper = []
	var lower = []

	for i in range(num_points + 1):
		var x = float(i) / num_points
		var yt = t / 2.0

		# Camber (Using Helper)
		var cam = _get_camber_geometry(camber_type, params.m, params.p, x)
		var theta = atan(cam.dy)

		upper.append(Vector2(x - yt * sin(theta), cam.y + yt * cos(theta)))
		lower.append(Vector2(x + yt * sin(theta), cam.y - yt * cos(theta)))

	return _finalize_output(upper, lower, params)

static func _gen_joukowski(params: Dictionary) -> Dictionary:
	# NOTE: Joukowski ignores 'camber_type' because the math
	# intrinsically defines the camber shape via the circle offset.
	var num_points = params.get("num_points", 100)
	var t_param = params.t * 0.8
	var m_param = params.m * 1.0

	var upper = []
	var lower = []

	var center_x = -t_param
	var center_y = m_param
	var radius = sqrt(pow(1.0 - center_x, 2) + pow(0.0 - center_y, 2))

	for i in range(num_points + 1):
		var beta = (float(i) / num_points) * PI * 2.0
		var zeta_x = center_x + radius * cos(beta)
		var zeta_y = center_y + radius * sin(beta)
		var denom = (zeta_x * zeta_x) + (zeta_y * zeta_y)
		if denom == 0: denom = 0.0001

		var final_x = (zeta_x + (zeta_x / denom))
		var final_y = (zeta_y - (zeta_y / denom)) # Minus because 1/(x+iy)

		final_x = (final_x + 2.0) / 4.0
		final_y = final_y / 4.0

		if i <= num_points / 2: lower.append(Vector2(final_x, final_y))
		else: upper.append(Vector2(final_x, final_y))

	lower.reverse()
	return _finalize_output(upper, lower, params)

static func _finalize_output(upper: Array, lower: Array, params: Dictionary) -> Dictionary:
	if params.get("mirror_y", false):
		for i in range(upper.size()): upper[i].y = -upper[i].y
		for i in range(lower.size()): lower[i].y = -lower[i].y
	return {"upper": upper, "lower": lower}
