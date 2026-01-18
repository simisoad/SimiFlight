@tool
class_name ExpAbnormalGeometry extends ExpertSetting

@onready var bluff_nose_min: SpinBoxExtended = %bluff_nose_threshold_min
@onready var bluff_nose_max: SpinBoxExtended = %bluff_nose_threshold_max
@onready var bluff_abs_min: SpinBoxExtended = %bluff_abs_threshold_min
@onready var bluff_abs_max: SpinBoxExtended = %bluff_abs_threshold_max
@onready var rect_start: SpinBoxExtended = %rect_threshold_start
@onready var rect_width: SpinBoxExtended = %rect_threshold_width
@onready var thick_pen_min: SpinBoxExtended = %thick_pen_min
@onready var thick_pen_max: SpinBoxExtended = %thick_pen_max
@onready var te_open_min: SpinBoxExtended = %te_open_pen_min
@onready var te_open_max: SpinBoxExtended = %te_open_pen_max

var _cfg: AeroPhysicsConfig # Local reference to the active physics resource

func setup_panel(physics_cfg: AeroPhysicsConfig) -> void:
	_cfg = physics_cfg

	# We use a temporary "Fresh" resource just to get the hardcoded defaults
	# for the "Reset" button functionality in SpinBoxSetupUtils
	var d = AeroPhysicsConfig.new()
	SpinBoxSetupUtils.setup(bluff_nose_min, 0.1, 0.9, 0.05, d.bluff_nose_threshold_min,
		"Nose width ratio (vs max thickness) where Bluff body effects START.")

	SpinBoxSetupUtils.setup(bluff_nose_max, 0.1, 1.0, 0.05, d.bluff_nose_threshold_max,
		"Nose width ratio where object becomes 100% Bluff (Brick).")

	SpinBoxSetupUtils.setup(bluff_abs_min, 0.01, 0.2, 0.005, d.bluff_abs_threshold_min,
		"Absolute Nose thickness (fraction of chord) where Bluff effects START.")

	SpinBoxSetupUtils.setup(bluff_abs_max, 0.01, 0.3, 0.005, d.bluff_abs_threshold_max,
		"Absolute Nose thickness where object is 100% Bluff.")

	SpinBoxSetupUtils.setup(rect_start, 0.5, 1.0, 0.05, d.rect_threshold_start,
		"Rectangularity factor (Area / BoundingBox) where Brick logic starts.")

	SpinBoxSetupUtils.setup(rect_width, 0.05, 0.5, 0.01, d.rect_threshold_width,
		"Range of rectangularity blending.")

	SpinBoxSetupUtils.setup(thick_pen_min, 0.1, 0.5, 0.01, d.thick_pen_min,
		"Thickness ratio where Lift Efficiency starts dropping.")

	SpinBoxSetupUtils.setup(thick_pen_max, 0.2, 0.6, 0.01, d.thick_pen_max,
		"Thickness ratio where Lift Efficiency is minimal (Fat Wing).")

	SpinBoxSetupUtils.setup(te_open_min, 0.0, 0.1, 0.001, d.te_open_pen_min,
		"Trailing Edge open thickness where Lift Penalty starts.")

	SpinBoxSetupUtils.setup(te_open_max, 0.01, 0.3, 0.001, d.te_open_pen_max,
		"Trailing Edge open thickness where Lift Penalty is max.")

	# Connections
	bluff_nose_min.value_changed.connect(func(v): _cfg.bluff_nose_threshold_min = v; EventBus.reanalyze_requested.emit())
	bluff_nose_max.value_changed.connect(func(v): _cfg.bluff_nose_threshold_max = v; EventBus.reanalyze_requested.emit())
	bluff_abs_min.value_changed.connect(func(v): _cfg.bluff_abs_threshold_min = v; EventBus.reanalyze_requested.emit())
	bluff_abs_max.value_changed.connect(func(v): _cfg.bluff_abs_threshold_max = v; EventBus.reanalyze_requested.emit())
	rect_start.value_changed.connect(func(v): _cfg.rect_threshold_start = v; EventBus.reanalyze_requested.emit())
	rect_width.value_changed.connect(func(v): _cfg.rect_threshold_width = v; EventBus.reanalyze_requested.emit())
	thick_pen_min.value_changed.connect(func(v): _cfg.thick_pen_min = v; EventBus.reanalyze_requested.emit())
	thick_pen_max.value_changed.connect(func(v): _cfg.thick_pen_max = v; EventBus.reanalyze_requested.emit())
	te_open_min.value_changed.connect(func(v): _cfg.te_open_pen_min = v; EventBus.reanalyze_requested.emit())
	te_open_max.value_changed.connect(func(v): _cfg.te_open_pen_max = v; EventBus.reanalyze_requested.emit())
