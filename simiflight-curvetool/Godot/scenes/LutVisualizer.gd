extends Control

# UI Referenzen (müssen im Inspector oder per Unique Name verknüpft sein)
@onready var file_selector: OptionButton = %FileSelector
@onready var mach_selector: OptionButton = %MachSelector
@onready var re_selector: OptionButton = %ReynoldsSelector
@onready var plot: Graph2D = %PlotVisu

# Pfad zu den LUTs
const LUT_DIR = "res://data/luts/"

var current_lut: AirfoilLut
var lift_series: LineSeries
var drag_series: LineSeries

func _ready():
	_setup_plot()
	_refresh_file_list()

func _setup_plot():
	# Initialisiere Plot-Linien
	lift_series = LineSeries.new(Color.BLUE, 2.0) # Blau für CL
	drag_series = LineSeries.new(Color.RED, 2.0)  # Rot für CD
	plot.add_series(lift_series)
	plot.add_series(drag_series)

	# Signale verbinden
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

		# Wenn Dateien gefunden wurden, lade die erste
		if file_selector.item_count > 0:
			_on_file_selected(0)
	else:
		push_error("Failed to access LUT directory: " + LUT_DIR)

func _on_file_selected(idx: int):
	var filename = file_selector.get_item_text(idx)
	var full_path = LUT_DIR + filename

	var res = load(full_path)
	if res is AirfoilLut:
		set_lut(res)

func set_lut(lut: AirfoilLut):
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

	# Setze Default-Werte (z.B. Mitte)
	if mach_selector.item_count > 0: mach_selector.select(0)
	if re_selector.item_count > 0: re_selector.select(0)

func _on_param_changed(_idx):
	_update_graph()

func _update_graph():
	if not current_lut: return

	lift_series.clear_data()
	drag_series.clear_data()

	var mach_idx = mach_selector.selected
	var re_idx = re_selector.selected

	if mach_idx == -1 or re_idx == -1: return

	# Iteriere über alle Alpha-Werte (X-Achse)
	for i in range(current_lut.alpha_points.size()):
		var alpha = current_lut.alpha_points[i]

		# Nutze die saubere Helper-Funktion aus AirfoilLut
		var coeffs = current_lut.get_coefficients_at_index(re_idx, mach_idx, i)

		lift_series.add_point(alpha, coeffs.x) # x = cl
		drag_series.add_point(alpha, coeffs.y) # y = cd

	plot.queue_redraw()
