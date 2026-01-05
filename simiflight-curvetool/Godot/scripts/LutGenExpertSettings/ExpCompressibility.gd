extends VBoxContainer

@onready var mach_limit_sub: SpinBox = %mach_limit_sub
@onready var mach_limit_sup: SpinBox = %mach_limit_sup
@onready var mach_stall_onset: SpinBox = %mach_stall_onset
@onready var mach_stall_reduction: SpinBox = %mach_stall_reduction

func _ready() -> void:
	# 1. Subsonic Limit
	_setup_spinbox(mach_limit_sub, 0.5, 0.99, 0.01, AeroPhysicsModel.mach_limit_sub,
		"Prandtl-Glauert Limit.\nBelow this Mach number, lift increases purely by 1/sqrt(1-M^2).\nUsually 0.8 to 0.9.")

	# 2. Supersonic Limit
	_setup_spinbox(mach_limit_sup, 1.0, 3.0, 0.01, AeroPhysicsModel.mach_limit_sup,
		"Ackeret Limit.\nAbove this Mach number, lift decreases by 1/sqrt(M^2-1).\nUsually 1.1 to 1.5.")

	# 3. Stall Onset Mach
	_setup_spinbox(mach_stall_onset, 0.1, 0.9, 0.05, AeroPhysicsModel.mach_stall_onset,
		"Mach number where the Stall Angle starts to decrease.\nShockwaves on the nose cause earlier stall at high speeds.")

	# 4. Stall Reduction Factor
	_setup_spinbox(mach_stall_reduction, 0.0, 2.0, 0.1, AeroPhysicsModel.mach_stall_reduction,
		"How aggressively the Stall Angle drops after passing the Onset Mach.\nHigher values mean the wing stalls much earlier at Transonic speeds.")

	mach_limit_sub.value_changed.connect(func(v): AeroPhysicsModel.mach_limit_sub = v)
	mach_limit_sup.value_changed.connect(func(v): AeroPhysicsModel.mach_limit_sup = v)
	mach_stall_onset.value_changed.connect(func(v): AeroPhysicsModel.mach_stall_onset = v)
	mach_stall_reduction.value_changed.connect(func(v): AeroPhysicsModel.mach_stall_reduction = v)

# Helper to configure the node in one line
func _setup_spinbox(node: SpinBox, min_v: float, max_v: float, step_v: float, default_v: float, tip: String) -> void:
	node.min_value = min_v
	node.max_value = max_v
	node.step = step_v
	node.value = default_v # Set value LAST (after range is set)
	node.tooltip_text = tip
	node.prefix = node.name + ":"
