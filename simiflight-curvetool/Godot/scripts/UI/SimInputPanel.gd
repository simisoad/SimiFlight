class_name SimInputPanel extends VBoxContainer

# Updated Signal: Now includes Chart Range (sweep_start, sweep_end)
signal parameters_changed(alpha: float, mach: float, re: float, speed: float, density: float, area: float, sweep_start: float, sweep_end: float)

# Live Simulation Inputs
@onready var input_alpha: SpinBox = %AlphaSpinBox
@onready var input_mach: SpinBox = %MachSpinBox
@onready var input_re: SpinBox = %ReynoldsSpinBox
@onready var input_speed: SpinBox = %AirspeedSpinBox
@onready var input_area: SpinBox = %WingAreaSpinBox
@onready var input_density: SpinBox = %AirDensitySpinBox
@onready var slider_alpha: HSlider = %AlphaSlider
@onready var sampling_step: SpinBox = %SamplingStep


# NEW: Chart Range Inputs (Moved from Generator View)
@onready var input_alpha_start: SpinBoxExtended = %AlphaStart
@onready var input_alpha_end: SpinBoxExtended = %AlphaEnd

# Constants
const SPEED_OF_SOUND = 340.29
const DYN_VISCOSITY = 1.81e-5
const CHORD = 1.0
var _updating: bool = false

func _ready() -> void:
	# 0. Sampling Steps
	if OS.has_feature("web"):
		sampling_step.min_value = 0.1
		sampling_step.step = 0.1
		sampling_step.value = 2.0
	else:
		sampling_step.min_value = 0.01
		sampling_step.step = 0.01
		sampling_step.value = 1.0
	sampling_step.value_changed.connect(func(v):
			LutGenerator.sampling_steps = v
			if v < 0.1:
				sampling_step.get_line_edit().self_modulate = Color.RED
			elif v < 0.5:
				sampling_step.get_line_edit().self_modulate = Color.ORANGE
			elif v < 1.0:
				sampling_step.get_line_edit().self_modulate = Color.YELLOW
			else:
				sampling_step.get_line_edit().self_modulate = Color.WHITE
				) # do not _emit_change()!
	# 1. Sync Alpha Slider/Box
	slider_alpha.value_changed.connect(func(v): input_alpha.value = v; _emit_change())
	input_alpha.value_changed.connect(func(v): slider_alpha.value = v; _emit_change())

	# 2. Physics Connections
	input_speed.value_changed.connect(_on_speed_changed)
	input_mach.value_changed.connect(_on_mach_changed)
	input_re.value_changed.connect(_on_reynolds_changed)
	input_density.value_changed.connect(_on_density_changed)

	# 3. Simple Updates
	input_area.value_changed.connect(func(_v): _emit_change())
	input_alpha_start.value_changed.connect(func(_v): _emit_change())
	input_alpha_end.value_changed.connect(func(_v): _emit_change())

	# Initial Emit
	await get_tree().process_frame
	_emit_change()
	_on_mach_changed(input_mach.value)

func _emit_change() -> void:
	if _updating: return
	parameters_changed.emit(
		input_alpha.value,
		input_mach.value,
		input_re.value,
		input_speed.value,
		input_density.value,
		input_area.value,
		input_alpha_start.value, # New
		input_alpha_end.value    # New
	)

func _on_speed_changed(v: float) -> void:
	if _updating: return
	_updating = true
	input_mach.value = v / SPEED_OF_SOUND
	input_re.value = (input_density.value * v * CHORD) / DYN_VISCOSITY
	_updating = false
	_emit_change()

func _on_mach_changed(v: float) -> void:
	if _updating: return
	_updating = true
	var speed = v * SPEED_OF_SOUND
	input_speed.value = speed
	input_re.value = (input_density.value * speed * CHORD) / DYN_VISCOSITY
	_updating = false
	_emit_change()

func _on_reynolds_changed(v: float) -> void:
	if _updating: return
	_updating = true
	var rho = input_density.value
	if rho <= 0.001: rho = 0.001
	var speed = (v * DYN_VISCOSITY) / (rho * CHORD)
	input_speed.value = speed
	input_mach.value = speed / SPEED_OF_SOUND
	_updating = false
	_emit_change()

func _on_density_changed(_v) -> void:
	# Trigger re-calc of Re based on current speed
	_on_speed_changed(input_speed.value)
