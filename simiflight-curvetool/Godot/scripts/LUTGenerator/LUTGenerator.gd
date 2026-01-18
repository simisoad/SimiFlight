class_name LutGenerator extends Resource

# -- Constants for Grid Generation --
const MACH_POINTS: Array[float] = [0.01, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
const REYNOLDS_POINTS: Array[float] = [1.0e4, 0.5e5, 1.0e5, 5.0e5, 1.0e6, 5.0e6, 1.0e7, 3.0e7, 5.0e7, 10.0e7]

const SMOOTH_PASSES: int = 1

static var sampling_steps: float = 0.5

# Alpha_range for Preview:
static var preview_alpha_start_deg: float = -360.0
static var preview_alpha_end_deg: float = 360.0

# -- Configuration Class --
class GeneratorConfig:
	var stall_angle_deg_fwd: float = 15.0
	var stall_angle_deg_bwd: float = 8.0
	var sharpness: float = 856.0
	var ac_position: float = 0.25

	var is_finite_wing: bool = false
	var sweep_deg: float = 30.0
	var taper: float = 0.0
	var sweep_location: float = 0.0
	var aspect_ratio: float = 6.0
	var oswald_efficiency: float = 0.85
	var is_bet_mode: bool = false
	var vortex_intensity: float = 1.0

	# Preview Settings
	var preview_mach: float = 0.1
	var preview_re: float = 1.8e6
	var physics: AeroPhysicsConfig = AeroPhysicsConfig.new()
## Creates a deep copy of this configuration
	func clone() -> GeneratorConfig:
		var c = GeneratorConfig.new()
		c.stall_angle_deg_fwd = stall_angle_deg_fwd
		c.stall_angle_deg_bwd = stall_angle_deg_bwd
		c.sharpness = sharpness
		c.ac_position = ac_position
		c.vortex_intensity = vortex_intensity
		c.sweep_deg = sweep_deg
		c.aspect_ratio = aspect_ratio
		c.oswald_efficiency = oswald_efficiency
		c.taper = taper
		c.sweep_location = sweep_location
		c.is_finite_wing = is_finite_wing
		c.is_bet_mode = is_bet_mode
		c.physics = physics # This is a reference, which is fine for now
		c.preview_mach = preview_mach
		c.preview_re = preview_re
		return c
func _init() -> void:
	EventBus.preview_start_alpha_set.connect(
		func(v):
		preview_alpha_start_deg = v
		)
	EventBus.preview_end_alpha_set.connect(func(v): preview_alpha_end_deg = v)

# -- Main Logic --
## Generates a single curve for UI previewing without generating the full LUT
static func calculate_preview_series(profile: AirfoilProfile, config: GeneratorConfig) -> AeroSeries:
	var geo = AirfoilGeometryAnalyzer.analyze(profile)
	var alpha_0 = geo.alpha_0
	var series = AeroSeries.new()
	series.name = profile.name

	var grid = _get_alpha_grid(preview_alpha_start_deg, preview_alpha_end_deg)

	for alpha_deg in grid:
		var coeffs = AeroPhysicsModel.compute_coefficients(
			deg_to_rad(alpha_deg), alpha_0, geo, config.preview_mach, config.preview_re, config
		)

		var res = AeroResult.new()
		res.alpha = alpha_deg
		res.cl = coeffs.cl
		res.cd = coeffs.cd
		res.cm = coeffs.cm
		res.sigma = coeffs.sigma
		series.results.append(res)

	# Optional: Apply smoothing to the results array here if needed
	return series

## Main function to generate the complete AirfoilLut resource
static func generate_lut(profile: AirfoilProfile, config: GeneratorConfig) -> AirfoilLut:
	if not profile:
		push_error("LutGenerator: No profile provided.")
		return null

	#print("LutGenerator: Starting generation for '%s'..." % profile.resource_name)

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

	#print("LutGenerator: Smoothing applied.")
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

static func _get_alpha_grid(start_deg: float = -180.0, end_deg: float = 180.0) -> Array[float]:
	var p: Array[float] = []
	var step_deg: float = sampling_steps
	var start := start_deg
	var end := end_deg

	var steps := int((end - start) / step_deg)

	for i in range(steps + 1):
		p.append(start + i * step_deg)

	return p
