class_name AeroPhysicsModel
extends RefCounted

# ==============================================================================
#  TUNING PARAMETERS
# ==============================================================================

# --- 1. Compressibility (Mach Effects) ---
static var mach_limit_sub: float = 0.9          # End of Subsonic regime (Prandtl-Glauert limit)
static var mach_limit_sup: float = 1.2          # Start of Pure Supersonic regime (Ackeret)
static var mach_stall_onset: float = 0.4        # Mach where stall angle begins to decrease
static var mach_stall_reduction: float = 0.5    # How fast stall angle drops after onset

# --- 2. Stall Geometry & Behavior ---
static var stall_re_ref: float = 5.0e5          # Reference Reynolds number
static var stall_le_quality_factor: float = 15.0 # How much LE Radius improves circulation
static var stall_max_cap_deg: float = 25.0      # Hard cap for forward stall angle
static var stall_min_deg: float = 6.0           # Minimum stall angle (even at high Mach)
static var stall_te_roundness_threshold: float = 0.05 # TE Thickness where it behaves like a generic Leading Edge

# Camber Shift: High camber shifts the stall angle range
static var stall_camber_shift_sensitivity: float = 40.0
static var stall_camber_shift_min: float = -5.0
static var stall_camber_shift_max: float = 8.0

# --- 3. Plate Lift (Post-Stall Blending) ---
static var plate_scale_sharp: float = 0.58    # Scale for sharp separation edge (clean wake)
static var plate_scale_blunt: float = 0.45    # Scale for round separation edge (messy wake)
static var plate_blunt_threshold: float = 0.04 # Radius/Thickness considered "Blunt"

static var plate_thickness_damping_threshold: float = 0.3
# Defines the blend window (in degrees) around 90 deg (or aerodynamic center)
static var plate_trans_width_deg: float = 20.0

# Defines the "Deep Stall" region where backward lift (LE radius) dominates
static var plate_deep_stall_start_deg: float = 110.0
static var plate_deep_stall_peak_deg: float = 170.0

# --- 4. Suction Spike & Crash (Stall Dynamics) ---
static var spike_ref_radius: float = 0.012      # Radius considered "good" for suction (1.5% chord ~ 0.015)
static var spike_max_capacity: float = 1.15     # Max multiplier for suction
static var spike_camber_penalty: float = 25.0   # Penalty when flying against camber

static var spike_boost_mag: float = 0.25        # Pre-stall suction rise magnitude
static var spike_crash_mag: float = 0.255       # Post-stall lift dump magnitude

static var recovery_thick_min: float = 30.0     # Recovery angle (deg) for thin wings
static var recovery_thick_max: float = 10.0     # Recovery angle (deg) for thick wings

# --- 5. Buffet / Noise ---
static var buffet_base_shake: float = 0.001
static var buffet_sharp_bonus: float = 0.0215     # Extra shake for sharp edges
static var buffet_window_width: float = 5.5     # Width of the shake window in degrees
static var buffet_freq_alpha: float = 100.0
static var buffet_freq_mach: float = 5.0

# --- 6. Drag Coefficients ---
static var drag_re_floor: float = 10000.0
static var drag_wave_peak_mach: float = 1.05    # Mach where wave drag peaks
static var drag_wave_factor: float = 5.0        # Multiplier for thickness^2 wave drag
static var drag_mcrit_thick_factor: float = 1.4 # How much thickness reduces Critical Mach
static var drag_base_factor: float = 0.15

# --- 7. Moment Parameters ---
static var ac_offset_supersonic: float = 0.25

# ==============================================================================
#  INTERNAL CONTEXT
# ==============================================================================

