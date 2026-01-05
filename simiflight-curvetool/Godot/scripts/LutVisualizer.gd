extends Control

# UI References (must be linked in Inspector or via Unique Name)
@onready var file_selector: OptionButton = %FileSelector
@onready var mach_selector: OptionButton = %MachSelector
@onready var re_selector: OptionButton = %ReynoldsSelector
@onready var plot: Graph2D = %PlotVisu
@onready var force_vis: ForceVisualizer = $VSplitContainer/ForceVisualizer
@onready var show_live_curves: CheckBox = %ShowLiveCurves
@onready var show_calculated_lut_curves: CheckBox = %ShowCalculatedLutCurves
# Path to LUTs
const LUT_DIR = "res://data/luts/"

var current_lut: AirfoilLut
var cl_series: LineSeries
var cd_series: LineSeries
var cm_series: LineSeries
var stall_series: LineSeries

var series_cl_live: LineSeries # The smoothed live curve
var series_cd_live: LineSeries
var series_cm_live: LineSeries
var marker_cl: LineSeries # A single point
var marker_cd: LineSeries # A single point


func _ready():
	_setup_plot()
	_refresh_file_list()
	if force_vis:
		force_vis.params_changed.connect(_on_sim_params_changed)
		force_vis.state_changed.connect(_on_sim_state_changed)
	show_live_curves.toggled.connect(_on_show_live_curves_toggled)
	show_calculated_lut_curves.toggled.connect(_on_show_calculated_lut_curves_toggled)
func _setup_plot():
	# Initialize Plot Lines
	cl_series = LineSeries.new(Color.BLUE, 2.0) # Blue for CL
	cd_series = LineSeries.new(Color.RED, 2.0)  # Red for CD
	cm_series = LineSeries.new(Color.GREEN, 2.0)
	stall_series = LineSeries.new(Color.DARK_VIOLET)

	# 1. Live Curves (e.g., dashed or lighter color)
	series_cl_live = LineSeries.new(Color.CYAN, 2.0) # Bright Blue for Live Cl
	series_cd_live = LineSeries.new(Color.ORANGE, 2.0) # Orange for Live Cd
	series_cm_live = LineSeries.new(Color.GREEN_YELLOW, 2.0)

	marker_cl = LineSeries.new(Color.WHITE, 5.0) # Thick point
	marker_cd = LineSeries.new(Color.YELLOW, 5.0)

	plot.add_series(series_cl_live)
	plot.add_series(series_cd_live)
	plot.add_series(series_cm_live)

	plot.add_series(cl_series)
	plot.add_series(cd_series)
	plot.add_series(cm_series)
	plot.add_series(stall_series)

	plot.add_series(marker_cl)
	plot.add_series(marker_cd)

	# Connect Signals
	file_selector.item_selected.connect(_on_file_selected)
	mach_selector.item_selected.connect(_on_param_changed)
	re_selector.item_selected.connect(_on_param_changed)

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

		# If files were found, load the first one
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
	force_vis.set_data(lut, lut.airfoil)
	current_lut = lut
	_populate_param_selectors()
	_update_graph()

func _populate_param_selectors():
	mach_selector.clear()
	re_selector.clear()

	if not current_lut: return

	for m in current_lut.mach_points:
		mach_selector.add_item("Mach %.2f" % m)

	for re in current_lut.reynolds_points:
		re_selector.add_item("Re %.1f" % re)

	# Set Default Values (e.g., middle)
	if mach_selector.item_count > 0: mach_selector.select(0)
	if re_selector.item_count > 0: re_selector.select(0)

func _on_param_changed(_idx):
	_update_graph()

func _update_graph():
	if not current_lut: return

	cl_series.clear_data()
	cd_series.clear_data()
	cm_series.clear_data()
	stall_series.clear_data()

	var mach_idx = mach_selector.selected
	var re_idx = re_selector.selected

	if mach_idx == -1 or re_idx == -1: return

	# Iterate over all Alpha values (X-axis)
	for i in range(current_lut.alpha_points.size()):
		var alpha = current_lut.alpha_points[i]

		# Use the clean Helper function from AirfoilLut
		# return Vector4(cl_data[idx], cd_data[idx], cm_data[idx], stall_data[idx])
		var coeffs: Vector4 = current_lut.get_coefficients_at_index(re_idx, mach_idx, i)

		cl_series.add_point(alpha, coeffs.x) # x = cl
		cd_series.add_point(alpha, coeffs.y) # y = cd
		cm_series.add_point(alpha, coeffs.z)
		stall_series.add_point(alpha, coeffs.w)

	plot.queue_redraw()

func _on_sim_params_changed(mach: float, re: float):
	# If Mach or Reynolds are changed in ForceVisualizer:
	# Recalculate the ENTIRE curve, exactly for these values!
	if not current_lut: return

	series_cl_live.clear_data()
	series_cd_live.clear_data()
	series_cm_live.clear_data()

	# We sample from -180 to 180 in 1-degree steps (or finer)
	# This uses your ingenious AirfoilSampler class!
	for i in range(-180, 181, 2): # 2 degree steps suffice for performance
		var alpha_rad = deg_to_rad(float(i))

		# Here we use the sampler to interpolate BETWEEN the LUT values
		var coeffs = AirfoilSampler.sample(current_lut, alpha_rad, mach, re)

		series_cl_live.add_point(float(i), coeffs.cl)
		series_cd_live.add_point(float(i), coeffs.cd)
		series_cm_live.add_point(float(i), coeffs.cm)

	plot.queue_redraw()

func _on_sim_state_changed(alpha: float, cl: float, cd: float, _cm: float):
	# Move markers to current position
	marker_cl.clear_data()
	marker_cd.clear_data()

	# TRICK: We draw a 1 degree wide line around the point
	var offset = 0.5 # Half degree to left and right

	# Marker for Cl
	marker_cl.add_point(alpha - offset, cl)
	marker_cl.add_point(alpha + offset, cl)

	# Marker for Cd
	marker_cd.add_point(alpha - offset, cd)
	marker_cd.add_point(alpha + offset, cd)

	plot.queue_redraw()

func _on_show_live_curves_toggled(toggled: bool) -> void:
	if !toggled:
		plot.remove_series(marker_cd)
		plot.remove_series(marker_cl)
		plot.remove_series(series_cl_live)
		plot.remove_series(series_cd_live)
		plot.remove_series(series_cm_live)
	else:
		plot.add_series(marker_cd)
		plot.add_series(marker_cl)
		plot.add_series(series_cl_live)
		plot.add_series(series_cd_live)
		plot.add_series(series_cm_live)
	plot.queue_redraw()
func _on_show_calculated_lut_curves_toggled(toggled: bool) -> void:
	if !toggled:
		plot.remove_series(cd_series)
		plot.remove_series(cl_series)
		plot.remove_series(cm_series)
		plot.remove_series(stall_series)
	else:
		plot.add_series(cd_series)
		plot.add_series(cl_series)
		plot.add_series(cm_series)
		plot.add_series(stall_series)
	plot.queue_redraw()
