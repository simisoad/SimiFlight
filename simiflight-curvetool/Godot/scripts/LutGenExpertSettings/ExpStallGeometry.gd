extends VBoxContainer

@onready var stall_re_ref: SpinBox = %stall_re_ref
@onready var stall_le_quality_factor: SpinBox = %stall_le_quality_factor
@onready var stall_max_cap_deg: SpinBox = %stall_max_cap_deg
@onready var stall_min_deg: SpinBox = %stall_min_deg
@onready var stall_te_roundness_threshold: SpinBox = %stall_te_roundness_threshold

@onready var stall_camber_shift_sensitivity: SpinBox = %stall_camber_shift_sensitivity
@onready var stall_camber_shift_min: SpinBox = %stall_camber_shift_min
@onready var stall_camber_shift_max: SpinBox = %stall_camber_shift_max

func _ready() -> void:
	# Reynolds
	_setup_spinbox(stall_re_ref, 10000.0, 50000000.0, 10000.0, AeroPhysicsModel.stall_re_ref,
		"Reference Reynolds Number.\nAt this Re, the Stall Angle Factor is nominal.\nLower Re reduces stall angle.")

	# LE Quality
	_setup_spinbox(stall_le_quality_factor, 1.0, 50.0, 0.5, AeroPhysicsModel.stall_le_quality_factor,
		"Leading Edge Quality.\nMultiplies the LE Radius to determine circulation efficiency.\nHigher = Better flow attachment.")

	# Caps
	_setup_spinbox(stall_max_cap_deg, 15.0, 45.0, 0.5, AeroPhysicsModel.stall_max_cap_deg,
		"Absolute maximum Stall Angle allowed (in degrees).\nPrevents physics explosions for extreme geometries.")
	_setup_spinbox(stall_min_deg, 1.0, 15.0, 0.5, AeroPhysicsModel.stall_min_deg,
		"Absolute minimum Stall Angle (in degrees).\nEven at Mach 2.0, a wing will usually hold flow for a few degrees.")

	# TE Roundness
	_setup_spinbox(stall_te_roundness_threshold, 0.001, 0.2, 0.001, AeroPhysicsModel.stall_te_roundness_threshold,
		"Thickness Threshold.\nIf Trailing Edge thickness > this value, the back is considered 'Round'.\nAffects Backward Flight stall logic.")

	# Camber Shifts
	_setup_spinbox(stall_camber_shift_sensitivity, 0.0, 100.0, 1.0, AeroPhysicsModel.stall_camber_shift_sensitivity,
		"How much Camber shifts the Stall Angle range.\nHigh camber stalls later on top, earlier on bottom.")
	_setup_spinbox(stall_camber_shift_min, -20.0, 0.0, 0.5, AeroPhysicsModel.stall_camber_shift_min,
		"Max negative shift (degrees) due to camber.")
	_setup_spinbox(stall_camber_shift_max, 0.0, 20.0, 0.5, AeroPhysicsModel.stall_camber_shift_max,
		"Max positive shift (degrees) due to camber.")

	# Connections
	stall_re_ref.value_changed.connect(func(v): AeroPhysicsModel.stall_re_ref = v)
	stall_le_quality_factor.value_changed.connect(func(v): AeroPhysicsModel.stall_le_quality_factor = v)
	stall_max_cap_deg.value_changed.connect(func(v): AeroPhysicsModel.stall_max_cap_deg = v)
	stall_min_deg.value_changed.connect(func(v): AeroPhysicsModel.stall_min_deg = v)
	stall_te_roundness_threshold.value_changed.connect(func(v): AeroPhysicsModel.stall_te_roundness_threshold = v)

	stall_camber_shift_sensitivity.value_changed.connect(func(v): AeroPhysicsModel.stall_camber_shift_sensitivity = v)
	stall_camber_shift_min.value_changed.connect(func(v): AeroPhysicsModel.stall_camber_shift_min = v)
	stall_camber_shift_max.value_changed.connect(func(v): AeroPhysicsModel.stall_camber_shift_max = v)

func _setup_spinbox(node: SpinBox, min_v: float, max_v: float, step_v: float, default_v: float, tip: String) -> void:
	node.min_value = min_v
	node.max_value = max_v
	node.step = step_v
	node.value = default_v
	node.tooltip_text = tip
	node.prefix = node.name + ":"