class _CalcContext:
	# Inputs
	var alpha_rad: float
	var alpha_0: float
	var geo: Dictionary
	var mach: float
	var re: float
	var config: LutGenerator.GeneratorConfig

	# Derived
	var thickness: float
	var angle_norm: float
	var angle_deg_abs: float
	var is_forward: bool

	# Calculations
	var cl_slope_factor: float = 1.0
	var mach_stall_factor: float = 1.0
	var re_factor: float = 1.0
	var current_stall_angle: float = 0.0
	var effective_alpha: float = 0.0
	var used_alpha0: float = 0.0
	var effective_slope: float = 0.0
	var stall_center_bias: float = 0.0

	# Outputs
	var sigma: float = 0.0
	var blended_cl: float = 0.0
	var spike_cl: float = 0.0
	var buffet_cl: float = 0.0
	var final_cl: float = 0.0
	var final_cd: float = 0.0
	var final_cm: float = 0.0

	func _init(_alpha: float, _a0: float, _geo: Dictionary, _m: float, _re: float, _cfg: LutGenerator.GeneratorConfig):
		alpha_rad = _alpha
		alpha_0 = _a0
		geo = _geo
		mach = _m
		re = _re
		config = _cfg
		thickness = geo.thickness

		angle_norm = wrapf(alpha_rad, -PI, PI)
		angle_deg_abs = rad_to_deg(abs(angle_norm))
		is_forward = abs(angle_norm) < (PI / 2.0)

# ==============================================================================
#  MAIN COMPUTE FUNCTION
# ==============================================================================

static func compute_coefficients(
	alpha_rad: float,
	alpha_0: float,
	geo: Dictionary,
	mach: float,
	re: float,
	config: LutGenerator.GeneratorConfig
) -> Dictionary:

	var ctx = _CalcContext.new(alpha_rad, alpha_0, geo, mach, re, config)

	_calc_compressibility(ctx)
	_calc_stall_geometry(ctx)
	_calc_sigma(ctx)
	_calc_base_lift(ctx)
	_calc_suction_spike(ctx)
	_calc_buffet(ctx)
	_calc_drag(ctx)
	_calc_moment(ctx)

	return {
		"cl": ctx.final_cl,
		"cd": ctx.final_cd,
		"cm": ctx.final_cm,
		"sigma": ctx.sigma
	}

# ==============================================================================
#  LOGIC PIPELINE
# ==============================================================================

static func _calc_compressibility(ctx: _CalcContext) -> void:
	# Slope Correction
	var factor = 1.0

	if ctx.mach <= mach_limit_sub:
		factor = 1.0 / sqrt(1.0 - pow(ctx.mach, 2))
	elif ctx.mach >= mach_limit_sup:
		factor = 4.0 / sqrt(pow(ctx.mach, 2) - 1.0)
	else:
		# Transonic Blending
		var val_sub = 1.0 / sqrt(1.0 - pow(mach_limit_sub, 2))
		var val_sup = min(4.0 / sqrt(pow(mach_limit_sup, 2) - 1.0), 3.0)
		var t = (ctx.mach - mach_limit_sub) / (mach_limit_sup - mach_limit_sub)
		factor = lerp(val_sub, val_sup, t)

	ctx.cl_slope_factor = min(factor, 4.0)

	# Mach Stall Effect
	if ctx.mach > mach_stall_onset:
		ctx.mach_stall_factor = clamp(1.0 - mach_stall_reduction * (ctx.mach - mach_stall_onset), 0.5, 1.0)
