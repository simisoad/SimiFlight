class_name LutGenerator
extends RefCounted

# --- Konstanten ---
const MACH_POINTS: Array[float] = [0.01, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5,0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0,7.0, 8.0, 9.0, 10]
const REYNOLDS_POINTS: Array[float] = [1.0e4,0.5e5,1.0e5, 5.0e5, 1.0e6, 5.0e6, 1.0e7, 3.0e7, 5.0e7, 10.0e7]

enum CalculationMethod { METHOD_1,METHOD_1A, METHOD_2, COMBINED }

var lut_curves_density: float = 1.0


class GeneratorConfig:
	var method: CalculationMethod = CalculationMethod.METHOD_1A

	# Physik Basis
	var stall_angle_deg: float = 15.0
	var sharpness: float = 12.0
	var cd_max: float = 2.1
	var ac_position: float = 0.25 # Standard 25% MAC
	# NEU: Wie gut fliegt der Flügel rückwärts? (0.0 bis 1.0)
	# 1.0 = Bikonvex (Symmetrisch), 0.3 = NACA (Schlechte Hinterkante)
	var backward_lift_scale: float = 1.0

	# Preview Settings
	var preview_mach: float = 0.1
	var preview_re: float = 1.0e6

	# Blending
	var blend_start_deg: float = 20.0
	var blend_width_deg: float = 20.0

# --- Öffentliche API ---

static func calculate_preview_curve(profile: AirfoilProfile, config: GeneratorConfig) -> Dictionary:
	var geo = analyze_geometry(profile)
	var alpha_0 = _calculate_alpha_0(profile)
	var curves = {"cl": [], "cd": [], "cm": [], "sigma": []}
	var grid = _get_alpha_grid()

	for alpha_deg in grid:
		var alpha_rad = deg_to_rad(alpha_deg)
		var coeffs = _calculate_point_strategy(alpha_rad, alpha_0, geo, config.preview_mach, config.preview_re, config)
		curves.cl.append(Vector2(alpha_deg, coeffs.cl))
		curves.cd.append(Vector2(alpha_deg, coeffs.cd))
		curves.cm.append(Vector2(alpha_deg, coeffs.cm))
		curves.sigma.append(Vector2(alpha_deg, coeffs.sigma))
	return curves

static func generate_lut(profile: AirfoilProfile, config: GeneratorConfig) -> AirfoilLut:
	if not profile: return null
	print("LutGenerator: Starting generation for '%s'..." % profile.name)

	var lut = AirfoilLut.new()
	lut.alpha_points = _get_alpha_grid()
	lut.mach_points = MACH_POINTS.duplicate()
	lut.reynolds_points = REYNOLDS_POINTS.duplicate()

	var geo = analyze_geometry(profile)
	var alpha_0 = _calculate_alpha_0(profile)

	for re in lut.reynolds_points:
		for mach in lut.mach_points:
			for alpha_deg in lut.alpha_points:
				var alpha_rad = deg_to_rad(alpha_deg)
				var coeffs = _calculate_point_strategy(alpha_rad, alpha_0, geo, mach, re, config)
				lut.cl_data.append(coeffs.cl)
				lut.cd_data.append(coeffs.cd)
				lut.cm_data.append(coeffs.cm)
				lut.stall_data.append(coeffs.sigma)
	return lut

static func save_lut(lut: AirfoilLut, path: String) -> void:
	ResourceSaver.save(lut, path)

# --- Kern-Logik (Strategy & Fixes) ---

