class_name LutGeneratorView extends Control

signal lut_generated(filename: String)

# --- Constants ---
const AIRFOIL_DIR = "res://data/airfoils/"
const LUT_DIR = "res://data/luts/"

# --- UI References ---
@onready var opt_profile: OptionButton = %ProfileSelector

# Inputs
@onready var input_stall_fwd: SpinBox = %StallAngleFwd
@onready var input_stall_bwd: SpinBox = %StallAngleBwd
@onready var input_sharpness: SpinBox = %Sharpness
@onready var input_mach: SpinBox = %MachPreview
@onready var input_re: SpinBox = %ReynoldsPreview
@onready var input_output_name: LineEdit = %OutputName
@onready var alpha_start: SpinBoxExtended = %AlphaStart
@onready var alpha_end: SpinBoxExtended = %AlphaEnd

# Buttons
@onready var btn_calc: Button = %CalcCurve
@onready var btn_generate: Button = %GenerateFullLUT
@onready var show_cl: Button = %ShowCl
@onready var show_cd: Button = %ShowCd
@onready var show_cm: Button = %ShowCm
@onready var show_stall: Button = %ShowStall
@onready var show_naca_0012_ref: Button = %ShowNACA0012Ref



# Plots (SimpleChart)
@onready var plot_preview: SimpleChart = %PlotPreview
@onready var plot_geometry: SimpleChart = %PlotGeometry

# Status
@onready var lbl_state: Label = %StateLabelInfo

# Data Caching
var current_profile: AirfoilProfile
var current_config: LutGenerator.GeneratorConfig

# Store the reference points so we don't recalculate them every frame
var ref_points_naca0012: Array[Vector2] = []

# Series Names (Constants for Toggling)
const NAME_CL = "Lift (Cl)"
const NAME_CD = "Drag (Cd)"
const NAME_CM = "Moment (Cm)"
const NAME_STALL = "Stall"
const NAME_REF = "NACA 0012 Ref"

var CL_COLOR: Color = Color.CYAN
var CD_COLOR: Color = Color.RED
var CM_COLOR: Color = Color.GREEN
var STALL_COLOR: Color = Color.DARK_VIOLET


func _ready():
	_init_plots()
	_generate_naca0012_ref_data() # Pre-calculate reference

	refresh_profile_list()
	_init_default_values()
	set_show_curve_btns_color(show_cl, CL_COLOR)
	set_show_curve_btns_color(show_cd, CD_COLOR)
	set_show_curve_btns_color(show_cm, CM_COLOR)
	set_show_curve_btns_color(show_stall, STALL_COLOR)
	# Connect Signals
	opt_profile.item_selected.connect(_on_profile_selected)
	btn_calc.pressed.connect(_on_calculate_preview_pressed)
	btn_generate.pressed.connect(_on_generate_full_lut_pressed)
	EventBus.reanalyze_requested.connect(func():
		if current_profile:
			 # Re-run the analyzer with new static settings
			var geo_data = AirfoilGeometryAnalyzer.analyze(current_profile)

			 # Update the UI inputs with the new estimation
			input_stall_fwd.value = geo_data.stall_angle_fwd
			input_stall_bwd.value = geo_data.stall_angle_back

			 # Optionally trigger a recalc of the curve
			_on_calculate_preview_pressed()
	)
	 # Connect FWD Limits
	input_stall_fwd.min_value = AeroPhysicsModel.stall_min_deg_fwd
	input_stall_fwd.max_value = AeroPhysicsModel.stall_max_cap_deg_fwd
	EventBus.stall_limits_fwd_changed.connect(func(min_v, max_v):
		input_stall_fwd.min_value = min_v
		input_stall_fwd.max_value = max_v
		# Optional: Clamp current value if it's now out of bounds
		if input_stall_fwd.value > max_v: input_stall_fwd.value = max_v
		if input_stall_fwd.value < min_v: input_stall_fwd.value = min_v
	)
	input_stall_bwd.min_value = AeroPhysicsModel.stall_min_deg_bwd
	input_stall_bwd.max_value = AeroPhysicsModel.stall_max_cap_deg_bwd
	# Connect BWD Limits
	EventBus.stall_limits_bwd_changed.connect(func(min_v, max_v):
		input_stall_bwd.min_value = min_v
		input_stall_bwd.max_value = max_v
		if input_stall_bwd.value > max_v: input_stall_bwd.value = max_v
		if input_stall_bwd.value < min_v: input_stall_bwd.value = min_v
	)

	LutGenerator.preview_alpha_start_deg = alpha_start.value
	LutGenerator.preview_alpha_end_deg = alpha_end.value
	alpha_start.default_val = alpha_start.value
	alpha_end.default_val = alpha_end.value
	alpha_start.value_changed.connect(func(v): LutGenerator.preview_alpha_start_deg = v)
	alpha_end.value_changed.connect(func(v): LutGenerator.preview_alpha_end_deg = v)

	# Toggles (using new plot_preview reference)
	show_cl.toggled.connect(func(v): plot_preview.set_series_visible(NAME_CL, v))
	show_cd.toggled.connect(func(v): plot_preview.set_series_visible(NAME_CD, v))
	show_cm.toggled.connect(func(v): plot_preview.set_series_visible(NAME_CM, v))
	show_stall.toggled.connect(func(v): plot_preview.set_series_visible(NAME_STALL, v))
	show_naca_0012_ref.toggled.connect(func(v): plot_preview.set_series_visible(NAME_REF, v))