static func _calc_stall_geometry(ctx: _CalcContext) -> void:
	# 1. Reynolds Factor (Applies to both)
	ctx.re_factor = 1.0 - 0.3 / (1.0 + ctx.re / stall_re_ref)

	var base_slope = (2.0 * PI) * ctx.cl_slope_factor
	ctx.effective_slope = base_slope

	# 2. Determine Orientation-Specific Parameters

	var active_stall_base_deg: float = 0.0
	var active_camber_sign: float = 1.0
	var orientation_stall_factor: float = 1.0

	if ctx.is_forward:
		# --- FORWARD FLIGHT ---
		# Standard LE Radius logic
		ctx.used_alpha0 = ctx.alpha_0

		# Use Forward Config
		active_stall_base_deg = ctx.config.stall_angle_deg_fwd
		active_camber_sign = 1.0 # Camber works as designed

		ctx.effective_alpha = ctx.angle_norm

	else:
		# --- BACKWARD FLIGHT ---
		# Determine efficiency of the Trailing Edge acting as a Leading Edge
		# If TE is sharp (0.0), efficiency is low. If TE is thick (oval), efficiency is high.
		var te_quality = clamp(ctx.geo.te_thickness / stall_te_roundness_threshold, 0.0, 1.0)

		# We blend between the defined "Backward Stall" (usually low) and "Forward Stall" (high)
		# based on how round the back is.
		active_stall_base_deg = lerp(ctx.config.stall_angle_deg_bwd, ctx.config.stall_angle_deg_fwd, te_quality)

		# Efficiency Penalty: Even a round TE is usually less optimized than a real LE.
		# If it's a perfect oval, te_quality is 1.0, factor approaches 0.95.
		# If it's sharp, factor is 1.0 (but applied to a lower base angle).
		orientation_stall_factor = lerp(1.0, 0.9, te_quality)

		# Invert Alpha 0 logic
		# If the wing has a sharp LE (now trailing), circulation is poor.
		var le_circulation_efficiency = clamp(1.0 - (ctx.geo.le_radius * stall_le_quality_factor), 0.5, 0.95)
		ctx.used_alpha0 = -ctx.alpha_0 * le_circulation_efficiency

		# Camber works in reverse relative to airflow
		active_camber_sign = -1.0

		# Rotate Alpha for calculation
		if ctx.angle_norm > 0:
			ctx.effective_alpha = ctx.angle_norm - PI
		else:
			ctx.effective_alpha = ctx.angle_norm + PI

	# 3. Universal Stall Calculation (Applied to both directions)

	# Clamp base stall
	var clamped_stall = min(active_stall_base_deg, stall_max_cap_deg)
	var base_stall_rad = deg_to_rad(clamped_stall) * ctx.re_factor * orientation_stall_factor

	# Camber Shift
	# High camber shifts the stall range.
	# In backward flight, this shift is inverted (controlled by active_camber_sign).
	var stall_shift_deg = clamp(ctx.geo.camber * stall_camber_shift_sensitivity * active_camber_sign, stall_camber_shift_min, stall_camber_shift_max)
	var stall_shift_rad = deg_to_rad(stall_shift_deg)

	# Side Blend Logic (Transition through 90 degrees)
	# We use the raw angle_norm to determine which side of the wing is loaded
	var side_blend = smoothstep(-0.1, 0.1, ctx.angle_norm)

	# If flying backward, the "Top" and "Bottom" swap aerodynamic roles relative to the wind vector
	if not ctx.is_forward:
		# Invert the blending direction for backward flight
		side_blend = 1.0 - side_blend

	var shift_factor = lerp(-1.0, 1.0, side_blend)
	var final_shift = stall_shift_rad * shift_factor

	# 4. Final Result
	# Now applies Mach Stall Factor to backward flight as well!
	ctx.current_stall_angle = max(deg_to_rad(stall_min_deg), (base_stall_rad + final_shift) * ctx.mach_stall_factor)
static func _calc_stall_geometry_old(ctx: _CalcContext) -> void:
	# Reynolds factor
	ctx.re_factor = 1.0 - 0.3 / (1.0 + ctx.re / stall_re_ref)

	var base_slope = (2.0 * PI) * ctx.cl_slope_factor
	ctx.effective_slope = base_slope

	# Alpha 0 adjustment for backward flight
	ctx.used_alpha0 = ctx.alpha_0
	if not ctx.is_forward:
		var circulation_efficiency = clamp(1.0 - (ctx.geo.le_radius * stall_le_quality_factor), 0.5, 0.95)
		ctx.used_alpha0 = -ctx.alpha_0 * circulation_efficiency

	if ctx.is_forward:
		var raw_stall = ctx.config.stall_angle_deg_fwd
		var clamped_stall = min(raw_stall, stall_max_cap_deg)
		var base_stall_rad = deg_to_rad(clamped_stall) * ctx.re_factor

		# High Cl Correction / Camber Shift
		var stall_shift_deg = clamp(ctx.geo.camber * stall_camber_shift_sensitivity, stall_camber_shift_min, stall_camber_shift_max)
		var stall_shift_rad = deg_to_rad(stall_shift_deg)

		var side_blend = smoothstep(-0.1, 0.1, ctx.angle_norm)
		var shift_factor = lerp(-1.0, 1.0, side_blend)
		var final_shift = stall_shift_rad * shift_factor

		ctx.current_stall_angle = max(deg_to_rad(stall_min_deg), (base_stall_rad + final_shift) * ctx.mach_stall_factor)
		ctx.effective_alpha = ctx.angle_norm
	else:
		# Backward flight
		ctx.current_stall_angle = deg_to_rad(ctx.config.stall_angle_deg_bwd) * ctx.re_factor
		if ctx.angle_norm > 0:
			ctx.effective_alpha = ctx.angle_norm - PI
		else:
			ctx.effective_alpha = ctx.angle_norm + PI

