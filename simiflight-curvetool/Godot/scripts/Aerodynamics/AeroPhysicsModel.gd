class_name AeroPhysicsModel
extends RefCounted

# ==============================================================================
#  INTERNAL CONTEXT
# ==============================================================================
static var is_forward_dir: float = 1.0
static var is_backward_dir: float = -1.0

class _CalcContext:
	var alpha_rad: float
	var alpha_0: float
	var geo: AirfoilGeometryResult
	var mach: float
	var re: float
	var config: LutGenerator.GeneratorConfig
	var p: AeroPhysicsConfig

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
	var camber_efficiency: float = 1.0
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

	# Pipeline Variables
	var vortex_weight: float = 0.0
	var helmbold_multiplier: float = 1.0
	var final_intensity: float = 0.0
	var sigma: float = 0.0
	var plate_phase_shift: float = 0.0

	# Force Components
	var cl_potential: float = 0.0
	var cl_vortex: float = 0.0
	var blended_cl: float = 0.0
	var spike_cl: float = 0.0
	var buffet_cl: float = 0.0

	var final_cl: float = 0.0
	var final_cd: float = 0.0
	var final_cm: float = 0.0

	# Geometric Sweeps
	var le_sweep_deg: float = 0.0
	var c4_sweep_deg: float = 0.0

	var symmetry: float = 0.0
	var direction: float = 0.0

	func _init(_alpha: float, _a0: float, _geo: AirfoilGeometryResult, _m: float, _re: float, _cfg: LutGenerator.GeneratorConfig):
		alpha_rad = _alpha
		alpha_0 = _a0
		geo = _geo
		mach = _m
		re = _re
		config = _cfg
		p = _cfg.physics
		thickness = geo.thickness
		angle_norm = wrapf(alpha_rad, -PI, PI)
		angle_deg_abs = rad_to_deg(abs(angle_norm))
		is_forward = abs(angle_norm) < (PI / 2.0)
		rectangularity = geo.rectangularity
		symmetry = geo.fore_aft_symmetry

		# --- 1. GEOMETRIC SWEEP DERIVATION ---
		var use_3d: bool = _cfg.is_finite_wing or _cfg.is_bet_mode
		var ar = max(_cfg.aspect_ratio, 0.1)
		var taper = _cfg.taper if use_3d else 1.0
		var user_sweep_rad = deg_to_rad(_cfg.sweep_deg if use_3d else 0.0)


		var taper_const = (1.0 - taper) / (1.0 + taper)
		var geom_factor = (4.0 / ar) * taper_const

		# LE Sweep (0.0 loc) -> Drives Vortex
		var tan_le = tan(user_sweep_rad) + geom_factor * (_cfg.sweep_location - 0.0)
		le_sweep_deg = rad_to_deg(atan(tan_le))

		# C4 Sweep (0.25 loc) -> Drives Lift Slope & Profile Drag
		var tan_c4 = tan(user_sweep_rad) + geom_factor * (_cfg.sweep_location - 0.25)
		c4_sweep_deg = rad_to_deg(atan(tan_c4))

		# --- 2. VORTEX & SLOPE SETUP ---
		vortex_weight = smoothstep(p.vortex_sweep_start, p.vortex_sweep_full, abs(le_sweep_deg))

		# Refined Helmbold for Low AR
		var a0_theory = 2.0 * PI
		var ar_eff = ar * _cfg.oswald_efficiency
		var h_term = a0_theory / (PI * ar_eff)
		var helmbold_val = 1.0 / (sqrt(1.0 + pow(h_term, 2.0)) + h_term)
		# Apply extra correction for extreme low AR (Deltas)
		if ar < 2.0: helmbold_val *= p.low_ar_slope_fix

		helmbold_multiplier = lerp(1.0, helmbold_val, 1.0 if use_3d else 0.0)
		final_intensity = geo.vortex_potential * vortex_weight * _cfg.vortex_intensity

		# --- 3. BLUFF & PENALTIES ---
		active_bluff_width = geo.le_bluntness if is_forward else geo.te_bluntness
		passive_bluff_width = geo.te_bluntness if is_forward else geo.le_bluntness

		var nose_ratio = active_bluff_width / max(thickness, 0.001)
		var face_factor = smoothstep(p.bluff_nose_threshold_min, p.bluff_nose_threshold_max, nose_ratio)
		var absolute_factor = smoothstep(p.bluff_abs_threshold_min, p.bluff_abs_threshold_max, active_bluff_width)

		var rect_factor = clamp((rectangularity - p.rect_threshold_start) / p.rect_threshold_width, 0.0, 1.0)
		bluff_factor = max(max(face_factor, absolute_factor), rect_factor)

		thickness_penalty = smoothstep(p.thick_pen_min, p.thick_pen_max, thickness)
		camber_efficiency = geo.camber_efficiency
		te_efficiency_penalty = smoothstep(p.te_open_pen_min, p.te_open_pen_max, passive_bluff_width)

		# --- 4. PHASE SHIFT ---
		plate_phase_shift = alpha_0 * 0.5 * camber_efficiency

