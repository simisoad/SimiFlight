class_name AeroPhysicsModel
extends RefCounted

# ==============================================================================
#  TUNING PARAMETERS
# ==============================================================================
# ==============================================================================
# --- 1. Compressibility (Mach Effects) ---
# ==============================================================================
static var mach_limit_sub: float = 0.9
static var mach_limit_sup: float = 1.2
static var mach_stall_onset_fwd: float = 0.4
static var mach_stall_onset_bwd: float = 0.2 # Sharp edges shock-stall earlier!
static var mach_stall_reduction: float = 0.5
# ==============================================================================
# --- 2. Stall Geometry & Behavior ---
# ==============================================================================
static var stall_re_ref: float = 5.0e5
static var stall_le_quality_factor: float = 15.0

static var stall_max_cap_deg_fwd: float = 25.0
static var stall_max_cap_deg_bwd: float = 25.0
static var stall_min_deg_fwd: float = 1.0
static var stall_min_deg_bwd: float = 1.0

static var stall_te_roundness_threshold: float = 0.05

static var stall_camber_shift_sensitivity: float = 40.0
static var stall_camber_shift_min: float = -5.0
static var stall_camber_shift_max: float = 8.0
# ==============================================================================
# --- 3. Plate Lift (Post-Stall Blending) ---
# ==============================================================================
static var plate_scale_sharp: float = 0.58
static var plate_scale_blunt: float = 0.45
static var plate_blunt_threshold: float = 0.04
static var plate_thickness_damping_threshold: float = 0.3
static var plate_trans_width_deg: float = 20.0
static var plate_deep_stall_start_deg: float = 110.0
static var plate_deep_stall_peak_deg: float = 170.0
# ==============================================================================
# --- 4. Suction Spike & Crash (SPLIT FORWARD / BACKWARD) ---
# ==============================================================================
static var spike_ref_radius: float = 0.012
static var spike_camber_penalty: float = 25.0
# ==============================================================================
# -- Forward Parameters --
# ==============================================================================
static var spike_max_capacity_fwd: float = 1.15
static var spike_boost_mag_fwd: float = 0.25
static var spike_crash_mag_fwd: float = 0.255
static var recovery_thick_min_fwd: float = 30.0
static var recovery_thick_max_fwd: float = 10.0
# ==============================================================================
# -- Backward Parameters --
# ==============================================================================
static var spike_max_capacity_bwd: float = 0.90  # Usually lower for backward flight
static var spike_boost_mag_bwd: float = 0.15     # Softer peak
static var spike_crash_mag_bwd: float = 0.20     # Softer crash
static var recovery_thick_min_bwd: float = 25.0
static var recovery_thick_max_bwd: float = 15.0
# ==============================================================================
# --- 5. Buffet / Noise ---
# ==============================================================================

static var buffet_base_shake_fwd: float = 0.001
static var buffet_base_shake_bwd: float = 0.005 # 5x vibration in reverse
static var buffet_sharp_bonus: float = 0.0215
static var buffet_window_width: float = 5.5
static var buffet_freq_alpha: float = 100.0
static var buffet_freq_mach: float = 5.0

# ==============================================================================
# --- 6. Drag Coefficients ---
# ==============================================================================

static var drag_re_floor: float = 10000.0
static var drag_wave_peak_mach: float = 1.05
static var drag_wave_factor: float = 5.0
static var drag_mcrit_thick_factor: float = 1.4
static var drag_base_factor: float = 0.25

# ==============================================================================
# --- 7. Moment Parameters ---
# ==============================================================================

static var ac_offset_supersonic: float = 0.25

# ==============================================================================
#  8. ABNORMAL GEOMETRY & BLUFF BODY LOGIC
# ==============================================================================

# How thick the nose must be (relative to max thickness) to start counting as "Bluff"
static var bluff_nose_threshold_min: float = 0.3
static var bluff_nose_threshold_max: float = 0.7