static func _calc_sigma(ctx: _CalcContext) -> void:
	ctx.stall_center_bias = ctx.alpha_0 * 0.5 if ctx.is_forward else 0.0

	ctx.sigma = _sigmoid_blend(
		ctx.effective_alpha,
		-ctx.current_stall_angle + ctx.stall_center_bias,
		ctx.current_stall_angle + ctx.stall_center_bias,
		ctx.config.sharpness
	)

static func _calc_base_lift(ctx: _CalcContext) -> void:
	var cl_linear = ctx.effective_slope * (ctx.effective_alpha - ctx.used_alpha0)

	# --- DYNAMIC PLATE SCALING ---

	# Physics: The efficiency of a flat plate depends on how cleanly the flow separates
	# from the rear edge (relative to flow).
	# Sharp Edge -> Clean Vortex Shedding -> Higher Lift (scale ~ 0.58)
	# Round Edge -> Attached/Messy Flow -> Lower Lift (scale ~ 0.45)

	# 1. Analyze the "Geometric Back" (Trailing Edge)
	# Used for Forward Flight
	var te_bluffness = clamp(ctx.geo.te_thickness / plate_blunt_threshold, 0.0, 1.0)
	var dynamic_fwd_scale = lerp(plate_scale_sharp, plate_scale_blunt, te_bluffness)

	# 2. Analyze the "Geometric Front" (Leading Edge)
	# Used for Backward Flight (because LE acts as the separation edge)
	# Note: LE Radius is usually small (0.01-0.03), so we scale it up to match thickness units
	var le_eff_thickness = ctx.geo.le_radius * 2.0
	var le_bluffness = clamp(le_eff_thickness / plate_blunt_threshold, 0.0, 1.0)
	var dynamic_bwd_scale = lerp(plate_scale_sharp, plate_scale_blunt, le_bluffness)

	# --- DYNAMIC TRANSITION WINDOW ---

	# The plate logic (Sin 2*alpha) centers naturally at 90 degrees.
	# However, camber shifts the aerodynamic center.
	# If camber is -0.05, the "Zero Lift" point shifts. We must shift the blending window too.

	var plate_phase_shift = ctx.geo.camber * 0.5
	var shift_deg = rad_to_deg(plate_phase_shift) # e.g. -2.5 degrees

	# Calculate window centers (Nominally 90 and 270/(-90))
	var center_fwd = 90.0 + shift_deg

	# Define window width (e.g. +/- 20 degrees)
	var window_half_width = plate_trans_width_deg

	# 1. Forward to Backward Transition (around 90 deg)
	var trans_start = center_fwd - window_half_width
	var trans_end = center_fwd + window_half_width
	var transition_blend = smoothstep(trans_start, trans_end, ctx.angle_deg_abs)

	# 2. Deep Backward Variation (Approaching 180 deg)
	# At 180 degrees, we are purely using the "Back" scale (which uses LE geometry)
	# Defines the "Deep Stall" region where backward lift (LE radius) dominates

	var rear_start = plate_deep_stall_start_deg
	var rear_end = plate_deep_stall_peak_deg
	var back_variation = smoothstep(rear_start, rear_end, ctx.angle_deg_abs)

	# --- COMPUTE FINAL SCALE ---

	# Lerp 1: Transition from Forward Scale to Base Backward Scale
	var current_scale = lerp(dynamic_fwd_scale, dynamic_bwd_scale, transition_blend)

	# Lerp 2: Slight boost for perfect 180 (optional, keeps your original logic of 0.52 max)
	# If dynamic_bwd_scale is low (0.45), we let it rise slightly at 180 if needed,
	# or just keep it consistent. For strict physics, keeping it at dynamic_bwd_scale is safer.
	# But to preserve your original curve shape, we can blend towards a "Max Bwd":
	var scale_180 = min(dynamic_bwd_scale * 1.1, plate_scale_sharp)
	current_scale = lerp(current_scale, scale_180, back_variation)

	# --- GEOMETRIC CORRECTIONS ---
	var thickness_damping = clamp(1.0 - (ctx.thickness * plate_thickness_damping_threshold), 0.8, 1.0)

	var cl_plate = ctx.config.cd_max * sin(2.0 * (ctx.alpha_rad - plate_phase_shift)) * current_scale * thickness_damping

	ctx.blended_cl = (ctx.sigma * cl_linear) + ((1.0 - ctx.sigma) * cl_plate)

