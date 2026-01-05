extends Control

signal lut_generated(path: String)

# --- Constants ---
const AIRFOIL_DIR = "res://data/airfoils/"
const LUT_DIR = "res://data/luts/"

# --- UI References ---
@onready var opt_profile: OptionButton = %ProfileSelector

# Inputs
@onready var input_stall_fwd: LineEdit = %StallAngleFwd
@onready var input_stall_bwd: LineEdit = %StallAngleBwd
@onready var input_sharpness: LineEdit = %Sharpness
@onready var input_mach: LineEdit = %MachPreview
@onready var input_re: LineEdit = %ReynoldsPreview # If you have this field, otherwise default value
@onready var input_output_name: LineEdit = %OutputName

# Buttons
@onready var btn_calc: Button = %CalcCurve
@onready var btn_generate: Button = %GenerateFullLUT
@onready var show_cl: Button = %ShowCl
@onready var show_cd: Button = %ShowCd
@onready var show_cm: Button = %ShowCm
@onready var show_stall: Button = %ShowStall
@onready var show_naca_0012_ref: Button = %ShowNACA0012Ref

# Plots & Status
@onready var plot_preview: Graph2D = %PlotPreview
@onready var plot_geometry: Graph2D = %PlotGeometry
@onready var lbl_state: Label = %StateLabelInfo

# Plot Series
var series_cl: LineSeries
var series_cd: LineSeries
var series_cm: LineSeries
var series_sigma: LineSeries

var series_geo_upper: LineSeries
var series_geo_lower: LineSeries

# Original Naca632012LiftCurve experimentally determined.
var series_cl_naca632012: LineSeries

# State
var current_profile: AirfoilProfile
var current_config: LutGenerator.GeneratorConfig

# Graph Text -> [Cl, Cd, Cm, Stall]
var graph_text: Array[int] = [1,1,1,1]

func _ready():
	_init_plots()
	refresh_profile_list()
	_init_default_values()
	# Connect Signals
	opt_profile.item_selected.connect(_on_profile_selected)
	btn_calc.pressed.connect(_on_calculate_preview_pressed)
	btn_generate.pressed.connect(_on_generate_full_lut_pressed)
	show_cl.toggled.connect(_on_show_cl_preview_toggled)
	show_cd.toggled.connect(_on_show_cd_preview_toggled)
	show_cm.toggled.connect(_on_show_cm_preview_toggled)
	show_stall.toggled.connect(_on_show_stall_preview_toggled)
	show_naca_0012_ref.toggled.connect(_on_show_show_naca_0012_preview_toggled)
	# Load first profile if available
	if opt_profile.item_count > 0:
		_on_profile_selected(0)
	_show_naca632012()
	plot_preview.queue_redraw()
	plot_geometry.queue_redraw()


func _init_default_values()-> void:
	var config: LutGenerator.GeneratorConfig = LutGenerator.GeneratorConfig.new()
	input_stall_fwd.text = str(config.stall_angle_deg_fwd)
	input_stall_bwd.text = str(config.stall_angle_deg_bwd)
	input_sharpness.text = str(config.sharpness)
	input_mach.text = str(config.preview_mach)
	input_re.text = str(config.preview_re)

func _init_plots():
	series_cl_naca632012 = LineSeries.new(Color.AQUAMARINE, 2.0)
	plot_preview.add_series(series_cl_naca632012)
	# Preview Plot setup
	series_cl = LineSeries.new(Color.CORNFLOWER_BLUE, 2.0)
	series_cd = LineSeries.new(Color.INDIAN_RED, 2.0)
	series_cm = LineSeries.new(Color.GREEN, 2.0)
	series_sigma = LineSeries.new(Color.DARK_VIOLET, 2.0)
	plot_preview.add_series(series_cl)
	plot_preview.add_series(series_cd)
	plot_preview.add_series(series_cm)
	plot_preview.add_series(series_sigma)



	# Geometry Plot setup
	series_geo_upper = LineSeries.new(Color.WEB_GREEN, 2.0)
	series_geo_lower = LineSeries.new(Color.YELLOW_GREEN, 2.0)
	plot_geometry.add_series(series_geo_upper)
	plot_geometry.add_series(series_geo_lower)

	# Fix Geometry Plot coordinates (Normalized 0..1)
	plot_geometry.x_min = -0.1
	plot_geometry.x_max = 1.1
	plot_geometry.y_min = -0.2
	plot_geometry.y_max = 0.2