# Absolute size override: If nose is wider than this fraction of chord (0.04 = 4%), it's a bluff body.
static var bluff_abs_threshold_min: float = 0.04
static var bluff_abs_threshold_max: float = 0.08

# Rectangularity Logic (Bricks/Plates)
static var rect_threshold_start: float = 0.7
static var rect_threshold_width: float = 0.25 # Range over which it blends to 100% brick

# Thickness Penalty (Fat Wing Efficiency)
static var thick_pen_min: float = 0.22
static var thick_pen_max: float = 0.45

# Camber Efficiency
static var camber_eff_threshold: float = 0.06 # Camber above this starts losing efficiency
static var camber_eff_slope: float = 10.0

# TE Openness Penalty (The "Banana" penalty for thick trailing edges)
static var te_open_pen_min: float = 0.02
static var te_open_pen_max: float = 0.15

# ==============================================================================
#  INTERNAL CONTEXT
# ==============================================================================

class _CalcContext:
	var alpha_rad: float
	var alpha_0: float
	var geo: Dictionary
	var mach: float
	var re: float
	var config: LutGenerator.GeneratorConfig

	var thickness: float
	var angle_norm: float
	var angle_deg_abs: float
	var is_forward: bool

	# Geometry Properties
	var active_bluff_width: float = 0.0
	var passive_bluff_width: float = 0.0
	var rectangularity: float = 0.0
	var bluff_factor: float = 0.0
	var thickness_penalty: float = 0.0
	var camber_efficiency: float = 1.0 # NEW
	var te_efficiency_penalty: float = 0.0

	# Calculation State
	var cl_slope_factor: float = 1.0
	var mach_stall_factor: float = 1.0
	var re_factor: float = 1.0
	var current_stall_angle: float = 0.0
	var effective_alpha: float = 0.0
	var used_alpha0: float = 0.0
	var effective_slope: float = 0.0
	var stall_center_bias: float = 0.0

	var sigma: float = 0.0
	var blended_cl: float = 0.0
	var spike_cl: float = 0.0
	var buffet_cl: float = 0.0
	var final_cl: float = 0.0
	var final_cd: float = 0.0
	var final_cm: float = 0.0

	var symmetry: float = 0.0 # New Variable

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

			rectangularity = geo.rectangularity

			symmetry = geo.fore_aft_symmetry

			# --- BLUFF LOGIC ---
			var le_tip = geo.le_tip_thickness
			var le_b = geo.le_bluntness
			var te_b = geo.te_bluntness
			var safe_thick = max(thickness, 0.001)

			if is_forward:
				active_bluff_width = le_b
				passive_bluff_width = te_b
			else:
				active_bluff_width = te_b
				passive_bluff_width = le_b

			# 1. Ratio Check (Relative Size)
			var nose_ratio = active_bluff_width / safe_thick

			# ADJUSTMENT 1: Lower the threshold.
			# If nose is > 30% of max thickness, it starts acting like a bluff body.
			# If nose is > 70% of max thickness, it is fully bluff.
			var face_factor = smoothstep(AeroPhysicsModel.bluff_nose_threshold_min, AeroPhysicsModel.bluff_nose_threshold_max, nose_ratio)

			# ADJUSTMENT 2: Absolute Size Override.
			# If the nose is wider than 6% chord, it's a bluff body, period.
			# (NACA 0012 is ~3.5%, so 6% is safe).
			var absolute_factor = smoothstep(AeroPhysicsModel.bluff_abs_threshold_min, AeroPhysicsModel.bluff_abs_threshold_max, active_bluff_width)
			face_factor = max(face_factor, absolute_factor)

			# Check True Tip (for sharp rectangles)
			if is_forward and (le_tip / safe_thick) > 0.5:
				face_factor = max(face_factor, smoothstep(0.5, 0.9, le_tip / safe_thick))

			var rect_factor = clamp((rectangularity - AeroPhysicsModel.rect_threshold_start) / AeroPhysicsModel.rect_threshold_width, 0.0, 1.0)

			bluff_factor = max(face_factor, rect_factor)

			# --- THICKNESS PENALTY ---
			thickness_penalty = smoothstep(AeroPhysicsModel.thick_pen_min, AeroPhysicsModel.thick_pen_max, thickness)

			# --- CAMBER EFFICIENCY ---
			var abs_camber = abs(geo.camber)
			if abs_camber > AeroPhysicsModel.camber_eff_threshold:
				camber_efficiency = clamp(1.0 - (abs_camber - AeroPhysicsModel.camber_eff_threshold) * AeroPhysicsModel.camber_eff_slope, 0.5, 1.0)

			# --- TE THICKNESS PENALTY ---
			var te_open = geo.te_openness
			te_efficiency_penalty = smoothstep(AeroPhysicsModel.te_open_pen_min, AeroPhysicsModel.te_open_pen_max, te_open)

