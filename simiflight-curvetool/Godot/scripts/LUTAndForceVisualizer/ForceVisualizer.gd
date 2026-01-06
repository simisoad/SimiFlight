class_name ForceVisualizer extends HSplitContainer
# UI References (please link in Inspector or via Unique Name)

signal params_changed(mach: float, re: float) # When environment changes (recalculate curve)
signal state_changed(alpha: float, cl: float, cd: float, cm: float) # When angle changes (move markers)

@onready var wind_tunnel_view: WindTunnelView = %WindTunnelView # The right area
@onready var input_alpha: SpinBox = %AlphaSpinBox
@onready var slider_alpha: HSlider = %AlphaSlider
@onready var input_mach: SpinBox = %MachSpinBox
@onready var input_re: SpinBox = %ReynoldsSpinBox
@onready var input_speed: SpinBox = %AirspeedSpinBox
@onready var input_area: SpinBox = %WingAreaSpinBox
@onready var input_density: SpinBox = %AirDensitySpinBox

@onready var lbl_cl: Label = %LblCl
@onready var lbl_cd: Label = %LblCd
@onready var lbl_cm: Label = %LblCm
@onready var lbl_lift: Label = %LblLift
@onready var lbl_drag: Label = %LblDrag
@onready var auto_scale_vectors_check_box: CheckBox = %AutoScaleVectorsCheckBox

# Physical Constants (ISA Standard Sea Level)
const SPEED_OF_SOUND = 340.29 # m/s
const DYN_VISCOSITY = 1.81e-5 # Pa s
const CHORD_LENGTH = 1.0 # m (Reference length)
var is_updating_params: bool = false
# Data
var current_lut: AirfoilLut
var current_profile: AirfoilProfile # For drawing the shape

func _ready() -> void:
	# Sync Slider & Spinbox (Alpha)
	if slider_alpha.value != input_alpha.value:
		slider_alpha.value = input_alpha.value
	slider_alpha.value_changed.connect(func(v): input_alpha.value = v; _update_sim())
	input_alpha.value_changed.connect(func(v): slider_alpha.value = v; _update_sim())

	# --- NEW: Intelligent Connections ---
	# We use custom functions instead of lambdas because it gets complex
	_on_mach_changed(input_mach.value) # initialize
	input_speed.value_changed.connect(_on_speed_changed)
	input_mach.value_changed.connect(_on_mach_changed)
	input_re.value_changed.connect(_on_reynolds_changed)
	input_density.value_changed.connect(_on_density_changed)

	# Area is independent, only changes force scaling
	input_area.value_changed.connect(func(_v): _update_sim())

	# Scale Vectors
	auto_scale_vectors_check_box.toggled.connect(_on_auto_scale_vectors_check_box_toggled)

func set_data(lut: AirfoilLut, profile: AirfoilProfile) -> void:
	if lut == null or profile == null:
		push_error("Airfoil Lut or Profil missing, ForceVisualizer won't work.")
		return

	current_lut = lut
	current_profile = profile

	# --- FIX FOR PROFILE GEOMETRY ---
	# We build a continuous path (Perimeter)
	# Assumption: Both arrays are sorted from 0.0 (Nose) to 1.0 (Tail).

	var continuous_geometry: Array [Vector2]

	# 1. Upper Surface: We walk BACKWARDS from Tail (1.0) to Nose (0.0)
	var upper_reversed = profile.upper_surface.duplicate()
	upper_reversed.reverse()
	continuous_geometry.append_array(upper_reversed)

	# 2. Lower Surface: We walk FORWARDS from Nose (0.0) to Tail (1.0)
	continuous_geometry.append_array(profile.lower_surface)

	# Now we have a loop: 1.0 -> ... -> 0.0 -> ... -> 1.0
	wind_tunnel_view.profile_points = continuous_geometry

	_update_sim()

func _update_sim() -> void:
	if not current_lut: return

	# 1. Fetch parameters
	var alpha_deg = input_alpha.value
	var mach = input_mach.value
	var re = input_re.value
	var speed = input_speed.value
	var area = input_area.value
	var rho = input_density.value

	# 2. Physics Sampling (uses your AirfoilSampler class)
	var coeffs = AirfoilSampler.sample(current_lut, deg_to_rad(alpha_deg), mach, re)

	# 3. Calculate Forces
	# q = 0.5 * rho * v^2
	var q = 0.5 * rho * pow(speed, 2)
	var lift_force = coeffs.cl * q * area
	var drag_force = coeffs.cd * q * area
	var moment = coeffs.cm * q * area * 1.0 # Assumption Chord = 1.0m

	# 4. UI Text Updates
	lbl_cl.text = "Cl: %.3f" % coeffs.cl
	lbl_cd.text = "Cd: %.4f" % coeffs.cd
	lbl_cm.text = "Cm: %.3f" % coeffs.cm

	lbl_lift.text = "Lift: %.1f N" % lift_force
	lbl_drag.text = "Drag: %.1f N" % drag_force

	# 5. Update Visualizer
	wind_tunnel_view.update_state(alpha_deg, lift_force, drag_force, moment, coeffs.cl, coeffs.cd, coeffs.cm, speed)
	# 6. SEND SIGNALS
	params_changed.emit(mach, re)
	state_changed.emit(alpha_deg, coeffs.cl, coeffs.cd, coeffs.cm)

func _on_speed_changed(new_speed: float) -> void:
	if is_updating_params: return
	is_updating_params = true

	# 1. Calculate Mach: M = v / a
	var new_mach = new_speed / SPEED_OF_SOUND
	input_mach.value = new_mach

	# 2. Calculate Reynolds: Re = (rho * v * L) / mu
	var rho = input_density.value
	var new_re = (rho * new_speed * CHORD_LENGTH) / DYN_VISCOSITY
	input_re.value = new_re

	is_updating_params = false
	_update_sim()

func _on_mach_changed(new_mach: float) -> void:
	if is_updating_params: return
	is_updating_params = true

	# 1. Calculate Speed: v = M * a
	var new_speed = new_mach * SPEED_OF_SOUND
	input_speed.value = new_speed

	# 2. Calculate Reynolds
	var rho = input_density.value
	var new_re = (rho * new_speed * CHORD_LENGTH) / DYN_VISCOSITY
	input_re.value = new_re

	is_updating_params = false
	_update_sim()

func _on_reynolds_changed(new_re: float) -> void:
	if is_updating_params: return
	is_updating_params = true

	# Here we calculate backwards: What speed do I need for this Re?
	# v = (Re * mu) / (rho * L)
	var rho = input_density.value
	if rho <= 0.001: rho = 0.001 # Div/0 Protection

	var new_speed = (new_re * DYN_VISCOSITY) / (rho * CHORD_LENGTH)
	input_speed.value = new_speed

	# Update Mach
	var new_mach = new_speed / SPEED_OF_SOUND
	input_mach.value = new_mach

	is_updating_params = false
	_update_sim()

func _on_density_changed(new_rho: float) -> void:
	if is_updating_params: return
	is_updating_params = true

	# If density changes (e.g., altitude), speed (TAS) usually stays the same,
	# but the Reynolds number changes.
	var v = input_speed.value
	var new_re = (new_rho * v * CHORD_LENGTH) / DYN_VISCOSITY
	input_re.value = new_re

	is_updating_params = false
	_update_sim()

func _on_auto_scale_vectors_check_box_toggled(toggled: bool) -> void:
	wind_tunnel_view.auto_scale_vectors = toggled
