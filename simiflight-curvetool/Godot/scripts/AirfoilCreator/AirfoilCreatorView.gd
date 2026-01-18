class_name AirfoilCreatorView extends Control

signal airfoil_saved(filename: String)

# --- UI References ---
@onready var spin_pt: SpinBox = %NumPointsSpinBox
@onready var input_name: LineEdit = %FileNameLineEdit
@onready var lbl_status: Label = %StatusLabel
@onready var plot: SimpleChart = %PlotGeometry
@onready var btn_save: Button = %BtnSave

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
	if OS.has_feature("web"):
		btn_save.disabled = true
		btn_save.text = "Save Airfoil (Desktop Only)"
	if OS.has_feature("release"):
		%AirfoilGeneratorFoldable.folded = false

func _init_ui():
	# Populate Option Buttons
	opt_shape.clear()
	opt_shape.add_item("NACA 4-Digit-Series", AirfoilGenerators.Family.NACA_4_DIGIT)
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
	btn_save.pressed.connect(_on_save_pressed)

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

func _generate():
	var selected_family = opt_shape.get_selected_id()

	# 1. Update UI Editable States
	var config = AirfoilGenerators.get_ui_config(selected_family)

	spin_m.editable = config.get("m", true)
	spin_p.editable = config.get("p", true)
	spin_t.editable = config.get("t", true)
	spin_le.editable = config.get("le", true)
	spin_te.editable = config.get("te", true)
	spin_exp.editable = config.get("exp", true)

	# Enable/Disable the Camber Dropdown
	opt_camber.disabled = not config.get("camber_mode", true)
	# 2. Gather Parameters
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

	# 3. Generate
	current_points = AirfoilGenerators.generate(selected_family, params)

	# 4. Auto-Name
	var auto_name = _get_auto_name(selected_family, params)
	input_name.placeholder_text = auto_name

	_draw_plot()

func _draw_plot():
	plot.clear_series()
	if current_points.is_empty(): return

	var upper_pts: Array[Vector2]
	var lower_pts: Array[Vector2]

	for p in current_points.upper:
		upper_pts.append(p)
	for p in current_points.lower:
		lower_pts.append(p)

	var up = ChartSeries.new(); up.name = "Upper"; up.points = upper_pts; up.color = Color.WEB_GREEN
	var lo = ChartSeries.new(); lo.name = "Lower"; lo.points = lower_pts; lo.color = Color.YELLOW_GREEN
	plot.add_series_resource(up)
	plot.add_series_resource(lo)

func _get_auto_name(family: int, params: Dictionary) -> String:
	var name_parts = []

	# --- 1. Base Values (Percentages) ---
	var m_int = int(params.m * 100.0)      # Camber %
	var p_int = int(params.p * 10.0)       # Position / 10
	var t_int = int(params.t * 100.0)      # Thickness %

	# --- 2. Family Specific Naming ---
	match family:
		AirfoilGenerators.Family.NACA_4_DIGIT:
			# Format: NACA XXXX
			# If Camber is 0, Position is irrelevant, conventionally '0'
			if m_int == 0: p_int = 0

			# %02d ensures thickness 9% becomes '09' -> "0009"
			var code = "NACA_%d%d%02d" % [m_int, p_int, t_int]
			name_parts.append(code)

			# Append Nose Modifier if significant
			# epsilon comparison because floats are rarely exactly 1.0
			if not is_equal_approx(params.le_mult, 1.0):
				# e.g. "_LE0.5" or "_LE2.0"
				name_parts.append("LE" + str(params.le_mult).pad_decimals(1))

		AirfoilGenerators.Family.JOUKOWSKI:
			# JavaFoil Style: Jouk f=2% t=12% -> File safe: JOUK_t12_f2
			name_parts.append("JOUK")
			name_parts.append("t%d" % t_int)
			name_parts.append("f%d" % m_int)

		AirfoilGenerators.Family.SUPER_SHAPE:
			# Detect specific shapes for readability
			var e = params.shape_exp
			var shape_name = "e" + str(e).pad_decimals(1) # Default: e2.5

			if is_equal_approx(e, 2.0): shape_name = "OVAL"
			elif is_equal_approx(e, 1.0): shape_name = "DIAMOND"
			elif is_equal_approx(e, 10.0): shape_name = "BOX"
			elif e > 15.0: shape_name = "RECT"

			name_parts.append("SHP_" + shape_name)
			name_parts.append("t%d" % t_int)
			# Only show camber if it exists
			if m_int > 0:
				name_parts.append("m%d" % m_int)

		AirfoilGenerators.Family.FLAT_PLATE:
			name_parts.append("PLATE")
			name_parts.append("t%d" % t_int)
			name_parts.append("m%d" % m_int)

	# --- 3. Global Modifiers ---

	# Camber Type (Reflex/Sine) - Skip for Joukowski/NACA Standard
	# We only tag if it's NOT standard (and if the generator supports it)
	if family != AirfoilGenerators.Family.JOUKOWSKI:
		if params.camber_type == AirfoilGenerators.CamberType.REFLEX:
			name_parts.append("REFLEX") # or REF
		elif params.camber_type == AirfoilGenerators.CamberType.SMOOTH_SINE:
			name_parts.append("SINE")

	# Trailing Edge Thickness (if significant)
	if params.te_thick > 0.001:
		# e.g. TE1
		name_parts.append("TE" + str(int(params.te_thick * 100)))

	# Mirror (Inverted)
	if params.mirror_y:
		# Prepend to front is usually better for sorting "INV_NACA..."
		name_parts.push_front("INV")

	# --- 4. Assemble ---
	# Join with underscores for file safety (JavaFoil uses spaces, but Godot prefers _)
	return "_".join(name_parts)

func _on_save_pressed():
	if current_points.is_empty(): return
	var fname = input_name.text.strip_edges()
	if fname.is_empty(): fname = input_name.placeholder_text.strip_edges()
	if not fname.ends_with(".dat"): fname += ".dat"

	# Use the helper to get the safe path
	var directory = FileSystemHandler.get_user_airfoil_dir()
	var path = directory.path_join(fname)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		lbl_status.text = "Error writing file."
		return

	file.store_line(fname.get_basename())
	# --- GENERATE METADATA ---
	var meta = {
		"family": opt_shape.get_selected_id(),
		"camber_type": opt_camber.get_selected_id(),
		"design_m": spin_m.value / 100.0,
		"design_p": spin_p.value / 10.0,
		"design_t": spin_t.value / 100.0,
		"le_mult": spin_le.value,
		"te_thick": spin_te.value / 100.0,
		"shape_exp": spin_exp.value,
		"is_inverted": check_mirror.button_pressed
	}
	file.store_line("#META: " + JSON.stringify(meta))
	# Write Upper (Tail to Nose)
	file.store_line("upper")
	var up = current_points.upper.duplicate()
	up.reverse()
	for pt in up: file.store_line("%.6f   %.6f" % [pt.x, pt.y])

	# Write Lower (Nose to Tail)
	file.store_line("lower")
	for i in range(0, current_points.lower.size()):
		var pt = current_points.lower[i]
		file.store_line("%.6f   %.6f" % [pt.x, pt.y])

	file.close()
	lbl_status.text = "Saved to Documents: " + fname
	airfoil_saved.emit(path)
