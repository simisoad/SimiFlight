class_name LUTVisualizer extends Control

# --- UI References ---
@onready var file_selector: OptionButton = %FileSelector
@onready var mach_selector: OptionButton = %MachSelector
@onready var re_selector: OptionButton = %ReynoldsSelector
@onready var show_live_curves: CheckBox = %ShowLiveCurves
@onready var show_calculated_lut_curves: CheckBox = %ShowCalculatedLutCurves

# The Custom Chart
@onready var plot: SimpleChart = %PlotVisu

# External Component (Simulation Driver)
@onready var force_vis: ForceVisualizer = $VSplitContainer/ForceVisualizer

# --- Constants & State ---
const LUT_DIR = "res://data/luts/"

var current_lut: AirfoilLut

# --- Data Containers (Points) ---
# We store the points here so we can re-draw the chart whenever we want
var pts_static_cl: Array[Vector2] = []
var pts_static_cd: Array[Vector2] = []
var pts_static_cm: Array[Vector2] = []
var pts_static_stall: Array[Vector2] = []

var pts_live_cl: Array[Vector2] = []
var pts_live_cd: Array[Vector2] = []
var pts_live_cm: Array[Vector2] = []

var pts_marker_cl: Array[Vector2] = []
var pts_marker_cd: Array[Vector2] = []

# --- Series Names ---
const N_STAT_CL = "LUT Cl"
const N_STAT_CD = "LUT Cd"
const N_STAT_CM = "LUT Cm"
const N_STAT_STALL = "LUT Stall"

const N_LIVE_CL = "Live Cl"
const N_LIVE_CD = "Live Cd"
const N_LIVE_CM = "Live Cm"

const N_MARK_CL = "Current Cl"
const N_MARK_CD = "Current Cd"


func _ready():
	_setup_plot()
	_refresh_file_list()

	# Connect Internal UI
	file_selector.item_selected.connect(_on_file_selected)
	mach_selector.item_selected.connect(_on_param_changed)
	re_selector.item_selected.connect(_on_param_changed)

	# Connect Visibility Toggles
	show_live_curves.toggled.connect(_refresh_chart_visuals.unbind(1)) # unbind ignores the bool arg, just refreshes
	show_calculated_lut_curves.toggled.connect(_refresh_chart_visuals.unbind(1))

	# Connect External Simulation Signals
	if force_vis:
		force_vis.params_changed.connect(_on_sim_params_changed)
		force_vis.state_changed.connect(_on_sim_state_changed)

func _setup_plot():
	# Configure the SimpleChart view
	plot.set_domain(-180.0, 180.0, -2.5, 2.5)
	# Optional: Enable grid if your SimpleChart has that property exposed
	# plot.show_grid = true