static func _calculate_point_strategy(alpha_rad: float, alpha_0: float, geo: Dictionary, mach: float, re: float, config: GeneratorConfig) -> Dictionary:
	match config.method:
		CalculationMethod.METHOD_1:
			return _compute_physics_m1(alpha_rad, alpha_0, geo, mach, re, config)
		CalculationMethod.METHOD_1A:
			return _compute_physics_m1a(alpha_rad, alpha_0, geo, mach, re, config)
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

	var start = config.blend_start_deg  # z.B. 20 Grad
	var end = start + config.blend_width_deg # z.B. 40 Grad

	# Berechne Faktor t: 0.0 = Nur M1, 1.0 = Nur M2
	var t = smoothstep(start, end, angle_deg)

	# Lineare Interpolation (Lerp) zwischen den Ergebnissen
	var cl = lerp(r1.cl, r2.cl, t)
	var cd = lerp(r1.cd, r2.cd, t)

	return {"cl": cl, "cd": cd}

static func _compute_physics_m1a(alpha_rad: float, alpha_0: float, geo: Dictionary, mach: float, re: float, config: GeneratorConfig) -> Dictionary:
	var thickness = geo.thickness

	var cl_slope_factor = 1.0
	# Grenzen für den Übergangsbereich
	var m_sub_limit = 0.9  # Bis hier gilt Prandtl-Glauert
	var m_sup_limit = 1.2  # Ab hier gilt Ackeret (Überschall)

	if mach <= m_sub_limit:
		# Subsonic: Steigt an bis zur Schallmauer
		cl_slope_factor = 1.0 / sqrt(1.0 - pow(mach, 2))
	elif mach >= m_sup_limit:
		# Supersonic: Sinkt wieder (Ackeret Theorie: 4 / sqrt(M^2 - 1))
		# Wir cappen es, damit es nicht zu extrem abfällt
		cl_slope_factor = 4.0 / sqrt(pow(mach, 2) - 1.0)
	else:
		# Transsonic Bridge (Interpolation)
		# Wir berechnen die Werte an den Rändern und verbinden sie linear.

		# Wert bei Mach 0.9
		var val_sub = 1.0 / sqrt(1.0 - pow(m_sub_limit, 2)) # ca. 2.29

		# Wert bei Mach 1.2
		var val_sup = 4.0 / sqrt(pow(m_sup_limit, 2) - 1.0) # ca. 6.0 (Theorie)

		# Ackeret liefert bei 1.2 oft noch zu hohe Werte für reale 3D-Flügel.
		# Wir begrenzen den Startwert für Überschall etwas konservativer,
		# z.B. auf den Wert des Unterschalls oder leicht höher.
		val_sup = min(val_sup, 3.0)

		# Interpolations-Faktor t (0.0 bei 0.9, 1.0 bei 1.2)
		var t = (mach - m_sub_limit) / (m_sup_limit - m_sub_limit)

		# Linearer Übergang (Lerp)
		cl_slope_factor = lerp(val_sub, val_sup, t)

	# Sicherheits-Limit für alle Fälle (damit Physik-Engine nicht explodiert)
	cl_slope_factor = min(cl_slope_factor, 4.0)

	var cl_slope = (2.0 * PI) * cl_slope_factor
	var cl_linear_fwd = cl_slope * (alpha_rad - alpha_0)

	var re_factor = 1.0 - 0.3 / (1.0 + re / 5.0e5)
	var stall_offset = 50.0 * thickness
	var stall_pos = deg_to_rad(config.stall_angle_deg + stall_offset) * re_factor
	var stall_neg = deg_to_rad(-config.stall_angle_deg - stall_offset) * re_factor

	# Sigmoid für Vorwärts-Stall
	var sigma_fwd = _sigmoid_blend(alpha_rad, stall_neg, stall_pos, config.sharpness)

	# --- B) Rückwärtsflug (180 Grad) ---
	# Wir mappen den Winkel so, dass 180 Grad wie 0 Grad behandelt wird
	var alpha_rad_back = 0.0
	if alpha_rad > 0:
		alpha_rad_back = alpha_rad - PI # 180 -> 0
	else:
		alpha_rad_back = alpha_rad + PI # -180 -> 0

	# Berechnung für Rückwärts (oft schlechterer Slope und früherer Stall)
	# Wir nehmen hier vereinfacht dieselben Stall-Winkel an, aber skalierten Lift
	var cl_linear_back = cl_slope * (alpha_rad_back - alpha_0) # Beachte Vorzeichen alpha_0
	var sigma_back = _sigmoid_blend(alpha_rad_back, stall_neg * 0.8, stall_pos * 0.8, config.sharpness) # Stallt oft früher rückwärts

	# Skalierung für Rückwärtsflug-Effizienz
	var lift_back = (sigma_back * cl_linear_back) * config.backward_lift_scale

	# --- C) Deep Stall (90 Grad / Flat Plate) ---
	# Das klassische Viterna Modell für den Bereich, wo gar nichts mehr fliegt
	var cl_plate = config.cd_max * sin(alpha_rad) * cos(alpha_rad)

	# Zusammensetzen
	var cl_fwd_part = (sigma_fwd * cl_linear_fwd)

	# Der Trick: Wir blenden zwischen (Fwd oder Back) und (Plate)
	# Wenn Flow Attached -> Nutze Fwd/Back Berechnung
	# Wenn Flow Detached (90°) -> Nutze Plate Berechnung

	# Wir nutzen sigma als Gewichtung für den "Attached Flow" Anteil
	# Aber da wir jetzt zwei Sigmas haben (vorne/hinten), müssen wir wählen.
	var current_sigma = sigma_fwd if cos(alpha_rad) > 0 else sigma_back

	# Harter Schnitt für Logik, weicher Übergang durch Formeln
	var lift_aero = 0.0
	if cos(alpha_rad) >= 0:
		lift_aero = cl_fwd_part
	else:
		lift_aero = lift_back

	# Finales Blending:
	# Nimm aerodynamischen Lift so lange wir nicht im Stall sind (current_sigma hoch)
	# Nimm Plate Lift wenn wir im Stall sind (current_sigma niedrig)
	var final_cl = current_sigma * lift_aero + (1.0 - current_sigma) * cl_plate


	# --- Drag Berechnung ---
	# --- 2. Drag Berechnung (Wave Drag Fix) ---
	var cd0_subsonic = 0.005 + (0.01 * thickness)
	var cd_induced = pow(final_cl, 2) / (PI * 30.0)
	var cd_plate = config.cd_max * pow(sin(alpha_rad), 2)

	# Wave Drag (Wellenwiderstand)
	var cd_wave = 0.0
	var m_crit = 0.8      # Start des Anstiegs
	var m_peak = 1.05     # Wo ist der Widerstand am höchsten?
	var cd_wave_peak = 4.0 * pow(thickness, 2) # Faustformel für Peak-Höhe basierend auf Dicke

	if mach > m_crit:
		if mach < m_peak:
			# Transsonic Rise (Anstieg zur Schallmauer)
			# Sinus-Kurve für weichen Anstieg von 0 auf Peak
			var ratio = (mach - m_crit) / (m_peak - m_crit)
			cd_wave = cd_wave_peak * sin(ratio * PI / 2.0)
		else:
			# Supersonic Decay (Abfall bei Überschall)
			# Formel: Peak * (1 / sqrt(M^2 - 1)) - aber sanft angepasst
			# Wir nutzen einfach den Kehrwert der Machzahl, das ist stabil für Raketen
			cd_wave = cd_wave_peak * (m_peak / mach)

	# Zusammenbau
	var final_cd = current_sigma * (cd0_subsonic + cd_induced + cd_wave) + (1.0 - current_sigma) * cd_plate

	## Mach Wave Drag (optional addieren)
	#if mach > 0.8:
		#final_cd += 0.08 * pow(mach - 0.8, 2)


	var cn = final_cl * cos(alpha_rad) + final_cd * sin(alpha_rad)