# ==============================================================================
#  MAIN COMPUTE PIPELINE
# ==============================================================================

static func compute_coefficients(alpha_rad: float, alpha_0: float, geo: AirfoilGeometryResult, mach: float, re: float, config: LutGenerator.GeneratorConfig) -> Dictionary:
	var ctx = _CalcContext.new(alpha_rad, alpha_0, geo, mach, re, config)

	ctx.direction = _get_directional_param(ctx, is_forward_dir, is_backward_dir)
	_calc_compressibility(ctx)
	_calc_stall_geometry(ctx)
	_calc_sigma(ctx)

	_calc_base_lift(ctx)
	_calc_suction_spike(ctx)
	_calc_vortex_lift_integrated(ctx)
	_calc_buffet(ctx)

	_calc_drag(ctx)
	_calc_moment(ctx)

	return {
		"cl": ctx.final_cl,
		"cd": ctx.final_cd,
		"cm": ctx.final_cm,
		"sigma": ctx.sigma,
		"direction": ctx.direction
	}

# ==============================================================================
#  PHYSICS STAGES
# ==============================================================================

static func _calc_compressibility(ctx: _CalcContext) -> void:
	var factor = 1.0
	var ACKERET_FACTOR = 2.5

	if ctx.mach <= ctx.p.mach_limit_sub:
		factor = 1.0 / sqrt(1.0 - pow(ctx.mach, 2))
	elif ctx.mach >= ctx.p.mach_limit_sup:
		var raw_sup = ACKERET_FACTOR / sqrt(pow(ctx.mach, 2) - 1.0)
		factor = min(raw_sup, ctx.p.max_factor_cl)
	else:
		var val_sub = 1.0 / sqrt(1.0 - pow(ctx.p.mach_limit_sub, 2))
		var raw_sup_target = ACKERET_FACTOR / sqrt(pow(ctx.p.mach_limit_sup, 2) - 1.0)
		var val_sup = min(raw_sup_target, ctx.p.max_factor_cl)
		var t = (ctx.mach - ctx.p.mach_limit_sub) / (ctx.p.mach_limit_sup - ctx.p.mach_limit_sub)
		factor = lerp(val_sub, val_sup, t)

	ctx.cl_slope_factor = min(factor, ctx.p.max_factor_cl)

	var limit = _get_directional_param(ctx, ctx.p.mach_stall_onset_fwd, ctx.p.mach_stall_onset_bwd)
	if ctx.mach > limit:
		ctx.mach_stall_factor = clamp(1.0 - ctx.p.mach_stall_reduction * (ctx.mach - limit), 0.5, 1.0)

