class_name AnalysisDashboardOLD extends Control

# --- Dependencies ---
@onready var settings_panel: GeneratorSettingsPanel = %LeftPanel
@onready var sim_panel: SimInputPanel = %SimulationControls
@onready var chart_2d: SimpleChart = %Chart2D
@onready var chart_polar: SimpleChart = %ChartPolar
@onready var legend_list = %SeriesLegendList
@onready var wing_visualizer: WingPlanformView = %WingPlanformView
@onready var force_vis: ForceVisualizer = %ForceVisualizer
@onready var geo_view: SimpleChart = %GeometryPreview
@onready var file_dialog: FileDialog = %SaveFileDialog

# --- Resources ---
var palette: AeroColorPalette = AeroColorPalette.new()

# --- Persistent State ---
var current_profile: AirfoilProfile
var live_series: AeroSeries      # The raw 2D physics data
var live_series_3d: AeroSeries   # The raw 3D physics data
var snapshots_alpha_coeff: Array[ChartSeries] = []
var snapshots_polar: Array[ChartSeries] = []
var ref_series: ChartSeries

# This map stores the visual ChartSeries objects (CL, CD, etc.)
# so that their Color and Visibility settings are NOT lost during updates.
var visual_series_map: Dictionary = {}

# Constants
const M_BEST_GLIDE = "Best Glide"
const M_MIN_SINK = "Min Sink"
const M_LIVE = "Pos"

var marker_visibility_cache: Dictionary = {} # Key: "SeriesName_MarkerName", Value: bool



func _ready() -> void:
	_setup_reference_data()
	_connections()
	call_deferred("_initial_load")

func _initial_load():
	if settings_panel.opt_profile.item_count > 0:
		settings_panel.on_profile_selected(0)

func _connections() -> void:
	settings_panel.profile_loaded.connect(_on_profile_loaded)
	settings_panel.config_updated.connect(func(_cfg): _refresh_all())
	sim_panel.parameters_changed.connect(_on_sim_params_changed)

	%BtnExportCSV.pressed.connect(func(): _open_export_dialog("*.csv", "_lut.csv"))
	%BtnExportXFoil.pressed.connect(func(): _open_export_dialog("*.pol", "_xfoil.pol"))
	file_dialog.file_selected.connect(_on_export_confirmed)

	#%BtnSnapshot.pressed.connect(_on_snapshot_pressed)

# ==============================================================================
#  PIPELINE: DATA -> SERIES -> CHARTS
# ==============================================================================

func _on_sim_params_changed(alpha, mach, re, speed, dens, area, start, end):
	if not current_profile: return
	var config = settings_panel.active_config
	config.preview_mach = mach; config.preview_re = re
	LutGenerator.preview_alpha_start_deg = start; LutGenerator.preview_alpha_end_deg = end

	_update_charts(config)
	_update_live_visuals(alpha, mach, re, speed, dens, area, config)
# ==============================================================================
#  CORE UPDATE PIPELINE
# ==============================================================================

func _update_charts(config: LutGenerator.GeneratorConfig):
	if not current_profile: return

	# 1. Generate Raw Physics Data (The "Thick" Logic)
	var config_2d = config.clone()
	config_2d.is_finite_wing = false; config_2d.is_bet_mode = false
	live_series = LutGenerator.calculate_preview_series(current_profile, config_2d)
	live_series.name += " (2D)"

	live_series_3d = null

	if config.is_finite_wing or config.is_bet_mode:
		live_series_3d = LutGenerator.calculate_preview_series(current_profile, config)

	# 2. Sync Visual Series (Update points/markers without losing color/visibility)
	_sync_all_visual_series(config)

	# 3. Push to Charts
	chart_2d.clear_series()
	chart_polar.clear_series()

	# Add Reference
	chart_2d.add_series_resource(ref_series)

	# Add everything from the map to the correct charts
	for key in visual_series_map.keys():
		var s = visual_series_map[key]
		if "Polar" in key:
			chart_polar.add_series_resource(s)
		else:
			chart_2d.add_series_resource(s)

	# Add Snapshots
	for snap in snapshots_alpha_coeff:
		chart_2d.add_series_resource(snap)
	for snap in snapshots_polar:
		chart_polar.add_series_resource(snap)
	# 4. UI Updates
	_rebuild_legend_ui()
	wing_visualizer.update_geometry(config.aspect_ratio, config.taper, config.sweep_deg, config.sweep_location)
	_update_stall_ui_sync(config)

