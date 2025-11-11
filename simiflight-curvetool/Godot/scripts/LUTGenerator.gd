# res://scripts/LutGenerator.gd
class_name LutGenerator
extends Node

# --- Physikalische Konstanten ---
const WING_CHORD = 1.0 # [m] Repräsentative Flügeltiefe, anpassen für dein Flugzeug!

# Internationale Standardatmosphäre (ISA) Konstanten
const SEA_LEVEL_TEMP_K = 288.15 # [K]
const SEA_LEVEL_DENSITY = 1.225 # [kg/m^3]
const LAPSE_RATE = 0.0065 # [K/m]
const GAS_CONSTANT_AIR = 287.05 # [J/(kg*K)]
const ADIABATIC_INDEX = 1.4
# Sutherland's Law Konstanten für Viskosität
const MU_REF = 1.716e-5 # [Pa*s] bei T_REF
const T_REF = 273.15 # [K]
const SUTHERLAND_CONST = 110.4 # [K]
const mach_points: Array[float]= [0.1, 0.3, 0.5, 0.7, 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2, 1.5, 2.0, 2.5, 3.0]
const altitude_points: Array[float] = [0, 100, 500, 1000, 2500, 5000, 7500, 11000, 12000, 15000, 18000, 24000, 400000]# [m]
const reynolds_points: Array[float] = [1.0e5, 5.0e5, 1.0e6, 5.0e6, 1.0e7, 3.0e7, 5.0e7]
# --- Öffentliche API ---
# Die Hauptfunktion, die alles ausführt.
static func generate_and_save_lut_old(airfoil_profile: AirfoilProfile, save_path: String):
	print("Starting LUT generation for: ", airfoil_profile.name)
	var lut = AirfoilLut.new()

	# Definiere das Grid für die LUT
	lut.alpha_points = _get_alpha_grid()
	lut.mach_points = mach_points
	lut.altitude_points = altitude_points
	
	# Initialisiere die Daten-Arrays, nicht nötig und geht so sowieso nicht
	#lut.cl_data = []
	#lut.cd_data = []

	# Holen der geometrischen Daten des Profils (einmalig)
	var geometry = _get_max_thickness_and_camber(airfoil_profile)
	var alpha_0 = _calculate_alpha_0(airfoil_profile)
	
	# Die große Dreifach-Schleife
	for altitude in lut.altitude_points:
		var atm = _get_isa_atmosphere(altitude)
		var speed_of_sound = _get_speed_of_sound(atm.temperature)
		print("  Calculating for Altitude: %d m" % altitude)

		for mach in lut.mach_points:
			var velocity = mach * speed_of_sound
			var reynolds = _calculate_reynolds(atm.density, velocity, WING_CHORD, atm.temperature)
			
			for alpha_deg in lut.alpha_points:
				var alpha_rad = deg_to_rad(alpha_deg)
				
				# Rufe die Master-Funktion auf (jetzt Teil dieser Klasse)
				var aero_coeffs = _compute_final_aero_curves_m1(alpha_rad, alpha_0, geometry, mach, reynolds)
				
				lut.cl_data.append(aero_coeffs.cl)
				lut.cd_data.append(aero_coeffs.cd)
	
	# Speichere die fertige Ressource
	var err = ResourceSaver.save(lut, save_path)
	if err == OK:
		print("Successfully saved LUT to: ", save_path)
	else:
		push_error("Failed to save LUT file!")
# --- Öffentliche API ---

# Die Hauptfunktion, die alles ausführt.
static func generate_and_save_lut(airfoil_profile: AirfoilProfile, save_path: String):
	print("Starting (alpha, Mach, Re) LUT generation for: ", airfoil_profile.name)
	var lut = AirfoilLut.new()

	# Definiere das Grid für die LUT
	lut.alpha_points = _get_alpha_grid()
	lut.mach_points = mach_points
	# Repräsentative Reynolds-Zahlen (von kleinen bis zu grossen Flugzeugen)
	lut.reynolds_points = reynolds_points
	
	#lut.cl_data = []
	#lut.cd_data = []

	var geometry = _get_max_thickness_and_camber(airfoil_profile)
	var alpha_0 = _calculate_alpha_0(airfoil_profile)
	
	# Die neue große Dreifach-Schleife: Re -> Mach -> Alpha
	for reynolds in lut.reynolds_points:
		print("  Calculating for Reynolds: %.1d" % reynolds)
		for mach in lut.mach_points:
			for alpha_deg in lut.alpha_points:
				var alpha_rad = deg_to_rad(alpha_deg)
				
				# Rufe die Master-Funktion mit den direkten Werten auf
				var aero_coeffs = _compute_final_aero_curves_m1(alpha_rad, alpha_0, geometry, mach, reynolds)
				
				lut.cl_data.append(aero_coeffs.cl)
				lut.cd_data.append(aero_coeffs.cd)
	
	var err = ResourceSaver.save(lut, save_path)
	if err == OK:
		print("Successfully saved (alpha, Mach, Re) LUT to: ", save_path)
	else:
		push_error("Failed to save LUT file!")