static func _calc_stall_geometry(ctx: _CalcContext) -> void:
	ctx.re_factor = 1.0 - 0.3 / (1.0 + ctx.re / ctx.p.stall_re_ref)

	var efficiency = 1.0
	efficiency *= lerp(1.0, 0.3, ctx.bluff_factor)
	efficiency *= lerp(1.0, 0.5, ctx.thickness_penalty)
	efficiency *= lerp(1.0, 0.5, ctx.te_efficiency_penalty)
	efficiency *= ctx.camber_efficiency

	var base_slope = (2.0 * PI) * ctx.cl_slope_factor * efficiency
	ctx.effective_slope = lerp(base_slope, (2.0 * PI) * ctx.helmbold_multiplier * cos(deg_to_rad(ctx.c4_sweep_deg)), ctx.vortex_weight)

	var current_max_cap = _get_directional_param(ctx, ctx.p.stall_max_cap_deg_fwd, ctx.p.stall_max_cap_deg_bwd)
	var current_min_floor = _get_directional_param(ctx, ctx.p.stall_min_deg_fwd, ctx.p.stall_min_deg_bwd)

	var active_stall_base_deg: float = 0.0
	var active_camber_sign: float = 1.0
	var orientation_stall_factor: float = 1.0

	if ctx.is_forward:
		ctx.used_alpha0 = ctx.alpha_0
		active_stall_base_deg = ctx.config.stall_angle_deg_fwd
		active_camber_sign = 1.0
		ctx.effective_alpha = ctx.angle_norm
	else:
		var te_rad = ctx.geo.te_radius_norm
		var te_quality = clamp(te_rad / 0.02, 0.0, 1.0)
		var derived_base = lerp(ctx.config.stall_angle_deg_bwd, ctx.config.stall_angle_deg_fwd, te_quality)
		if ctx.bluff_factor > 0.0: derived_base = lerp(derived_base, 4.0, ctx.bluff_factor)
		active_stall_base_deg = lerp(derived_base, ctx.config.stall_angle_deg_bwd, ctx.symmetry)
		var raw_orientation = lerp(1.0, 0.9, te_quality)
		orientation_stall_factor = lerp(raw_orientation, 1.0, ctx.symmetry)
		ctx.used_alpha0 = -ctx.alpha_0
		active_camber_sign = -1.0
		ctx.effective_alpha = ctx.angle_norm - PI if ctx.angle_norm > 0 else ctx.angle_norm + PI

	# Dynamic Vortex Stall Bonus
	active_stall_base_deg += ctx.p.vortex_stall_shift_max * ctx.final_intensity

	var clamped_stall = min(active_stall_base_deg, current_max_cap)
	var base_stall_rad = deg_to_rad(clamped_stall) * ctx.re_factor * orientation_stall_factor

	var stall_shift_deg = clamp(ctx.geo.camber * ctx.p.stall_camber_shift_sensitivity * active_camber_sign, ctx.p.stall_camber_shift_min, ctx.p.stall_camber_shift_max)
	var stall_shift_rad = deg_to_rad(stall_shift_deg) * ctx.camber_efficiency

	var side_blend = smoothstep(-0.1, 0.1, ctx.angle_norm)
	if not ctx.is_forward: side_blend = 1.0 - side_blend
	var final_shift = stall_shift_rad * lerp(-1.0, 1.0, side_blend)

	var limit_stall = lerp(current_min_floor, 1.0, ctx.bluff_factor)
	ctx.current_stall_angle = max(deg_to_rad(limit_stall), (base_stall_rad + final_shift) * ctx.mach_stall_factor)

static func _calc_sigma(ctx: _CalcContext) -> void:
	var bias_fwd = ctx.alpha_0 * 0.5
	var bias_bwd = lerp(0.0, -ctx.alpha_0 * 0.5, ctx.symmetry)
	ctx.stall_center_bias = bias_fwd if ctx.is_forward else bias_bwd

	var sharpnes_multiplier: float = _get_directional_param(ctx, ctx.p.stall_sharpness_fwd_mult, ctx.p.stall_sharpness_bwd_mult)
	var base_sharpness = ctx.config.sharpness * sharpnes_multiplier
	var final_sharpness = lerp(base_sharpness, base_sharpness * 2.0, ctx.bluff_factor)

	var delta_alpha = ctx.effective_alpha - ctx.alpha_0
	if (delta_alpha * ctx.geo.camber) < 0.0:
		final_sharpness *= (1.0 - clamp(abs(ctx.geo.camber) * 20.0, 0.0, 0.6))

	ctx.sigma = _sigmoid_blend(ctx.effective_alpha, -ctx.current_stall_angle + ctx.stall_center_bias, ctx.current_stall_angle + ctx.stall_center_bias, final_sharpness)