func _sync_all_visual_series(config: LutGenerator.GeneratorConfig):
	# Define the channels we want to see in the legend/charts
	var channels = [
		{"id": "CL", "var": "cl", "col": palette.cl},
		{"id": "CD", "var": "cd", "col": palette.cd},
		{"id": "CM", "var": "cm", "col": palette.cm},
		{"id": "Sigma", "var": "sigma", "col": palette.sigma}
	]

	# Update 2D Channels
	for c in channels:
		_update_visual_series("2D_" + c.id, live_series, c.var, c.col, 1.0)

	# Update 3D Channels (Only if active)
	if live_series_3d:
		for c in channels:
			_update_visual_series("3D_" + c.id, live_series_3d, c.var, c.col, 0.5)
	else:
		# Remove 3D from map if disabled so they vanish from legend
		var keys_to_remove = []
		for k in visual_series_map.keys(): if "3D_" in k: keys_to_remove.append(k)
		for k in keys_to_remove: visual_series_map.erase(k)

	# Update Polar Channels
	_update_polar_series("2D_Polar", live_series, palette.polar, 1.0)
	if live_series_3d:
		_update_polar_series("3D_Polar", live_series_3d, palette.polar, 0.5)
	else:
		visual_series_map.erase("2D_Polar_3D") # Cleanup

# --- Updated Helper: Add Marker with Cache Persistence ---
func _add_marker_to_series(series: ChartSeries, m_name: String, x: float, y: float, col: Color, fill: bool = true):
	var m = series.add_marker(m_name, x, y, col, fill)

	# Create a unique key for this specific marker in this specific series
	var cache_key = series.name + "_" + m_name

	# If we have a saved preference, apply it. Otherwise, default to true.
	if marker_visibility_cache.has(cache_key):
		m.visible = marker_visibility_cache[cache_key]
	else:
		marker_visibility_cache[cache_key] = m.visible

# --- Updated _update_visual_series ---
func _update_visual_series(key: String, source: AeroSeries, y_var: String, def_col: Color, alpha_mod: float):
	if not visual_series_map.has(key):
		var new_s = AeroSeries.new()
		new_s.type = "ALPHA_COEF"
		new_s.name = source.name + " " + y_var.to_upper()
		new_s.color = def_col
		new_s.color.a = alpha_mod
		#new_s.visible = source.visible
		visual_series_map[key] = new_s

	var s = visual_series_map[key]
	s.points = source.get_points_for_axes("alpha", y_var)

	s.clear_markers()
	var live_res = _find_result_at_alpha(source, sim_panel.input_alpha.value)
	if live_res:
		# Use the new cached helper instead of s.add_marker directly
		_add_marker_to_series(s, M_LIVE, live_res.alpha, live_res.get(y_var), Color.WHITE, false)

