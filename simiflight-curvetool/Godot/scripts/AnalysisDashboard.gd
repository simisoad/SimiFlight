class_name AnalysisDashboard extends Control

# --- Dependencies ---
@onready var settings_panel: GeneratorSettingsPanel = %LeftPanel
@onready var sim_panel: SimInputPanel = %SimulationControls
@onready var chart_2d: SimpleChart = %Chart2D
@onready var chart_polar: SimpleChart = %ChartPolar
@onready var raw_data_tree: Tree = %RawDataTree

@onready var force_vis: ForceVisualizer = %ForceVisualizer
@onready var geo_view: SimpleChart = %GeometryPreview

# --- UI Toggles (Center Panel) ---
@onready var btn_show_cl: Button = %ShowCl
@onready var btn_show_cd: Button = %ShowCd
@onready var btn_show_cm: Button = %ShowCm
@onready var btn_show_stall: Button = %ShowStall
@onready var btn_show_snapshot: Button = %ShowSnapshot
@onready var btn_show_ref: Button = %ShowRef
@onready var btn_snapshot: Button = %BtnSnapshot

# ... UI References for Polar Toolbar ...
@onready var btn_polar_show_curve: Button = %PolarShowCurve
@onready var btn_polar_show_glide: Button = %PolarShowGlide
@onready var btn_polar_show_sink: Button = %PolarShowSink


@onready var check_auto_scale: CheckBox = %CheckAutoScale
@onready var check_wind_anim: CheckBox = %CheckWindAnim

var cached_sweep_results: Dictionary = {}
var ghost_results: Dictionary = {}
# UI References
@onready var btn_export_xfoil: Button = %BtnExportXFoil
@onready var btn_export_csv: Button = %BtnExportCSV
@onready var file_dialog: FileDialog = %SaveFileDialog
# Finite Wing
@onready var check_finite: CheckBox = %ShowFiniteWing
@onready var input_ar: SpinBox = %InputAR
@onready var input_eff: SpinBox = %InputEff
@onready var input_taper: SpinBox = %InputTaper
@onready var input_sweep: SpinBox = %InputSweep
@onready var input_sweep_location: SpinBox = %InputSweepLocation

@onready var wing_visualizer: WingPlanformView = %WingPlanformView


# --- State ---
var current_profile: AirfoilProfile
var ref_points_naca0012: Array[Vector2] = []

# Constants for Series Names and Current Names
const S_CL = "Lift (Cl)"
var current_s_cl_name: String = ""
const S_CL_SNAP = "Lift (Cl) Snapshot: "
const S_CD = "Drag (Cd)"
const S_CM = "Moment (Cm)"
const S_STALL = "Stall"
const S_REF = "Ref (NACA0012)"
const S_POLAR_CURVE = "Polar Curve"
const M_BEST_GLIDE = "Max Range (Best Glide)"
const M_MIN_SINK = "Max Endurance (Min Sink)"

func _ready() -> void:
	_check_if_developer()
	btn_show_snapshot.disabled = true
	_generate_naca0012_ref_data()
	_connections()
	_setup_analysis_curve()
	_setup_polar()

	if settings_panel.opt_profile.item_count > 0:
		settings_panel.opt_profile.select(0)
		settings_panel.on_profile_selected(0)

	if OS.has_feature("web"):
		btn_export_csv.disabled = true
		btn_export_csv.tooltip_text = "Available in Desktop Version"

		btn_export_xfoil.disabled = true
		btn_export_xfoil.tooltip_text = "Available in Desktop Version"

func _check_if_developer() -> void:
	if OS.has_feature("release"):
		%SimulationControlsFoldable.folded = false
		%ConfigSettingsFoldable.folded = false
		#%ToggleExpertSettings.button_pressed = false
		%ExpertSettingsScrollContainer.visible = false
		for child in %ExpertSettings.get_children(true):
			print("child: ", child)
			if child is FoldableContainer:
				var fold_child: FoldableContainer = child
				fold_child.fold()
		%CenterPanelTabContainer.current_tab = 0
	else:
		print("Running from the editor.")