static func _calc_base_lift(ctx: _CalcContext) -> void:
	ctx.cl_potential = ctx.effective_slope * (ctx.effective_alpha - ctx.used_alpha0)

	var te_bluffness = clamp(ctx.geo.te_openness / ctx.p.plate_blunt_threshold, 0.0, 1.0)
	var dynamic_fwd_scale = lerp(ctx.p.plate_scale_sharp, ctx.p.plate_scale_blunt, te_bluffness)
	var le_eff_thickness = ctx.geo.le_radius * 2.0
	if ctx.active_bluff_width > 0.01: le_eff_thickness = ctx.active_bluff_width
	var le_bluffness = clamp(le_eff_thickness / ctx.p.plate_blunt_threshold, 0.0, 1.0)
	var dynamic_bwd_scale = lerp(ctx.p.plate_scale_sharp, ctx.p.plate_scale_blunt, le_bluffness)

	var transition_blend = smoothstep(ctx.p.plate_trans_width_deg * -1.0, ctx.p.plate_trans_width_deg, ctx.angle_deg_abs - 90.0)
	var back_variation = smoothstep(ctx.p.plate_deep_stall_start_deg, ctx.p.plate_deep_stall_peak_deg, ctx.angle_deg_abs)

	var current_scale = lerp(dynamic_fwd_scale, dynamic_bwd_scale, transition_blend)
	current_scale = lerp(current_scale, min(dynamic_bwd_scale * 1.1, ctx.p.plate_scale_sharp), back_variation)

	var thickness_damping = clamp(1.0 - (ctx.thickness * ctx.p.plate_thickness_damping_threshold), 0.8, 1.0)
	var cl_plate = ctx.p.cd_max * sin(2.0 * (ctx.alpha_rad - ctx.plate_phase_shift)) * current_scale * thickness_damping

	ctx.blended_cl = (ctx.sigma * ctx.cl_potential) + ((1.0 - ctx.sigma) * cl_plate)

static func _calc_suction_spike(ctx: _CalcContext) -> void:
	var p_capacity = _get_directional_param(ctx, ctx.p.spike_max_capacity_fwd, ctx.p.spike_max_capacity_bwd)
	var p_boost = _get_directional_param(ctx, ctx.p.spike_boost_mag_fwd, ctx.p.spike_boost_mag_bwd)
	var p_crash = _get_directional_param(ctx, ctx.p.spike_crash_mag_fwd, ctx.p.spike_crash_mag_bwd)
	var p_rec_min = _get_directional_param(ctx, ctx.p.recovery_thick_min_fwd, ctx.p.recovery_thick_min_bwd)
	var p_rec_max = _get_directional_param(ctx, ctx.p.recovery_thick_max_fwd, ctx.p.recovery_thick_max_bwd)

	var active_radius = ctx.geo.le_radius if ctx.is_forward else lerp(ctx.geo.te_radius_norm, ctx.geo.le_radius, ctx.symmetry)
	if not ctx.is_forward and active_radius <= 0.0001: active_radius = (ctx.geo.te_openness * ctx.geo.te_openness) / 0.1

	active_radius = min(active_radius, 0.005)
	var suction_capacity = clamp(sqrt(active_radius / ctx.p.spike_ref_radius_fwd), 0.0, p_capacity) * (1.0 - ctx.bluff_factor)

	var delta_alpha = ctx.effective_alpha - ctx.alpha_0
	var side_damper = clamp(1.0 - abs(ctx.geo.camber) * ctx.p.spike_camber_penalty, 0.4, 1.0) if (delta_alpha * ctx.geo.camber) < 0.0 else 1.0

	var boost_mag = p_boost * suction_capacity * side_damper
	var crash_mag = p_crash * suction_capacity * side_damper
	var boost_val = boost_mag * sin(ctx.sigma * PI) * sign(delta_alpha)

	var stall_excess = max(0.0, abs(ctx.effective_alpha - ctx.stall_center_bias) - ctx.current_stall_angle)
	var dynamic_recovery = lerp(p_rec_min, p_rec_max, clamp((ctx.thickness - 0.05) / 0.15, 0.0, 1.0))
	var crash_decay = 0.5 * (1.0 + cos(clamp(stall_excess / deg_to_rad(dynamic_recovery), 0.0, 1.0) * PI))

	var crash_val = -crash_mag * crash_decay * sign(delta_alpha)
	var blend_width = lerp(0.15, 0.30, clamp((ctx.thickness - 0.05) / 0.10, 0.0, 1.0))
	ctx.spike_cl = lerp(crash_val, boost_val, smoothstep(0.5 - blend_width, 0.5 + blend_width, ctx.sigma))

	ctx.final_cl = ctx.blended_cl + ctx.spike_cl