#^"theme_override_colors/font_color"
	# Load first profile if available
	if opt_profile.item_count > 0:
		_on_profile_selected(0)

static func set_show_curve_btns_color(button: Button, color: Color) -> void:
	button.add_theme_color_override(&"font_color", color)
	button.add_theme_color_override(&"font_hover_color", color)
	button.add_theme_color_override(&"font_pressed_color", color)
	button.add_theme_color_override(&"font_focus_color", color)
	button.add_theme_color_override(&"font_hover_pressed_color", color)

func _init_default_values()-> void:
	var config: LutGenerator.GeneratorConfig = LutGenerator.GeneratorConfig.new()
	input_stall_fwd.value = config.stall_angle_deg_fwd
	input_stall_bwd.value = config.stall_angle_deg_bwd
	input_sharpness.value = config.sharpness
	input_mach.value = config.preview_mach
	input_re.value = config.preview_re

func _init_plots():
	# 1. Setup Preview Chart (Aerodynamics)
	# Range: -180..180 X, -2.5..2.5 Y
	plot_preview.set_domain(-180.0, 180.0, -2.5, 2.5)

	# 2. Setup Geometry Chart (Visual)
	# Range: 0..1 X (Chord), -0.5..0.5 Y (Thickness)
	#plot_geometry.set_domain(0.0, 1.0, -0.25, 0.25)

	# Optional: Adjust Geometry colors/settings if exposed in SimpleChart
	# plot_geometry.show_grid = false # Example if you added that property

func _generate_naca0012_ref_data() -> void:
	ref_points_naca0012.clear()
	var NACA632012 = NACA632012LiftCurve.new()
	ref_points_naca0012.append_array(NACA632012.NACA0012_WINDTUNNEL)

func refresh_profile_list():
	var old_selection = ""
	if opt_profile.selected >= 0:
		old_selection = opt_profile.get_item_text(opt_profile.selected)

	opt_profile.clear()
	var dir = DirAccess.open(AIRFOIL_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".dat") or file_name.ends_with(".txt"):
					opt_profile.add_item(file_name)
			file_name = dir.get_next()
	else:
		lbl_state.text = "Error: Directory not found: " + AIRFOIL_DIR

	# Restore selection
	for i in range(opt_profile.item_count):
		if opt_profile.get_item_text(i) == old_selection:
			opt_profile.select(i)
			break

# --- Logic ---

