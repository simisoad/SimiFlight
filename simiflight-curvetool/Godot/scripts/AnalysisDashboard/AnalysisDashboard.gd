class_name AnalysisDashboard extends Control

# --- UI Dependencies ---
@onready var settings_panel: GeneratorSettingsPanel = %LeftPanel
@onready var sim_panel: SimInputPanel = %SimulationControls
@onready var chart_2d: SimpleChart = %Chart2D
@onready var chart_polar: SimpleChart = %ChartPolar
@onready var legend_list: VBoxContainer = %SeriesLegendList
@onready var wing_visualizer: WingPlanformView = %WingPlanformView
@onready var force_vis: ForceVisualizer = %ForceVisualizer
@onready var geo_view: SimpleChart = %GeometryPreview
@onready var file_dialog: FileDialog = %SaveFileDialog
@onready var tree_2d: Tree = %RawDataTree2D
@onready var tree_3d: Tree = %RawDataTree3D
@onready var aero_ray_visualizer: AeroRayVisualizer = %AeroRayVisualizer
@onready var best_glide: Label = %BestGlide
@onready var ld_ratio: Label = %ld_ratio

# --- Resources & State ---
var palette: AeroColorPalette = AeroColorPalette.new()
var current_profile: AirfoilProfile

# Data Sources (The raw physics results needed for Export)
var live_data_2d: AeroSeries
var live_data_3d: AeroSeries

# Managed Visual Series (The curves drawn on charts)
var managed_series: Array[ChartSeries] = []
var snapshots: Array[ChartSeries] = []
var ref_series: ChartSeries

# Constants for Categories
const CAT_2D = "2D ANALYSIS (ALPHA/COEFF)"
const CAT_POLAR = "POLAR ANALYSIS (CD/CL)"
const CAT_SNAPSHOTS = "SNAPSHOTS"

const SUB_BASE = "Airfoil (2D)"
const SUB_FINITE = "Finite Wing (3D)"

func _ready() -> void:
	_setup_reference_data()
	_connections()
	await self.get_tree().process_frame
	call_deferred("_initial_load")

func _initial_load() -> void:
	if settings_panel.opt_profile.item_count > 0:
		settings_panel.on_profile_selected(0)

func _connections() -> void:
	tree_2d.gui_input.connect(_on_tree_gui_input.bind(tree_2d))
	tree_3d.gui_input.connect(_on_tree_gui_input.bind(tree_3d))
	settings_panel.profile_loaded.connect(_on_profile_loaded)
	settings_panel.config_updated.connect(func(_cfg): _refresh_all())
	sim_panel.parameters_changed.connect(_on_sim_params_changed)

	%BtnExportCSV.pressed.connect(func(): _open_export_dialog("*.csv", "_lut.csv"))
	%BtnExportXFoil.pressed.connect(func(): _open_export_dialog("*.pol", "_xfoil.pol"))
	file_dialog.file_selected.connect(_on_export_confirmed)

# ==============================================================================
#  CORE UPDATE PIPELINE
# ==============================================================================

func _on_sim_params_changed(alpha, mach, re, speed, dens, area, start, end) -> void:
	if not current_profile: return
	var config = settings_panel.active_config
	config.preview_mach = mach; config.preview_re = re
	LutGenerator.preview_alpha_start_deg = start; LutGenerator.preview_alpha_end_deg = end

	_update_charts(config)
	_update_live_visuals(alpha, mach, re, speed, dens, area, config)

func _update_charts(config: LutGenerator.GeneratorConfig) -> void:
	if not current_profile: return

	# 1. Generate Raw Physics Data (Stored in class variables for Export access)
	var config_2d = config.clone()
	config_2d.is_finite_wing = false
	live_data_2d = LutGenerator.calculate_preview_series(current_profile, config_2d)

	live_data_3d = null
	if config.is_finite_wing or config.is_bet_mode:
		live_data_3d = LutGenerator.calculate_preview_series(current_profile, config)

	# 2. Sync Managed Series (Updates points/markers, preserves user settings)
	_sync_all_visual_series(live_data_2d, live_data_3d)

	# 3. Push to Charts
	chart_2d.clear_series()
	chart_polar.clear_series()
	chart_2d.add_series_resource(ref_series)

	# Route managed series based on TYPE, not Category
	for s in managed_series:
		if s.type == "POLAR": chart_polar.add_series_resource(s)
		else: chart_2d.add_series_resource(s)

	# Route snapshots based on TYPE, not Category
	for snap in snapshots:
		if snap.type == "POLAR": chart_polar.add_series_resource(snap)
		else: chart_2d.add_series_resource(snap)

	# 4. UI Updates
	_rebuild_legend_ui()
	wing_visualizer.update_geometry(config.aspect_ratio, config.taper, config.sweep_deg, config.sweep_location)

	_update_raw_data_tab(live_data_2d,live_data_3d)

	_update_stall_ui_sync(config)