static func _calc_suction_spike(ctx: _CalcContext) -> void:
	var active_radius = 0.0
	if ctx.is_forward:
		active_radius = ctx.geo.get("le_radius", 0.0)
	else:
		var te_thick = ctx.geo.get("te_thickness", 0.0)
		active_radius = (te_thick * te_thick) / 0.1
	#print("active_radius at %f alpha is: %f" % [rad_to_deg(ctx.alpha_rad), active_radius])
	var raw_suction = sqrt(active_radius / spike_ref_radius)
	var suction_capacity = clamp(raw_suction, 0.0, spike_max_capacity)

	var delta_alpha = ctx.effective_alpha - ctx.alpha_0
	var aero_sign = sign(delta_alpha)

	var side_damper = 1.0
	if (delta_alpha * ctx.geo.camber) < 0.0:
		var camber_penalty = abs(ctx.geo.camber) * spike_camber_penalty
		side_damper = clamp(1.0 - camber_penalty, 0.4, 1.0)

	var boost_mag = spike_boost_mag * suction_capacity * side_damper
	var crash_mag = spike_crash_mag * suction_capacity * side_damper

	var boost_val = boost_mag * sin(ctx.sigma * PI) * aero_sign

	var dist_from_stall = abs(ctx.effective_alpha - ctx.stall_center_bias) - ctx.current_stall_angle
	var stall_excess = max(0.0, dist_from_stall)

	var dynamic_recovery = lerp(recovery_thick_min, recovery_thick_max, clamp((ctx.thickness - 0.05) / 0.15, 0.0, 1.0))
	var recovery_rad = deg_to_rad(dynamic_recovery)
	var ratio = clamp(stall_excess / recovery_rad, 0.0, 1.0)
	var crash_decay = 0.5 * (1.0 + cos(ratio * PI))

	var crash_val = -crash_mag * crash_decay * aero_sign
	var blend_width = lerp(0.15, 0.30, clamp((ctx.thickness - 0.05) / 0.10, 0.0, 1.0))
	var blend_min = 0.5 - blend_width
	var blend_max = 0.5 + blend_width

	var phase_blend = smoothstep(blend_min, blend_max, ctx.sigma)
	ctx.spike_cl = lerp(crash_val, boost_val, phase_blend)

	ctx.final_cl = ctx.blended_cl + ctx.spike_cl

static func _calc_buffet(ctx: _CalcContext) -> void:
	var buffet_signal = 0.0
	var facing_edge_radius = ctx.geo.le_radius if ctx.is_forward else max(ctx.geo.te_thickness * 0.5, 0.0001)
	var smoothness_threshold = 0.01

	var sharp_edge_factor = clamp(1.0 - (facing_edge_radius / smoothness_threshold), 0.0, 1.0)
	var stall_deg_abs = rad_to_deg(ctx.current_stall_angle)
	var angle_relative_abs = ctx.angle_deg_abs if ctx.is_forward else abs(180.0 - ctx.angle_deg_abs)

	# Use vars for start/end
	var noise_start_agnle_offset: float = 0.0
	var noise_start_angle = stall_deg_abs + noise_start_agnle_offset
	var noise_end_angle = noise_start_angle + buffet_window_width

	if angle_relative_abs > noise_start_angle and angle_relative_abs < noise_end_angle:
		var total_amp = buffet_base_shake + (buffet_sharp_bonus * sharp_edge_factor)
		var frequency = ctx.alpha_rad * buffet_freq_alpha + (ctx.mach * buffet_freq_mach)
		var cos_sin_freq: float = 0.0
		if ctx.alpha_rad > 0.0:
			cos_sin_freq = sin(frequency)*-1
		else:
			cos_sin_freq = cos(frequency)
		var noise_wave = cos_sin_freq

		var fade_in = smoothstep(noise_start_angle, noise_start_angle + 1.0, angle_relative_abs)
		var fade_out = 1.0 - smoothstep(noise_end_angle - 1.0, noise_end_angle, angle_relative_abs)

		buffet_signal = noise_wave * total_amp * fade_in * fade_out

	ctx.buffet_cl = buffet_signal
	ctx.final_cl += buffet_signal