func _on_profile_selected(index: int):
	var file_name = opt_profile.get_item_text(index)
	var full_path = AIRFOIL_DIR + file_name

	var profile = AirfoilProfile.new()
	if profile.load_from_dat(full_path):
		current_profile = profile
		lbl_state.text = "Loaded: " + profile.name

		# Automatic Parameter Estimation
		var geo_data = AirfoilGeometryAnalyzer.analyze(profile)
		var est_stall_fwd = geo_data.stall_angle_fwd
		var est_stall_back = geo_data.stall_angle_back

		input_stall_fwd.value = est_stall_fwd
		input_stall_bwd.value = est_stall_back

		print("Auto-Estimated: Stall=%.1f (Thick=%.1f%% at %.1f%%)" %
			[est_stall_fwd, geo_data.thickness*100, geo_data.pos_max_thick_x*100])

		input_output_name.text = file_name.get_basename() + "_lut"

		_draw_geometry()
		_on_calculate_preview_pressed()
	else:
		lbl_state.text = "Error parsing profile."

func _get_current_config() -> LutGenerator.GeneratorConfig:
	var config: LutGenerator.GeneratorConfig
	if self.current_config == null:
		config = LutGenerator.GeneratorConfig.new()
	else:
		config = self.current_config

	config.stall_angle_deg_fwd = input_stall_fwd.value
	config.stall_angle_deg_bwd = input_stall_bwd.value
	config.sharpness = input_sharpness.value
	config.preview_mach = input_mach.value
	config.preview_re = input_re.value


	return config

# Action 1: Calculate Preview
func _on_calculate_preview_pressed():
	if not current_profile: return

	var config = _get_current_config()
	var results = LutGenerator.calculate_preview_curve(current_profile, config)

	# 1. Clear Chart
	plot_preview.clear_series()

	# 2. Prepare Data Arrays
	var cl_points: Array[Vector2] = []
	var cd_points: Array[Vector2] = []
	var cm_points: Array[Vector2] = []
	var stall_points: Array[Vector2] = []

	for p in results.cl: cl_points.append(Vector2(p.x, p.y))
	for p in results.cd: cd_points.append(Vector2(p.x, p.y))
	for p in results.cm: cm_points.append(Vector2(p.x, p.y))
	for p in results.sigma: stall_points.append(Vector2(p.x, p.y))

	# 3. Add to Chart
	plot_preview.add_series(NAME_CL, cl_points, Color.CYAN)
	plot_preview.add_series(NAME_CD, cd_points, Color.RED)
	plot_preview.add_series(NAME_CM, cm_points, Color.GREEN)
	plot_preview.add_series(NAME_STALL, stall_points, Color.DARK_VIOLET)

	# Add Reference Curve
	plot_preview.add_series(NAME_REF, ref_points_naca0012_points_copy(), Color(1, 1, 1, 0.3), 1.0)

	# 4. Sync Visibility with Buttons
	plot_preview.set_series_visible(NAME_CL, show_cl.button_pressed)
	plot_preview.set_series_visible(NAME_CD, show_cd.button_pressed)
	plot_preview.set_series_visible(NAME_CM, show_cm.button_pressed)
	plot_preview.set_series_visible(NAME_STALL, show_stall.button_pressed)
	plot_preview.set_series_visible(NAME_REF, show_naca_0012_ref.button_pressed)

	lbl_state.text = "Preview calculated"

func ref_points_naca0012_points_copy() -> Array:
	return ref_points_naca0012.duplicate()

# Action 2: Generate Full LUT
func _on_generate_full_lut_pressed():
	if not current_profile: return
	await get_tree().process_frame
	lbl_state.text = "Generating full LUT..."
	await get_tree().process_frame
	await get_tree().process_frame

	var config = _get_current_config()
	var lut = LutGenerator.generate_lut(current_profile, config)

	var fname = input_output_name.text
	if not fname.ends_with(".tres"): fname += ".tres"
	var save_path = LUT_DIR + fname

	LutGenerator.save_lut(lut, save_path)

	lbl_state.text = "LUT saved to: " + fname
	lut_generated.emit(fname)

# Visualization of the Profile (Geometry) - UPDATED TO SIMPLECHART
func _draw_geometry():
	if not current_profile: return

	plot_geometry.clear_series()

	# Note: SimpleChart expects Array[Vector2], which upper_surface/lower_surface usually are.
	# If they are typed arrays, they pass through directly.

	plot_geometry.add_series("Upper", current_profile.upper_surface, Color.WEB_GREEN, 2.0)
	plot_geometry.add_series("Lower", current_profile.lower_surface, Color.YELLOW_GREEN, 2.0)
