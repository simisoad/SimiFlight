class_name GeneratorSettingsPanel extends PanelContainer

signal profile_loaded(profile: AirfoilProfile)
signal config_updated(config: LutGenerator.GeneratorConfig)

var active_config: LutGenerator.GeneratorConfig = LutGenerator.GeneratorConfig.new()
var current_profile: AirfoilProfile
var _profile_paths: Dictionary = {}
var custom_json_dir: String = ""

# UI References
@onready var opt_profile: OptionButton = %ProfileSelector
@onready var input_output_name: LineEdit = %OutputName
@onready var btn_generate: Button = %GenerateFullLUT
@onready var lbl_state: Label = %StateLabelInfo
@onready var check_export_json: CheckBox = %CheckExportJson
@onready var check_export_tres: CheckBox = %CheckExportTres
@onready var line_json_path: LineEdit = %JsonPathDisplay
@onready var btn_select_path: SquareButton = %BtnSelectPath
@onready var folder_dialog: FileDialog = %FolderDialog

# Configuration Inputs
@onready var input_stall_fwd: SpinBox = %StallAngleFwd
@onready var input_stall_bwd: SpinBox = %StallAngleBwd
@onready var input_sharpness: SpinBoxExtended = %Sharpness
@onready var vortex_intensity: SpinBox = %VortexIntensity
@onready var input_sweep: SpinBox = %InputSweep
@onready var input_taper: SpinBox = %InputTaper
@onready var input_sweep_location: SpinBox = %InputSweepLocation
@onready var input_ar: SpinBox = %InputAR
@onready var input_eff: SpinBox = %InputEff
@onready var input_bet_mode: CheckBox = %BETMode
@onready var input_finite_wing: CheckBox = %ShowFiniteWing
@onready var input_wing_span: SpinBox = %InputWingSpan
@onready var input_area: SpinBoxExtended = %WingAreaSpinBox

func _ready() -> void:
	_refresh_profile_list()
	_setup_connections()
	_init_default_values()
	_setup_expert_settings()

	#if opt_profile.item_count > 0:
		#on_profile_selected(0)

func _setup_connections() -> void:
	# Grouped connection for all physics-altering inputs
	var config_inputs = [
		input_stall_fwd, input_stall_bwd, input_sharpness,
		input_sweep, input_taper, input_sweep_location,
		input_ar, input_eff, vortex_intensity
	]
	for input in config_inputs:
		input.value_changed.connect(func(_v): _sync_and_emit())

	input_bet_mode.toggled.connect(func(_v): _sync_and_emit())
	input_finite_wing.toggled.connect(func(_v): _sync_and_emit())

	# Special handling for Span/AR link
	input_wing_span.value_changed.connect(_on_wing_span_changed)
	input_ar.value_changed.connect(_on_ar_changed)
	input_area.value_changed.connect(_on_area_changed)

	opt_profile.item_selected.connect(on_profile_selected)
	btn_generate.pressed.connect(_on_generate_full_lut_pressed)
	EventBus.reanalyze_requested.connect(_sync_and_emit)

	btn_select_path.pressed.connect(func(): folder_dialog.popup_centered_ratio(0.6))
	folder_dialog.dir_selected.connect(func(dir): custom_json_dir = dir; line_json_path.text = dir)

func _sync_and_emit() -> void:
	# Update the data object from UI
	active_config.stall_angle_deg_fwd = input_stall_fwd.value
	active_config.stall_angle_deg_bwd = input_stall_bwd.value
	active_config.sharpness = input_sharpness.value
	active_config.is_bet_mode = input_bet_mode.button_pressed
	active_config.is_finite_wing = input_finite_wing.button_pressed
	active_config.vortex_intensity = vortex_intensity.value
	active_config.taper = input_taper.value
	active_config.sweep_location = input_sweep_location.value
	active_config.sweep_deg = input_sweep.value
	active_config.aspect_ratio = input_ar.value
	active_config.oswald_efficiency = input_eff.value

	# Recalc Oswald automatically
	var est_e = AeroPhysicsModel.estimate_oswald(active_config.aspect_ratio, active_config.taper, active_config.sweep_deg)
	input_eff.set_value_no_signal(est_e)
	active_config.oswald_efficiency = est_e

	config_updated.emit(active_config)
#AR = Span² / Wing Area
func _on_wing_span_changed(span: float) -> void:
	# area = span^2 / ar
	input_area.value = (span * span) / input_ar.value
	input_ar.value = (span * span) / input_area.value


func _on_area_changed(area: float) -> void:
	input_wing_span.value = sqrt(input_ar.value * input_area.value)
	input_ar.value = (input_wing_span.value*input_wing_span.value) / area

func _on_ar_changed(ar: float) -> void:
	input_area.value = (input_wing_span.value*input_wing_span.value) / input_ar.value
	input_wing_span.value = sqrt(ar * input_area.value)

func on_profile_selected(index: int) -> void:
	var id = opt_profile.get_item_id(index)
	if not _profile_paths.has(id): return

	var profile = AirfoilProfile.new()
	if profile.load_from_dat(_profile_paths[id]):
		current_profile = profile
		var geo = AirfoilGeometryAnalyzer.analyze(profile)

		# Update UI with analyzed defaults
		input_stall_fwd.value = geo.stall_angle_fwd
		input_stall_bwd.value = geo.stall_angle_back

		profile_loaded.emit(profile)
		_sync_and_emit()

func _init_default_values() -> void:
	var d = AeroPhysicsConfig.new()
	input_stall_fwd.min_value = d.stall_min_deg_fwd
	input_stall_fwd.max_value = d.stall_max_cap_deg_fwd
	input_stall_bwd.min_value = d.stall_min_deg_bwd
	input_stall_bwd.max_value = d.stall_max_cap_deg_bwd

func _setup_expert_settings() -> void:
	%DragAndMoment.setup_panel(active_config.physics)
	%BuffetNoise.setup_panel(active_config.physics)
	%PlateLift.setup_panel(active_config.physics)
	%StallBehavior.setup_panel(active_config.physics)
	%SuctionSpikeAndCrash.setup_panel(active_config.physics)
	%AbnormalGeometry.setup_panel(active_config.physics)
	%CompressibilityMachEffects.setup_panel(active_config.physics)

func _refresh_profile_list():
	opt_profile.clear(); _profile_paths.clear()
	_scan_directory("res://data/airfoils/", "[Built-in] ", 0)
	_scan_directory(FileSystemHandler.get_user_airfoil_dir(), "", opt_profile.item_count)

func _scan_directory(path: String, prefix: String, start_id: int):
	var dir = DirAccess.open(path)
	if not dir: return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var current_id = start_id
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".dat") or file_name.ends_with(".txt")):
			opt_profile.add_item(prefix + file_name, current_id)
			_profile_paths[current_id] = path.path_join(file_name)
			current_id += 1
		file_name = dir.get_next()

func _on_generate_full_lut_pressed():
	if not current_profile: return
	btn_generate.disabled = true
	lbl_state.text = "Generating..."
	await get_tree().process_frame

	var lut = LutGenerator.generate_lut(current_profile, active_config)
	var target_dir = custom_json_dir if not custom_json_dir.is_empty() else FileSystemHandler.get_user_data_root()
	var fname = input_output_name.text.get_basename()

	if check_export_json.button_pressed:
		LutJSONExporter.save_lut_as_json(lut, target_dir.path_join(fname + ".json"))
	if check_export_tres.button_pressed:
		LutGenerator.save_lut(lut, target_dir.path_join(fname + ".tres"))

	lbl_state.text = "Export Complete"
	btn_generate.disabled = false