func _sync_all_visual_series(source_2d: AeroSeries, source_3d: AeroSeries) -> void:
	var channels = ["CL", "CD", "CM", "Sigma"]

	# Update 2D Channels
	for id in channels:
		_update_alpha_data(CAT_2D, SUB_BASE, id, source_2d, 1.0)
	_update_polar_data(CAT_POLAR, SUB_BASE, source_2d, 1.0)

	# Update 3D Channels
	if source_3d:
		for id in channels:
			_update_alpha_data(CAT_2D, SUB_FINITE, id, source_3d, 0.6)
		_update_polar_data(CAT_POLAR, SUB_FINITE, source_3d, 0.6)
	else:
		# Cleanup: Remove 3D series from managed list if disabled
		var to_remove: Array[ChartSeries] = []
		for s in managed_series:
			if s.subcategory == SUB_FINITE: to_remove.append(s)
		for s in to_remove: managed_series.erase(s)

func _update_alpha_data(cat: String, sub: String, id: String, source: AeroSeries, alpha_mod: float) -> void:
	var s = _get_or_create_managed(cat, sub, id)
	s.type = "ALPHA"

	# --- STATE PRESERVATION ---
	# Find the "Pos" marker if it exists and remember its visibility
	var pos_visible: bool = true
	for m in s.markers:
		if m.name == "Pos":
			pos_visible = m.visible
			break

	s.name = current_profile.name + " " + id
	s.points = source.get_points_for_axes("alpha", id.to_lower())
	s.color.a = alpha_mod

	s.clear_markers()
	var live_res = _find_result_at_alpha(source, sim_panel.input_alpha.value)
	if live_res:
		var new_m = s.add_marker("Pos", live_res.alpha, live_res.get(id.to_lower()), Color.WHITE, false)
		new_m.visible = pos_visible # Re-apply the saved state

func _update_polar_data(cat: String, sub: String, source: AeroSeries, alpha_mod: float) -> void:
	var s = _get_or_create_managed(cat, sub, "POLAR")
	s.type = "POLAR" # Set the routing type

	# --- STATE PRESERVATION ---
	var states: Array[bool] = [true, true, true] # [Best Glide, Min Sink, Pos]
	for m in s.markers:
		if m.name == "Best Glide": states[0] = m.visible
		elif m.name == "Min Sink": states[1] = m.visible
		elif m.name == "Pos":       states[2] = m.visible

	s.name = current_profile.name + " Polar"
	s.points = source.get_points_for_axes("cd", "cl")
	s.color.a = alpha_mod

	s.clear_markers()
	var metrics = AeroPostProcessor.find_efficiency_markers(source)
	if metrics.best_glide:
		var m = s.add_marker("Best Glide", metrics.best_glide.cd, metrics.best_glide.cl, palette.best_glide)
		m.visible = states[0]
	if metrics.min_sink:
		var m = s.add_marker("Min Sink", metrics.min_sink.cd, metrics.min_sink.cl, palette.min_sink)
		m.visible = states[1]

	var live_res = _find_result_at_alpha(source, sim_panel.input_alpha.value)
	if live_res:
		var m = s.add_marker("Pos", live_res.cd, live_res.cl, Color.WHITE, false)
		m.visible = states[2]

	best_glide.text = "Best Glide Alpha: %.1f (L/D: %.1f)" % [
		metrics.best_glide.alpha if metrics.best_glide else 0.0,
		metrics.max_ld
	]
func _get_or_create_managed(cat: String, sub: String, id: String) -> ChartSeries:
	for s in managed_series:
		if s.category == cat and s.subcategory == sub and s.channel_id == id:
			return s

	var new_s = ChartSeries.new()
	new_s.category = cat
	new_s.subcategory = sub
	new_s.channel_id = id

	# Initial Color from Palette
	match id:
		"CL": new_s.color = palette.cl
		"CD": new_s.color = palette.cd
		"CM": new_s.color = palette.cm
		"Sigma": new_s.color = palette.sigma
		"POLAR": new_s.color = palette.polar

	managed_series.append(new_s)
	return new_s