# Die Hauptfunktion, die alles ausführt.
static func generate_and_save_lut_combine_m1_m2(airfoil_profile: AirfoilProfile, save_path: String):
	print("Starting LUT generation for: ", airfoil_profile.name)
	var lut = AirfoilLut.new()

	# Definiere das Grid für die LUT
	lut.alpha_points = _get_alpha_grid()
	lut.mach_points = mach_points
	lut.reynolds_points = reynolds_points
	
	# Initialisiere die Daten-Arrays
	#lut.cl_data = []
	#lut.cd_data = []

	# Holen der geometrischen Daten des Profils (einmalig)
	var geometry = _get_max_thickness_and_camber(airfoil_profile)
	var alpha_0 = _calculate_alpha_0(airfoil_profile)
	
	# Die große Dreifach-Schleife
	for reynolds in lut.reynolds_points:
		print("  Calculating for Reynolds: %.1d" % reynolds)
		for mach in lut.mach_points:
			#var velocity = mach * speed_of_sound
			#var reynolds = _calculate_reynolds(atm.density, velocity, WING_CHORD, atm.temperature)
			var cl_data_m1: Array[Vector2] = []
			var cl_data_m2: Array[Vector2] = []
			var cd_data_m1: Array[Vector2] = []
			var cd_data_m2: Array[Vector2] = []
			for alpha_deg in lut.alpha_points:
				var alpha_rad = deg_to_rad(alpha_deg)
				
				# Rufe die Master-Funktion auf (jetzt Teil dieser Klasse)
				var aero_coeffs_m1: Dictionary = _compute_final_aero_curves_m1(alpha_rad, alpha_0, geometry, mach, reynolds)
				var aero_coeffs_m2: Dictionary = _compute_final_aero_curves_m2(alpha_rad, alpha_0, geometry, mach, reynolds)
				cl_data_m1.append(Vector2(alpha_deg, aero_coeffs_m1.cl))
				cl_data_m2.append(Vector2(alpha_deg, aero_coeffs_m2.cl))
				cd_data_m1.append(Vector2(alpha_deg, aero_coeffs_m1.cd))
				cd_data_m2.append(Vector2(alpha_deg, aero_coeffs_m2.cd))
				
			var final_lift_coeffs: Array[float] = _combine_curves(cl_data_m1, cl_data_m2, true)
			var final_drag_coeffs: Array[float] = _combine_curves(cd_data_m1, cd_data_m2)
			lut.cl_data.append_array(final_lift_coeffs)
			lut.cd_data.append_array(final_drag_coeffs)
	
	# Speichere die fertige Ressource
	var err = ResourceSaver.save(lut, save_path)
	if err == OK:
		print("Successfully saved LUT to: ", save_path)
	else:
		push_error("Failed to save LUT file!")
		
static func _combine_curves(p_curve_01: Array, p_curve_02: Array, p_is_lift_curve: bool = false) -> Array:
	var new_y: float = 0.0
	var new_curve: Array[float] = []
	var factor_c_01: float = 1.0
	var factor_c_02: float = 1.0
	for i in p_curve_01.size():
		if p_is_lift_curve:
			if i < 90:
				factor_c_01 = 20.0
				factor_c_02 = 1.0
			elif i < 180:
				factor_c_01 = 1.0
				factor_c_02 = 8.0
			elif i < 270:
				factor_c_01 = 1.0
				factor_c_02 = 8.0
			else:
				factor_c_01 = 20.0
				factor_c_02 = 1.0
		new_y = p_curve_01[i].y*factor_c_01 + p_curve_02[i].y*factor_c_02
		new_y /= (factor_c_01+factor_c_02)
		new_curve.append(new_y)
	return new_curve

# --- Aerodynamische Berechnungs-Engine (aus plot_test.gd hierher verschoben) ---

