class_name LutGenerator2
extends RefCounted

# --- Konstanten ---
const MACH_POINTS: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2, 1.5, 2.0, 2.5, 3.0]
const REYNOLDS_POINTS: Array[float] = [1.0e5, 5.0e5, 1.0e6, 5.0e6, 1.0e7, 3.0e7, 5.0e7]

enum CalculationMethod { METHOD_1, METHOD_2, COMBINED }

class GeneratorConfig:
	var method: CalculationMethod = CalculationMethod.COMBINED
	var stall_angle_deg: float = 15.0
	var sharpness: float = 12.0
	var cd_max: float = 2.1
	var preview_mach: float = 0.1
	var preview_re: float = 1.0e6

	# Neu: Blending Parameter für "Combined"
	var blend_start_deg: float = 20.0 # Ab hier fängt M2 an reinzumischen
	var blend_width_deg: float = 20.0 # Über so viele Grad wird gemischt

# --- Öffentliche API ---

static func calculate_preview_curve(profile: AirfoilProfile, config: GeneratorConfig) -> Dictionary:
	var geo = _analyze_geometry(profile)
	var alpha_0 = _calculate_alpha_0(profile)
	var curves = {"cl": [], "cd": []}
	var grid = _get_alpha_grid()

	for alpha_deg in grid:
		var alpha_rad = deg_to_rad(alpha_deg)
		var coeffs = _calculate_point_strategy(alpha_rad, alpha_0, geo, config.preview_mach, config.preview_re, config)
		curves.cl.append(Vector2(alpha_deg, coeffs.cl))
		curves.cd.append(Vector2(alpha_deg, coeffs.cd))

	return curves

static func generate_lut(profile: AirfoilProfile, config: GeneratorConfig) -> AirfoilLut:
	if not profile: return null
	print("LutGenerator: Starting generation for '%s'..." % profile.name)

	var lut = AirfoilLut.new()
	lut.alpha_points = _get_alpha_grid()
	lut.mach_points = MACH_POINTS.duplicate()
	lut.reynolds_points = REYNOLDS_POINTS.duplicate()

	var geo = _analyze_geometry(profile)
	var alpha_0 = _calculate_alpha_0(profile)

	for re in lut.reynolds_points:
		for mach in lut.mach_points:
			for alpha_deg in lut.alpha_points:
				var alpha_rad = deg_to_rad(alpha_deg)
				var coeffs = _calculate_point_strategy(alpha_rad, alpha_0, geo, mach, re, config)
				lut.cl_data.append(coeffs.cl)
				lut.cd_data.append(coeffs.cd)
	return lut

static func save_lut(lut: AirfoilLut, path: String) -> void:
	ResourceSaver.save(lut, path)

# --- Kern-Logik (Strategy & Fixes) ---

static func _calculate_point_strategy(alpha_rad: float, alpha_0: float, geo: Dictionary, mach: float, re: float, config: GeneratorConfig) -> Dictionary:
	match config.method:
		CalculationMethod.METHOD_1:
			return _compute_physics_m1(alpha_rad, alpha_0, geo, mach, re, config)
		CalculationMethod.METHOD_2:
			return _compute_physics_m2(alpha_rad, alpha_0, geo, mach, re, config)
		CalculationMethod.COMBINED:
			# Beide berechnen
			var r1 = _compute_physics_m1(alpha_rad, alpha_0, geo, mach, re, config)
			var r2 = _compute_physics_m2(alpha_rad, alpha_0, geo, mach, re, config)

			# Mischen basierend auf smoothstep
			return _blend_results_smooth(r1, r2, alpha_rad, config)
		_:
			return {"cl": 0.0, "cd": 0.0}

# NEU: Sanftes Blending ohne Stufen
static func _blend_results_smooth(r1: Dictionary, r2: Dictionary, alpha_rad: float, config: GeneratorConfig) -> Dictionary:
	var angle_deg = abs(rad_to_deg(alpha_rad))
	# Wir normalisieren den Winkel auf 0-180 für die Misch-Logik (Symmetrie)
	if angle_deg > 180.0: angle_deg = 360.0 - angle_deg

	# Logik:
	# Im linearen Bereich (0 bis Stall) vertrauen wir M1.
	# Im Deep Stall (90 Grad) vertrauen wir M2 (oder Viterna).

	var start = config.blend_start_deg  # z.B. 20 Grad
	var end = start + config.blend_width_deg # z.B. 40 Grad

	# Berechne Faktor t: 0.0 = Nur M1, 1.0 = Nur M2
	var t = smoothstep(start, end, angle_deg)

	# Lineare Interpolation (Lerp) zwischen den Ergebnissen
	var cl = lerp(r1.cl, r2.cl, t)
	var cd = lerp(r1.cd, r2.cd, t)

	return {"cl": cl, "cd": cd}

