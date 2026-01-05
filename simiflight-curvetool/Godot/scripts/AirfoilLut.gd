class_name AirfoilLut
extends Resource

# Axis Definitions
@export var alpha_points: Array[float] = []
@export var mach_points: Array[float] = []
@export var reynolds_points: Array[float] = []

# Flat Data Arrays (Size = alpha * mach * reynolds)
@export var cl_data: Array[float] = []
@export var cd_data: Array[float] = []
@export var cm_data: Array[float] = []
@export var stall_data: Array[float] = [] # 1.0 = Clean, 0.0 = Full Stall

@export var airfoil: AirfoilProfile

# Helper: Calculates the 1D index for the flat arrays
# Encapsulates the data structure logic.
func get_data_index(re_idx: int, mach_idx: int, alpha_idx: int) -> int:
	var num_alphas = alpha_points.size()
	var num_machs = mach_points.size()

	# Stride Logic: Re is the outer loop, then Mach, then Alpha
	return (re_idx * num_machs * num_alphas) + (mach_idx * num_alphas) + alpha_idx

# Helper: Returns Cl/Cd for specific indices
func get_coefficients_at_index(re_idx: int, mach_idx: int, alpha_idx: int) -> Vector4:
	var idx = get_data_index(re_idx, mach_idx, alpha_idx)
	if idx >= 0 and idx < cl_data.size():
		return Vector4(cl_data[idx], cd_data[idx], cm_data[idx], stall_data[idx])
	return Vector4.ZERO
