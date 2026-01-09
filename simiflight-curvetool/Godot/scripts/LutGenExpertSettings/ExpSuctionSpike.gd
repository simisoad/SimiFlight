extends VBoxContainer

# Shared Parameters
@onready var spike_ref_radius: SpinBoxExtended = %spike_ref_radius
@onready var spike_camber_penalty: SpinBoxExtended = %spike_camber_penalty

# Forward Flight Parameters
@onready var spike_max_capacity_fwd: SpinBoxExtended = %spike_max_capacity_fwd
@onready var spike_boost_mag_fwd: SpinBoxExtended = %spike_boost_mag_fwd
@onready var spike_crash_mag_fwd: SpinBoxExtended = %spike_crash_mag_fwd
@onready var recovery_thick_min_fwd: SpinBoxExtended = %recovery_thick_min_fwd
@onready var recovery_thick_max_fwd: SpinBoxExtended = %recovery_thick_max_fwd

# Backward Flight Parameters (NEW - Make sure nodes exist in Scene!)
@onready var spike_max_capacity_bwd: SpinBoxExtended = %spike_max_capacity_bwd
@onready var spike_boost_mag_bwd: SpinBoxExtended = %spike_boost_mag_bwd
@onready var spike_crash_mag_bwd: SpinBoxExtended = %spike_crash_mag_bwd
@onready var recovery_thick_min_bwd: SpinBoxExtended = %recovery_thick_min_bwd
@onready var recovery_thick_max_bwd: SpinBoxExtended = %recovery_thick_max_bwd

func _ready() -> void:
	# --- Shared ---
	SpinBoxSetupUtils.setup(spike_ref_radius, 0.0001, 0.05, 0.0001, AeroPhysicsModel.spike_ref_radius,
		"The LE Radius considered 'Standard' (100% capacity). Usually 1.2% to 1.5% chord.")

	SpinBoxSetupUtils.setup(spike_camber_penalty, 0.0, 100.0, 1.0, AeroPhysicsModel.spike_camber_penalty,
		"Penalty applied to the spike when flying against camber (Negative AoA).")

	# --- Forward (Standard) ---
	SpinBoxSetupUtils.setup(spike_max_capacity_fwd, 0.5, 2.0, 0.05, AeroPhysicsModel.spike_max_capacity_fwd,
		"Max multiplier for the suction spike in Forward flight.", "Fwd Max Capacity")

	SpinBoxSetupUtils.setup(spike_boost_mag_fwd, 0.0, 1.0, 0.01, AeroPhysicsModel.spike_boost_mag_fwd,
		"Magnitude of Lift Boost before stall (Forward).", "Fwd Boost Mag")

	SpinBoxSetupUtils.setup(spike_crash_mag_fwd, 0.0, 1.0, 0.01, AeroPhysicsModel.spike_crash_mag_fwd,
		"Magnitude of Lift Drop after stall (Forward).", "Fwd Crash Mag")

	SpinBoxSetupUtils.setup(recovery_thick_min_fwd, 10.0, 90.0, 1.0, AeroPhysicsModel.recovery_thick_min_fwd,
		"Recovery Angle for THIN wings (Forward). Hysteresis effect.", "Fwd Recov Thin")

	SpinBoxSetupUtils.setup(recovery_thick_max_fwd, 5.0, 45.0, 1.0, AeroPhysicsModel.recovery_thick_max_fwd,
		"Recovery Angle for THICK wings (Forward).", "Fwd Recov Thick")

	# --- Backward (Reverse/Bluff) ---
	SpinBoxSetupUtils.setup(spike_max_capacity_bwd, 0.1, 2.0, 0.05, AeroPhysicsModel.spike_max_capacity_bwd,
		"Max multiplier for suction spike in Backward flight. Usually lower.", "Bwd Max Capacity")

	SpinBoxSetupUtils.setup(spike_boost_mag_bwd, 0.0, 1.0, 0.01, AeroPhysicsModel.spike_boost_mag_bwd,
		"Magnitude of Lift Boost before stall (Backward).", "Bwd Boost Mag")

	SpinBoxSetupUtils.setup(spike_crash_mag_bwd, 0.0, 1.0, 0.01, AeroPhysicsModel.spike_crash_mag_bwd,
		"Magnitude of Lift Drop after stall (Backward).", "Bwd Crash Mag")

	SpinBoxSetupUtils.setup(recovery_thick_min_bwd, 10.0, 90.0, 1.0, AeroPhysicsModel.recovery_thick_min_bwd,
		"Recovery Angle for THIN wings (Backward).", "Bwd Recov Thin")

	SpinBoxSetupUtils.setup(recovery_thick_max_bwd, 5.0, 45.0, 1.0, AeroPhysicsModel.recovery_thick_max_bwd,
		"Recovery Angle for THICK wings (Backward).", "Bwd Recov Thick")


	# --- Connections ---
	spike_ref_radius.value_changed.connect(func(v): AeroPhysicsModel.spike_ref_radius = v; EventBus.reanalyze_requested.emit())
	spike_camber_penalty.value_changed.connect(func(v): AeroPhysicsModel.spike_camber_penalty = v; EventBus.reanalyze_requested.emit())

	# Fwd
	spike_max_capacity_fwd.value_changed.connect(func(v): AeroPhysicsModel.spike_max_capacity_fwd = v; EventBus.reanalyze_requested.emit())
	spike_boost_mag_fwd.value_changed.connect(func(v): AeroPhysicsModel.spike_boost_mag_fwd = v; EventBus.reanalyze_requested.emit())
	spike_crash_mag_fwd.value_changed.connect(func(v): AeroPhysicsModel.spike_crash_mag_fwd = v; EventBus.reanalyze_requested.emit())
	recovery_thick_min_fwd.value_changed.connect(func(v): AeroPhysicsModel.recovery_thick_min_fwd = v; EventBus.reanalyze_requested.emit())
	recovery_thick_max_fwd.value_changed.connect(func(v): AeroPhysicsModel.recovery_thick_max_fwd = v; EventBus.reanalyze_requested.emit())

	# Bwd
	spike_max_capacity_bwd.value_changed.connect(func(v): AeroPhysicsModel.spike_max_capacity_bwd = v; EventBus.reanalyze_requested.emit())
	spike_boost_mag_bwd.value_changed.connect(func(v): AeroPhysicsModel.spike_boost_mag_bwd = v; EventBus.reanalyze_requested.emit())
	spike_crash_mag_bwd.value_changed.connect(func(v): AeroPhysicsModel.spike_crash_mag_bwd = v; EventBus.reanalyze_requested.emit())
	recovery_thick_min_bwd.value_changed.connect(func(v): AeroPhysicsModel.recovery_thick_min_bwd = v; EventBus.reanalyze_requested.emit())
	recovery_thick_max_bwd.value_changed.connect(func(v): AeroPhysicsModel.recovery_thick_max_bwd = v; EventBus.reanalyze_requested.emit())