func _connections() -> void:
	# 1. Connections
	settings_panel.profile_loaded.connect(_on_profile_loaded)
	settings_panel.config_updated.connect(func(_cfg): _refresh_all())
	sim_panel.parameters_changed.connect(_on_sim_params_changed)

	# 1. Connect Auto Scale
	# Initialize with current checkbox state
	force_vis.set_auto_scale(check_auto_scale.button_pressed)
	# Connect signal
	check_auto_scale.toggled.connect(force_vis.set_auto_scale)

	# 2. Connect Animation
	# Initialize
	force_vis.set_wind_animation(check_wind_anim.button_pressed)
	# Connect signal
	check_wind_anim.toggled.connect(force_vis.set_wind_animation)

	# 1. Connect CSV Button
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)

	btn_export_csv.pressed.connect(func():
		file_dialog.filters = ["*.csv ; CSV Data"]
		file_dialog.current_file = current_profile.name + "_lut.csv"
		file_dialog.popup_centered_ratio(0.6)
	)

	# 2. Connect XFoil Button
	btn_export_xfoil.pressed.connect(func():
		file_dialog.filters = ["*.pol ; XFoil Polar"]
		file_dialog.current_file = current_profile.name + "_xfoil.pol"
		file_dialog.popup_centered_ratio(0.6)
	)
	file_dialog.file_selected.connect(_on_save_csv_confirmed)
	# Finite Wing Connections
	check_finite.toggled.connect(func(_v): _refresh_all())
	input_ar.value_changed.connect(func(_v): _refresh_all(); _recalc_estimate_oswald())
	input_sweep.value_changed.connect(func(_v): _refresh_all(); _recalc_estimate_oswald())
	input_taper.value_changed.connect(func(_v): _refresh_all(); _recalc_estimate_oswald())
	input_sweep_location.value_changed.connect(func(_v): _refresh_all(); _recalc_estimate_oswald())
	input_eff.value_changed.connect(func(_v): _refresh_all())
	input_eff.emit_signal(&"changed")
	_recalc_estimate_oswald() # initialise
	btn_snapshot.pressed.connect(_on_snapshot_pressed)

func _setup_analysis_curve() -> void:
	# Toggle Logic
	# We use 'unbind(1)' because the toggled signal sends a bool,
	# but set_series_visible needs name + bool.
	btn_show_cl.toggled.connect(func(v): chart_2d.set_series_visible(S_CL, v))
	btn_show_snapshot.toggled.connect(func(v): chart_2d.set_series_visible(S_CL_SNAP+current_s_cl_name, v))
	btn_show_cd.toggled.connect(func(v): chart_2d.set_series_visible(S_CD, v))
	btn_show_cm.toggled.connect(func(v): chart_2d.set_series_visible(S_CM, v))
	btn_show_stall.toggled.connect(func(v): chart_2d.set_series_visible(S_STALL, v))
	btn_show_ref.toggled.connect(func(v): chart_2d.set_series_visible(S_REF, v))

	# Set Button Colors (Optional style helper)
	_colorize_button(btn_show_cl, Color.CYAN)
	_colorize_button(btn_show_snapshot, Color(0.0, 0.5, 0.5, 0.5))
	_colorize_button(btn_show_cd, Color.RED)
	_colorize_button(btn_show_cm, Color.GREEN)
	_colorize_button(btn_show_stall, Color.DARK_VIOLET)

func _setup_polar() -> void:
	btn_polar_show_curve.toggled.connect(func(v): chart_polar.set_series_visible(S_POLAR_CURVE, v))
	btn_polar_show_glide.toggled.connect(func(v): chart_polar.set_marker_visible(M_BEST_GLIDE, v))
	btn_polar_show_sink.toggled.connect(func(v): chart_polar.set_marker_visible(M_MIN_SINK, v))

	# Style
	_colorize_button(btn_polar_show_curve, Color.ORANGE)
	_colorize_button(btn_polar_show_glide, Color.GOLD)
	_colorize_button(btn_polar_show_sink, Color.CORNFLOWER_BLUE)


func _on_sim_params_changed(alpha: float, mach: float, re: float, speed: float, dens: float, area: float, start_deg: float, end_deg: float):
	# 1. Update Global Config for Sweep Range
	# Note: If these statics are used elsewhere, this keeps them in sync.
	LutGenerator.preview_alpha_start_deg = start_deg
	LutGenerator.preview_alpha_end_deg = end_deg

	# 2. Update Generator Config with current Mach/Re
	# This ensures the Chart uses the same physics as the visualizer
	var config = settings_panel.get_current_config()
	config.preview_mach = mach
	config.preview_re = re

	# 3. Recalculate EVERYTHING
	_update_charts(config)
	_update_live_point(alpha, mach, re, speed, dens, area, config)
	force_vis.set_profile_geometry(current_profile)

func _refresh_all():
	# Manually trigger an update using current Sim Panel values
	sim_panel._emit_change()

