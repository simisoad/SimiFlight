class_name AirfoilSampler
extends RefCounted

# We use binary search for speed
static func sample(lut: AirfoilLut, alpha_rad: float, mach: float, re: float) -> Dictionary:
	# 1. Convert Alpha from Rad to Deg (since LUT is stored in Deg)
	var alpha_deg = rad_to_deg(alpha_rad)

	# Clamp inputs to range (Safety)
	# We usually don't wrap Alpha here, as the LUT goes from -180 to 180.
	# But we should limit Mach and Re.
	mach = clamp(mach, lut.mach_points[0], lut.mach_points[-1])
	re = clamp(re, lut.reynolds_points[0], lut.reynolds_points[-1])

	# 2. Find indices (The "left" neighbors)
	var i_a = _find_lower_index(lut.alpha_points, alpha_deg)
	var i_m = _find_lower_index(lut.mach_points, mach)
	var i_r = _find_lower_index(lut.reynolds_points, re)

	# 3. Calculate weights (Where are we between index i and i+1?)
	# Value between 0.0 and 1.0
	var w_a: float = _get_weight(lut.alpha_points, i_a, alpha_deg)
	var w_m: float = _get_weight(lut.mach_points, i_m, mach)
	var w_r: float = _get_weight(lut.reynolds_points, i_r, re)

	# 4. Trilinear interpolation for all coefficients
	var cl: float = _trilinear_interp(lut.cl_data, lut, i_r, i_m, i_a, w_r, w_m, w_a)
	var cd: float = _trilinear_interp(lut.cd_data, lut, i_r, i_m, i_a, w_r, w_m, w_a)
	var cm: float = _trilinear_interp(lut.cm_data, lut, i_r, i_m, i_a, w_r, w_m, w_a)

	# Optional: Interpolate stall degree (Sigma)
	var sigma = _trilinear_interp(lut.stall_data, lut, i_r, i_m, i_a, w_r, w_m, w_a)

	return {"cl": cl, "cd": cd, "cm": cm, "stall": sigma}

# --- Helper Functions ---

static func _find_lower_index(arr: Array[float], val: float) -> int:
	# binary_search returns the index where the value would be inserted to maintain order.
	var idx = arr.bsearch(val)
	# We want the index *left* of the value.
	# bsearch often returns the index after or at exact match.
	# We correct this manually to be safe:
	idx = max(0, idx - 1)

	# Ensure we don't run out of the array (we need idx and idx+1 for interpolation)
	if idx >= arr.size() - 1:
		idx = arr.size() - 2
	return idx

static func _get_weight(arr: Array[float], idx: int, val: float) -> float:
	var v1 = arr[idx]
	var v2 = arr[idx+1]
	if is_equal_approx(v1, v2): return 0.0
	return (val - v1) / (v2 - v1)

static func _trilinear_interp(data: Array[float], lut: AirfoilLut, ir: int, im: int, ia: int, wr: float, wm: float, wa: float) -> float:
	# Step 1: Interpolate Alpha (4x)
	# We fetch the 8 corners of the cube around our point

	# Plane Re_low, Mach_low
	var c000 = data[lut.get_data_index(ir, im, ia)]
	var c001 = data[lut.get_data_index(ir, im, ia+1)]
	var c00 = lerp(c000, c001, wa) # Interpolate along Alpha

	# Plane Re_low, Mach_high
	var c010 = data[lut.get_data_index(ir, im+1, ia)]
	var c011 = data[lut.get_data_index(ir, im+1, ia+1)]
	var c01 = lerp(c010, c011, wa)

	# Plane Re_high, Mach_low
	var c100 = data[lut.get_data_index(ir+1, im, ia)]
	var c101 = data[lut.get_data_index(ir+1, im, ia+1)]
	var c10 = lerp(c100, c101, wa)

	# Plane Re_high, Mach_high
	var c110 = data[lut.get_data_index(ir+1, im+1, ia)]
	var c111 = data[lut.get_data_index(ir+1, im+1, ia+1)]
	var c11 = lerp(c110, c111, wa)

	# Step 2: Interpolate Mach (2x)
	var c0 = lerp(c00, c01, wm) # Re_low result
	var c1 = lerp(c10, c11, wm) # Re_high result

	# Step 3: Interpolate Reynolds (1x)
	return lerp(c0, c1, wr)
