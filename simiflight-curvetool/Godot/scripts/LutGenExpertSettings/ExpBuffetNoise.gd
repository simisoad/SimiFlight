extends VBoxContainer

@onready var buffet_base_shake: SpinBox = %buffet_base_shake
@onready var buffet_sharp_bonus: SpinBox = %buffet_sharp_bonus
@onready var buffet_window_width: SpinBox = %buffet_window_width
@onready var buffet_freq_alpha: SpinBox = %buffet_freq_alpha
@onready var buffet_freq_mach: SpinBox = %buffet_freq_mach

func _ready() -> void:
	_setup_spinbox(buffet_base_shake, 0.0, 0.5, 0.0001, AeroPhysicsModel.buffet_base_shake,
		"Base noise amplitude in the stall region.")
	_setup_spinbox(buffet_sharp_bonus, 0.0, 0.8, 0.0001, AeroPhysicsModel.buffet_sharp_bonus,
		"Extra noise added for sharp leading edges (which separate more violently).")
	_setup_spinbox(buffet_window_width, 1.0, 20.0, 0.5, AeroPhysicsModel.buffet_window_width,
		"Width of the stall angle window (in degrees) where buffet occurs.")

	_setup_spinbox(buffet_freq_alpha, -300.0, 300.0, 1.0, AeroPhysicsModel.buffet_freq_alpha,
		"Noise Frequency multiplier based on Angle of Attack.")
	_setup_spinbox(buffet_freq_mach, 1.0, 50.0, 1.0, AeroPhysicsModel.buffet_freq_mach,
		"Noise Frequency multiplier based on Mach speed.")

	buffet_base_shake.value_changed.connect(func(v): AeroPhysicsModel.buffet_base_shake = v)
	buffet_sharp_bonus.value_changed.connect(func(v): AeroPhysicsModel.buffet_sharp_bonus = v)
	buffet_window_width.value_changed.connect(func(v): AeroPhysicsModel.buffet_window_width = v)
	buffet_freq_alpha.value_changed.connect(func(v): AeroPhysicsModel.buffet_freq_alpha = v)
	buffet_freq_mach.value_changed.connect(func(v): AeroPhysicsModel.buffet_freq_mach = v)

func _setup_spinbox(node: SpinBox, min_v: float, max_v: float, step_v: float, default_v: float, tip: String) -> void:
	node.min_value = min_v
	node.max_value = max_v
	node.step = step_v
	node.value = default_v
	node.tooltip_text = tip
	node.prefix = node.name + ":"