# ==============================================================================
#  MAIN COMPUTE
# ==============================================================================

static func compute_coefficients(alpha_rad: float, alpha_0: float, geo: Dictionary, mach: float, re: float, config: LutGenerator.GeneratorConfig) -> Dictionary:
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

static func _calc_compressibility(ctx: _CalcContext) -> void:
	var factor = 1.0
	if ctx.mach <= mach_limit_sub:
		factor = 1.0 / sqrt(1.0 - pow(ctx.mach, 2))
	elif ctx.mach >= mach_limit_sup:
		factor = 4.0 / sqrt(pow(ctx.mach, 2) - 1.0)
	else:
		var val_sub = 1.0 / sqrt(1.0 - pow(mach_limit_sub, 2))
		var val_sup = min(4.0 / sqrt(pow(mach_limit_sup, 2) - 1.0), 3.0)
		var t = (ctx.mach - mach_limit_sub) / (mach_limit_sup - mach_limit_sub)
		factor = lerp(val_sub, val_sup, t)

	ctx.cl_slope_factor = min(factor, 4.0)

	var limit = _get_directional_param(ctx, mach_stall_onset_fwd, mach_stall_onset_bwd)
	if ctx.mach > limit:
		ctx.mach_stall_factor = clamp(1.0 - mach_stall_reduction * (ctx.mach - limit), 0.5, 1.0)