static func _calc_drag(ctx: _CalcContext) -> void:
	var safe_re = max(ctx.re, drag_re_floor)
	var cf = 0.074 / pow(safe_re, 0.2)

	# Hoerner Form Factor (Body thickness)
	var form_factor = 1.0 + (2.0 * ctx.thickness) + (60.0 * pow(ctx.thickness, 4))

	# 1. Skin Friction + Form Drag
	var cd0_profile = 2.0 * cf * form_factor + (0.005 * abs(ctx.geo.camber))

	# 2. Base Drag (NEW: Crucial for Oval/Blunt TE shapes)
	# Drag caused by the vacuum behind a thick trailing edge.
	# Formula approx: 0.1 to 0.2 * (t_te / chord)
	var te_thick = ctx.geo.get("te_thickness", 0.0)
	var cd_base = drag_base_factor * te_thick

	# 3. Induced Drag (Approximation for 2D/infinite wing)
	# Note: If this LUT is for a 3D wing, the Sim usually calculates this.
	# For 2D sections, this should be very small.
	var cd_induced = pow(ctx.blended_cl, 2) / (PI * 25.0)

	var cd0_subsonic = cd0_profile + cd_base + cd_induced

	# 4. Plate Drag (Stall)
	var plate_multiplier = 1.0
	if ctx.mach < 1.0:
		plate_multiplier = 1.0
	elif ctx.mach < 1.5:
		var t = (ctx.mach - 1.0) / 0.5
		plate_multiplier = 1.0 + (0.1 * sin(t * PI))
	else:
		var t = clamp((ctx.mach - 1.5) / 8.5, 0.0, 1.0)
		plate_multiplier = lerp(1.0, 0.92, t)

	var cd_plate = (ctx.config.cd_max * plate_multiplier) * pow(sin(ctx.alpha_rad), 2)

	# 5. Wave Drag
	var cd_wave = 0.0
	var m_crit = 0.9 - (ctx.thickness * drag_mcrit_thick_factor) - (abs(ctx.blended_cl) * 0.1)
	m_crit = clamp(m_crit, 0.6, 0.95)

	if ctx.mach > m_crit:
		var cd_wave_peak = drag_wave_factor * pow(ctx.thickness, 2.0)
		if ctx.mach < drag_wave_peak_mach:
			var ratio_mach = clamp((ctx.mach - m_crit) / (drag_wave_peak_mach - m_crit), 0.0, 1.0)
			cd_wave = cd_wave_peak * sin(ratio_mach * PI / 2.0)
		else:
			cd_wave = cd_wave_peak * (drag_wave_peak_mach / ctx.mach)

	# Final Blend
	ctx.final_cd = ctx.sigma * (cd0_subsonic + cd_wave) + (1.0 - ctx.sigma) * cd_plate

static func _calc_drag_old(ctx: _CalcContext) -> void:
	var safe_re = max(ctx.re, drag_re_floor)
	var cf = 0.074 / pow(safe_re, 0.2)
	var form_factor = 1.0 + (2.0 * ctx.thickness) + (60.0 * pow(ctx.thickness, 4))

	var cd0_subsonic = 2.0 * cf * form_factor + (0.005 * abs(ctx.geo.camber))
	var cd_induced = pow(ctx.blended_cl, 2) / (PI * 25.0)

	var plate_multiplier = 1.0
	if ctx.mach < 1.0:
		plate_multiplier = 1.0
	elif ctx.mach < 1.5:
		var t = (ctx.mach - 1.0) / 0.5
		plate_multiplier = 1.0 + (0.1 * sin(t * PI))
	else:
		var t = clamp((ctx.mach - 1.5) / 8.5, 0.0, 1.0)
		plate_multiplier = lerp(1.0, 0.92, t)

	var cd_plate = (ctx.config.cd_max * plate_multiplier) * pow(sin(ctx.alpha_rad), 2)

	var cd_wave = 0.0
	var m_crit = 0.9 - (ctx.thickness * drag_mcrit_thick_factor) - (abs(ctx.blended_cl) * 0.1)
	m_crit = clamp(m_crit, 0.6, 0.95)

	if ctx.mach > m_crit:
		var cd_wave_peak = drag_wave_factor * pow(ctx.thickness, 2.0)
		if ctx.mach < drag_wave_peak_mach:
			var ratio_mach = clamp((ctx.mach - m_crit) / (drag_wave_peak_mach - m_crit), 0.0, 1.0)
			cd_wave = cd_wave_peak * sin(ratio_mach * PI / 2.0)
		else:
			cd_wave = cd_wave_peak * (drag_wave_peak_mach / ctx.mach)

	ctx.final_cd = ctx.sigma * (cd0_subsonic + cd_induced + cd_wave) + (1.0 - ctx.sigma) * cd_plate
