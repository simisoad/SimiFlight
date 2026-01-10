class_name LutGenerator extends RefCounted

# -- Constants for Grid Generation --
const MACH_POINTS: Array[float] = [0.01, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
const REYNOLDS_POINTS: Array[float] = [1.0e4, 0.5e5, 1.0e5, 5.0e5, 1.0e6, 5.0e6, 1.0e7, 3.0e7, 5.0e7, 10.0e7]

const SMOOTH_PASSES: int = 1

# Alpha_range for Preview:
static var preview_alpha_start_deg: float = -360.0
static var preview_alpha_end_deg: float = 360.0

# -- Configuration Class --
class GeneratorConfig:
	var stall_angle_deg_fwd: float = 15.0
	var stall_angle_deg_bwd: float = 8.0
	var sharpness: float = 25.0
	var cd_max: float = 2.1
	var ac_position: float = 0.25


	# Preview Settings
	var preview_mach: float = 0.1
	var preview_re: float = 1.0e6

func _init() -> void:
	EventBus.preview_start_alpha_set.connect(
		func(v):
		preview_alpha_start_deg = v
		print("hoio"))
	EventBus.preview_end_alpha_set.connect(func(v): preview_alpha_end_deg = v)

# -- Main Logic --
## Generates a single curve for UI previewing without generating the full LUT
static func calculate_preview_curve(profile: AirfoilProfile, config: GeneratorConfig) -> Dictionary:
	var geo = AirfoilGeometryAnalyzer.analyze(profile)

	print("Airfoil: %s geometry from AirfoilGeometryAnalyzer.analyze():" % profile.name)
	for entry in geo:
		print(entry, ": ", geo[entry])

	var alpha_0 = geo.alpha_0

	# 1. Create temporary float arrays (for smoothing)
	var raw_cl: Array[float] = []
	var raw_cd: Array[float] = []
	var raw_cm: Array[float] = []
	var raw_sigma: Array[float] = []
	var alpha_values: Array[float] = []

	var raw_direction: Array[float] = []

	var grid = _get_alpha_grid(preview_alpha_start_deg, preview_alpha_end_deg)

	# 2. Calculate Physics
	for alpha_deg in grid:
		var alpha_rad = deg_to_rad(alpha_deg)
		var coeffs = AeroPhysicsModel.compute_coefficients(
			alpha_rad, alpha_0, geo, config.preview_mach, config.preview_re, config
		)

		alpha_values.append(alpha_deg)
		raw_cl.append(coeffs.cl)
		raw_cd.append(coeffs.cd)
		raw_cm.append(coeffs.cm)
		raw_sigma.append(coeffs.sigma) # We usually don't smooth sigma, or only very lightly
		raw_direction.append(coeffs.direction)
	# 3. Apply Smoothing (Identical to LUT generation)
	# Here we use the static function _smooth_array
	var smoothed_cl = _smooth_array(raw_cl, SMOOTH_PASSES)
	var smoothed_cd = _smooth_array(raw_cd, SMOOTH_PASSES)
	var smoothed_cm = _smooth_array(raw_cm, SMOOTH_PASSES)
	# Leave Sigma unsmoothed so one can see exactly where the logic switches

	# 4. Pack data into return format (Vector2 Arrays)
	var curves = {"cl": [], "cd": [], "cm": [], "sigma": [], "direction": []}

	for i in range(grid.size()):
		var a = alpha_values[i]
		curves.cl.append(Vector2(a, smoothed_cl[i]))
		curves.cd.append(Vector2(a, smoothed_cd[i]))
		curves.cm.append(Vector2(a, smoothed_cm[i]))
		curves.sigma.append(Vector2(a, raw_sigma[i]))
		curves.direction.append(Vector2(a, raw_direction[i]))

	return curves

## Main function to generate the complete AirfoilLut resource
static func generate_lut(profile: AirfoilProfile, config: GeneratorConfig) -> AirfoilLut:
	if not profile:
		push_error("LutGenerator: No profile provided.")
		return null

	print("LutGenerator: Starting generation for '%s'..." % profile.resource_name)

	var lut = AirfoilLut.new()
	lut.airfoil = profile
	lut.alpha_points = _get_alpha_grid()
	lut.mach_points = MACH_POINTS.duplicate()
	lut.reynolds_points = REYNOLDS_POINTS.duplicate()

	# 1. Analyze Geometry once
	var geo = AirfoilGeometryAnalyzer.analyze(profile)
	var alpha_0 = geo.alpha_0

	# 2. Iterate over all dimensions (Re -> Mach -> Alpha)
	for re in lut.reynolds_points:
		for mach in lut.mach_points:
			for alpha_deg in lut.alpha_points:
				var alpha_rad = deg_to_rad(alpha_deg)

				# 3. Compute Physics
				var coeffs = AeroPhysicsModel.compute_coefficients(
					alpha_rad, alpha_0, geo, mach, re, config
				)

				# 4. Store Data
				lut.cl_data.append(coeffs.cl)
				lut.cd_data.append(coeffs.cd)
				lut.cm_data.append(coeffs.cm)
				lut.stall_data.append(coeffs.sigma)

	lut.cl_data = _smooth_array(lut.cl_data, SMOOTH_PASSES) # 1 Pass is usually enough
	lut.cd_data = _smooth_array(lut.cd_data, SMOOTH_PASSES)
	lut.cm_data = _smooth_array(lut.cm_data, SMOOTH_PASSES)

	print("LutGenerator: Smoothing applied.")
	return lut


static func save_lut(lut: AirfoilLut, path: String) -> void:
	var error = ResourceSaver.save(lut, path)
	if error != OK:
		push_error("LutGenerator: Failed to save LUT to %s" % path)
	else:
		print("LutGenerator: Saved successfully to %s" % path)

static func _smooth_array(data: Array[float], passes: int = 1) -> Array[float]:
	var result = data.duplicate()
	var n = result.size()
	if n < 3: return result

	for p in range(passes):
		var temp = result.duplicate()
		for i in range(1, n - 1):
			# Simple 3-Point "Moving Average" (Box Blur)
			# Weighted: 25% left, 50% center, 25% right
			result[i] = 0.25 * temp[i-1] + 0.5 * temp[i] + 0.25 * temp[i+1]
	return result

static func _get_alpha_grid(start_deg: float = -180.0, end_deg: float = 180.0, density: float = 0.5) -> Array[float]:
	var p: Array[float] = []
	var step_deg: float = density
	var start := start_deg
	var end := end_deg

	var steps := int((end - start) / step_deg)

	for i in range(steps + 1):
		p.append(start + i * step_deg)

	return p