# 1. Basis Cm0
	# Wirken lassen wir es nur, wenn Strömung anliegt (current_sigma)
	var cm0 = -2.0 * geo.camber # oder config.fixed_cm0
	var moment_camber = cm0 * current_sigma

	# 2. Bestimmung des Druckpunkts (Center of Pressure - x_cop)
	var cop_attached = 0.5 - (0.25 * cos(alpha_rad))

	# Der Druckpunkt im Stall ist immer die Mitte (Flache Platte)
	var cop_stall = 0.5

	# 3. Finaler Druckpunkt durch Blending
	# Wenn sigma=1 (Flug) -> Nimm cop_attached
	# Wenn sigma=0 (Stall) -> Nimm cop_stall (Mitte)
	var current_cop = lerp(cop_stall, cop_attached, current_sigma)

	# 4. Der Hebelarm
	# Abstand vom physikalischen Drehpunkt (AC, meist 0.25) zum aktuellen Druckpunkt
	var lever_arm = config.ac_position - current_cop

	# 5. Finales Moment
	# Moment = Wölbungsmoment + (Kraft * Hebelarm)
	var final_cm = moment_camber + (cn * lever_arm)

	return {"cl": final_cl, "cd": final_cd, "cm": final_cm, "sigma": current_sigma}

# Hilfsfunktion für den Sigmoid-Übergang (macht den Code lesbarer)
static func _sigmoid_blend(val: float, min_boundary: float, max_boundary: float, sharpness: float) -> float:
	# Gibt 1.0 zurück, wenn val INNERHALB der boundaries ist
	# Gibt 0.0 zurück, wenn val AUSSERHALB ist
	var s1 = 1.0 / (1.0 + exp(sharpness * (val - max_boundary)))
	var s2 = 1.0 / (1.0 + exp(-sharpness * (val - min_boundary)))
	return min(s1, s2)

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

