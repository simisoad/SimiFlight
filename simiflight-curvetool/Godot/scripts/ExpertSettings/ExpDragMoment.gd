@tool
class_name ExpDragMoment extends ExpertSetting

@onready var cd_max: SpinBoxExtended = %cd_max
@onready var drag_re_floor: SpinBoxExtended = %drag_re_floor
@onready var drag_wave_peak_mach: SpinBoxExtended = %drag_wave_peak_mach
@onready var drag_wave_factor: SpinBoxExtended = %drag_wave_factor
@onready var drag_mcrit_thick_factor: SpinBoxExtended = %drag_mcrit_thick_factor
@onready var drag_base_factor: SpinBoxExtended = %drag_base_factor
@onready var ac_offset_supersonic: SpinBoxExtended = %ac_offset_supersonic
var _cfg: AeroPhysicsConfig # Local reference to the active physics resource


func setup_panel(physics_cfg: AeroPhysicsConfig) -> void:
	_cfg = physics_cfg
	var d = AeroPhysicsConfig.new()

	SpinBoxSetupUtils.setup(cd_max, 0.0, 4.0, 0.01, d.cd_max,
		"Maximum value Cd can reach.")

	SpinBoxSetupUtils.setup(drag_re_floor, 1000.0, 1000000.0, 1000.0, d.drag_re_floor,
		"Minimum Reynolds Number for Drag calculations.\nPrevents infinite drag at zero speed.")

	SpinBoxSetupUtils.setup(drag_wave_peak_mach, 0.95, 1.5, 0.01, d.drag_wave_peak_mach,
		"The Mach number where Wave Drag (Sound Barrier) is strongest.\nUsually just above Mach 1.0.")

	SpinBoxSetupUtils.setup(drag_wave_factor, 1.0, 20.0, 0.5, d.drag_wave_factor,
		"Multiplier for Thickness-based Wave Drag.\nHigher values create a massive 'wall' at Mach 1.")

	SpinBoxSetupUtils.setup(drag_mcrit_thick_factor, 0.5, 3.0, 0.1, d.drag_mcrit_thick_factor,
		"How much Thickness reduces the Critical Mach number.\nThick wings hit the sound barrier earlier.")

	SpinBoxSetupUtils.setup(drag_base_factor, 0.0, 1.0, 0.01, d.drag_base_factor,
		"Base Drag Factor.\nDrag caused by a blunt/cut-off Trailing Edge (vacuum effect).")

	SpinBoxSetupUtils.setup(ac_offset_supersonic, 0.0, 0.5, 0.01, d.ac_offset_supersonic,
		"Aerodynamic Center Shift.\nHow far aft the AC moves in supersonic flight (fraction of chord).\nUsually 0.25 (moves from 25% to 50%).")

	cd_max.value_changed.connect(func(v): _cfg.cd_max = v; EventBus.reanalyze_requested.emit())
	drag_re_floor.value_changed.connect(func(v): _cfg.drag_re_floor = v; EventBus.reanalyze_requested.emit())
	drag_wave_peak_mach.value_changed.connect(func(v): _cfg.drag_wave_peak_mach = v; EventBus.reanalyze_requested.emit())
	drag_wave_factor.value_changed.connect(func(v): _cfg.drag_wave_factor = v; EventBus.reanalyze_requested.emit())
	drag_mcrit_thick_factor.value_changed.connect(func(v): _cfg.drag_mcrit_thick_factor = v; EventBus.reanalyze_requested.emit())
	drag_base_factor.value_changed.connect(func(v): _cfg.drag_base_factor = v; EventBus.reanalyze_requested.emit())
	ac_offset_supersonic.value_changed.connect(func(v): _cfg.ac_offset_supersonic = v; EventBus.reanalyze_requested.emit())
