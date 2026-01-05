extends VBoxContainer

@onready var drag_re_floor: SpinBox = %drag_re_floor
@onready var drag_wave_peak_mach: SpinBox = %drag_wave_peak_mach
@onready var drag_wave_factor: SpinBox = %drag_wave_factor
@onready var drag_mcrit_thick_factor: SpinBox = %drag_mcrit_thick_factor
@onready var drag_base_factor: SpinBox = %drag_base_factor
@onready var ac_offset_supersonic: SpinBox = %ac_offset_supersonic

func _ready() -> void:
	_setup_spinbox(drag_re_floor, 1000.0, 1000000.0, 1000.0, AeroPhysicsModel.drag_re_floor,
		"Minimum Reynolds Number for Drag calculations.\nPrevents infinite drag at zero speed.")

	_setup_spinbox(drag_wave_peak_mach, 0.95, 1.5, 0.01, AeroPhysicsModel.drag_wave_peak_mach,
		"The Mach number where Wave Drag (Sound Barrier) is strongest.\nUsually just above Mach 1.0.")

	_setup_spinbox(drag_wave_factor, 1.0, 20.0, 0.5, AeroPhysicsModel.drag_wave_factor,
		"Multiplier for Thickness-based Wave Drag.\nHigher values create a massive 'wall' at Mach 1.")

	_setup_spinbox(drag_mcrit_thick_factor, 0.5, 3.0, 0.1, AeroPhysicsModel.drag_mcrit_thick_factor,
		"How much Thickness reduces the Critical Mach number.\nThick wings hit the sound barrier earlier.")

	_setup_spinbox(drag_base_factor, 0.0, 1.0, 0.01, AeroPhysicsModel.drag_base_factor,
		"Base Drag Factor.\nDrag caused by a blunt/cut-off Trailing Edge (vacuum effect).")

	_setup_spinbox(ac_offset_supersonic, 0.0, 0.5, 0.01, AeroPhysicsModel.ac_offset_supersonic,
		"Aerodynamic Center Shift.\nHow far aft the AC moves in supersonic flight (fraction of chord).\nUsually 0.25 (moves from 25% to 50%).")

	drag_re_floor.value_changed.connect(func(v): AeroPhysicsModel.drag_re_floor = v)
	drag_wave_peak_mach.value_changed.connect(func(v): AeroPhysicsModel.drag_wave_peak_mach = v)
	drag_wave_factor.value_changed.connect(func(v): AeroPhysicsModel.drag_wave_factor = v)
	drag_mcrit_thick_factor.value_changed.connect(func(v): AeroPhysicsModel.drag_mcrit_thick_factor = v)
	drag_base_factor.value_changed.connect(func(v): AeroPhysicsModel.drag_base_factor = v)
	ac_offset_supersonic.value_changed.connect(func(v): AeroPhysicsModel.ac_offset_supersonic = v)

func _setup_spinbox(node: SpinBox, min_v: float, max_v: float, step_v: float, default_v: float, tip: String) -> void:
	node.min_value = min_v
	node.max_value = max_v
	node.step = step_v
	node.value = default_v
	node.tooltip_text = tip
	node.prefix = node.name + ":"