# --- Updated _update_polar_series ---
func _update_polar_series(key: String, source: AeroSeries, def_col: Color, alpha_mod: float):
	if not visual_series_map.has(key):
		var new_s = AeroSeries.new()
		new_s.name = source.name + " Polar"
		new_s.type = "POLAR"
		new_s.color = def_col
		new_s.color.a = alpha_mod
		#new_s.visible = source.visible
		visual_series_map[key] = new_s

	var s = visual_series_map[key]
	s.points = source.get_points_for_axes("cd", "cl")

	s.clear_markers()
	var metrics = AeroPostProcessor.find_efficiency_markers(source)
	if metrics.best_glide:
		_add_marker_to_series(s, M_BEST_GLIDE, metrics.best_glide.cd, metrics.best_glide.cl, palette.best_glide)
	if metrics.min_sink:
		_add_marker_to_series(s, M_MIN_SINK, metrics.min_sink.cd, metrics.min_sink.cl, palette.min_sink)

	var live_res = _find_result_at_alpha(source, sim_panel.input_alpha.value)
	if live_res:
		_add_marker_to_series(s, M_LIVE, live_res.cd, live_res.cl, Color.WHITE, false)

# ==============================================================================
#  LEGEND UI
# ==============================================================================
func _rebuild_legend_ui():
	# We only rebuild if the number of items changed to avoid UI flickering
	var total_count = visual_series_map.size() + snapshots_alpha_coeff.size() +snapshots_polar.size() + 1 # +1 for Ref
	if legend_list.get_child_count() == total_count: return

	for child in legend_list.get_children(): child.queue_free()

	# 1. Add Reference
	_create_legend_item(ref_series)

	# 2. Add Live/3D Series from Map (Sorted)
	var keys = visual_series_map.keys()
	keys.sort()
	for k in keys:
		_create_legend_item(visual_series_map[k])

	# 3. Add Snapshots
	for snap in snapshots_alpha_coeff:
		_create_legend_item(snap, true)

	for snap in snapshots_polar:
		_create_legend_item(snap, true)


func _create_legend_item(series: ChartSeries, can_delete: bool = false):
	var item = SeriesLegendItem.new()
	legend_list.add_child(item)
	item.setup(series, can_delete)
	item.snap_shot_taken.connect(_on_snap_shot_taken)
	item.series_changed.connect(func(): _refresh_all())
	item.delete_requested.connect(func():
		if series in snapshots_alpha_coeff: snapshots_alpha_coeff.erase(series)
		if series in snapshots_polar: snapshots_polar.erase(series)
		_refresh_all()
	)

func _on_snap_shot_taken(chart: String, series:AeroSeries):
	var snapshots: Array[ChartSeries]
	if chart == "ALPHA_COEF":
		snapshots = snapshots_alpha_coeff.duplicate(true)
	elif chart == "POLAR":
		snapshots = snapshots_polar.duplicate(true)
	var snap = ChartSeries.new()
	snap.name = "Snap: " + series.name + " (" + str(snapshots.size()+1) + ")"
	snap.points = series.points
	snap.color = Color.from_hsv(randf(), 0.6, 0.8)
	if chart == "ALPHA_COEF":
		snapshots_alpha_coeff.append(snap)
	elif chart == "POLAR":
		snapshots_polar.append(snap)

	_refresh_all()

# ==============================================================================
#  HELPERS
# ==============================================================================

func _on_export_confirmed(path: String):
	if not live_series: return
	var m = sim_panel.input_mach.value
	var r = sim_panel.input_re.value
	if path.ends_with(".csv"):
		AeroExporter.export_csv(path, live_series, current_profile, m, r)
	else:
		AeroExporter.export_xfoil(path, live_series, current_profile, m, r)

func _find_result_at_alpha(series: AeroSeries, target: float) -> AeroResult:
	if series.results.is_empty(): return null
	var closest = series.results[0]
	var min_diff = abs(closest.alpha - target)
	for r in series.results:
		var d = abs(r.alpha - target)
		if d < min_diff: min_diff = d; closest = r
	return closest

func _on_profile_loaded(profile: AirfoilProfile):
	current_profile = profile
	visual_series_map.clear() # Reset visual settings for new profile
	force_vis.set_profile_geometry(profile)

	# Update Airfoil Preview
	geo_view.clear_series()
	var up = ChartSeries.new(); up.name = "Upper"; up.points = profile.upper_surface; up.color = Color.WEB_GREEN
	var lo = ChartSeries.new(); lo.name = "Lower"; lo.points = profile.lower_surface; lo.color = Color.YELLOW_GREEN
	geo_view.add_series_resource(up); geo_view.add_series_resource(lo)

	_refresh_all()