static func _calc_stall_geometry(ctx: _CalcContext) -> void:
	ctx.re_factor = 1.0 - 0.3 / (1.0 + ctx.re / stall_re_ref)

	# --- EFFICIENCY PENALTIES ---
	var efficiency = 1.0

	# 1. Bluff Body (Brick): 30% min efficiency
	efficiency *= lerp(1.0, 0.3, ctx.bluff_factor)

	# 2. Fat Wing: 50% min efficiency
	efficiency *= lerp(1.0, 0.5, ctx.thickness_penalty)

	# 3. Thick TE (Banana):
	# ADJUSTMENT 4: Max penalty 50% (down from 30%).
	if ctx.is_forward:
		efficiency *= lerp(1.0, 0.5, ctx.te_efficiency_penalty)

	# 4. High Camber
	efficiency *= ctx.camber_efficiency

	var base_slope = (2.0 * PI) * ctx.cl_slope_factor * efficiency
	ctx.effective_slope = base_slope

	var current_max_cap = _get_directional_param(ctx, stall_max_cap_deg_fwd, stall_max_cap_deg_bwd)
	var current_min_floor = _get_directional_param(ctx, stall_min_deg_fwd, stall_min_deg_bwd)

	var active_stall_base_deg: float = 0.0
	var active_camber_sign: float = 1.0
	var orientation_stall_factor: float = 1.0


	if ctx.is_forward:
		ctx.used_alpha0 = ctx.alpha_0
		active_stall_base_deg = ctx.config.stall_angle_deg_fwd
		active_camber_sign = 1.0
		ctx.effective_alpha = ctx.angle_norm
	else:
		var te_rad = ctx.geo.get("te_radius", 0.0)
		var te_quality = clamp(te_rad / 0.02, 0.0, 1.0)

		active_stall_base_deg = lerp(ctx.config.stall_angle_deg_bwd, ctx.config.stall_angle_deg_fwd, te_quality)

		if ctx.bluff_factor > 0.0:
			active_stall_base_deg = lerp(active_stall_base_deg, 4.0, ctx.bluff_factor)

		orientation_stall_factor = lerp(1.0, 0.9, te_quality)

		ctx.used_alpha0 = -ctx.alpha_0
		active_camber_sign = -1.0

		if ctx.angle_norm > 0:
			ctx.effective_alpha = ctx.angle_norm - PI
		else:
			ctx.effective_alpha = ctx.angle_norm + PI

	var clamped_stall = min(active_stall_base_deg, current_max_cap)
	var base_stall_rad = deg_to_rad(clamped_stall) * ctx.re_factor * orientation_stall_factor

	var stall_shift_deg = clamp(ctx.geo.camber * stall_camber_shift_sensitivity * active_camber_sign, stall_camber_shift_min, stall_camber_shift_max)
	var stall_shift_rad = deg_to_rad(stall_shift_deg) * ctx.camber_efficiency

	var side_blend = smoothstep(-0.1, 0.1, ctx.angle_norm)
	if not ctx.is_forward: side_blend = 1.0 - side_blend
	var shift_factor = lerp(-1.0, 1.0, side_blend)
	var final_shift = stall_shift_rad * shift_factor

	var limit_stall = lerp(current_min_floor, 1.0, ctx.bluff_factor)
	ctx.current_stall_angle = max(deg_to_rad(limit_stall), (base_stall_rad + final_shift) * ctx.mach_stall_factor)

static func _calc_sigma(ctx: _CalcContext) -> void:
	ctx.stall_center_bias = ctx.alpha_0 * 0.5 if ctx.is_forward else 0.0

	var base_sharpness = ctx.config.sharpness

	var final_sharpness = lerp(base_sharpness, base_sharpness * 2.0, ctx.bluff_factor)

	# Anti-Camber Kink Fix
	var delta_alpha = ctx.effective_alpha - ctx.alpha_0
	if (delta_alpha * ctx.geo.camber) < 0.0:
		var cam_pen = abs(ctx.geo.camber) * 20.0
		var smooth_factor = clamp(cam_pen, 0.0, 0.6)
		final_sharpness *= (1.0 - smooth_factor)

	ctx.sigma = _sigmoid_blend(ctx.effective_alpha, -ctx.current_stall_angle + ctx.stall_center_bias, ctx.current_stall_angle + ctx.stall_center_bias, final_sharpness)
