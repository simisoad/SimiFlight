extends VBoxContainer

@onready var spike_ref_radius: SpinBox = %spike_ref_radius
@onready var spike_max_capacity: SpinBox = %spike_max_capacity
@onready var spike_camber_penalty: SpinBox = %spike_camber_penalty
@onready var spike_boost_mag: SpinBox = %spike_boost_mag
@onready var spike_crash_mag: SpinBox = %spike_crash_mag
@onready var recovery_thick_min: SpinBox = %recovery_thick_min
@onready var recovery_thick_max: SpinBox = %recovery_thick_max

func _ready() -> void:
	_setup_spinbox(spike_ref_radius, 0.0001, 0.05, 0.0001, AeroPhysicsModel.spike_ref_radius,
		"The LE Radius considered 'Standard' (100% capacity).\nUsually 0.012 to 0.015 (1.5% chord).")

	_setup_spinbox(spike_max_capacity, 0.5, 2.0, 0.05, AeroPhysicsModel.spike_max_capacity,
		"Maximum multiplier for the suction spike.\nLimits how strong the 'pop' can be for very round noses.")

	_setup_spinbox(spike_camber_penalty, 0.0, 100.0, 1.0, AeroPhysicsModel.spike_camber_penalty,
		"Penalty applied to the spike when flying against camber (Negative AoA).\nReduces the 'pop' when airflow is fighting the shape.")

	_setup_spinbox(spike_boost_mag, 0.0, 1.0, 0.01, AeroPhysicsModel.spike_boost_mag,
		"Magnitude of the Lift Boost (Suction Spike) just before stall.\nCreates the characteristic 'hump' in the lift curve.")

	_setup_spinbox(spike_crash_mag, 0.0, 1.0, 0.01, AeroPhysicsModel.spike_crash_mag,
		"Magnitude of the Lift Drop (Stall Crash) just after stall.\nDetermines how deep the lift drops into the vortex region.")

	_setup_spinbox(recovery_thick_min, 10.0, 90.0, 1.0, AeroPhysicsModel.recovery_thick_min,
		"Recovery Angle (deg) for THIN wings.\nThin wings hold the stall vortex longer (hysteresis).")

	_setup_spinbox(recovery_thick_max, 5.0, 45.0, 1.0, AeroPhysicsModel.recovery_thick_max,
		"Recovery Angle (deg) for THICK wings.\nThick wings recover from the stall vortex faster.")

	spike_ref_radius.value_changed.connect(func(v): AeroPhysicsModel.spike_ref_radius = v)
	spike_max_capacity.value_changed.connect(func(v): AeroPhysicsModel.spike_max_capacity = v)
	spike_camber_penalty.value_changed.connect(func(v): AeroPhysicsModel.spike_camber_penalty = v)
	spike_boost_mag.value_changed.connect(func(v): AeroPhysicsModel.spike_boost_mag = v)
	spike_crash_mag.value_changed.connect(func(v): AeroPhysicsModel.spike_crash_mag = v)
	recovery_thick_min.value_changed.connect(func(v): AeroPhysicsModel.recovery_thick_min = v)
	recovery_thick_max.value_changed.connect(func(v): AeroPhysicsModel.recovery_thick_max = v)

func _setup_spinbox(node: SpinBox, min_v: float, max_v: float, step_v: float, default_v: float, tip: String) -> void:
	node.min_value = min_v
	node.max_value = max_v
	node.step = step_v
	node.value = default_v
	node.tooltip_text = tip
	node.prefix = node.name + ":"