func _update_charts(config: LutGenerator.GeneratorConfig):
	if not current_profile: return

	# 1. 2D Calculation (Standard)
	var res = LutGenerator.calculate_preview_curve(current_profile, config)
	cached_sweep_results = res
	_update_raw_data_tab(cached_sweep_results)
	# 2. 3D Calculation (Finite Wing)
	var show_3d = check_finite.button_pressed
	var pts_cl_3d: Array[Vector2] = []
	var pts_cd_3d: Array[Vector2] = []
	var pts_polar_3d: Array[Vector2] = []

	if show_3d:
		var ar: float = input_ar.value
		var eff: float = input_eff.value

		var	sweep: float = input_sweep.value
		for i in range(res.cl.size()):
			var alpha = res.cl[i].x
			var cl_2d = res.cl[i].y
			var cd_2d = res.cd[i].y

			var res_3d = AeroPhysicsModel.calculate_finite_wing(cl_2d, cd_2d, ar, eff, sweep, input_taper.value, 0.0)

			pts_cl_3d.append(Vector2(alpha, res_3d.cl))
			pts_cd_3d.append(Vector2(alpha, res_3d.cd))
			pts_polar_3d.append(Vector2(res_3d.cd, res_3d.cl))

	# 3. Draw 2D Chart
	chart_2d.clear_series()

	if not ghost_results.is_empty():
		chart_2d.add_series(S_CL_SNAP + current_s_cl_name, ghost_results.cl, Color(0.0, 0.5, 0.5, 0.5), 2.0, btn_show_snapshot.button_pressed)
	chart_2d.add_series(S_CL, res.cl, Color.CYAN, 2.0, btn_show_cl.button_pressed)
	chart_2d.add_series(S_CD, res.cd, Color.RED, 2.0, btn_show_cd.button_pressed)
	chart_2d.add_series(S_CM, res.cm, Color.GREEN, 2.0, btn_show_cm.button_pressed)
	chart_2d.add_series(S_STALL, res.sigma, Color.DARK_VIOLET, 2.0, btn_show_stall.button_pressed)
	chart_2d.add_series(S_REF, ref_points_naca0012, Color(1, 1, 1, 0.3), 1.0, btn_show_ref.button_pressed)

	if show_3d:
		# Draw 3D lines as Dashed or Faint
		chart_2d.add_series("Cl (3D)", pts_cl_3d, Color(0, 1, 1, 0.5), 1.5) # Faint Cyan
		chart_2d.add_series("Cd (3D)", pts_cd_3d, Color(1, 0, 0, 0.5), 1.5) # Faint Red

	# 4. POLAR CALCULATION
	chart_polar.clear_series()
	chart_polar.clear_markers()


	var polar_pts: Array[Vector2] = []

	# Variables to track maxima
	var max_ld_ratio: float = -1.0
	var max_endurance_factor: float = -1.0 # Cl^1.5 / Cd

	var pt_best_glide: Vector2 = Vector2.ZERO
	var pt_min_sink: Vector2 = Vector2.ZERO

	var alpha_best_glide: float = 0.0
	var alpha_min_sink: float = 0.0

	for i in range(res.cl.size()):
		var cl = res.cl[i].y
		var cd = res.cd[i].y
		var alpha = res.cl[i].x

		polar_pts.append(Vector2(cd, cl))

		# Only check for efficiency in positive lift (flying upright)
		# and ignore Drag = 0 (divide by zero protection)
		if cl > 0.1 and cd > 0.0001:
			# 1. Max Range (Best Glide) = Max Cl/Cd
			var ld = cl / cd
			if ld > max_ld_ratio:
				max_ld_ratio = ld
				pt_best_glide = Vector2(cd, cl)
				alpha_best_glide = alpha

			# 2. Max Endurance (Min Sink) = Max Cl^1.5 / Cd
			var endurance = pow(cl, 1.5) / cd
			if endurance > max_endurance_factor:
				max_endurance_factor = endurance
				pt_min_sink = Vector2(cd, cl)
				alpha_min_sink = alpha

	# 3. Draw Curve
	chart_polar.add_series(S_POLAR_CURVE, polar_pts, Color.ORANGE, 2.0, btn_polar_show_curve.button_pressed)

	# 4. Draw Special Markers
	# Best Glide (Gold)
	chart_polar.add_marker(M_BEST_GLIDE, pt_best_glide, 6.0, Color.GOLD, 0.0, true, btn_polar_show_glide.button_pressed)

	# Min Sink (Blue)
	chart_polar.add_marker(M_MIN_SINK, pt_min_sink, 6.0, Color.CORNFLOWER_BLUE, 0.0, true, btn_polar_show_sink.button_pressed)

	if show_3d:
		chart_polar.add_series("Polar (3D)", pts_polar_3d, Color(1, 0.65, 0, 0.5), 1.5) # Faint Orange
	# 5. Add Live Marker (White Hollow)
	# (Re-added in _update_live_point, but good to have context here)
	%BestGlide.text = str("Best Glide at Alpha: %.1f (L/D: %.1f), Min Sink: %.1f" % [alpha_best_glide, max_ld_ratio, alpha_min_sink])
	_update_raw_data_tab(res)