static func _calc_base_lift(ctx: _CalcContext) -> void:
	var cl_linear = ctx.effective_slope * (ctx.effective_alpha - ctx.used_alpha0)

	var te_gap = ctx.geo.get("te_openness", 0.0)
	var te_bluffness = clamp(te_gap / plate_blunt_threshold, 0.0, 1.0)
	var dynamic_fwd_scale = lerp(plate_scale_sharp, plate_scale_blunt, te_bluffness)

	var le_eff_thickness = ctx.geo.le_radius * 2.0
	if ctx.active_bluff_width > 0.01:
		le_eff_thickness = ctx.active_bluff_width

	var le_bluffness = clamp(le_eff_thickness / plate_blunt_threshold, 0.0, 1.0)
	var dynamic_bwd_scale = lerp(plate_scale_sharp, plate_scale_blunt, le_bluffness)

	var plate_phase_shift = ctx.geo.camber * 0.5 * ctx.camber_efficiency
	var shift_deg = rad_to_deg(plate_phase_shift)
	var center_fwd = 90.0 + shift_deg
	var window_half_width = plate_trans_width_deg
	var trans_start = center_fwd - window_half_width
	var trans_end = center_fwd + window_half_width
	var transition_blend = smoothstep(trans_start, trans_end, ctx.angle_deg_abs)

	var rear_start = plate_deep_stall_start_deg
	var rear_end = plate_deep_stall_peak_deg
	var back_variation = smoothstep(rear_start, rear_end, ctx.angle_deg_abs)

	var current_scale = lerp(dynamic_fwd_scale, dynamic_bwd_scale, transition_blend)
	var scale_180 = min(dynamic_bwd_scale * 1.1, plate_scale_sharp)
	current_scale = lerp(current_scale, scale_180, back_variation)

	var thickness_damping = clamp(1.0 - (ctx.thickness * plate_thickness_damping_threshold), 0.8, 1.0)
	var cl_plate = ctx.config.cd_max * sin(2.0 * (ctx.alpha_rad - plate_phase_shift)) * current_scale * thickness_damping

	ctx.blended_cl = (ctx.sigma * cl_linear) + ((1.0 - ctx.sigma) * cl_plate)

static func _calc_suction_spike(ctx: _CalcContext) -> void:
	var p_capacity = spike_max_capacity_fwd if ctx.is_forward else spike_max_capacity_bwd
	var p_boost = spike_boost_mag_fwd if ctx.is_forward else spike_boost_mag_bwd
	var p_crash = spike_crash_mag_fwd if ctx.is_forward else spike_crash_mag_bwd
	var p_rec_min = recovery_thick_min_fwd if ctx.is_forward else recovery_thick_min_bwd
	var p_rec_max = recovery_thick_max_fwd if ctx.is_forward else recovery_thick_max_bwd

	var active_radius = 0.0
	if ctx.is_forward:
		active_radius = ctx.geo.get("le_radius", 0.0)
	else:
		var te_r = ctx.geo.get("te_radius", 0.0)
		if te_r <= 0.0001:
			var te_thick = ctx.geo.get("te_openness", 0.0001)
			te_r = (te_thick * te_thick) / 0.1
		active_radius = te_r

	# Clamp Active Radius to prevent super-lift from massive TE radius
	active_radius = min(active_radius, 0.05)

	var raw_suction = sqrt(active_radius / spike_ref_radius)
	var suction_capacity = clamp(raw_suction, 0.0, p_capacity)

	# Bluff bodies separate immediately
	suction_capacity *= (1.0 - ctx.bluff_factor)

	var delta_alpha = ctx.effective_alpha - ctx.alpha_0
	var aero_sign = sign(delta_alpha)

	var side_damper = 1.0
	if (delta_alpha * ctx.geo.camber) < 0.0:
		var camber_penalty = abs(ctx.geo.camber) * spike_camber_penalty
		side_damper = clamp(1.0 - camber_penalty, 0.4, 1.0)

	var boost_mag = p_boost * suction_capacity * side_damper
	var crash_mag = p_crash * suction_capacity * side_damper

	var boost_val = boost_mag * sin(ctx.sigma * PI) * aero_sign

	var dist_from_stall = abs(ctx.effective_alpha - ctx.stall_center_bias) - ctx.current_stall_angle
	var stall_excess = max(0.0, dist_from_stall)

	var dynamic_recovery = lerp(p_rec_min, p_rec_max, clamp((ctx.thickness - 0.05) / 0.15, 0.0, 1.0))
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

	# FIX: Correctly determine the radius facing the wind
	var facing_edge_radius = 0.0
	if ctx.is_forward:
		facing_edge_radius = ctx.geo.le_radius
	else:
		# Use TE Radius from Analyzer
		# If TE Radius is 0 (NACA), it means Sharp -> High noise
		facing_edge_radius = ctx.geo.te_radius

	var smoothness_threshold = 0.01

	# If radius is 0 (Sharp), Factor is 1.0 -> High Shake
	# If radius is large (Round Rect), Factor is 0.0 -> Low Shake
	var sharp_edge_factor = clamp(1.0 - (facing_edge_radius / smoothness_threshold), 0.0, 1.0)

	var stall_deg_abs = rad_to_deg(ctx.current_stall_angle)
	var angle_relative_abs = ctx.angle_deg_abs if ctx.is_forward else abs(180.0 - ctx.angle_deg_abs)

	var noise_start_angle = stall_deg_abs
	var noise_end_angle = noise_start_angle + buffet_window_width

	if angle_relative_abs > noise_start_angle and angle_relative_abs < noise_end_angle:
		var current_base_shake = _get_directional_param(ctx, buffet_base_shake_fwd, buffet_base_shake_bwd)
		var total_amp = current_base_shake + (buffet_sharp_bonus * sharp_edge_factor)
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

	# 1. BASE DRAG (Vacuum behind)
	var cd_base = drag_base_factor * ctx.passive_bluff_width

	# 2. BLUFF PRESSURE (Pushing on front)
	var pressure_width = max(0.0, ctx.active_bluff_width - 0.045)
	var cd_bluff_pressure = 0.8 * pressure_width

	# 3. FORM DRAG (Thickness)
	var form_factor = 1.0 + (2.0 * ctx.thickness) + (60.0 * pow(ctx.thickness, 4))
	if ctx.thickness > 0.25: form_factor *= 1.5

	var cd0_profile = 2.0 * cf * form_factor + (0.005 * abs(ctx.geo.camber)) + cd_base + cd_bluff_pressure

	var cd_induced = pow(ctx.blended_cl, 2) / (PI * 25.0)
	var cd0_subsonic = cd0_profile + cd_induced

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

	ctx.final_cd = ctx.sigma * (cd0_subsonic + cd_wave) + (1.0 - ctx.sigma) * cd_plate

