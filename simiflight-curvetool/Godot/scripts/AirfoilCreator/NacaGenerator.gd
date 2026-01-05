class_name NacaGenerator
extends RefCounted

enum ShapeType {
	NACA_POLYNOMIAL, # Standard Teardrop shape
	ELLIPTICAL       # Oval / Lens shape (Symmetric Left-Right)
}

static func generate_universal(m: float, p: float, t: float, le_mult: float, te_thick: float, shape_type: ShapeType, num_points: int = 100) -> Dictionary:
	var upper = []
	var lower = []

	# --- NACA COEFFICIENTS ---
	# a0 controls the Leading Edge (Sqrt term)
	var a0 = 0.2969 * le_mult
	var a1 = -0.1260
	var a2 = -0.3516
	var a3 = 0.2843

	# FIX: Calculate a4 DYNAMICALLY.
	# The sum of all coefficients must be 0 for the thickness to return to 0 at x=1.0.
	# a4 = -(a0 + a1 + a2 + a3)
	var a4 = -(a0 + a1 + a2 + a3)

	for i in range(num_points + 1):
		var beta = (float(i) / num_points) * PI
		var x = (1.0 - cos(beta)) / 2.0

		# 1. THICKNESS DISTRIBUTION
		var yt = 0.0

		if shape_type == ShapeType.NACA_POLYNOMIAL:
			# Standard Aerodynamic Teardrop
			yt = 5.0 * t * (a0 * sqrt(x) + a1 * x + a2 * pow(x, 2) + a3 * pow(x, 3) + a4 * pow(x, 4))

		elif shape_type == ShapeType.ELLIPTICAL:
			# Pure Ellipse / Oval
			# Formula: y = (t/2) * sqrt(1 - (2x - 1)^2)
			var term = 1.0 - pow(2.0 * x - 1.0, 2)
			var base_y = sqrt(max(0.0, term))

			# Apply LE Sharpness to Oval?
			# We can power the result to sharpen/blunt the tips.
			# 1.0 = Circle. <1.0 = Square-ish. >1.0 = Sharp-ish.
			# Note: Inverting logic to match NACA (High LE = Blunt)
			if le_mult != 1.0:
				# This is purely experimental "Frankenstein" math to allow modifying the oval
				var exponent = 1.0 / le_mult
				base_y = pow(base_y, exponent)

			yt = (t / 2.0) * base_y

		# 2. TRAILING EDGE THICKNESS
		# We add half the requested thickness linearly
		# At x=1, the polynomial part is now guaranteed to be 0, so this is the ONLY thickness at the tail.
		yt += (te_thick * 0.5) * x

		# 3. CAMBER
		var yc = 0.0
		var dyc_dx = 0.0

		if m != 0:
			if x < p:
				yc = (m / pow(p, 2)) * (2.0 * p * x - pow(x, 2))
				dyc_dx = (2.0 * m / pow(p, 2)) * (p - x)
			else:
				yc = (m / pow(1.0 - p, 2)) * ((1.0 - 2.0 * p) + 2.0 * p * x - pow(x, 2))
				dyc_dx = (2.0 * m / pow(1.0 - p, 2)) * (p - x)

		# 4. COORDINATE TRANSFORMATION
		var theta = atan(dyc_dx)

		var xu = x - yt * sin(theta)
		var yu = yc + yt * cos(theta)

		var xl = x + yt * sin(theta)
		var yl = yc - yt * cos(theta)

		upper.append(Vector2(xu, yu))
		lower.append(Vector2(xl, yl))

	return {"upper": upper, "lower": lower}