func _update_live_point(alpha: float, mach: float, re: float, speed: float, dens: float, area: float, config: LutGenerator.GeneratorConfig):
	if not current_profile: return

	# Single Point Physics
	var geo = AirfoilGeometryAnalyzer.analyze(current_profile)
	var coeffs = AeroPhysicsModel.compute_coefficients(deg_to_rad(alpha), geo.alpha_0, geo, mach, re, config)

	# Forces
	var q = 0.5 * dens * pow(speed, 2)
	var forces = {
		"lift": coeffs.cl * q * area,
		"drag": coeffs.cd * q * area,
		"moment": coeffs.cm * q * area
	}

	force_vis.update_visuals(alpha, coeffs, forces, speed)
	_ld_ratio(coeffs, alpha)
	# Markers
	chart_2d.clear_markers()
	chart_2d.add_marker("Live", Vector2(alpha, coeffs.cl), 5.0, Color.WHITE, 2.0, false)
	#chart_polar.clear_markers()
	chart_polar.add_marker("Live", Vector2(coeffs.cd, coeffs.cl), 5.0, Color.WHITE, 2.0, false)

func _ld_ratio(coeffs: Dictionary, alpha: float)-> void:
	var ld_ratio = 0.0
	if coeffs.cd != 0.0:
		ld_ratio = coeffs.cl / coeffs.cd
	%ld_ratio.text = "Alpha: %.1f° Cl: %.3f Cd: %.4f L/D: %.1f" % [alpha, coeffs.cl, coeffs.cd, ld_ratio]

func _update_raw_data_tab(results: Dictionary):
	raw_data_tree.clear()

	# Setup Root
	var root = raw_data_tree.create_item()

	# Setup Headers
	raw_data_tree.set_column_title(0, "Alpha (°)")
	raw_data_tree.set_column_title(1, "Cl")
	raw_data_tree.set_column_title(2, "Cd")
	raw_data_tree.set_column_title(3, "Cm")
	raw_data_tree.set_column_title(4, "L/D")

	# Populate Rows
	# We iterate through the results
	for i in range(results.cl.size()):
		var alpha = results.cl[i].x
		var cl = results.cl[i].y
		var cd = results.cd[i].y
		var cm = results.cm[i].y

		var item: TreeItem = raw_data_tree.create_item(root)
		for column in raw_data_tree.columns:
			item.set_text_alignment(column,HORIZONTAL_ALIGNMENT_CENTER)
		# Column 0: Alpha
		item.set_text(0, "%.1f" % alpha)

		# Column 1-3: Coefficients
		item.set_text(1, "%.4f" % cl)
		item.set_text(2, "%.5f" % cd)
		item.set_text(3, "%.4f" % cm)

		# Column 4: L/D (Protect div by zero)
		var ld = "--"
		if abs(cd) > 0.0001:
			ld = "%.1f" % (cl / cd)
		item.set_text(4, ld)

		# Optional: Coloring rows based on stall
		var sigma = results.sigma[i].y
		if sigma < 0.5: # Stalled
			for col in range(5):
				item.set_custom_color(col, Color(0.7, 0.3, 0.3)) # Red tint
		elif abs(alpha) < 0.1: # Zero
			for col in range(5):
				item.set_custom_bg_color(col, Color(1, 1, 1, 0.1)) # Highlight zero

func _on_profile_loaded(profile: AirfoilProfile):
	current_profile = profile
	geo_view.clear_series()
	geo_view.add_series("Upper", current_profile.upper_surface, Color.WEB_GREEN, 2.0)
	geo_view.add_series("Lower", current_profile.lower_surface, Color.YELLOW_GREEN, 2.0)
	_refresh_all()

func _generate_naca0012_ref_data():
	var NACA632012 = NACA632012LiftCurve.new()
	ref_points_naca0012 = NACA632012.NACA0012_WINDTUNNEL

