class_name AirfoilLut
extends Resource

# Achsen-Definitionen
@export var alpha_points: Array[float] = []
@export var mach_points: Array[float] = []
@export var reynolds_points: Array[float] = []

# Flache Daten-Arrays (Größe = alpha * mach * reynolds)
@export var cl_data: Array[float] = []
@export var cd_data: Array[float] = []
@export var cm_data: Array[float] = []
@export var stall_data: Array[float] = [] # 1.0 = Clean, 0.0 = Full Stall

# Hilfsfunktion: Berechnet den 1D-Index für die flachen Arrays
# Dies kapselt die Datenstruktur-Logik.
func get_data_index(re_idx: int, mach_idx: int, alpha_idx: int) -> int:
	var num_alphas = alpha_points.size()
	var num_machs = mach_points.size()

	# Stride-Logik: Re ist der äußerste Loop, dann Mach, dann Alpha
	return (re_idx * num_machs * num_alphas) + (mach_idx * num_alphas) + alpha_idx

# Hilfsfunktion: Gibt Cl/Cd für spezifische Indizes zurück
func get_coefficients_at_index(re_idx: int, mach_idx: int, alpha_idx: int) -> Vector2:
	var idx = get_data_index(re_idx, mach_idx, alpha_idx)
	if idx >= 0 and idx < cl_data.size():
		return Vector2(cl_data[idx], cd_data[idx])
	return Vector2.ZERO