static func _calc_moment(ctx: _CalcContext) -> void:
	var cn = ctx.final_cl * cos(ctx.alpha_rad) + ctx.final_cd * sin(ctx.alpha_rad)

	var base_cm0 = 0.0
	if ctx.geo.has("cm_0"):
		base_cm0 = ctx.geo.cm_0
	else:
		base_cm0 = -2.0 * ctx.geo.camber

	if not ctx.is_forward:
		base_cm0 = -base_cm0

	var moment_camber = base_cm0 * ctx.sigma

	var ac_target = ctx.config.ac_position
	if ctx.mach > 0.8:
		var shift_factor = clamp((ctx.mach - 0.8) / 0.4, 0.0, 1.0)
		ac_target += (ac_offset_supersonic * shift_factor)

	# Bluff body AC shift (towards center)
	var bluff_ac = lerp(ac_target, 0.5, ctx.bluff_factor)

	var cop = 0.5
	if ctx.is_forward:
		cop = lerp(0.5, bluff_ac, ctx.sigma)
	else:
		var ac_bwd = 1.0 - bluff_ac
		cop = lerp(0.5, ac_bwd, ctx.sigma)

	var lever_arm = ctx.config.ac_position - cop

	ctx.final_cm = moment_camber + (cn * lever_arm)
	ctx.final_cm += ctx.buffet_cl * 0.2

static func _sigmoid_blend(val: float, min_boundary: float, max_boundary: float, sharpness: float) -> float:
	var s1 = 1.0 / (1.0 + exp(sharpness * (val - max_boundary)))
	var s2 = 1.0 / (1.0 + exp(-sharpness * (val - min_boundary)))
	return min(s1, s2)

static func _get_directional_param(ctx: _CalcContext, fwd_val: float, bwd_val: float) -> float:
	if ctx.is_forward:
		return fwd_val
	else:
		# If perfectly symmetric (1.0), use fwd_val.
		# If normal wing (0.0), use bwd_val.
		return lerp(bwd_val, fwd_val, ctx.symmetry)
