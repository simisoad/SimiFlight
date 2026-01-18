@tool
class_name ExpBuffetNoise extends ExpertSetting

@onready var buffet_base_shake_fwd: SpinBoxExtended = %buffet_base_shake_fwd
@onready var buffet_base_shake_bwd: SpinBoxExtended = %buffet_base_shake_bwd
@onready var buffet_sharp_bonus: SpinBoxExtended = %buffet_sharp_bonus
@onready var buffet_window_width: SpinBoxExtended = %buffet_window_width
@onready var buffet_freq_alpha: SpinBoxExtended = %buffet_freq_alpha
@onready var buffet_freq_mach: SpinBoxExtended = %buffet_freq_mach
var _cfg: AeroPhysicsConfig # Local reference to the active physics resource

func setup_panel(physics_cfg: AeroPhysicsConfig) -> void:
	_cfg = physics_cfg

	var d = AeroPhysicsConfig.new()

	SpinBoxSetupUtils.setup(buffet_base_shake_fwd, 0.0, 0.5, 0.0001, d.buffet_base_shake_fwd,
		"Base noise amplitude (Forward).", "Base Shake Fwd")

	SpinBoxSetupUtils.setup(buffet_base_shake_bwd, 0.0, 0.5, 0.0001, d.buffet_base_shake_bwd,
		"Base noise amplitude (Backward). Usually higher.", "Base Shake Bwd")

	SpinBoxSetupUtils.setup(buffet_sharp_bonus, 0.0, 0.8, 0.0001, d.buffet_sharp_bonus,
		"Extra noise added for sharp leading edges.")

	SpinBoxSetupUtils.setup(buffet_window_width, 1.0, 20.0, 0.5, d.buffet_window_width,
		"Width of the stall angle window (degrees).")

	SpinBoxSetupUtils.setup(buffet_freq_alpha, -300.0, 300.0, 1.0, d.buffet_freq_alpha,
		"Noise Frequency multiplier based on AoA.")

	SpinBoxSetupUtils.setup(buffet_freq_mach, 1.0, 50.0, 1.0, d.buffet_freq_mach,
		"Noise Frequency multiplier based on Mach.")

	buffet_base_shake_fwd.value_changed.connect(func(v): _cfg.buffet_base_shake_fwd = v; EventBus.reanalyze_requested.emit())
	buffet_sharp_bonus.value_changed.connect(func(v): _cfg.buffet_sharp_bonus = v; EventBus.reanalyze_requested.emit())
	buffet_window_width.value_changed.connect(func(v): _cfg.buffet_window_width = v; EventBus.reanalyze_requested.emit())
	buffet_freq_alpha.value_changed.connect(func(v): _cfg.buffet_freq_alpha = v; EventBus.reanalyze_requested.emit())
	buffet_freq_mach.value_changed.connect(func(v): _cfg.buffet_freq_mach = v; EventBus.reanalyze_requested.emit())