static func analyze_geometry(profile: AirfoilProfile) -> Dictionary:
	var max_thick = 0.0
	var pos_max_thick_x = 0.3
	var max_camber = 0.0 # NEU

	if profile.upper_surface.size() > 0:
		var count = min(profile.upper_surface.size(), profile.lower_surface.size())
		for i in range(count):
			var upper_y = profile.upper_surface[i].y
			var lower_y = profile.lower_surface[i].y

			# Dicke
			var t = upper_y - lower_y
			if t > max_thick:
				max_thick = t
				pos_max_thick_x = profile.upper_surface[i].x

			# Camber (Mittellinie zwischen oben und unten)
			var mean_line_y = (upper_y + lower_y) / 2.0
			# Wir suchen den Punkt, der am weitesten von der Sehne (y=0) weg ist
			if abs(mean_line_y) > abs(max_camber):
				max_camber = mean_line_y

	return {
		"thickness": max_thick,
		"pos_max_thick_x": pos_max_thick_x,
		"camber": max_camber # NEU
	}

# Neue Hilfsfunktion
static func estimate_cm0(geo_data: Dictionary) -> float:
	# Faustformel: cm0 ist ca. -2 * max_camber
	# Bei Bikonvex ist camber ~0 -> cm0 = 0
	return -2.0 * geo_data.camber

static func estimate_backward_scale(geo: Dictionary) -> float:
	var x_pos = geo.pos_max_thick_x

	# Berechnung des Abstands zur Mitte (0.5)
	var dist_from_center = abs(x_pos - 0.5)
	var scale = 1.0 - (dist_from_center * 3.2) # Faktor 3.2 sorgt für starken Abfall

	return clamp(scale, 0.25, 1.0) # Nicht unter 0.25 gehen

static func estimate_stall_angle(geo: Dictionary) -> float:
	var base_stall = 9.0 # Konservativer Basiswert
	var thickness_factor = 50.0 # Wie stark Dicke hilft

	var estimated = base_stall + (geo.thickness * thickness_factor)
	return clamp(estimated, 8.0, 20.0) # Sinnvolle Limits


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
	for i in range(-180, 181, 1): p.append(float(i))
	return p