func _refresh_file_list():
	file_selector.clear()
	var dir = DirAccess.open(LUT_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				file_selector.add_item(file_name)
			file_name = dir.get_next()

		if file_selector.item_count > 0:
			_on_file_selected(0)
	else:
		push_error("Failed to access LUT directory: " + LUT_DIR)

func _on_file_selected(idx: int):
	var filename = file_selector.get_item_text(idx)
	var full_path = LUT_DIR + filename
	if FileAccess.file_exists(full_path):
		var res = ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if res is AirfoilLut:
			set_lut(res)

func set_lut(lut: AirfoilLut):
	current_lut = lut
	if force_vis:
		force_vis.set_data(lut, lut.airfoil)

	_populate_param_selectors()
	_recalc_static_curves() # Calculate data
	_refresh_chart_visuals() # Draw data

func _populate_param_selectors():
	mach_selector.clear()
	re_selector.clear()

	if not current_lut: return

	for m in current_lut.mach_points:
		mach_selector.add_item("Mach %.2f" % m)

	for re in current_lut.reynolds_points:
		re_selector.add_item("Re %.1f" % re)

	if mach_selector.item_count > 0: mach_selector.select(0)
	if re_selector.item_count > 0: re_selector.select(0)

func _on_param_changed(_idx):
	_recalc_static_curves()
	_refresh_chart_visuals()

# ------------------------------------------------------------------------------
# DATA CALCULATION
# ------------------------------------------------------------------------------

func _recalc_static_curves():
	# Clears and rebuilds the "LUT" (Static) arrays based on dropdowns
	pts_static_cl.clear()
	pts_static_cd.clear()
	pts_static_cm.clear()
	pts_static_stall.clear()

	if not current_lut: return

	var mach_idx = mach_selector.selected
	var re_idx = re_selector.selected
	if mach_idx == -1 or re_idx == -1: return

	for i in range(current_lut.alpha_points.size()):
		var alpha = current_lut.alpha_points[i]
		# Vector4(cl, cd, cm, stall)
		var coeffs: Vector4 = current_lut.get_coefficients_at_index(re_idx, mach_idx, i)

		pts_static_cl.append(Vector2(alpha, coeffs.x))
		pts_static_cd.append(Vector2(alpha, coeffs.y))
		pts_static_cm.append(Vector2(alpha, coeffs.z))
		pts_static_stall.append(Vector2(alpha, coeffs.w))

func _on_sim_params_changed(mach: float, re: float):
	# Recalculates the "Live" interpolated curves
	pts_live_cl.clear()
	pts_live_cd.clear()
	pts_live_cm.clear()

	if not current_lut: return

	# Sample from -180 to 180 (Step 2 degrees is fine for visualization)
	for i in range(-180, 181, 2):
		var alpha_rad = deg_to_rad(float(i))
		var coeffs = AirfoilSampler.sample(current_lut, alpha_rad, mach, re)

		pts_live_cl.append(Vector2(float(i), coeffs.cl))
		pts_live_cd.append(Vector2(float(i), coeffs.cd))
		pts_live_cm.append(Vector2(float(i), coeffs.cm))

	_refresh_chart_visuals()

func _on_sim_state_changed(alpha: float, cl: float, cd: float, _cm: float):
	# Updates the Marker positions
	pts_marker_cl.clear()
	pts_marker_cd.clear()

	var offset = 1.0 # 1 degree width for the marker line

	pts_marker_cl.append(Vector2(alpha - offset, cl))
	pts_marker_cl.append(Vector2(alpha + offset, cl))

	pts_marker_cd.append(Vector2(alpha - offset, cd))
	pts_marker_cd.append(Vector2(alpha + offset, cd))

	_refresh_chart_visuals()

# ------------------------------------------------------------------------------
# VISUALIZATION
# ------------------------------------------------------------------------------

func _refresh_chart_visuals():
	# This function pushes all current data arrays to the SimpleChart
	# and sets their visibility.

	plot.clear_series()

	# 1. Add Static LUT Curves
	plot.add_series(N_STAT_CL, pts_static_cl, Color.BLUE, 2.0)
	plot.add_series(N_STAT_CD, pts_static_cd, Color.RED, 2.0)
	plot.add_series(N_STAT_CM, pts_static_cm, Color.GREEN, 2.0)
	plot.add_series(N_STAT_STALL, pts_static_stall, Color.DARK_VIOLET, 1.5)

	# 2. Add Live Curves
	plot.add_series(N_LIVE_CL, pts_live_cl, Color.CYAN, 2.0)
	plot.add_series(N_LIVE_CD, pts_live_cd, Color.ORANGE, 2.0)
	plot.add_series(N_LIVE_CM, pts_live_cm, Color.GREEN_YELLOW, 2.0)

	# 3. Add Markers (Thick White/Yellow lines)
	plot.add_series(N_MARK_CL, pts_marker_cl, Color.WHITE, 4.0)
	plot.add_series(N_MARK_CD, pts_marker_cd, Color.YELLOW, 4.0)

	# 4. Apply Visibility Logic
	var show_static = show_calculated_lut_curves.button_pressed
	var show_live = show_live_curves.button_pressed

	plot.set_series_visible(N_STAT_CL, show_static)
	plot.set_series_visible(N_STAT_CD, show_static)
	plot.set_series_visible(N_STAT_CM, show_static)
	plot.set_series_visible(N_STAT_STALL, show_static)

	plot.set_series_visible(N_LIVE_CL, show_live)
	plot.set_series_visible(N_LIVE_CD, show_live)
	plot.set_series_visible(N_LIVE_CM, show_live)

	# Markers follow Live visibility
	plot.set_series_visible(N_MARK_CL, show_live)
	plot.set_series_visible(N_MARK_CD, show_live)