static func _calc_moment(ctx: _CalcContext) -> void:
	# 1. Calculate Normal Force (approx Cl at low angles)
	var cn = ctx.final_cl * cos(ctx.alpha_rad) + ctx.final_cd * sin(ctx.alpha_rad)

	# 2. Determine Cm0 (Pitching moment at zero lift)
	var base_cm0 = 0.0
	if ctx.geo.has("cm_0"):
		base_cm0 = ctx.geo.cm_0
	else:
		# Thin airfoil theory approximation
		base_cm0 = -2.0 * ctx.geo.camber

	# FIX: If flying backward, the camber shape relative to flow is inverted.
	# We also need to check if the 'active' trailing edge is sharp or round (like in stall logic),
	# but simply inverting the sign is 90% of the solution for non-symmetric airfoils.
	if not ctx.is_forward:
		base_cm0 = -base_cm0

	var moment_camber = base_cm0 * ctx.sigma

	# 3. Determine Aerodynamic Center (AC) Position
	# Subsonic: defined in config (usually 0.25)
	# Supersonic: shifts towards 0.50
	var ac_target = ctx.config.ac_position

	if ctx.mach > 0.8:
		# Shift AC back between Mach 0.8 and 1.2
		var shift_factor = clamp((ctx.mach - 0.8) / 0.4, 0.0, 1.0)
		ac_target += (ac_offset_supersonic * shift_factor)

	# 4. Center of Pressure (CoP) blending
	# Laminar (sigma=1): Force acts at AC
	# Stall (sigma=0): Force acts at Plate Center (0.5)

	var cop = 0.5
	if ctx.is_forward:
		cop = lerp(0.5, ac_target, ctx.sigma)
	else:
		# Backward Flight:
		# If we fly backward, the "Leading Edge" is at chord=1.0.
		# The AC is 25% from that edge, so it is at 0.75 relative to the geometric origin.
		# Note: Supersonic shift applies here too (0.75 -> 0.50)
		var ac_bwd = 1.0 - ac_target
		cop = lerp(0.5, ac_bwd, ctx.sigma)

	# 5. Calculate Final Moment
	# Moment = Cm0 + Cn * (Pivot - CoP)
	# We assume the pivot (CG) for the LUT generation is at the AC reference (config.ac_position),
	# but usually, LUTs define Cm around the quarter-chord (0.25).

	# Lever arm: Distance from the Reference Point (0.25) to the actual CoP
	var lever_arm = ctx.config.ac_position - cop

	ctx.final_cm = moment_camber + (cn * lever_arm)

	# Add Buffet noise to moment
	ctx.final_cm += ctx.buffet_cl * 0.2
static func _calc_moment_old(ctx: _CalcContext) -> void:
	var cn = ctx.final_cl * cos(ctx.alpha_rad) + ctx.final_cd * sin(ctx.alpha_rad)

	var cm0 = -2.0 * ctx.geo.camber
	if ctx.geo.has("cm_0"):
		cm0 = ctx.geo.cm_0

	var moment_camber = cm0 * ctx.sigma

	var cop = lerp(0.5, ctx.config.ac_position, ctx.sigma)
	if not ctx.is_forward:
		cop = lerp(0.5, 0.75, ctx.sigma)

	var lever_arm = ctx.config.ac_position - cop
	ctx.final_cm = moment_camber + (cn * lever_arm)
	ctx.final_cm += ctx.buffet_cl * 0.2

static func _sigmoid_blend(val: float, min_boundary: float, max_boundary: float, sharpness: float) -> float:
	var s1 = 1.0 / (1.0 + exp(sharpness * (val - max_boundary)))
	var s2 = 1.0 / (1.0 + exp(-sharpness * (val - min_boundary)))
	return min(s1, s2)