static func _calculate_cl_primary(angle_rad, current_alpha_0, geometry, mach_number, reynolds_number) -> float:
	var thickness = geometry.thickness
	var cl_slope = (2.0 * PI) / sqrt(1.0 - pow(min(mach_number, 0.95), 2))
	var cl_linear = cl_slope * (angle_rad - current_alpha_0)
	var cd_max = 2.1
	var cl_post_stall = cd_max * sin(angle_rad - current_alpha_0) * cos(angle_rad)
	
	var re_factor = 1.0 - 0.3 / (1.0 + reynolds_number / 5.0e5)
	var alpha_stall_pos = deg_to_rad(11.0 + 50.0 * thickness) * re_factor
	var alpha_stall_neg = deg_to_rad(-7.0 - 50.0 * thickness) * re_factor
	var sharpness_pos = 15.0
	var sharpness_neg = 8.0
	
	var sigma_pos = 1.0 / (1.0 + exp(sharpness_pos * (angle_rad - alpha_stall_pos)))
	var sigma_neg = 1.0 / (1.0 + exp(-sharpness_neg * (angle_rad - alpha_stall_neg)))
	var sigma = min(sigma_pos, sigma_neg)
	
	return sigma * cl_linear + (1.0 - sigma) * cl_post_stall

static func _compute_final_aero_curves_m1(alpha_rad: float, alpha_0: float, geometry: Dictionary, mach_number: float, reynolds_number: float) -> Dictionary:
	var thickness = geometry.thickness
	var cl_primary = _calculate_cl_primary(alpha_rad, alpha_0, geometry, mach_number, reynolds_number)
	var mirrored_alpha = alpha_rad - PI if alpha_rad > 0 else alpha_rad + PI
	var cl_mirrored = _calculate_cl_primary(mirrored_alpha, -alpha_0, geometry, mach_number, reynolds_number)
	var blend_sharpness_90 = 8.0
	var sigma_90 = 1.0 / (1.0 + exp(blend_sharpness_90 * (abs(alpha_rad) - deg_to_rad(90.0))))
	var final_cl = sigma_90 * cl_primary + (1.0 - sigma_90) * cl_mirrored
	
	var cf = 0.074 / pow(reynolds_number, 0.2)
	var cd_min = 2.0 * cf * (1.0 + 2.0 * thickness)
	var oswald_eff = 0.95
	var ar_eff = 50.0
	var cd_i = pow(final_cl, 2) / (PI * ar_eff * oswald_eff)
	var cd_pre_stall = cd_min + cd_i
	
	var cd_max_drag_base = 2.1
	var cd_max_drag_re = cd_max_drag_base * (1.0 + 5.0 / sqrt(reynolds_number))
	var cd_post_stall = cd_max_drag_re * pow(sin(alpha_rad), 2)
	
	var re_factor = 1.0 - 0.3 / (1.0 + reynolds_number / 5.0e5)
	var alpha_stall_pos_cd = deg_to_rad(11.0 + 50.0 * thickness) * re_factor
	var alpha_stall_neg_cd = deg_to_rad(-7.0 - 50.0 * thickness) * re_factor
	var sharpness_pos_cd = 15.0
	var sharpness_neg_cd = 8.0
	var sigma_pos_cd = 1.0 / (1.0 + exp(sharpness_pos_cd * (alpha_rad - alpha_stall_pos_cd)))
	var sigma_neg_cd = 1.0 / (1.0 + exp(-sharpness_neg_cd * (alpha_rad - alpha_stall_neg_cd)))
	var sigma_cd = min(sigma_pos_cd, sigma_neg_cd)

	var m_crit = 0.75; var m_peak = 1.05; var peak_drag = 0.08
	var cd_wave = 0.0
	if mach_number > m_crit:
		if mach_number <= m_peak:
			var x = (mach_number - m_crit) / (m_peak - m_crit)
			cd_wave = peak_drag * sin(x * PI / 2.0)
		else:
			var decay_factor = sqrt(pow(m_peak, 2) - 1.0) / sqrt(pow(mach_number, 2) - 1.0)
			cd_wave = peak_drag * decay_factor

	var final_cd = sigma_cd * cd_pre_stall + (1.0 - sigma_cd) * cd_post_stall + cd_wave
	
	return {"cl": final_cl, "cd": final_cd}
	