# ==============================================================================
#  LEGEND UI
# ==============================================================================

func _rebuild_legend_ui() -> void:
	for child in legend_list.get_children(): child.queue_free()

	# 1. Reference
	_add_legend_header("REFERENCE DATA")
	_create_legend_item(ref_series)

	# 2. Categorized Managed Series
	var categories = [CAT_2D, CAT_POLAR, CAT_SNAPSHOTS]
	var subcategories = [SUB_BASE, SUB_FINITE]

	for cat in categories:
		var cat_items = _get_series_in_group(cat)
		if cat_items.is_empty(): continue

		_add_legend_header(cat)

		for sub in subcategories:
			var sub_items: Array[ChartSeries] = []
			for s in cat_items: if s.subcategory == sub: sub_items.append(s)

			if not sub_items.is_empty():
				_add_legend_subheader(sub)
				for s in sub_items: _create_legend_item(s)

		# Snapshots usually don't have subcategories
		for s in cat_items:
			if s.subcategory == "": _create_legend_item(s, true)

func _get_series_in_group(cat: String) -> Array[ChartSeries]:
	var list: Array[ChartSeries] = []
	for s in managed_series: if s.category == cat: list.append(s)
	for s in snapshots: if s.category == cat: list.append(s)
	return list

func _add_legend_header(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.GOLD)
	#lbl.add_theme_font_size_override("font_size", 14)
	legend_list.add_child(lbl)

func _add_legend_subheader(text: String) -> void:
	var lbl = Label.new()
	lbl.text = "  > " + text
	lbl.modulate = Color(0.4, 0.7, 1.0)
	legend_list.add_child(lbl)

func _create_legend_item(series: ChartSeries, can_delete: bool = false) -> void:
	var item = SeriesLegendItem.new()
	legend_list.add_child(item)
	item.setup(series, can_delete)

	item.series_changed.connect(func():
		if series.channel_id != "":
			palette.update_channel_color(series.channel_id, series.color)
		_refresh_all()
	)

	item.snap_shot_taken.connect(_on_snapshot_requested)
	item.delete_requested.connect(func():
		snapshots.erase(series)
		_refresh_all()
	)

func _on_snapshot_requested(source: ChartSeries) -> void:
	var snap = source.copy()
	snap.category = CAT_SNAPSHOTS # Legend grouping
	snap.subcategory = ""
	snap.name = "Copy: " + source.name
	# snap.type is already copied from source via source.copy()
	snap.color = Color.from_hsv(randf(), 0.6, 0.8)
	snapshots.append(snap)
	_refresh_all()

# ==============================================================================
#  EXPORT LOGIC (FIXED)
# ==============================================================================

func _on_export_confirmed(path: String) -> void:
	# Determine which data source to export.
	# If BET Mode is active, we export the modified 3D/BET series.
	# Otherwise, we export the standard 2D airfoil polar.
	var export_source: AeroSeries = live_data_2d

	if settings_panel.active_config.is_bet_mode and live_data_3d:
		export_source = live_data_3d

	if not export_source:
		printerr("Export failed: No data source available.")
		return

	var m = sim_panel.input_mach.value
	var r = sim_panel.input_re.value

	if path.ends_with(".csv"):
		AeroExporter.export_csv(path, export_source, current_profile, m, r)
	else:
		AeroExporter.export_xfoil(path, export_source, current_profile, m, r)

# ==============================================================================
#  HELPERS
# ==============================================================================

func _on_profile_loaded(profile: AirfoilProfile) -> void:
	current_profile = profile
	managed_series.clear()
	force_vis.set_profile_geometry(profile)
	aero_ray_visualizer.set_profile(profile)
	geo_view.clear_series()
	var up = ChartSeries.new(); up.name = "Upper"; up.points = profile.upper_surface; up.color = Color.WEB_GREEN
	var lo = ChartSeries.new(); lo.name = "Lower"; lo.points = profile.lower_surface; lo.color = Color.YELLOW_GREEN
	geo_view.add_series_resource(up); geo_view.add_series_resource(lo)

	_refresh_all()

func _setup_reference_data() -> void:
	ref_series = ChartSeries.new()
	ref_series.name = "Reference"
	ref_series.points = NACA632012LiftCurve.new().NACA0012_WINDTUNNEL
	ref_series.color = palette.ref
	ref_series.visible = false

func _refresh_all() -> void:
	sim_panel.emit_change()

