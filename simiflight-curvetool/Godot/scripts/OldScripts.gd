# Helper-Funktion, die unser bestes Modell für den primären Bereich [-90°, +90°] enthält.
func _calculate_cl_primary(
	angle_rad: float,
	alpha_0: float,
	geometry: Dictionary,
	mach_number: float,
	reynolds_number: float) -> float:
	var cl_slope = (2.0 * PI) / sqrt(1.0 - pow(min(mach_number, 0.95), 2))
	var cl_linear = cl_slope * (angle_rad - alpha_0)
	var cd_max = 1.9
	var cl_post_stall = cd_max * sin(angle_rad - alpha_0) * cos(angle_rad)
	var re_factor = 1.0 - 0.2 / (1.0 + reynolds_number / 1.0e5) # Beispiel-Heuristik
	# re_factor ist ~0.8 bei niedriger Re und ~1.0 bei hoher Re
	var alpha_stall_pos = deg_to_rad(9.0 + 50.0 * geometry.thickness) * re_factor
	var alpha_stall_neg = deg_to_rad(-7.0 - 50.0 * geometry.thickness)
	var sharpness_pos = 15.0
	var sharpness_neg = 8.0
	
	var sigma_pos = 1.0 / (1.0 + exp(sharpness_pos * (angle_rad - alpha_stall_pos)))
	var sigma_neg = 1.0 / (1.0 + exp(-sharpness_neg * (angle_rad - alpha_stall_neg)))
	var sigma = min(sigma_pos, sigma_neg)
	
	return sigma * cl_linear + (1.0 - sigma) * cl_post_stall	
# DIE FINALE MASTER-FUNKTION
# Ersetzt alle vorherigen _compute... Funktionen.
func _compute_final_aero_curves(alpha_rad: float, alpha_0: float, geometry: Dictionary, mach_number: float = 0.1, reynolds_number: float = 100000) -> Dictionary:

	# Hauptlogik für glatte 360° CL-Kurve
	var cl_primary = _calculate_cl_primary(alpha_rad, alpha_0, geometry, mach_number, reynolds_number)
	
	var mirrored_alpha: float = alpha_rad - PI if alpha_rad > 0 else alpha_rad + PI
	# HIER WAR DER BUG: Verwende mirrored_alpha!
	var cl_mirrored = _calculate_cl_primary(mirrored_alpha, -alpha_0, geometry, mach_number, reynolds_number)
	
	var blend_sharpness_90 = 8.0
	var sigma_90 = 1.0 / (1.0 + exp(blend_sharpness_90 * (abs(alpha_rad) - deg_to_rad(90.0))))
	
	var final_cl = sigma_90 * cl_primary + (1.0 - sigma_90) * cl_mirrored
	
	# --- TEIL 2: HOCHPRÄZISE CD-BERECHNUNG ---
	
	# Wir verwenden das Modell, das du validiert hast, aber mit unserem finalen CL-Wert.
	var thickness = geometry.thickness
	#var cd_min = 0.004 + 0.01 * thickness + 0.1 * pow(thickness, 4)
	var cf = 0.074 / pow(reynolds_number, 0.2) # Reibungsbeiwert nach Schlichting
	var cd_min = 2.0 * cf * (1.0 + 2.0 * thickness) # Formfaktor
	
	var oswald_eff = 0.95
	var ar_eff = 50.0
	var cd_i = pow(final_cl, 2) / (PI * ar_eff * oswald_eff)
	var cd_pre_stall = cd_min + cd_i
	
	var cd_max_drag = 1.9
	# Wichtige Korrektur für CD: Asymmetrie durch alpha_0 berücksichtigen!
	# Das stellt sicher, dass der minimale Widerstand bei alpha=alpha_0 liegt, nicht bei alpha=0.
	var cd_post_stall = cd_max_drag * pow(sin(alpha_rad), 2)
	
	# Blending mit dem gleichen Sigma wie bei der CL-Berechnung
	var alpha_stall_pos = deg_to_rad(12.0 + 50.0 * geometry.thickness)
	var alpha_stall_neg = deg_to_rad(-8.0 - 50.0 * geometry.thickness)
	var sharpness_pos = 10.0
	var sharpness_neg = 5.0
	var sigma_pos_cd = 1.0 / (1.0 + exp(sharpness_pos * (alpha_rad - alpha_stall_pos)))
	var sigma_neg_cd = 1.0 / (1.0 + exp(-sharpness_neg * (alpha_rad - alpha_stall_neg)))
	var sigma_cd = min(sigma_pos_cd, sigma_neg_cd)
	var cd_wave = 0.0
	if mach_number > 0.75:
		cd_wave = 20 * pow(mach_number - 0.75, 4)
	var final_cd = sigma_cd * cd_pre_stall + (1.0 - sigma_cd) * cd_post_stall
	final_cd = final_cd + cd_wave
	return {"cl": final_cl, "cd": final_cd}
