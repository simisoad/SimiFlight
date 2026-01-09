class_name LutVisualizer extends Control

@export_group("LiveMarkers")
@export var markers_radius: float = 5.0
# --- UI References ---
@onready var file_selector: OptionButton = %FileSelector
@onready var mach_selector: OptionButton = %MachSelector
@onready var re_selector: OptionButton = %ReynoldsSelector

@onready var show_live_curves: CheckBox = %ShowLiveCurves
@onready var show_calculated_lut_curves: CheckBox = %ShowCalculatedLutCurves

@onready var show_cl: Button = %ShowCl
@onready var show_cd: Button = %ShowCd
@onready var show_cm: Button = %ShowCm
@onready var show_stall: Button = %ShowStall

@onready var show_cl_live: Button = %ShowClLive
@onready var show_cd_live: Button = %ShowCdLive
@onready var show_cm_live: Button = %ShowCmLive
@onready var show_stall_live: Button = %ShowStallLive

# The Custom Chart
@onready var plot: SimpleChart = %PlotVisu

# External Component (Simulation Driver)
@onready var force_vis: ForceVisualizer = %ForceVisualizer

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
var pts_live_stall: Array[Vector2] = []

var pos_marker_cl: Vector2 = Vector2.ZERO
var pos_marker_cd: Vector2 = Vector2.ZERO
var pos_marker_cm: Vector2 = Vector2.ZERO
var pos_marker_stall: Vector2 = Vector2.ZERO
# --- Series Names ---
const N_STAT_CL: String = "LUT Cl"
const N_STAT_CD: String = "LUT Cd"
const N_STAT_CM: String = "LUT Cm"
const N_STAT_STALL: String = "LUT Stall"

const N_LIVE_CL: String = "Live Cl"
const N_LIVE_CD: String = "Live Cd"
const N_LIVE_CM: String = "Live Cm"
const N_LIVE_STALL: String = "Live Stall"

const N_MARK_CL: String = "Current Cl"
const N_MARK_CD: String = "Current Cd"
const N_MARK_CM: String = "Current Cm"
const N_MARK_STALL: String = "Current Stall"

# Color Const
const CL_COLOR_STATIC: Color = Color.CYAN
const CD_COLOR_STATIC: Color = Color.RED
const CM_COLOR_STATIC: Color = Color.GREEN
const STALL_COLOR_STATIC: Color = Color.DARK_VIOLET

const CL_COLOR_LIVE = Color.SKY_BLUE
const CD_COLOR_LIVE = Color.DARK_RED
const CM_COLOR_LIVE = Color.GREEN_YELLOW
const STALL_COLOR_LIVE = Color.VIOLET


func _ready():
	_setup_plot()
	refresh_file_list()

	# Connect Internal UI
	file_selector.item_selected.connect(_on_file_selected)
	mach_selector.item_selected.connect(_on_param_changed)
	re_selector.item_selected.connect(_on_param_changed)

	# Connect Visibility Toggles
	show_live_curves.toggled.connect(_refresh_chart_visuals.unbind(1)) # unbind ignores the bool arg, just refreshes
	show_calculated_lut_curves.toggled.connect(_refresh_chart_visuals.unbind(1))

	LutGeneratorView.set_show_curve_btns_color(show_cl, CL_COLOR_STATIC)
	LutGeneratorView.set_show_curve_btns_color(show_cd, CD_COLOR_STATIC)
	LutGeneratorView.set_show_curve_btns_color(show_cm, CM_COLOR_STATIC)
	LutGeneratorView.set_show_curve_btns_color(show_stall, STALL_COLOR_STATIC)

	LutGeneratorView.set_show_curve_btns_color(show_cl_live, CL_COLOR_LIVE)
	LutGeneratorView.set_show_curve_btns_color(show_cd_live, CD_COLOR_LIVE)
	LutGeneratorView.set_show_curve_btns_color(show_cm_live, CM_COLOR_LIVE)
	LutGeneratorView.set_show_curve_btns_color(show_stall_live, STALL_COLOR_LIVE)

	show_calculated_lut_curves.toggled.connect(func(v):
			show_cl.disabled = !v
			show_cd.disabled = !v
			show_cm.disabled = !v
			show_stall.disabled = !v
			)
	show_live_curves.toggled.connect(func(v):
			show_cl_live.disabled = !v
			show_cd_live.disabled = !v
			show_cm_live.disabled = !v
			show_stall_live.disabled = !v
			)

	show_cl.toggled.connect(func(v): plot.set_series_visible(N_STAT_CL, v))
	show_cd.toggled.connect(func(v): plot.set_series_visible(N_STAT_CD, v))
	show_cm.toggled.connect(func(v): plot.set_series_visible(N_STAT_CM, v))
	show_stall.toggled.connect(func(v): plot.set_series_visible(N_STAT_STALL, v))

	show_cl_live.toggled.connect(func(v): plot.set_series_visible(N_LIVE_CL, v); plot.set_marker_visible(N_MARK_CL, v))
	show_cd_live.toggled.connect(func(v): plot.set_series_visible(N_LIVE_CD, v); plot.set_marker_visible(N_MARK_CD, v))
	show_cm_live.toggled.connect(func(v): plot.set_series_visible(N_LIVE_CM, v); plot.set_marker_visible(N_MARK_CM, v))
	show_stall_live.toggled.connect(func(v): plot.set_series_visible(N_LIVE_STALL, v); plot.set_marker_visible(N_MARK_STALL, v))

	# Connect External Simulation Signals
	if force_vis:
		force_vis.params_changed.connect(_on_sim_params_changed)
		force_vis.state_changed.connect(_on_sim_state_changed)
		_on_sim_params_changed(force_vis.input_mach.value, force_vis.input_re.value)


