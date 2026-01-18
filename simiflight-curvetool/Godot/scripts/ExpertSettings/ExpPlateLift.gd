@tool
class_name ExpPlateLift extends ExpertSetting

@onready var plate_scale_sharp: SpinBoxExtended = %plate_scale_sharp
@onready var plate_scale_blunt: SpinBoxExtended = %plate_scale_blunt
@onready var plate_blunt_threshold: SpinBoxExtended = %plate_blunt_threshold
@onready var plate_thickness_damping_threshold: SpinBoxExtended = %plate_thickness_damping_threshold
@onready var plate_trans_width_deg: SpinBoxExtended = %plate_trans_width_deg
@onready var plate_deep_stall_start_deg: SpinBoxExtended = %plate_deep_stall_start_deg
@onready var plate_deep_stall_peak_deg: SpinBoxExtended = %plate_deep_stall_peak_deg

var default_plate_scale_sharp: float
var default_plate_scale_blunt: float
var default_plate_blunt_threshold: float
var default_plate_thickness_damping_threshold: float
var default_plate_trans_width_deg: float
var default_plate_deep_stall_start_deg: float
var default_plate_deep_stall_peak_deg: float

var _cfg: AeroPhysicsConfig # Local reference to the active physics resource

func setup_panel(physics_cfg: AeroPhysicsConfig) -> void:
	_cfg = physics_cfg

	var d = AeroPhysicsConfig.new()
	SpinBoxSetupUtils.setup(plate_scale_sharp, 0.1, 1.5, 0.01, d.plate_scale_sharp,
		"Lift Scale for SHARP edges (Clean Separation).\nStandard Flat Plate theory is approx 0.58.")

	SpinBoxSetupUtils.setup(plate_scale_blunt, 0.1, 1.5, 0.01, d.plate_scale_blunt,
		"Lift Scale for BLUNT/ROUND edges (Messy Separation).\nRound objects have less post-stall lift (~0.45).")
	SpinBoxSetupUtils.setup(plate_blunt_threshold, 0.001, 0.2, 0.001, d.plate_blunt_threshold,
		"Thickness threshold to determine if an edge is Sharp or Blunt.")
	SpinBoxSetupUtils.setup(plate_thickness_damping_threshold, 0.0, 1.0, 0.05, d.plate_thickness_damping_threshold,
		"Thickness Damping.\nVery thick wings generate less stable post-stall lift.")

	# New vars setup
	SpinBoxSetupUtils.setup(plate_trans_width_deg, 1.0, 45.0, 1.0, d.plate_trans_width_deg,
		"Width of the blend window (degrees) around 90 deg AoA.")
	SpinBoxSetupUtils.setup(plate_deep_stall_start_deg, 90.0, 160.0, 1.0, d.plate_deep_stall_start_deg,
		"Angle where the 'Back Side' physics (using LE radius) begin to dominate.")
	SpinBoxSetupUtils.setup(plate_deep_stall_peak_deg, 140.0, 180.0, 1.0, d.plate_deep_stall_peak_deg,
		"Angle of maximum backward efficiency.")

	plate_scale_sharp.value_changed.connect(func(v): _cfg.plate_scale_sharp = v; EventBus.reanalyze_requested.emit())
	plate_scale_blunt.value_changed.connect(func(v): _cfg.plate_scale_blunt = v; EventBus.reanalyze_requested.emit())
	plate_blunt_threshold.value_changed.connect(func(v): _cfg.plate_blunt_threshold = v; EventBus.reanalyze_requested.emit())
	plate_thickness_damping_threshold.value_changed.connect(func(v): _cfg.plate_thickness_damping_threshold = v; EventBus.reanalyze_requested.emit())

	plate_trans_width_deg.value_changed.connect(func(v): _cfg.plate_trans_width_deg = v; EventBus.reanalyze_requested.emit())
	plate_deep_stall_start_deg.value_changed.connect(func(v): _cfg.plate_deep_stall_start_deg = v; EventBus.reanalyze_requested.emit())
	plate_deep_stall_peak_deg.value_changed.connect(func(v): _cfg.plate_deep_stall_peak_deg = v; EventBus.reanalyze_requested.emit())
