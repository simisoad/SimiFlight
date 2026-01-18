@tool
class_name ExpSuctionSpike extends ExpertSetting

# Shared Parameters
@onready var spike_ref_radius_fwd: SpinBoxExtended = %spike_ref_radius_fwd
@onready var spike_camber_penalty: SpinBoxExtended = %spike_camber_penalty

# Forward Flight Parameters
@onready var spike_max_capacity_fwd: SpinBoxExtended = %spike_max_capacity_fwd
@onready var spike_boost_mag_fwd: SpinBoxExtended = %spike_boost_mag_fwd
@onready var spike_crash_mag_fwd: SpinBoxExtended = %spike_crash_mag_fwd
@onready var recovery_thick_min_fwd: SpinBoxExtended = %recovery_thick_min_fwd
@onready var recovery_thick_max_fwd: SpinBoxExtended = %recovery_thick_max_fwd

# Backward Flight Parameters (NEW - Make sure nodes exist in Scene!)
@onready var spike_ref_radius_bwd: SpinBoxExtended = %spike_ref_radius_bwd
@onready var spike_max_capacity_bwd: SpinBoxExtended = %spike_max_capacity_bwd
@onready var spike_boost_mag_bwd: SpinBoxExtended = %spike_boost_mag_bwd
@onready var spike_crash_mag_bwd: SpinBoxExtended = %spike_crash_mag_bwd
@onready var recovery_thick_min_bwd: SpinBoxExtended = %recovery_thick_min_bwd
@onready var recovery_thick_max_bwd: SpinBoxExtended = %recovery_thick_max_bwd
var _cfg: AeroPhysicsConfig # Local reference to the active physics resource

func setup_panel(physics_cfg: AeroPhysicsConfig) -> void:
	_cfg = physics_cfg

	# We use a temporary "Fresh" resource just to get the hardcoded defaults
	# for the "Reset" button functionality in SpinBoxSetupUtils
	var d = AeroPhysicsConfig.new()
	# --- Shared ---
	SpinBoxSetupUtils.setup(spike_camber_penalty, 0.0, 100.0, 1.0, d.spike_camber_penalty,
		"Penalty applied to the spike when flying against camber (Negative AoA).")

	# --- Forward (Standard) ---
	SpinBoxSetupUtils.setup(spike_ref_radius_fwd, 0.00001, 1.0, 0.00001, d.spike_ref_radius_fwd,
		"The LE Radius considered 'Standard' (100% capacity) for FWD flight. Usually 1.2% to 1.5% chord.")

	SpinBoxSetupUtils.setup(spike_max_capacity_fwd, 0.01, 10.0, 0.01, d.spike_max_capacity_fwd,
		"Max multiplier for the suction spike in Forward flight.", "Fwd Max Capacity")

	SpinBoxSetupUtils.setup(spike_boost_mag_fwd, 0.0, 2.0, 0.01, d.spike_boost_mag_fwd,
		"Magnitude of Lift Boost before stall (Forward).", "Fwd Boost Mag")

	SpinBoxSetupUtils.setup(spike_crash_mag_fwd, 0.0, 2.0, 0.01, d.spike_crash_mag_fwd,
		"Magnitude of Lift Drop after stall (Forward).", "Fwd Crash Mag")

	SpinBoxSetupUtils.setup(recovery_thick_min_fwd, 0.01, 90.0, 0.01, d.recovery_thick_min_fwd,
		"Recovery Angle for THIN wings (Forward). Hysteresis effect.", "Fwd Recov Thin")

	SpinBoxSetupUtils.setup(recovery_thick_max_fwd, 0.01, 45.0, 0.01, d.recovery_thick_max_fwd,
		"Recovery Angle for THICK wings (Forward).", "Fwd Recov Thick")

	# --- Backward (Reverse/Bluff) ---
	SpinBoxSetupUtils.setup(spike_ref_radius_bwd, 0.00001, 1.0, 0.00001, d.spike_ref_radius_bwd,
		"The LE Radius considered 'Standard' (100% capacity) for BWD flight. Lower this for sharp tails!", "Ref Radius Bwd")

	SpinBoxSetupUtils.setup(spike_max_capacity_bwd, 0.01, 10.0, 0.01, d.spike_max_capacity_bwd,
		"Max multiplier for suction spike in Backward flight. Usually lower.", "Bwd Max Capacity")

	SpinBoxSetupUtils.setup(spike_boost_mag_bwd, 0.0, 2.0, 0.01, d.spike_boost_mag_bwd,
		"Magnitude of Lift Boost before stall (Backward).", "Bwd Boost Mag")

	SpinBoxSetupUtils.setup(spike_crash_mag_bwd, 0.0, 2.0, 0.01, d.spike_crash_mag_bwd,
		"Magnitude of Lift Drop after stall (Backward).", "Bwd Crash Mag")

	SpinBoxSetupUtils.setup(recovery_thick_min_bwd, 0.01, 90.0, 0.01, d.recovery_thick_min_bwd,
		"Recovery Angle for THIN wings (Backward).", "Bwd Recov Thin")

	SpinBoxSetupUtils.setup(recovery_thick_max_bwd, 0.01, 45.0, 0.01, d.recovery_thick_max_bwd,
		"Recovery Angle for THICK wings (Backward).", "Bwd Recov Thick")


	# --- Connections ---
	spike_camber_penalty.value_changed.connect(func(v): _cfg.spike_camber_penalty = v; EventBus.reanalyze_requested.emit())

	# Fwd
	spike_ref_radius_fwd.value_changed.connect(func(v): _cfg.spike_ref_radius_fwd = v; EventBus.reanalyze_requested.emit())
	spike_max_capacity_fwd.value_changed.connect(func(v): _cfg.spike_max_capacity_fwd = v; EventBus.reanalyze_requested.emit())
	spike_boost_mag_fwd.value_changed.connect(func(v): _cfg.spike_boost_mag_fwd = v; EventBus.reanalyze_requested.emit())
	spike_crash_mag_fwd.value_changed.connect(func(v): _cfg.spike_crash_mag_fwd = v; EventBus.reanalyze_requested.emit())
	recovery_thick_min_fwd.value_changed.connect(func(v): _cfg.recovery_thick_min_fwd = v; EventBus.reanalyze_requested.emit())
	recovery_thick_max_fwd.value_changed.connect(func(v): _cfg.recovery_thick_max_fwd = v; EventBus.reanalyze_requested.emit())

	# Bwd
	spike_ref_radius_bwd.value_changed.connect(func(v): _cfg.spike_ref_radius_bwd = v; EventBus.reanalyze_requested.emit())
	spike_max_capacity_bwd.value_changed.connect(func(v): _cfg.spike_max_capacity_bwd = v; EventBus.reanalyze_requested.emit())
	spike_boost_mag_bwd.value_changed.connect(func(v): _cfg.spike_boost_mag_bwd = v; EventBus.reanalyze_requested.emit())
	spike_crash_mag_bwd.value_changed.connect(func(v): _cfg.spike_crash_mag_bwd = v; EventBus.reanalyze_requested.emit())
	recovery_thick_min_bwd.value_changed.connect(func(v): _cfg.recovery_thick_min_bwd = v; EventBus.reanalyze_requested.emit())
	recovery_thick_max_bwd.value_changed.connect(func(v): _cfg.recovery_thick_max_bwd = v; EventBus.reanalyze_requested.emit())