func _colorize_button(btn: Button, col: Color):
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_pressed_color", col)
	btn.add_theme_color_override("font_hover_color", col)
func _on_save_csv_confirmed(path: String):
	if cached_sweep_results.is_empty(): return
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Could not open file for writing: " + path)
		return
	if path.ends_with(".csv"):
		_save_csv(file,path)
	elif path.ends_with(".pol") or path.ends_with(".txt"):
		_save_xfoil(file, path)

func _save_xfoil(file: FileAccess, path: String):
	var mach = sim_panel.input_mach.value
	var re = sim_panel.input_re.value
	var version: String = ProjectSettings.get_setting("application/config/version")
	file.store_line("SimiFoil v"+version)
	file.store_line("")
	# --- XFLR5 / Standard XFoil Header ---
	# Line 1: Header title
	file.store_line(" Calculated polar for: %s" % current_profile.name)
	file.store_line("")

	# Line 3: Method description (Dummy values to satisfy parser)
	file.store_line(" 1 1 Reynolds number fixed Mach number fixed")
	file.store_line("")

	# Line 5: Transition factors (Dummy 1.0)
	file.store_line(" xtrf =   1.000 (top)        1.000 (bottom)")

	# Line 6: Parameters (Formatted strictly)
	# Note: We convert Re to Millions (e.g. 0.100 e 6) because XFLR5 expects it.
	var re_millions = re / 1000000.0

	file.store_line(" Mach =   %.3f     Re =     %.3f e 6     Ncrit =   15.850" % [mach, re_millions])

	file.store_line("")

	# Column Headers (Space aligned)
	file.store_line("  alpha    CL        CD       CDp       CM      Top_Xtr  Bot_Xtr")
	file.store_line(" ------ -------- --------- --------- -------- -------- --------")

	# --- Data Rows ---
	var cl_size = cached_sweep_results.cl.size()
	for i in range(cl_size):
		var alpha = cached_sweep_results.cl[i].x
		var cl = cached_sweep_results.cl[i].y
		var cd = cached_sweep_results.cd[i].y
		var cm = cached_sweep_results.cm[i].y

		# Dummy values
		var cdp = 0.0000
		var xtr = 1.0000

		# Strict Fixed-Width Formatting
		var line = "%7.3f  %8.4f  %9.5f  %9.5f  %8.4f  %7.4f  %7.4f" % [
			alpha, cl, cd, cdp, cm, xtr, xtr
		]
		file.store_line(line)

	file.close()
	print("XFoil Polar Saved to: " + path)


func _save_csv(file: FileAccess, path: String) -> void:
	# 1. Write Header Info
	file.store_line("# Airfoil: %s" % current_profile.name)
	file.store_line("# Settings: StallFwd=%.1f StallBwd=%.1f Mach=%.2f Re=%.0f" % [
		settings_panel.input_stall_fwd.value,
		settings_panel.input_stall_bwd.value,
		sim_panel.input_mach.value,
		sim_panel.input_re.value
	])
	file.store_line("") # Empty line

	# 2. Write CSV Columns
	# Using ; or , depends on region, but , is standard for "CSV"
	file.store_line("Alpha (deg), Cl, Cd, Cm, L/D, Stall_Sigma")

	var cl_size = cached_sweep_results.cl.size()
	for i in range(cl_size):
		var alpha = cached_sweep_results.cl[i].x
		var cl = cached_sweep_results.cl[i].y
		var cd = cached_sweep_results.cd[i].y
		var cm = cached_sweep_results.cm[i].y
		var sigma = cached_sweep_results.sigma[i].y

		var ld = 0.0
		if abs(cd) > 0.00001:
			ld = cl / cd

		# Format string
		var line = "%.2f, %.6f, %.6f, %.6f, %.2f, %.2f" % [alpha, cl, cd, cm, ld, sigma]
		file.store_line(line)

	file.close()
	print("CSV Saved to: " + path)

func _on_snapshot_pressed():
	btn_show_snapshot.disabled = false
	current_s_cl_name = current_profile.name
	# Copy current results to ghost
	ghost_results = cached_sweep_results.duplicate(true)
	_refresh_all() # Trigger redraw

func _recalc_estimate_oswald() -> void:
	var estimated_e: float = AeroPhysicsModel.estimate_oswald(input_ar.value, input_taper.value, input_sweep.value)
	print("estimated_e: ", estimated_e)
	input_eff.value = estimated_e
	wing_visualizer.update_geometry(input_ar.value, input_taper.value, input_sweep.value, input_sweep_location.value)