func _show_naca632012() -> void:
	var NACA632012 = NACA632012LiftCurve.new()
	series_cl_naca632012.clear_data()
	var corrected_ref: Array[Vector2]
	for p in NACA632012.NACA0012_WINDTUNNEL:
		if !(p.x + 180.0 >180.0):
			corrected_ref.append(Vector2(p.x + 180, p.y))
		else:
			corrected_ref.append(Vector2(p.x -180, p.y))

	series_cl_naca632012.add_point_array(corrected_ref)




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
				# Filter for .dat or .txt files
				if file_name.ends_with(".dat") or file_name.ends_with(".txt"):
					opt_profile.add_item(file_name)
			file_name = dir.get_next()
	else:
		lbl_state.text = "Error: Directory not found: " + AIRFOIL_DIR
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

		# --- NEW: Automatic Parameter Estimation ---

		# 1. Analyze Geometry
		var geo_data = AirfoilGeometryAnalyzer.analyze(profile)

		# 2. Estimate values
		var est_stall_fwd = geo_data.stall_angle_fwd
		var est_stall_bwd = geo_data.stall_angle_back


		# 3. Write to UI (round to 1 decimal place)
		input_stall_fwd.text = String.num(est_stall_fwd, 1)
		input_stall_bwd.text = String.num(est_stall_bwd, 1)



		print("Auto-Estimated: Stall=%.1f (Thick=%.1f%% at %.1f%%)" %
			[est_stall_fwd, geo_data.thickness*100, geo_data.pos_max_thick_x*100])

		# ---------------------------------------------
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

	# Parse Strings to Floats (with fallback)
	config.stall_angle_deg_fwd = float(input_stall_fwd.text)
	config.stall_angle_deg_bwd = float(input_stall_bwd.text)
	config.sharpness = float(input_sharpness.text)
	config.preview_mach = float(input_mach.text)

	# Reynolds if available, otherwise default
	if input_re and input_re.text.is_valid_float():
		config.preview_re = float(input_re.text)


	return config

# Action 1: Calculate Preview Only (Your "CalcCLCDButton")
func _on_calculate_preview_pressed():
	if not current_profile: return

	var config = _get_current_config()

	# Call static logic
	var results = LutGenerator.calculate_preview_curve(current_profile, config)

	# Plot
	series_cl.clear_data()
	series_cd.clear_data()
	series_cm.clear_data()
	series_sigma.clear_data()

	for p in results.cl:
		series_cl.add_point(p.x, p.y)
	for p in results.cd:
		series_cd.add_point(p.x, p.y)
	for p in results.cm:
		series_cm.add_point(p.x, p.y)
	for p in results.sigma:
		series_sigma.add_point(p.x,p.y)

	plot_preview.queue_redraw()
	lbl_state.text = "Preview calculated"

# Action 2: Generate Full LUT and Save
func _on_generate_full_lut_pressed():
	if not current_profile: return

	lbl_state.text = "Generating full LUT (this may take a moment)..."
	await get_tree().process_frame # Prevent UI freeze

	var config = _get_current_config()
	var lut = LutGenerator.generate_lut(current_profile, config)

	# Save
	var fname = input_output_name.text
	if not fname.ends_with(".tres"): fname += ".tres"
	var save_path = LUT_DIR + fname

	LutGenerator.save_lut(lut, save_path)

	lbl_state.text = "LUT saved to: " + fname
	lut_generated.emit(save_path) # Signal to MainController to switch tabs

# Visualization of the Profile (Geometry)
func _draw_geometry():
	if not current_profile: return
	series_geo_upper.clear_data()
	series_geo_lower.clear_data()

	for p in current_profile.upper_surface:
		series_geo_upper.add_point(p.x, p.y)
	for p in current_profile.lower_surface:
		series_geo_lower.add_point(p.x, p.y)

	plot_geometry.queue_redraw()

func _on_show_cl_preview_toggled(toggled: bool) -> void:
	toggle_curves(series_cl, toggled)
func _on_show_cd_preview_toggled(toggled: bool) -> void:
	toggle_curves(series_cd, toggled)
func _on_show_cm_preview_toggled(toggled: bool) -> void:
	toggle_curves(series_cm, toggled)
func _on_show_stall_preview_toggled(toggled: bool) -> void:
	toggle_curves(series_sigma, toggled)
func _on_show_show_naca_0012_preview_toggled(toggled: bool) -> void:
	toggle_curves(series_cl_naca632012, toggled)
func toggle_curves(curve: LineSeries, toggle: bool) -> void:
	if toggle:
		plot_preview.add_series(curve)
	else:
		plot_preview.remove_series(curve)
	plot_preview.queue_redraw()
