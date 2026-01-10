extends VBoxContainer

@onready var stall_re_ref: SpinBoxExtended = %stall_re_ref
@onready var stall_le_quality_factor: SpinBoxExtended = %stall_le_quality_factor

# FWD Limits
@onready var stall_max_cap_deg_fwd: SpinBoxExtended = %stall_max_cap_deg_fwd
@onready var stall_min_deg_fwd: SpinBoxExtended = %stall_min_deg_fwd

# BWD Limits
@onready var stall_max_cap_deg_bwd: SpinBoxExtended = %stall_max_cap_deg_bwd
@onready var stall_min_deg_bwd: SpinBoxExtended = %stall_min_deg_bwd

# Other params
@onready var stall_te_roundness_threshold: SpinBoxExtended = %stall_te_roundness_threshold
@onready var stall_camber_shift_sensitivity: SpinBoxExtended = %stall_camber_shift_sensitivity
@onready var stall_camber_shift_min: SpinBoxExtended = %stall_camber_shift_min
@onready var stall_camber_shift_max: SpinBoxExtended = %stall_camber_shift_max

# NEW PARAMETERS
@onready var stall_sharpness_fwd_mult: SpinBoxExtended = %stall_sharpness_fwd_mult
@onready var stall_sharpness_bwd_mult: SpinBoxExtended = %stall_sharpness_bwd_mult

func _ready() -> void:
	# Reynolds
	SpinBoxSetupUtils.setup(stall_re_ref, 10000.0, 50000000.0, 10000.0, AeroPhysicsModel.stall_re_ref,
		"Reference Reynolds Number.\nAt this Re, the Stall Angle Factor is nominal.\nLower Re reduces stall angle.")

	# LE Quality
	SpinBoxSetupUtils.setup(stall_le_quality_factor, 1.0, 50.0, 0.5, AeroPhysicsModel.stall_le_quality_factor,
		"Leading Edge Quality.\nMultiplies the LE Radius to determine circulation efficiency.\nHigher = Better flow attachment.")


	SpinBoxSetupUtils.setup(stall_te_roundness_threshold, 0.001, 0.2, 0.001, AeroPhysicsModel.stall_te_roundness_threshold,
		"Thickness Threshold.\nIf Trailing Edge thickness > this value, the back is considered 'Round'.\nAffects Backward Flight stall logic.")
	# --- FWD LIMITS ---
	SpinBoxSetupUtils.setup(stall_min_deg_fwd, 1.0, 45.0, 0.5, AeroPhysicsModel.stall_min_deg_fwd,
		"Minimum Forward Stall Angle.", "Fwd Min")

	# The setup for Max must account for the current Min to prevent errors
	SpinBoxSetupUtils.setup(stall_max_cap_deg_fwd, AeroPhysicsModel.stall_min_deg_fwd, 90.0, 0.5, AeroPhysicsModel.stall_max_cap_deg_fwd,
		"Maximum Forward Stall Angle Cap.", "Fwd Max")

	# --- BWD LIMITS ---
	SpinBoxSetupUtils.setup(stall_min_deg_bwd, 1.0, 45.0, 0.5, AeroPhysicsModel.stall_min_deg_bwd,
		"Minimum Backward Stall Angle.", "Bwd Min")

	SpinBoxSetupUtils.setup(stall_max_cap_deg_bwd, AeroPhysicsModel.stall_min_deg_bwd, 90.0, 0.5, AeroPhysicsModel.stall_max_cap_deg_bwd,
		"Maximum Backward Stall Angle Cap.", "Bwd Max")
	# Camber Shifts
	SpinBoxSetupUtils.setup(stall_camber_shift_sensitivity, 0.0, 100.0, 1.0, AeroPhysicsModel.stall_camber_shift_sensitivity,
		"How much Camber shifts the Stall Angle range.\nHigh camber stalls later on top, earlier on bottom.")
	SpinBoxSetupUtils.setup(stall_camber_shift_min, -20.0, 0.0, 0.5, AeroPhysicsModel.stall_camber_shift_min,
		"Max negative shift (degrees) due to camber.")
	SpinBoxSetupUtils.setup(stall_camber_shift_max, 0.0, 20.0, 0.5, AeroPhysicsModel.stall_camber_shift_max,
		"Max positive shift (degrees) due to camber.")
	# --- SHARPNESS MULTIPLIERS ---
	SpinBoxSetupUtils.setup(stall_sharpness_fwd_mult, 0.5, 5.0, 0.1, AeroPhysicsModel.stall_sharpness_fwd_mult,
		"Multiplier for the base sharpness in Forward flight. Default 1.0.", "Sharpness Mult Fwd")

	SpinBoxSetupUtils.setup(stall_sharpness_bwd_mult, 0.5, 10.0, 0.1, AeroPhysicsModel.stall_sharpness_bwd_mult,
		"Multiplier for the base sharpness in Backward flight. Higher = snappier stall break.", "Sharpness Mult Bwd")
	# Connections
	stall_re_ref.value_changed.connect(func(v): AeroPhysicsModel.stall_re_ref = v; EventBus.reanalyze_requested.emit())
	stall_le_quality_factor.value_changed.connect(func(v): AeroPhysicsModel.stall_le_quality_factor = v; EventBus.reanalyze_requested.emit())
# 1. Update Model & Emit Signal for FWD
	stall_min_deg_fwd.value_changed.connect(func(v):
		AeroPhysicsModel.stall_min_deg_fwd = v
		stall_max_cap_deg_fwd.min_value = v # Ensure Max can't go below Min
		EventBus.stall_limits_fwd_changed.emit(v, stall_max_cap_deg_fwd.value)
	)

	stall_max_cap_deg_fwd.value_changed.connect(func(v):
		AeroPhysicsModel.stall_max_cap_deg_fwd = v
		EventBus.stall_limits_fwd_changed.emit(stall_min_deg_fwd.value, v)
	)

	# 2. Update Model & Emit Signal for BWD
	stall_min_deg_bwd.value_changed.connect(func(v):
		AeroPhysicsModel.stall_min_deg_bwd = v
		stall_max_cap_deg_bwd.min_value = v
		EventBus.stall_limits_bwd_changed.emit(v, stall_max_cap_deg_bwd.value)
	)

	stall_max_cap_deg_bwd.value_changed.connect(func(v):
		AeroPhysicsModel.stall_max_cap_deg_bwd = v
		EventBus.stall_limits_bwd_changed.emit(stall_min_deg_bwd.value, v)
	)

	stall_te_roundness_threshold.value_changed.connect(func(v): AeroPhysicsModel.stall_te_roundness_threshold = v; EventBus.reanalyze_requested.emit())

	stall_camber_shift_sensitivity.value_changed.connect(func(v): AeroPhysicsModel.stall_camber_shift_sensitivity = v; EventBus.reanalyze_requested.emit())
	stall_camber_shift_min.value_changed.connect(func(v): AeroPhysicsModel.stall_camber_shift_min = v; EventBus.reanalyze_requested.emit())
	stall_camber_shift_max.value_changed.connect(func(v): AeroPhysicsModel.stall_camber_shift_max = v; EventBus.reanalyze_requested.emit())
	stall_sharpness_fwd_mult.value_changed.connect(func(v): AeroPhysicsModel.stall_sharpness_fwd_mult = v; EventBus.reanalyze_requested.emit())
	stall_sharpness_bwd_mult.value_changed.connect(func(v): AeroPhysicsModel.stall_sharpness_bwd_mult = v; EventBus.reanalyze_requested.emit())
