extends VBoxContainer

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

func _ready() -> void:
	_setup_spinbox(plate_scale_sharp, 0.1, 1.5, 0.01, AeroPhysicsModel.plate_scale_sharp,
		"Lift Scale for SHARP edges (Clean Separation).\nStandard Flat Plate theory is approx 0.58.")

	_setup_spinbox(plate_scale_blunt, 0.1, 1.5, 0.01, AeroPhysicsModel.plate_scale_blunt,
		"Lift Scale for BLUNT/ROUND edges (Messy Separation).\nRound objects have less post-stall lift (~0.45).")
	_setup_spinbox(plate_blunt_threshold, 0.001, 0.2, 0.001, AeroPhysicsModel.plate_blunt_threshold,
		"Thickness threshold to determine if an edge is Sharp or Blunt.")
	_setup_spinbox(plate_thickness_damping_threshold, 0.0, 1.0, 0.05, AeroPhysicsModel.plate_thickness_damping_threshold,
		"Thickness Damping.\nVery thick wings generate less stable post-stall lift.")

	# New vars setup
	_setup_spinbox(plate_trans_width_deg, 1.0, 45.0, 1.0, AeroPhysicsModel.plate_trans_width_deg,
		"Width of the blend window (degrees) around 90 deg AoA.")
	_setup_spinbox(plate_deep_stall_start_deg, 90.0, 160.0, 1.0, AeroPhysicsModel.plate_deep_stall_start_deg,
		"Angle where the 'Back Side' physics (using LE radius) begin to dominate.")
	_setup_spinbox(plate_deep_stall_peak_deg, 140.0, 180.0, 1.0, AeroPhysicsModel.plate_deep_stall_peak_deg,
		"Angle of maximum backward efficiency.")

	plate_scale_sharp.value_changed.connect(func(v): AeroPhysicsModel.plate_scale_sharp = v)
	plate_scale_blunt.value_changed.connect(func(v): AeroPhysicsModel.plate_scale_blunt = v)
	plate_blunt_threshold.value_changed.connect(func(v): AeroPhysicsModel.plate_blunt_threshold = v)
	plate_thickness_damping_threshold.value_changed.connect(func(v): AeroPhysicsModel.plate_thickness_damping_threshold = v)

	plate_trans_width_deg.value_changed.connect(func(v): AeroPhysicsModel.plate_trans_width_deg = v)
	plate_deep_stall_start_deg.value_changed.connect(func(v): AeroPhysicsModel.plate_deep_stall_start_deg = v)
	plate_deep_stall_peak_deg.value_changed.connect(func(v): AeroPhysicsModel.plate_deep_stall_peak_deg = v)

func _setup_spinbox(node: SpinBoxExtended, min_v: float, max_v: float, step_v: float, default_v: float, tip: String) -> void:
	node.min_value = min_v
	node.max_value = max_v
	node.step = step_v
	node.value = default_v
	node.default_val = node.value
	node.tooltip_text = tip
	node.prefix = node.name + ":"
