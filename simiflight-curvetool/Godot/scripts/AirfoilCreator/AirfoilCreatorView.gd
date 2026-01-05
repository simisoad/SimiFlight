class_name AirfoilCreatorView extends HSplitContainer

signal airfoil_saved(filename: String)

# UI References
@onready var spin_m: SpinBox = %CamberSpinBox
@onready var spin_p: SpinBox = %PositionSpinBox
@onready var spin_t: SpinBox = %ThicknessSpinbox

# The Frankenstein Sliders
@onready var spin_le: SpinBox = %SpinNoseRadius # Range 0.0 to 2.0, Step 0.1
@onready var spin_te: SpinBox = %SpinTEThick    # Range 0.0 to 5.0 (%), Step 0.1

# The Type Selector
@onready var check_oval: CheckBox = %CheckOvalShape # NEW UI ELEMENT

@onready var input_name: LineEdit = %FileNameLineEdit
@onready var plot: Graph2D = %PlotGeometry
@onready var lbl_status: Label = %StatusLabel

var current_points: Dictionary = {}
var line_upper: LineSeries
var line_lower: LineSeries
# New: A specific line to close the gap visually
var line_closure: LineSeries

func _ready():
	_init_plot()

	# Connect ALL signals to the generator
	var params = [spin_m, spin_p, spin_t, spin_le, spin_te]
	for s in params:
		s.value_changed.connect(func(_v): _generate())

	check_oval.toggled.connect(func(_b): _generate())
	%SaveBtn.pressed.connect(_on_save_pressed)

	# Defaults
	spin_m.value = 2.0
	spin_p.value = 4.0
	spin_t.value = 12.0
	spin_le.value = 1.0 # Standard
	spin_te.value = 0.0 # Closed

	_generate()

func _init_plot():
	line_upper = LineSeries.new(Color.GREEN, 2.0)
	line_lower = LineSeries.new(Color.YELLOW, 2.0)
	line_closure = LineSeries.new(Color.WHITE, 2.0) # To draw the vertical line at the back

	plot.add_series(line_upper)
	plot.add_series(line_lower)
	plot.add_series(line_closure)

	plot.x_min = -0.1
	plot.x_max = 1.1
	plot.y_min = -0.3
	plot.y_max = 0.3

func _generate():
	var m = spin_m.value / 100.0
	var p = spin_p.value / 10.0
	var t = spin_t.value / 100.0

	var le = spin_le.value
	var te = spin_te.value / 100.0

	var type = NacaGenerator.ShapeType.ELLIPTICAL if check_oval.button_pressed else NacaGenerator.ShapeType.NACA_POLYNOMIAL

	current_points = NacaGenerator.generate_universal(m, p, t, le, te, type, 60)

	# Auto-Naming logic (Simplified)
	var base_name = "NACA" if type == 0 else "OVAL"
	if le != 1.0 or te != 0.0:
		base_name = "MOD"
	input_name.placeholder_text = "%s %d%d%02d" % [base_name, int(m*100), int(p*10), int(t*100)]

	_draw_plot()

func _draw_plot():
	line_upper.clear_data()
	line_lower.clear_data()
	line_closure.clear_data()

	# 1. Draw Upper
	for pt in current_points.upper:
		line_upper.add_point(pt.x, pt.y)

	# 2. Draw Lower
	for pt in current_points.lower:
		line_lower.add_point(pt.x, pt.y)

	# 3. VISUALLY CLOSE THE TRAILING EDGE
	# Get the last point of upper and lower
	if current_points.upper.size() > 0:
		var last_up = current_points.upper.back()
		var last_low = current_points.lower.back()

		# Draw a vertical line connecting them
		line_closure.add_point(last_up.x, last_up.y)
		line_closure.add_point(last_low.x, last_low.y)

	plot.queue_redraw()


func _on_save_pressed():
	if current_points.is_empty(): return

	var fname = input_name.text.strip_edges()
	if fname.is_empty():
		lbl_status.text = "Error: Name is empty."
		return

	if not fname.ends_with(".dat"):
		fname += ".dat"

	var path = "res://data/airfoils/" + fname

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		lbl_status.text = "Error writing file."
		return

	# Write SELIG format
	# Line 1: Name
	file.store_line(input_name.text)

	# Line 2+: X  Y
	# Selig format usually runs Upper Surface (1.0 -> 0.0) then Lower (0.0 -> 1.0)

	# 1. Upper (Reverse order: Tail to Nose)
	var up = current_points.upper.duplicate()
	up.reverse()
	for pt in up:
		file.store_line("%.6f   %.6f" % [pt.x, pt.y])

	# 2. Lower (Standard order: Nose to Tail)
	# Skip first point of lower if it's identical to upper's nose (0,0) to avoid dupes?
	# Selig format usually accepts dupes at 0,0, but let's be safe.
	for i in range(1, current_points.lower.size()):
		var pt = current_points.lower[i]
		file.store_line("%.6f   %.6f" % [pt.x, pt.y])

	file.close()
	lbl_status.text = "Saved: " + fname

	# Emit Signal to update other tabs
	airfoil_saved.emit(path)
