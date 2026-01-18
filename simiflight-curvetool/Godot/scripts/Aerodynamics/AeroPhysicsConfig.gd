class_name AeroPhysicsConfig extends Resource

@export_group("Compressibility (Mach Effects)")
@export var max_factor_cl: float = 2.5
@export var mach_limit_sub: float = 0.89
@export var mach_limit_sup: float = 1.2
@export var mach_stall_onset_fwd: float = 0.4
@export var mach_stall_onset_bwd: float = 0.2
@export var mach_stall_reduction: float = 0.5

@export_group("Stall Behavior")
@export var stall_re_ref: float = 5.0e5
@export var stall_le_quality_factor: float = 15.0 # Added
@export var stall_max_cap_deg_fwd: float = 40.0
@export var stall_max_cap_deg_bwd: float = 40.0
@export var stall_min_deg_fwd: float = 1.0
@export var stall_min_deg_bwd: float = 1.0
@export var stall_te_roundness_threshold: float = 0.05 # Added
@export var stall_camber_shift_sensitivity: float = 40.0
@export var stall_camber_shift_min: float = -5.0
@export var stall_camber_shift_max: float = 8.0
@export var stall_sharpness_fwd_mult: float = 1.3
@export var stall_sharpness_bwd_mult: float = 1.0

@export_group("Post-Stall (Plate)")
@export var plate_scale_sharp: float = 0.58
@export var plate_scale_blunt: float = 0.45
@export var plate_blunt_threshold: float = 0.06
@export var plate_thickness_damping_threshold: float = 0.3
@export var plate_trans_width_deg: float = 20.0
@export var plate_deep_stall_start_deg: float = 151.0
@export var plate_deep_stall_peak_deg: float = 174.0

@export_group("Suction Spike")
@export var spike_camber_penalty: float = 25.0
@export var spike_ref_radius_fwd: float = 0.012
@export var spike_max_capacity_fwd: float = 1.15
@export var spike_boost_mag_fwd: float = 0.25
@export var spike_crash_mag_fwd: float = 0.255
@export var recovery_thick_min_fwd: float = 30.0
@export var recovery_thick_max_fwd: float = 10.0
@export var spike_ref_radius_bwd: float = 0.005
@export var spike_max_capacity_bwd: float = 0.90
@export var spike_boost_mag_bwd: float = 0.15
@export var spike_crash_mag_bwd: float = 0.05
@export var recovery_thick_min_bwd: float = 25.0
@export var recovery_thick_max_bwd: float = 15.0

@export_group("Buffet & Noise") # New Category
@export var buffet_base_shake_fwd: float = 0.001
@export var buffet_base_shake_bwd: float = 0.005
@export var buffet_sharp_bonus: float = 0.0215
@export var buffet_window_width: float = 5.5
@export var buffet_freq_alpha: float = 100.0
@export var buffet_freq_mach: float = 5.0

@export_group("Vortex Lift")
@export var vortex_kv_ref: float = 1.15
@export var vortex_stall_shift_max: float = 18.0
@export var vortex_cm_shift: float = 0.15
@export var vortex_sweep_start: float = 10.0
@export var vortex_sweep_full: float = 35.0
@export var low_ar_slope_fix: float = 0.85 # Correction for extreme low AR

@export_group("Drag & Moment")
@export var cd_max: float = 2.1
@export var drag_re_floor: float = 10000.0
@export var drag_wave_peak_mach: float = 1.05
@export var drag_wave_factor: float = 5.0
@export var drag_mcrit_thick_factor: float = 1.4
@export var drag_base_factor: float = 0.25
@export var ac_offset_supersonic: float = 0.25

@export_group("Abnormal Geometry")
@export var bluff_nose_threshold_min: float = 0.3
@export var bluff_nose_threshold_max: float = 0.7
@export var bluff_abs_threshold_min: float = 0.04
@export var bluff_abs_threshold_max: float = 0.08
@export var rect_threshold_start: float = 0.7
@export var rect_threshold_width: float = 0.25
@export var thick_pen_min: float = 0.22
@export var thick_pen_max: float = 0.45
@export var camber_eff_threshold: float = 0.06
@export var camber_eff_slope: float = 10.0
@export var te_open_pen_min: float = 0.02
@export var te_open_pen_max: float = 0.15

# In AeroPhysicsConfig.gd
@export_group("Geometric Sensitivity")
@export var induced_drag_cap_factor: float = 0.5 # Max % of cd_max allowed for induced drag
@export var sweep_drag_max_mult: float = 2.0     # Max multiplier for profile drag at high sweep

@export_group("Material & Surface")
@export var surface_roughness: float = 0.1 # 0.0 = Mirror, 1.0 = Sandpaper
@export var bluff_mach_rise: float = 0.4   # How much Cd_max increases at Mach 1.0
