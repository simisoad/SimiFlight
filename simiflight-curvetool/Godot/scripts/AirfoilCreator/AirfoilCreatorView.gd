class_name AirfoilCreatorView extends HSplitContainer

signal airfoil_saved(filename: String)

# --- UI References ---
@onready var spin_m: SpinBox = %CamberSpinBox
@onready var spin_p: SpinBox = %PositionSpinBox
@onready var spin_t: SpinBox = %ThicknessSpinbox

# The Frankenstein Sliders
@onready var spin_le: SpinBox = %SpinNoseRadius # Range 0.0 to 2.0, Step 0.1
@onready var spin_te: SpinBox = %SpinTEThick    # Range 0.0 to 5.0 (%), Step 0.1

# The Type Selector
@onready var check_oval: CheckBox = %CheckOvalShape

@onready var input_name: LineEdit = %FileNameLineEdit
@onready var lbl_status: Label = %StatusLabel

# --- Plot Reference ---
@onready var plot: SimpleChart = %PlotGeometry

# --- State ---
var current_points: Dictionary = {}

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
	# Set visual domain to framing the airfoil comfortably
	# X: -0.1 to 1.1 (Chord is 0.0 to 1.0)
	# Y: -0.3 to 0.3 (Thickness usually maxes at +/- 0.15)
	plot.set_domain(-0.1, 1.1, -0.3, 0.3)

	# Optional: You could disable the grid if you want a cleaner look
	# plot.show_grid = false

func _generate():
	var m = spin_m.value / 100.0
	var p = spin_p.value / 10.0
	var t = spin_t.value / 100.0

	var le = spin_le.value
	var te = spin_te.value / 100.0

	var type = NacaGenerator.ShapeType.ELLIPTICAL if check_oval.button_pressed else NacaGenerator.ShapeType.NACA_POLYNOMIAL

	# This returns { "upper": [Vector2], "lower": [Vector2] }
	current_points = NacaGenerator.generate_universal(m, p, t, le, te, type, 60)

	# Auto-Naming logic
	var base_name = "NACA" if type == 0 else "OVAL"
	if le != 1.0 or te != 0.0:
		base_name = "MOD"
	input_name.placeholder_text = "%s %d%d%02d" % [base_name, int(m*100), int(p*10), int(t*100)]

	_draw_plot()

func _draw_plot():
	plot.clear_series()

	if current_points.is_empty(): return

	# 1. Prepare Data
	# NacaGenerator returns Array[Vector2], so we can pass them directly.
	var upper_pts: Array = current_points.upper
	var lower_pts: Array = current_points.lower

	# 2. Closure Line (Visual line at the Trailing Edge)
	var closure_pts: Array[Vector2] = []
	if not upper_pts.is_empty() and not lower_pts.is_empty():
		closure_pts.append(upper_pts.back())
		closure_pts.append(lower_pts.back())

	# 3. Add Series to SimpleChart
	plot.add_series("Upper", upper_pts, Color.GREEN, 2.0)
	plot.add_series("Lower", lower_pts, Color.YELLOW, 2.0)

	# Only draw closure if there is a gap (TE thickness > 0)
	if spin_te.value > 0.0:
		plot.add_series("Closure", closure_pts, Color.WHITE, 2.0)

func _on_save_pressed():
	if current_points.is_empty(): return

	var fname = input_name.text.strip_edges()
	if fname.is_empty():
		# Fallback to placeholder if user didn't type anything
		fname = input_name.placeholder_text.strip_edges()

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
	file.store_line(fname.get_basename())

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