static func _compute_final_aero_curves_m2(alpha_rad: float, alpha_0: float, geometry: Dictionary, mach_number: float, reynolds_number: float) -> Dictionary:
	var thickness = geometry.thickness
	
	# 1. REYNOLDS-EINFLUSS (logarithmisch)
	var re_exponent = clamp(log(reynolds_number) / log(1e6), 0.7, 1.3)
	var alpha_stall_base = deg_to_rad(10.0 + 45.0 * thickness)
	var alpha_stall_pos_re = alpha_stall_base * re_exponent
	
	# 2. CD-MAX BERECHNUNG (dickere Profile > höherer CD)
	var cd_max = 1.8 + 0.6 * thickness
	
	# 3. CL-BERECHNUNG
	var cl_slope = (2.0 * PI) / sqrt(1.0 - pow(min(mach_number, 0.95), 2))
	var cl_linear = cl_slope * (alpha_rad - alpha_0)
	var cl_post_stall = (cd_max / 2) * sin(2 * alpha_rad)  # Viterna-Methode
	
	var sharpness = 12.0
	var sigma = 1.0 / (1.0 + exp(sharpness * (abs(alpha_rad) - alpha_stall_pos_re)))
	var final_cl = sigma * cl_linear + (1.0 - sigma) * cl_post_stall
	
	# 4. CD-BERECHNUNG (KORRIGIERT)
	# a) Reibungswiderstand (Prandtl-Schlichting)
	var cf = 0.455 / pow(log(reynolds_number)/log(10), 2.58)
	var cd_friction = 2.0 * cf * (1.0 + 2.2 * thickness + 100 * pow(thickness, 4))
	
	# b) Induzierter Widerstand
	var oswald_eff = 0.85 + 0.15 * (1 - exp(-reynolds_number/1e6)) - 0.1 * thickness
	var ar_eff = 50.0  # Effektive Streckung
	var cd_induced = pow(final_cl, 2) / (PI * ar_eff * oswald_eff)
	var cd_pre_stall = cd_friction + cd_induced
	
	# c) Post-Stall Widerstand
	var cd_post_stall = cd_max * pow(sin(alpha_rad), 2) * (1.0 + 0.5 * (1 - re_exponent))
	
	# d) Mach-Effekte (KORRIGIERT)
	var m_crit = 0.7 + 0.1 * thickness
	var cd_wave = 0.0
	if mach_number > m_crit:
		if mach_number < 1.0:
			cd_wave = 0.002 * exp(10 * (mach_number - m_crit)) * thickness * 100
		elif mach_number < 1.05:  # Glättung bei Mach 1.0
			cd_wave = 0.08 * (mach_number - m_crit) / 0.35
		else:
			var beta = max(sqrt(mach_number * mach_number - 1.0), 0.01)
			cd_wave = 4 * thickness * thickness / beta
	
	# e) Finales CD mit Blending
	var sigma_cd = 1.0 / (1.0 + exp(sharpness * (abs(alpha_rad) - alpha_stall_pos_re)))
	var final_cd = sigma_cd * cd_pre_stall + (1.0 - sigma_cd) * cd_post_stall + cd_wave
	
	return {"cl": final_cl, "cd": final_cd}
	
# --- Physikalische Hilfsfunktionen ---

static func _get_isa_atmosphere(altitude_m: float) -> Dictionary:
	# Vereinfachtes ISA-Modell für die Troposphäre (bis 11km)
	altitude_m = clamp(altitude_m, 0.0, 11000.0)
	var temp_k = SEA_LEVEL_TEMP_K - LAPSE_RATE * altitude_m
	var pressure_pa = 101325.0 * pow(1.0 - LAPSE_RATE * altitude_m / SEA_LEVEL_TEMP_K, 5.255)
	var density = pressure_pa / (GAS_CONSTANT_AIR * temp_k)
	return {"temperature": temp_k, "density": density}

static func _get_speed_of_sound(temperature_kelvin: float) -> float:
	return sqrt(ADIABATIC_INDEX * GAS_CONSTANT_AIR * temperature_kelvin)

static func _calculate_reynolds(density, velocity, chord, temperature_kelvin):
	# Sutherland's Law zur Berechnung der dynamischen Viskosität
	var mu = MU_REF * ( (T_REF + SUTHERLAND_CONST) / (temperature_kelvin + SUTHERLAND_CONST) ) * pow(temperature_kelvin / T_REF, 1.5)
	return (density * velocity * chord) / mu

# --- Geometrie-Hilfsfunktionen (aus plot_test.gd hierher verschoben) ---
# Diese benötigen das AirfoilProfile-Objekt als Input

static func _get_max_thickness_and_camber(profile: AirfoilProfile) -> Dictionary:
	var max_thickness = 0.0
	var max_camber = 0.0
	var count = min(profile.upper_surface.size(), profile.lower_surface.size())
	if count == 0: return {"thickness": 0.0, "camber": 0.0}
	for i in range(count):
		var thickness = profile.upper_surface[i].y - profile.lower_surface[i].y
		if thickness > max_thickness: max_thickness = thickness
		var camber_y = (profile.upper_surface[i].y + profile.lower_surface[i].y) / 2.0
		if abs(camber_y) > abs(max_camber): max_camber = camber_y
	return {"thickness": max_thickness, "camber": max_camber}

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
	var points: Array[float] = []
	for i in range(-180, 181, 2):
		points.append(float(i))
	return points