static func _calc_vortex_lift_integrated(ctx: _CalcContext) -> void:
	if ctx.final_intensity <= 0.0: return
	var alpha_abs = abs(ctx.effective_alpha)
	var kv = ctx.p.vortex_kv_ref * PI * sin(deg_to_rad(ctx.le_sweep_deg)) * ctx.final_intensity
	ctx.cl_vortex = kv * pow(sin(alpha_abs), 2.0) * cos(alpha_abs) * ctx.sigma
	ctx.final_cl += ctx.cl_vortex * sign(ctx.effective_alpha)
	ctx.final_cd += ctx.cl_vortex * tan(alpha_abs)
	ctx.final_cm -= ctx.cl_vortex * ctx.p.vortex_cm_shift
	ctx.spike_cl *= (1.0 - (ctx.final_intensity * ctx.sigma))

static func _calc_buffet(ctx: _CalcContext) -> void:
	var facing_edge_radius = ctx.geo.le_radius if ctx.is_forward else ctx.geo.te_radius_norm
	var sharp_edge_factor = clamp(1.0 - (facing_edge_radius / 0.01), 0.0, 1.0)
	var angle_relative_abs = ctx.angle_deg_abs if ctx.is_forward else abs(180.0 - ctx.angle_deg_abs)
	var noise_start = rad_to_deg(ctx.current_stall_angle)
	var noise_end = noise_start + ctx.p.buffet_window_width

	if angle_relative_abs > noise_start and angle_relative_abs < noise_end:
		var total_amp = _get_directional_param(ctx, ctx.p.buffet_base_shake_fwd, ctx.p.buffet_base_shake_bwd) + (ctx.p.buffet_sharp_bonus * sharp_edge_factor)
		var freq = ctx.alpha_rad * ctx.p.buffet_freq_alpha + (ctx.mach * ctx.p.buffet_freq_mach)
		var noise_wave = -sin(freq) if ctx.alpha_rad > 0.0 else cos(freq)
		var fade = smoothstep(noise_start, noise_start + 1.0, angle_relative_abs) * (1.0 - smoothstep(noise_end - 1.0, noise_end, angle_relative_abs))
		ctx.buffet_cl = noise_wave * total_amp * fade
	ctx.final_cl += ctx.buffet_cl

static func _calc_drag(ctx: _CalcContext) -> void:
	var safe_re = max(ctx.re, ctx.p.drag_re_floor)
	var cf = 0.074 / pow(safe_re, 0.2) * (1.0 + ctx.p.surface_roughness * 0.5)

	# 1. Profile Drag
	var form_factor = 1.0 + (2.0 * ctx.thickness) + (60.0 * pow(ctx.thickness, 4))
	if ctx.thickness >= 0.25: form_factor *= 1.5
	var cd0_profile = 2.0 * cf * form_factor + (0.005 * abs(ctx.geo.cm_0))
	cd0_profile += (ctx.p.drag_base_factor * ctx.passive_bluff_width) + (0.8 * max(0.0, ctx.active_bluff_width - 0.045))

	# 2. Sweep Correction
	var sweep_rad = deg_to_rad(ctx.c4_sweep_deg)
	cd0_profile *= clamp(1.0 / max(cos(sweep_rad), 0.5), 1.0, ctx.p.sweep_drag_max_mult)

	# 3. Wave Drag (Transonic Rise)
	var cd_wave = 0.0
	var m_crit = clamp(0.9 - (ctx.thickness * ctx.p.drag_mcrit_thick_factor) - (abs(ctx.blended_cl) * 0.1), 0.6, 0.95)
	if ctx.mach > m_crit:
		var cd_wave_peak = ctx.p.drag_wave_factor * pow(ctx.thickness, 1.5)
		var ratio_mach = clamp((ctx.mach - m_crit) / (ctx.p.drag_wave_peak_mach - m_crit), 0.0, 1.0)
		cd_wave = cd_wave_peak * (sin(ratio_mach * PI / 2.0) if ctx.mach < ctx.p.drag_wave_peak_mach else (ctx.p.drag_wave_peak_mach / ctx.mach))

	# 4. Induced Drag (Sigma-Weighted)
	var cd_induced = 0.0
	if ctx.config.is_finite_wing and not ctx.config.is_bet_mode:
		var raw_induced = pow(ctx.cl_potential * ctx.sigma, 2) / (PI * max(ctx.config.aspect_ratio, 0.1) * ctx.config.oswald_efficiency)
		cd_induced = min(raw_induced, ctx.p.cd_max * ctx.p.induced_drag_cap_factor)

	# 5. Plate Drag (Mach-Dependent Bluff Rise)
	var plate_mult = lerp(1.0, 0.92, clamp((ctx.mach - 1.5) / 8.5, 0.0, 1.0)) if ctx.mach >= 1.0 else 1.0
	# NEW: Bluff Mach Rise (Cd_max increases near Mach 1.0)
	var bluff_mach_factor = 1.0 + ctx.p.bluff_mach_rise * smoothstep(0.7, 1.0, ctx.mach) * (1.0 - smoothstep(1.0, 1.5, ctx.mach))
	var cd_plate = (ctx.p.cd_max * plate_mult * bluff_mach_factor) * pow(sin(ctx.alpha_rad - ctx.plate_phase_shift), 2)

	# 6. Final Blending
	ctx.final_cd += (ctx.sigma * (cd0_profile + cd_induced + cd_wave)) + ((1.0 - ctx.sigma) * cd_plate)

	# 7. Sanity Cap
	ctx.final_cd = min(ctx.final_cd, ctx.p.cd_max * bluff_mach_factor * (1.0 + cd_wave))