func _setup_plot():
	plot.set_domain(-180.0, 180.0, -2.5, 2.5)

func refresh_file_list(select_id_hash = null):
	file_selector.clear()
	var dir = DirAccess.open(LUT_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				file_selector.add_item(file_name, hash(file_name))
			file_name = dir.get_next()

		if file_selector.item_count > 0:
			if select_id_hash:
				var idx: int = file_selector.get_item_index(select_id_hash)
				_on_file_selected(idx)
			else:
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
	pts_live_stall.clear()

	if not current_lut: return

	# Sample from -180 to 180 (Step 2 degrees is fine for visualization)
	for i in LutGenerator._get_alpha_grid(-180.0,180.0,0.1):
		var alpha_rad = deg_to_rad(i)
		var coeffs = AirfoilSampler.sample(current_lut, alpha_rad, mach, re)

		pts_live_cl.append(Vector2(i, coeffs.cl))
		pts_live_cd.append(Vector2(i, coeffs.cd))
		pts_live_cm.append(Vector2(i, coeffs.cm))
		pts_live_stall.append(Vector2(i, coeffs.stall))

	_refresh_chart_visuals()

func _on_sim_state_changed(alpha: float, cl: float, cd: float, cm: float, stall: float):
	# Updates the Marker positions
	pos_marker_cl = Vector2(alpha, cl)
	pos_marker_cm =  Vector2(alpha, cm)
	pos_marker_cd =  Vector2(alpha, cd)
	pos_marker_stall = Vector2(alpha, stall)

	_refresh_chart_visuals()

# ------------------------------------------------------------------------------
# VISUALIZATION
# ------------------------------------------------------------------------------

func _refresh_chart_visuals():
	# This function pushes all current data arrays to the SimpleChart
	# and sets their visibility.

	plot.clear_series()
	plot.clear_markers()

	# 1. Add Static LUT Curves
	plot.add_series(N_STAT_CL, pts_static_cl, CL_COLOR_STATIC, 2.0)
	plot.add_series(N_STAT_CD, pts_static_cd, CD_COLOR_STATIC, 2.0)
	plot.add_series(N_STAT_CM, pts_static_cm, CM_COLOR_STATIC, 2.0)
	plot.add_series(N_STAT_STALL, pts_static_stall, STALL_COLOR_STATIC, 2.0)

	# 2. Add Live Curves
	plot.add_series(N_LIVE_CL, pts_live_cl, CL_COLOR_LIVE, 2.0)
	plot.add_series(N_LIVE_CD, pts_live_cd, CD_COLOR_LIVE, 2.0)
	plot.add_series(N_LIVE_CM, pts_live_cm, CM_COLOR_LIVE, 2.0)
	plot.add_series(N_LIVE_STALL, pts_live_stall, STALL_COLOR_LIVE, 2.0)

	# 3. Add Markers (Thick White/Yellow lines)
	plot.add_marker(N_MARK_CL, pos_marker_cl, markers_radius, CL_COLOR_LIVE, 2.0, false) #(N_MARK_CL, pos_marker_cl, Color.AQUA, 2.0)
	plot.add_marker(N_MARK_CD, pos_marker_cd, markers_radius, CD_COLOR_LIVE, 2.0, false)
	plot.add_marker(N_MARK_CM, pos_marker_cm, markers_radius, CM_COLOR_LIVE, 2.0, false)
	plot.add_marker(N_MARK_STALL, pos_marker_stall, markers_radius, STALL_COLOR_LIVE, 2.0, false)
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
	plot.set_series_visible(N_LIVE_STALL, show_live)

	# Markers follow Live visibility
	plot.set_marker_visible(N_MARK_CL, show_live)
	plot.set_marker_visible(N_MARK_CD, show_live)
	plot.set_marker_visible(N_MARK_CM, show_live)
	plot.set_marker_visible(N_MARK_STALL, show_live)
