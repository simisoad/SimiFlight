class_name AirfoilCreatorView extends HSplitContainer

signal airfoil_saved(filename: String)

# --- UI References ---
@onready var spin_pt: SpinBox = %NumPointsSpinBox
@onready var input_name: LineEdit = %FileNameLineEdit
@onready var lbl_status: Label = %StatusLabel
@onready var plot: SimpleChart = %PlotGeometry

# --- Parameters UI ---
@onready var spin_m: SpinBox = %CamberSpinBox       # Camber %
@onready var spin_p: SpinBox = %PositionSpinBox     # Camber Pos
@onready var spin_t: SpinBox = %ThicknessSpinbox    # Thickness %
@onready var spin_le: SpinBox = %SpinNoseRadius     # LE Mult
@onready var spin_te: SpinBox = %SpinTEThick        # TE Thickness

# Assuming you add them to the VBoxContainer where the other sliders are.
@onready var opt_shape: OptionButton = %OptionShapeMode   # [NACA, SuperShape]
@onready var opt_camber: OptionButton = %OptionCamberMode # [Standard, Smooth, Reflex]
@onready var spin_exp: SpinBox = %SpinShapeExp            # Exponent for SuperShape
@onready var check_mirror: CheckBox = %CheckMirrorY       # Mirror Y

# --- State ---
var current_points: Dictionary = {}

func _ready():
	_init_ui()
	_init_plot()
	_generate()

func _init_ui():
	# Populate Option Buttons
	opt_shape.clear()
	opt_shape.add_item("NACA 4-Series", AirfoilGenerators.Family.NACA_4_DIGIT)
	opt_shape.add_item("Joukowski (Organic)", AirfoilGenerators.Family.JOUKOWSKI)
	opt_shape.add_item("Super-Shape (Geo)", AirfoilGenerators.Family.SUPER_SHAPE)
	opt_shape.add_item("Flat Plate", AirfoilGenerators.Family.FLAT_PLATE)

	# --- Setup Camber Types ---
	opt_camber.clear()
	opt_camber.add_item("Standard (Parabolic)", AirfoilGenerators.CamberType.STANDARD)
	opt_camber.add_item("Smooth (Sine Arc)", AirfoilGenerators.CamberType.SMOOTH_SINE)
	opt_camber.add_item("Reflex (Flying Wing)", AirfoilGenerators.CamberType.REFLEX)

	# Connect Signals
	var params = [spin_m, spin_p, spin_t, spin_le, spin_te, spin_pt, spin_exp]
	for s in params:
		s.value_changed.connect(func(_v): _generate())

	opt_shape.item_selected.connect(func(_i):  _generate()) #_update_visibility();
	opt_camber.item_selected.connect(func(_i): _generate())
	check_mirror.toggled.connect(func(_b): _generate())
	%SaveBtn.pressed.connect(_on_save_pressed)

	# Set Default Values
	spin_m.value = 2.0
	spin_p.value = 4.0
	spin_t.value = 12.0
	spin_le.value = 1.0
	spin_te.value = 0.0
	spin_exp.value = 2.0 # Circle default

	#_update_visibility()

func _init_plot():
	plot.set_domain(-0.1, 1.1, -0.4, 0.4)

#func _update_visibility():
	## Hide/Show controls based on mode
	#var mode = opt_shape.get_selected_id()
#
	## "Shape Exponent" is only useful for SuperShape
	##spin_exp.editable = (mode == AirfoilGenerators.ThicknessType.SUPER_SHAPE)
##
	### "Nose Sharpness" (LE Mult) is only useful for NACA
	##spin_le.editable = (mode == AirfoilGenerators.ThicknessType.NACA_4_DIGIT)

func _generate():
	var selected_family = opt_shape.get_selected_id()

	# 0. Update UI Editable States
	var config = AirfoilGenerators.get_ui_config(selected_family)

	spin_m.editable = config.get("m", true)
	spin_p.editable = config.get("p", true)
	spin_t.editable = config.get("t", true)
	spin_le.editable = config.get("le", true)
	spin_te.editable = config.get("te", true)
	spin_exp.editable = config.get("exp", true)

	# Enable/Disable the Camber Dropdown
	opt_camber.disabled = not config.get("camber_mode", true)
	# 1. Gather Parameters
	var params = {
		"num_points": int(spin_pt.value),
		"m": spin_m.value / 100.0,
		"p": spin_p.value / 10.0,
		"t": spin_t.value / 100.0,
		"le_mult": spin_le.value,
		"te_thick": spin_te.value / 100.0,
		"thick_type": opt_shape.get_selected_id(),
		"camber_type": opt_camber.get_selected_id(),
		"shape_exp": spin_exp.value,
		"mirror_y": check_mirror.button_pressed
	}

	# 2. Generate
	current_points = AirfoilGenerators.generate(selected_family, params)

	# 3. Auto-Name
	var type_str = "UNK"
	match selected_family:
		AirfoilGenerators.Family.NACA_4_DIGIT: type_str = "NACA"
		AirfoilGenerators.Family.JOUKOWSKI: type_str = "JOUK"
		AirfoilGenerators.Family.SUPER_SHAPE: type_str = "SHP"
		AirfoilGenerators.Family.FLAT_PLATE: type_str = "PLAT"

	var mod_str = "INV_" if params.mirror_y else ""

	if params.mirror_y: mod_str += "INV_"
	if params.camber_type == AirfoilGenerators.CamberType.REFLEX: mod_str += "REF_"
	var camber_pos_string_size: float = 1.0
	if int(spin_t.value) < 10:
		camber_pos_string_size = 10.0
	var camber_string: String = str(int(spin_m.value))
	var camber_pos_string: String = str(int(spin_p.value*camber_pos_string_size))
	var thickness_string: String = str(int(spin_t.value))
	input_name.placeholder_text = "%s%s-%s%s%s" % [mod_str, type_str, camber_string,camber_pos_string, thickness_string]

	_draw_plot()

func _draw_plot():
	plot.clear_series()
	if current_points.is_empty(): return

	var upper_pts: Array = current_points.upper
	var lower_pts: Array = current_points.lower

	# Calculate closure line
	var closure_pts: Array[Vector2] = []
	if not upper_pts.is_empty():
		closure_pts.append(upper_pts.back())
		closure_pts.append(lower_pts.back())

	plot.add_series("Upper", upper_pts, Color.GREEN, 2.0)
	plot.add_series("Lower", lower_pts, Color.YELLOW, 2.0)

	# Draw closure if TE is thick
	if spin_te.value > 0.0 or abs(upper_pts.back().y - lower_pts.back().y) > 0.001:
		plot.add_series("Closure", closure_pts, Color.WHITE, 2.0)

func _on_save_pressed():
	# (Keep your existing save logic here, it was fine)
	if current_points.is_empty(): return
	var fname = input_name.text.strip_edges()
	if fname.is_empty(): fname = input_name.placeholder_text.strip_edges()
	if not fname.ends_with(".dat"): fname += ".dat"

	var path = "res://data/airfoils/" + fname
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		lbl_status.text = "Error writing file."
		return

	file.store_line(fname.get_basename())

	# Write Upper (Tail to Nose)
	var up = current_points.upper.duplicate()
	up.reverse()
	for pt in up: file.store_line("%.6f   %.6f" % [pt.x, pt.y])

	# Write Lower (Nose to Tail)
	for i in range(1, current_points.lower.size()):
		var pt = current_points.lower[i]
		file.store_line("%.6f   %.6f" % [pt.x, pt.y])

	file.close()
	lbl_status.text = "Saved: " + fname
	airfoil_saved.emit(path)