# --- Methode 1: Korrigiert (Symmetrie Fix!) ---
static func _compute_physics_m1(alpha_rad: float, alpha_0: float, geo: Dictionary, mach: float, re: float, config: GeneratorConfig) -> Dictionary:
	var thickness = geo.thickness

	# Prandtl-Glauert Korrektur für Lift Slope
	var cl_slope = (2.0 * PI) / sqrt(1.0 - pow(min(mach, 0.95), 2))
	var cl_linear = cl_slope * (alpha_rad - alpha_0)

	# Viterna-Style Post-Stall (Symmetrisch um 0 wenn alpha_0=0)
	var cl_post_stall = config.cd_max * sin(alpha_rad - alpha_0) * cos(alpha_rad)

	# Stall Blending Parameter
	var re_factor = 1.0 - 0.3 / (1.0 + re / 5.0e5)

	# BUGFIX: Negative Stall Angle basierend auf Config nutzen!
	var stall_offset = 50.0 * thickness
	var stall_rad_pos = deg_to_rad(config.stall_angle_deg + stall_offset) * re_factor
	var stall_rad_neg = deg_to_rad(-config.stall_angle_deg - stall_offset) * re_factor # War vorher hardcoded -7.0!

	# Sigmoid Funktionen
	var sigma_pos = 1.0 / (1.0 + exp(config.sharpness * (alpha_rad - stall_rad_pos)))
	var sigma_neg = 1.0 / (1.0 + exp(-config.sharpness * (alpha_rad - stall_rad_neg))) # Symmetrische Sharpness nutzen
	var sigma = min(sigma_pos, sigma_neg)

	var cl = sigma * cl_linear + (1.0 - sigma) * cl_post_stall

	# Drag Berechnung
	var cf = 0.074 / pow(re, 0.2)
	var cd_min = 2.0 * cf * (1.0 + 2.0 * thickness) + (0.1 * pow(mach, 6)) # Kleiner Mach-Drag im Min
	var cd_induced = pow(cl, 2) / (PI * 30.0)
	var cd_flow_sep = config.cd_max * pow(sin(alpha_rad), 2)

	var cd = cd_min + (sigma * cd_induced) + ((1.0 - sigma) * cd_flow_sep)

	return {"cl": cl, "cd": cd}

# --- Methode 2: Alternative ---
static func _compute_physics_m2(alpha_rad: float, alpha_0: float, geo: Dictionary, mach: float, re: float, config: GeneratorConfig) -> Dictionary:
	var thickness = geo.thickness

	# Simuliere Reynolds-Einfluss
	var re_exponent = clamp(log(re) / log(1e6), 0.7, 1.3)
	var stall_base = deg_to_rad(config.stall_angle_deg) * re_exponent

	var cl_slope = 2.0 * PI
	var cl_linear = cl_slope * (alpha_rad - alpha_0)

	# M2 nutzt eine etwas andere Stall-Formel (reiner Sinus für Deep Stall)
	var cl_deep_stall = (config.cd_max * 0.8) * sin(2.0 * alpha_rad)

	var sigma = 1.0 / (1.0 + exp(config.sharpness * (abs(alpha_rad) - stall_base)))
	var cl = sigma * cl_linear + (1.0 - sigma) * cl_deep_stall

	# Drag M2 (Mehr Wave Drag Fokus)
	var cf = 0.455 / pow(log(re)/log(10.0), 2.58)
	var cd_friction = 2.0 * cf * (1.0 + 2.0 * thickness)

	var cd_wave = 0.0
	var m_crit = 0.7 + (0.1 * thickness)
	if mach > m_crit:
		if mach < 1.05:
			cd_wave = 0.1 * pow((mach - m_crit), 2) * 20.0
		else:
			cd_wave = 0.1 / sqrt(pow(mach, 2) - 1.0)

	var cd_stall_part = config.cd_max * pow(sin(alpha_rad), 2)
	var cd = cd_friction + cd_wave + (1.0 - sigma) * cd_stall_part + (sigma * (pow(cl, 2) * 0.05))

	return {"cl": cl, "cd": cd}

# --- Helfer ---

static func _analyze_geometry(profile: AirfoilProfile) -> Dictionary:
	var max_t = 0.0
	if profile.upper_surface.size() > 0:
		for i in range(min(profile.upper_surface.size(), profile.lower_surface.size())):
			var t = profile.upper_surface[i].y - profile.lower_surface[i].y
			if t > max_t: max_t = t
	return {"thickness": max_t if max_t > 0 else 0.12}


static func _calculate_alpha_0(profile: AirfoilProfile) -> float:
	var camber_line = []
	var count = min(profile.upper_surface.size(), profile.lower_surface.size())
	for i in range(count): camber_line.append((profile.upper_surface[i] + profile.lower_surface[i]) / 2.0)
	var x = []; var z = []
	for p in camber_line: x.append(p.x); z.append(p.y)
	if x.size() < 2: return 0.0
	var dzdx = []
	for i in range(x.size()):
		if i == 0: dzdx.append((z[1] - z[0]) / (x[1] - x[0]))
		elif i == x.size() - 1: dzdx.append((z[-1] - z[-2]) / (x[-1] - x[-2]))
		else: dzdx.append((z[i+1] - z[i-1]) / (x[i+1] - x[i-1]))
	var alpha_0 = 0.0
	var N = dzdx.size()
	if N > 1:
		for i in range(N):
			var theta = PI * float(i) / float(N - 1)
			alpha_0 += dzdx[i] * (cos(theta) - 1.0)
		alpha_0 *= (PI / float(N - 1)) * (-1.0 / PI)
	return alpha_0



static func _get_alpha_grid() -> Array[float]:
	var p: Array[float] = []
	for i in range(-180, 181, 2): p.append(float(i))
	return p