func _find_result_at_alpha(series: AeroSeries, target: float) -> AeroResult:
	if series.results.is_empty(): return null
	var closest = series.results[0]
	var min_diff = abs(closest.alpha - target)
	for r in series.results:
		var d = abs(r.alpha - target)
		if d < min_diff: min_diff = d; closest = r
	return closest

func _open_export_dialog(f, s) -> void:
	file_dialog.filters = [f]
	file_dialog.current_file = current_profile.name + s
	file_dialog.popup_centered_ratio(0.6)

func _update_live_visuals(alpha, mach, re, speed, dens, area, config) -> void:
	var geo = AirfoilGeometryAnalyzer.analyze(current_profile)
	var coeffs = AeroPhysicsModel.compute_coefficients(deg_to_rad(alpha), geo.alpha_0, geo, mach, re, config)
	var q = 0.5 * dens * pow(speed, 2)
	force_vis.update_visuals(alpha, coeffs, {"lift": coeffs.cl*q*area, "drag": coeffs.cd*q*area, "moment": coeffs.cm*q*area}, speed)
	var ld = coeffs.cl / coeffs.cd if abs(coeffs.cd) > 0.0001 else 0.0
	ld_ratio.text = "Alpha: %.1f° Cl: %.3f Cd: %.4f L/D: %.1f" % [alpha, coeffs.cl, coeffs.cd, ld]

func _update_stall_ui_sync(config: LutGenerator.GeneratorConfig) -> void:
	var geo = AirfoilGeometryAnalyzer.analyze(current_profile)
	var v_weight = smoothstep(config.physics.vortex_sweep_start, config.physics.vortex_sweep_full, config.sweep_deg)
	var bonus = config.physics.vortex_stall_shift_max * geo.vortex_potential * v_weight * config.vortex_intensity
	if has_node("%LblEffectiveStall"):
		get_node("%LblEffectiveStall").text = "Effective Stall: %.1f° (+%.1f° Vortex)" % [config.stall_angle_deg_fwd + bonus, bonus]

func _update_raw_data_tab(data_2d: AeroSeries, data_3d: AeroSeries):
	# Update both trees independently
	_populate_single_tree(tree_2d, data_2d, "2D Airfoil")
	_populate_single_tree(tree_3d, data_3d, "3D Finite Wing")

# Helper to fill rows and handle formatting
func _populate_single_tree(tree: Tree, series: AeroSeries, title_prefix: String):
	tree.clear()
	if not series:
		tree.columns = 1
		tree.create_item().set_text(0, "No Data Available")
		return

	tree.columns = 5
	tree.column_titles_visible = true

	var headers = ["Alpha", "Cl", "Cd", "Cm", "L/D"]
	for i in range(headers.size()):
		tree.set_column_title(i, headers[i])
		tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_CENTER)
		tree.set_column_expand(i, true)

	var root = tree.create_item()
	var current_alpha = sim_panel.input_alpha.value

	for r in series.results:
		var item = tree.create_item(root)
		item.set_text(0, "%.1f" % r.alpha)
		item.set_text(1, "%.4f" % r.cl)
		item.set_text(2, "%.5f" % r.cd)
		item.set_text(3, "%.4f" % r.cm)

		var ld = (r.cl / r.cd) if abs(r.cd) > 0.0001 else 0.0
		item.set_text(4, "%.2f" % ld if abs(r.cd) > 0.0001 else "--")

		for i in range(5):
			item.set_text_alignment(i, HORIZONTAL_ALIGNMENT_CENTER)

		# Stall Warning (Sigma)
		if r.sigma < 0.5:
			item.set_custom_color(0, Color.INDIAN_RED)
			item.set_tooltip_text(0, "Stall Condition (Sigma < 0.5)")

		# Highlight Live Row & Auto-Scroll
		if abs(r.alpha - current_alpha) < 0.1:
			for i in range(5):
				item.set_custom_bg_color(i, Color(0.2, 0.4, 0.6, 0.4))
			tree.scroll_to_item(item) # This keeps the active row in view!

func _on_tree_gui_input(event: InputEvent, tree: Tree):
	if event is InputEventKey and event.pressed:
		# Check for Ctrl + C
		if event.keycode == KEY_C and event.ctrl_pressed:
			var selected = tree.get_selected()
			if not selected: return

			# Build a tab-separated string for Excel/Notepad
			var clipboard_text = ""
			for i in range(tree.columns):
				clipboard_text += selected.get_text(i) + "\t"

			DisplayServer.clipboard_set(clipboard_text.strip_edges())
			print("Copied row to clipboard: ", clipboard_text)