static func _calc_moment(ctx: _CalcContext) -> void:
	var cn = ctx.final_cl * cos(ctx.alpha_rad) + ctx.final_cd * sin(ctx.alpha_rad)
	var moment_camber = (ctx.geo.cm_0 if ctx.is_forward else -ctx.geo.cm_0) * ctx.sigma
	var ac_target = ctx.config.ac_position
	if ctx.mach > 0.8: ac_target += (ctx.p.ac_offset_supersonic * clamp((ctx.mach - 0.8) / 0.4, 0.0, 1.0))
	var bluff_ac = lerp(ac_target, 0.5, ctx.bluff_factor)
	var cop = lerp(0.5, bluff_ac if ctx.is_forward else 1.0 - bluff_ac, ctx.sigma)
	ctx.final_cm = moment_camber + (cn * (ctx.config.ac_position - cop)) + (ctx.buffet_cl * 0.2)

static func _sigmoid_blend(val: float, min_b: float, max_b: float, sharp: float) -> float:
	return min(1.0 / (1.0 + exp(sharp * (val - max_b))), 1.0 / (1.0 + exp(-sharp * (val - min_b))))

static func _get_directional_param(ctx: _CalcContext, fwd: float, bwd: float) -> float:
	return fwd if ctx.is_forward else lerp(bwd, fwd, ctx.symmetry)

static func get_quarter_chord_sweep(sweep_deg: float, taper: float, ar: float, sweep_loc: float) -> float:
	var tan_q = tan(deg_to_rad(sweep_deg)) + (4.0 / max(ar, 0.1)) * (sweep_loc - 0.25) * (1.0 - taper) / (1.0 + taper)
	return rad_to_deg(atan(tan_q))

static func calculate_finite_wing(cl_2d: float, cd_2d: float, aspect_ratio: float, efficiency: float, sweep_deg_user: float, taper: float, sweep_loc: float) -> Dictionary:
	var sweep_c4 = get_quarter_chord_sweep(sweep_deg_user, taper, aspect_ratio, sweep_loc)
	var cos_s = cos(deg_to_rad(sweep_c4))
	var multiplier = 1.0 / (sqrt(1.0 + pow((2.0*PI) / (PI * aspect_ratio * efficiency), 2.0)) + ((2.0*PI) / (PI * aspect_ratio * efficiency)))
	var cl_3d = cl_2d * multiplier * cos_s
	return {"cl": cl_3d, "cd": cd_2d / max(cos_s, 0.5) + (cl_3d**2 / (PI * aspect_ratio * efficiency)), "sweep_c4": sweep_c4}

static func estimate_oswald(aspect_ratio: float, taper: float, sweep_deg: float) -> float:
	var e_straight = 1.0 - 0.5 * pow(taper - 0.45, 2)
	var e_swept = 4.61 * (1.0 - 0.045 * pow(aspect_ratio, 0.68)) * pow(cos(deg_to_rad(sweep_deg)), 0.15) - 3.1
	return clamp(lerp(e_straight, e_swept, smoothstep(0.0, 15.0, abs(sweep_deg))), 0.1, 1.0)