func _setup_reference_data():
	ref_series = ChartSeries.new()
	ref_series.name = "NACA 0012 Ref"
	ref_series.points = NACA632012LiftCurve.new().NACA0012_WINDTUNNEL
	ref_series.color = palette.ref
	ref_series.visible = false

func _refresh_all():
	sim_panel.emit_change()

func _open_export_dialog(f, s):
	file_dialog.filters = [f]; file_dialog.current_file = current_profile.name + s; file_dialog.popup_centered_ratio(0.6)

func _update_live_visuals(alpha, mach, re, speed, dens, area, config):
	var geo = AirfoilGeometryAnalyzer.analyze(current_profile)
	var coeffs = AeroPhysicsModel.compute_coefficients(deg_to_rad(alpha), geo.alpha_0, geo, mach, re, config)
	var q = 0.5 * dens * pow(speed, 2)
	force_vis.update_visuals(alpha, coeffs, {"lift": coeffs.cl*q*area, "drag": coeffs.cd*q*area, "moment": coeffs.cm*q*area}, speed)

func _update_stall_ui_sync(config: LutGenerator.GeneratorConfig):
	var geo = AirfoilGeometryAnalyzer.analyze(current_profile)
	var v_weight = smoothstep(config.physics.vortex_sweep_start, config.physics.vortex_sweep_full, config.sweep_deg)
	var bonus = config.physics.vortex_stall_shift_max * geo.vortex_potential * v_weight * config.vortex_intensity

	# Note: We do NOT change the SpinBox value (input).
	# We update a label to show the RESULT of the physics.
	if has_node("%LblEffectiveStall"):
		get_node("%LblEffectiveStall").text = "Effective Stall: %.1f° (+%.1f° Vortex)" % [config.stall_angle_deg_fwd + bonus, bonus]


func _update_live_visuals(alpha: float, mach: float, re: float, speed: float, dens: float, area: float, config: LutGenerator.GeneratorConfig):
	# Guard: Safety check
	if not current_profile: return

	var geo = AirfoilGeometryAnalyzer.analyze(current_profile)
	var coeffs = AeroPhysicsModel.compute_coefficients(deg_to_rad(alpha), geo.alpha_0, geo, mach, re, config)

	var q = 0.5 * dens * pow(speed, 2)
	var forces = {
		"lift": coeffs.cl * q * area,
		"drag": coeffs.cd * q * area,
		"moment": coeffs.cm * q * area
	}

	force_vis.update_visuals(alpha, coeffs, forces, speed)
	var ld = coeffs.cl / coeffs.cd if abs(coeffs.cd) > 0.0001 else 0.0
	%ld_ratio.text = "Alpha: %.1f° Cl: %.3f Cd: %.4f L/D: %.1f" % [alpha, coeffs.cl, coeffs.cd, ld]

func _update_raw_data_tab(series: AeroSeries):
	raw_data_tree.clear()
	var root = raw_data_tree.create_item()
	raw_data_tree.set_column_title(0, "Alpha (°)"); raw_data_tree.set_column_title(1, "Cl")
	raw_data_tree.set_column_title(2, "Cd"); raw_data_tree.set_column_title(3, "Cm")
	raw_data_tree.set_column_title(4, "L/D")

	for r in series.results:
		var item = raw_data_tree.create_item(root)
		item.set_text(0, "%.1f" % r.alpha)
		item.set_text(1, "%.4f" % r.cl)
		item.set_text(2, "%.5f" % r.cd)
		item.set_text(3, "%.4f" % r.cm)
		item.set_text(4, "%.1f" % (r.cl/r.cd) if abs(r.cd) > 0.0001 else "--")
		if r.sigma < 0.5: item.set_custom_color(0, Color.INDIAN_RED)
