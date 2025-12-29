extends Control

signal lut_generated(path: String)

# --- Konstanten ---
const AIRFOIL_DIR = "res://data/airfoils/"
const LUT_DIR = "res://data/luts/"

# --- UI Referenzen ---
@onready var opt_profile: OptionButton = %ProfileSelector
@onready var opt_method: OptionButton = %MethodSelector

# Inputs
@onready var input_stall: LineEdit = %StallAngle
@onready var input_sharpness: LineEdit = %Sharpness
@onready var input_mach: LineEdit = %MachPreview
@onready var input_re: LineEdit = %ReynoldsPreview # Falls du das Feld hast, sonst Standardwert
@onready var input_output_name: LineEdit = %OutputName
@onready var input_backward_scale: LineEdit = %BackwardScaleInput
# Buttons
@onready var btn_calc: Button = %CalcCurve
@onready var btn_generate: Button = %GenerateFullLUT

# Plots & Status
@onready var plot_preview: Graph2D = %PlotPreview
@onready var plot_geometry: Graph2D = %PlotGeometry
@onready var lbl_state: Label = %StateLabel

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

func _ready():
	_init_plots()
	_populate_methods()
	_populate_profiles()
	_init_default_values()
	# Signale verbinden
	opt_profile.item_selected.connect(_on_profile_selected)
	btn_calc.pressed.connect(_on_calculate_preview_pressed)
	btn_generate.pressed.connect(_on_generate_full_lut_pressed)

	# Erstes Profil laden, falls vorhanden
	if opt_profile.item_count > 0:
		_on_profile_selected(0)
	#_show_naca632012()

func _init_default_values()-> void:
	var config: LutGenerator.GeneratorConfig = LutGenerator.GeneratorConfig.new()
	input_stall.text = str(config.stall_angle_deg)
	input_sharpness.text = str(config.sharpness)
	input_mach.text = str(config.preview_mach)
	input_re.text = str(config.preview_re)

func _init_plots():
	# Preview Plot setup
	series_cl = LineSeries.new(Color.CORNFLOWER_BLUE, 2.0)
	series_cd = LineSeries.new(Color.INDIAN_RED, 2.0)
	series_cm = LineSeries.new(Color.GREEN, 2.0)
	series_sigma = LineSeries.new(Color.DARK_VIOLET, 2.0)
	plot_preview.add_series(series_cl)
	plot_preview.add_series(series_cd)
	plot_preview.add_series(series_cm)
	plot_preview.add_series(series_sigma)

	series_cl_naca632012 = LineSeries.new(Color.AQUAMARINE, 2.0)
	plot_preview.add_series(series_cl_naca632012)
	# Geometry Plot setup
	series_geo_upper = LineSeries.new(Color.WEB_GREEN, 2.0)
	series_geo_lower = LineSeries.new(Color.YELLOW_GREEN, 2.0)
	plot_geometry.add_series(series_geo_upper)
	plot_geometry.add_series(series_geo_lower)

	# Geometrie-Plot fixieren (Normierte Koordinaten 0..1)
	plot_geometry.x_min = -0.1
	plot_geometry.x_max = 1.1
	plot_geometry.y_min = -0.2
	plot_geometry.y_max = 0.2

func _show_naca632012() -> void:
	var NACA632012 = NACA632012LiftCurve.new()
	series_cl_naca632012.clear_data()
	for p in NACA632012.NACA0012_WINDTUNNEL:
		series_cl_naca632012.add_point(p.x, p.y)


func _populate_methods():
	opt_method.clear()
	# Die Reihenfolge muss mit dem Enum im LutGenerator übereinstimmen!
	opt_method.add_item("Method 1 (Linear/Viterna)")
	opt_method.add_item("Method 1A (Linear/Viterna)")
	opt_method.add_item("Method 2 (Complex/Wave)")
	opt_method.add_item("Combined (Blended)")
	opt_method.select(1) # Default auf Combined

func _populate_profiles():
	opt_profile.clear()
	var dir = DirAccess.open(AIRFOIL_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				# Filtere nach .dat oder .txt Dateien
				if file_name.ends_with(".dat") or file_name.ends_with(".txt"):
					opt_profile.add_item(file_name)
			file_name = dir.get_next()
	else:
		lbl_state.text = "Error: Directory not found: " + AIRFOIL_DIR

# --- Logik ---

func _on_profile_selected(index: int):
	var file_name = opt_profile.get_item_text(index)
	var full_path = AIRFOIL_DIR + file_name

	var profile = AirfoilProfile.new()
	if profile.load_from_dat(full_path):
		current_profile = profile
		lbl_state.text = "Loaded: " + profile.name

		# --- NEU: Automatische Parameter-Schätzung ---

		# 1. Geometrie analysieren
		var geo_data = LutGenerator.analyze_geometry(profile)

		# 2. Werte schätzen
		var est_stall = LutGenerator.estimate_stall_angle(geo_data)
		var est_bw_scale = LutGenerator.estimate_backward_scale(geo_data)

		# 3. Ins UI schreiben (auf 1 oder 2 Kommastellen runden)
		input_stall.text = String.num(est_stall, 1)

		# Falls du das Feld schon im UI hast:
		if input_backward_scale:
			input_backward_scale.text = String.num(est_bw_scale, 2)

		print("Auto-Estimated: Stall=%.1f, BW-Scale=%.2f (Thick=%.1f%% at %.1f%%)" %
			[est_stall, est_bw_scale, geo_data.thickness*100, geo_data.pos_max_thick_x*100])

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

	# Strings zu Floats parsen (mit Fallback)
	config.stall_angle_deg = float(input_stall.text)
	config.sharpness = float(input_sharpness.text)
	config.preview_mach = float(input_mach.text)

	# Methode aus Dropdown
	config.method = opt_method.selected as LutGenerator.CalculationMethod

	# Reynolds falls vorhanden, sonst default
	if input_re and input_re.text.is_valid_float():
		config.preview_re = float(input_re.text)
	if input_backward_scale:
		config.backward_lift_scale = float(input_backward_scale.text)

	return config

# Aktion 1: Nur Vorschau berechnen (Dein "CalcCLCDButton")
func _on_calculate_preview_pressed():
	if not current_profile: return

	var config = _get_current_config()

	# Aufruf der statischen Logik
	var results = LutGenerator.calculate_preview_curve(current_profile, config)

	# Plotten
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
	lbl_state.text = "Preview calculated using " + opt_method.get_item_text(opt_method.selected)

# Aktion 2: Volle LUT generieren und speichern
func _on_generate_full_lut_pressed():
	if not current_profile: return

	lbl_state.text = "Generating full LUT (this may take a moment)..."
	await get_tree().process_frame # UI freeze verhindern

	var config = _get_current_config()
	var lut = LutGenerator.generate_lut(current_profile, config)

	# Speichern
	var fname = input_output_name.text
	if not fname.ends_with(".tres"): fname += ".tres"
	var save_path = LUT_DIR + fname

	LutGenerator.save_lut(lut, save_path)

	lbl_state.text = "LUT saved to: " + fname
	lut_generated.emit(save_path) # Signal an MainController um Tab zu wechseln

# Visualisierung des Profils (Geometrie)
func _draw_geometry():
	if not current_profile: return
	series_geo_upper.clear_data()
	series_geo_lower.clear_data()

	for p in current_profile.upper_surface:
		series_geo_upper.add_point(p.x, p.y)
	for p in current_profile.lower_surface:
		series_geo_lower.add_point(p.x, p.y)

	plot_geometry.queue_redraw()
